//
//  ThermalGovernor.swift
//  MeloNX
//
//  Real-time thermal management for iOS/iPadOS devices
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ThermalGovernor: ObservableObject {
    static let shared = ThermalGovernor()
    
    @Published var currentFPSPace: FPSPace = .unlimited
    @Published var thermalState: ThermalState = .nominal
    
    private var cancellables = Set<AnyCancellable>()
    private var fpsHistory: [UInt64] = []
    private var thermalStateHistory: [ThermalState] = []
    private let nativeSettings = NativeSettingsManager.shared
    private let fpsWindowSize = 30
    private let thermalHistoryWindow = 10
    private let thermalHysteresisThreshold = 6
    
    enum FPSPace: Int, CaseIterable {
        case fps30 = 30
        case fps45 = 45
        case fps60 = 60
        case unlimited = 0
        
        var description: String {
            switch self {
            case .fps30: return "30 FPS"
            case .fps45: return "45 FPS"
            case .fps60: return "60 FPS"
            case .unlimited: return "Unlimited"
            }
        }
    }
    
    enum ThermalState {
        case nominal, warm, warning, critical
        
        var description: String {
            switch self {
            case .nominal: return "Normal"
            case .warm: return "Warm"
            case .warning: return "Warming Up"
            case .critical: return "Hot"
            }
        }
    }
    
    func startMonitoring() {
        guard nativeSettings.setting(forKey: "THERMAL_GOVERNOR_ENABLED", default: true).value else { return }
        
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        updateThermalState()
    }
    
    func stopMonitoring() {
        cancellables.removeAll()
    }
    
    private func updateThermalState() {
        let measuredState: ThermalState
        
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            measuredState = .nominal
        case .fair:
            measuredState = .warm
        case .serious:
            measuredState = .warning
        case .critical:
            measuredState = .critical
        default:
            measuredState = .nominal
        }
        
        thermalStateHistory.append(measuredState)
        
        if thermalStateHistory.count > thermalHistoryWindow {
            thermalStateHistory.removeFirst(thermalStateHistory.count - thermalHistoryWindow)
        }
        
        let stabilizedState = resolveThermalState(measuredState)
        
        if thermalState != stabilizedState {
            thermalState = stabilizedState
            applyThermalProfile()
        }
    }
    
    private func resolveThermalState(_ measuredState: ThermalState) -> ThermalState {
        guard thermalStateHistory.count >= thermalHysteresisThreshold else {
            return measuredState
        }
        
        let recentStates = thermalStateHistory.suffix(thermalHysteresisThreshold)
        let isConsistent = recentStates.allSatisfy { $0 == measuredState }
        
        if !isConsistent {
            return thermalState
        }
        
        if isCoolingDown(to: measuredState) {
            return thermalState
        }
        
        return measuredState
    }
    
    private func isCoolingDown(to newState: ThermalState) -> Bool {
        let stateRank: [ThermalState: Int] = [
            .nominal: 0,
            .warm: 1,
            .warning: 2,
            .critical: 3
        ]
        
        guard let currentRank = stateRank[thermalState],
              let newRank = stateRank[newState] else {
            return false
        }
        
        if newRank >= currentRank {
            return false
        }
        
        let recentHistory = thermalStateHistory.suffix(thermalHistoryWindow / 2)
        let hasWarmReading = recentHistory.contains(.warm)
        let hasWarningReading = recentHistory.contains(.warning)
        
        if currentRank >= 2 && newRank == 0 {
            return !hasWarmReading && !hasWarningReading
        }
        
        return false
    }
    
    func recordFPS(_ fps: UInt64) {
        fpsHistory.append(fps)
        
        if fpsHistory.count > fpsWindowSize {
            fpsHistory.removeFirst(fpsHistory.count - fpsWindowSize)
        }
        
        evaluateFPSPace()
    }
    
    private func evaluateFPSPace() {
        let shouldCap30 = shouldCapAt30FPS()
        let shouldCap45 = shouldCapAt45FPS()
        let shouldCap60 = shouldCapAt60FPS()
        
        let newFPSPace: FPSPace
        if shouldCap30 {
            newFPSPace = .fps30
        } else if shouldCap45 {
            newFPSPace = .fps45
        } else if shouldCap60 {
            newFPSPace = .fps60
        } else {
            newFPSPace = .unlimited
        }
        
        if currentFPSPace != newFPSPace {
            currentFPSPace = newFPSPace
            applyFPSPace()
        }
    }
    
    private func shouldCapAt30FPS() -> Bool {
        guard thermalState == .critical else { return false }
        
        let avgFPS = Double(calculateAverageFPS())
        let variance = fpsHistory
            .map { Double($0) - avgFPS }
            .map { $0 * $0 }
            .reduce(0, +) / Double(fpsHistory.count)
        let hasHighVariance = variance > 25
        
        return avgFPS < 35 || hasHighVariance
    }
    
    private func shouldCapAt45FPS() -> Bool {
        guard thermalState == .warning else { return false }
        
        let avgFPS = Double(calculateAverageFPS())
        let variance = fpsHistory
            .map { Double($0) - avgFPS }
            .map { $0 * $0 }
            .reduce(0, +) / Double(fpsHistory.count)
        let hasHighVariance = variance > 25
        
        return avgFPS < 55 || hasHighVariance
    }
    
    private func shouldCapAt60FPS() -> Bool {
        guard thermalState == .nominal || thermalState == .warm else { return false }
        
        if thermalState == .warm {
            return calculateAverageFPS() < 55
        }
        
        return calculateAverageFPS() < 55
    }
    
    private func calculateAverageFPS() -> UInt64 {
        guard !fpsHistory.isEmpty else { return 60 }
        return fpsHistory.reduce(UInt64(0), +) / UInt64(fpsHistory.count)
    }
    
    private func applyThermalProfile() {
        switch thermalState {
        case .nominal:
            if nativeSettings.setting(forKey: "THERMAL_STABILITY_PROFILE", default: true).value {
                currentFPSPace = .fps60
            } else {
                currentFPSPace = .unlimited
            }
        case .warm:
            currentFPSPace = .fps60
        case .warning:
            currentFPSPace = .fps45
        case .critical:
            currentFPSPace = .fps30
        }
        
        applyFPSPace()
        print("[ThermalGovernor] Thermal state: \(thermalState.description), FPS cap: \(currentFPSPace.description)")
    }
    
    private func applyFPSPace() {
        NotificationCenter.default.post(
            name: .init("ThermalGovernorFPSPaceChanged"),
            object: currentFPSPace.rawValue
        )
    }
}
