//
//  ThermalGovernor.swift
//  MeloNX
//
//  Real-time thermal management for iOS devices
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
    private let nativeSettings = NativeSettingsManager.shared
    private let fpsWindowSize = 30
    
    enum FPSPace: Int, CaseIterable {
        case fps30 = 30
        case fps60 = 60
        case unlimited = 0
        
        var description: String {
            switch self {
            case .fps30: return "30 FPS"
            case .fps60: return "60 FPS"
            case .unlimited: return "Unlimited"
            }
        }
    }
    
    enum ThermalState {
        case nominal, warning, critical
        
        var description: String {
            switch self {
            case .nominal: return "Normal"
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
        let newThermalState: ThermalState
        
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            newThermalState = .nominal
        case .fair, .serious:
            newThermalState = .warning
        case .critical:
            newThermalState = .critical
        default:
            newThermalState = .nominal
        }
        
        if thermalState != newThermalState {
            thermalState = newThermalState
            applyThermalProfile()
        }
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
        let shouldCap60 = shouldCapAt60FPS()
        
        let newFPSPace: FPSPace
        if shouldCap30 {
            newFPSPace = .fps30
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
        guard thermalState == .critical || thermalState == .warning else { return false }
        
        let avgFPS = Double(calculateAverageFPS())
        let variance = fpsHistory
            .map { Double($0) - avgFPS }
            .map { $0 * $0 }
            .reduce(0, +) / Double(fpsHistory.count)
        let hasHighVariance = variance > 25
        
        return avgFPS < 35 || hasHighVariance
    }
    
    private func shouldCapAt60FPS() -> Bool {
        guard thermalState == .nominal else { return false }
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
        case .warning:
            currentFPSPace = .fps30
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
