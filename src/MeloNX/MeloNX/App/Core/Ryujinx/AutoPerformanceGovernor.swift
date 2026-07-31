//
//  AutoPerformanceGovernor.swift
//  MeloNX
//
//  Automatic performance scaling based on real FPS and thermal conditions
//

import Foundation
import Combine

@MainActor
class AutoPerformanceGovernor: ObservableObject {
    static let shared = AutoPerformanceGovernor()
    
    @Published var currentProfile: PerformanceProfile = .balanced
    @Published var fpsHistory: [UInt64] = []
    @Published var isGovernorActive: Bool = false
    @Published var thermalFPSCap: Int = 60
    
    private var cancellables = Set<AnyCancellable>()
    private let nativeSettings = NativeSettingsManager.shared
    private var currentTitleId: String?
    
    private let fpsWindowSize = 60
    private let lowFpsThreshold: UInt64 = 25
    private let criticalFpsThreshold: UInt64 = 15
    private let recoveryFpsThreshold: UInt64 = 35
    
    private var lastProfileAdjustment: Date = Date()
    private let minAdjustmentInterval: TimeInterval = 5.0
    
    enum PerformanceProfile: String, CaseIterable {
        case aggressive = "Aggressive"
        case balanced = "Balanced"
        case conservative = "Conservative"
        case powerSaving = "Power Saving"
    }
    
    struct ProfileSettings {
        let name: String
        let resScale: Double
        let maxAnisotropy: Float
        
        static let balanced = ProfileSettings(
            name: "Balanced",
            resScale: 0.8,
            maxAnisotropy: 8.0
        )
        
        static let conservative = ProfileSettings(
            name: "Conservative",
            resScale: 0.6,
            maxAnisotropy: 4.0
        )
        
        static let powerSaving = ProfileSettings(
            name: "Power Saving",
            resScale: 0.5,
            maxAnisotropy: 2.0
        )
    }
    
    struct ThermalMetrics {
        let averageFps: UInt64
        let minFps: UInt64
        let maxFps: UInt64
        let fpsVariance: Double
        let isThermalThrottling: Bool
        
        static let unknown = ThermalMetrics(
            averageFps: 0,
            minFps: 0,
            maxFps: 0,
            fpsVariance: 0,
            isThermalThrottling: false
        )
    }
    
    func startMonitoring(for titleId: String) {
        guard nativeSettings.setting(forKey: "AUTO_PERFORMANCE_PROFILE", default: true).value else { return }
        
        isGovernorActive = true
        fpsHistory.removeAll()
        currentTitleId = titleId
        
        NotificationCenter.default.publisher(for: .init("FPSUpdated"))
            .sink { [weak self] notification in
                guard let fps = notification.object as? UInt64 else { return }
                self?.updateWithFPS(fps, titleId: titleId)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .init("ThermalGovernorFPSPaceChanged"))
            .sink { [weak self] notification in
                guard let fpsCap = notification.object as? Int else { return }
                self?.thermalFPSCap = fpsCap
                self?.reactToThermalCap(fpsCap)
            }
            .store(in: &cancellables)
    }
    
    func stopMonitoring() {
        isGovernorActive = false
        cancellables.removeAll()
    }
    
    func updateWithFPS(_ fps: UInt64, titleId: String) {
        guard isGovernorActive else { return }
        
        fpsHistory.append(fps)
        
        if fpsHistory.count > fpsWindowSize {
            fpsHistory.removeFirst(fpsHistory.count - fpsWindowSize)
        }
        
        if Date().timeIntervalSince(lastProfileAdjustment) > minAdjustmentInterval {
            evaluateAndAdjustProfile()
        }
    }
    
    private func reactToThermalCap(_ fpsCap: Int) {
        guard isGovernorActive else { return }
        
        switch fpsCap {
        case 30:
            if currentProfile != .powerSaving {
                degradePerformance(to: .powerSaving, reason: "thermal cap 30 FPS")
            }
        case 45:
            if currentProfile == .aggressive || currentProfile == .balanced {
                degradePerformance(to: .conservative, reason: "thermal cap 45 FPS")
            }
        case 60:
            if currentProfile == .conservative || currentProfile == .powerSaving {
                recoverFromThermal()
            }
        default:
            break
        }
    }
    
    private func evaluateAndAdjustProfile() {
        guard fpsHistory.count >= 30 else { return }
        
        let metrics = calculateMetrics()
        
        if metrics.averageFps < criticalFpsThreshold {
            degradePerformance(to: nil, reason: "low performance")
            lastProfileAdjustment = Date()
        } else if metrics.averageFps < lowFpsThreshold && metrics.isThermalThrottling {
            degradePerformance(to: nil, reason: "low performance")
            lastProfileAdjustment = Date()
        } else if metrics.averageFps > recoveryFpsThreshold && currentProfile != .aggressive {
            recoverPerformance(metrics: metrics)
            lastProfileAdjustment = Date()
        }
    }
    
    private func calculateMetrics() -> ThermalMetrics {
        guard !fpsHistory.isEmpty else { return .unknown }
        
        let sum = fpsHistory.reduce(UInt64(0), +)
        let average = sum / UInt64(fpsHistory.count)
        let min = fpsHistory.min() ?? 0
        let max = fpsHistory.max() ?? 0
        
        let averageDouble = Double(average)
        let variance = fpsHistory.map { Double($0) - averageDouble }
            .map { $0 * $0 }
            .reduce(0, +) / Double(fpsHistory.count)
        
        let isThermalThrottling = variance > 25 && min < 10 && max > 40
        
        return ThermalMetrics(
            averageFps: average,
            minFps: min,
            maxFps: max,
            fpsVariance: variance,
            isThermalThrottling: isThermalThrottling
        )
    }
    
    private func degradePerformance(to target: PerformanceProfile? = nil, reason: String) {
        let previousProfile = currentProfile
        
        if let target {
            currentProfile = target
        } else {
            switch currentProfile {
            case .aggressive:
                currentProfile = .balanced
            case .balanced:
                currentProfile = .conservative
            case .conservative:
                currentProfile = .powerSaving
            case .powerSaving:
                break
            }
        }
        
        applyProfile(currentProfile)
        logProfileChange(from: previousProfile, to: currentProfile, reason: reason)
    }
    
    private func recoverPerformance(metrics: ThermalMetrics) {
        let previousProfile = currentProfile
        
        switch currentProfile {
        case .powerSaving:
            currentProfile = .conservative
        case .conservative:
            currentProfile = .balanced
        case .balanced:
            if metrics.averageFps > recoveryFpsThreshold + 20 {
                currentProfile = .aggressive
            }
        case .aggressive:
            break
        }
        
        applyProfile(currentProfile)
        logProfileChange(from: previousProfile, to: currentProfile, reason: "recovering performance")
    }
    
    private func recoverFromThermal() {
        let previousProfile = currentProfile
        
        switch currentProfile {
        case .powerSaving:
            currentProfile = .conservative
        case .conservative:
            currentProfile = .balanced
        case .balanced:
            currentProfile = .aggressive
        case .aggressive:
            break
        }
        
        applyProfile(currentProfile)
        logProfileChange(from: previousProfile, to: currentProfile, reason: "thermal recovery")
    }
    
    private func applyProfile(_ profile: PerformanceProfile) {
        let settings = profileSettings(for: profile)
        RyujinxBridge.updateGovernorSettings(
            resScale: settings.resScale,
            maxAnisotropy: settings.maxAnisotropy,
            disablePTC: profile != .aggressive
        )
    }
    
    private func profileSettings(for profile: PerformanceProfile) -> ProfileSettings {
        switch profile {
        case .aggressive: return ProfileSettings(name: "Aggressive", resScale: 1.0, maxAnisotropy: 16.0)
        case .balanced: return .balanced
        case .conservative: return .conservative
        case .powerSaving: return .powerSaving
        }
    }
    
    private func logProfileChange(from old: PerformanceProfile, to new: PerformanceProfile, reason: String) {
        print("[AutoPerformance] Profile: \(old.rawValue) → \(new.rawValue) (reason: \(reason))")
        
        NotificationCenter.default.post(
            name: .init("AutoPerformanceProfileChanged"),
            object: ["from": old.rawValue, "to": new.rawValue, "reason": reason]
        )
    }
    
    func getPerGameProfileKey(for titleId: String) -> String {
        "perf_profile_\(titleId)"
    }
    
    func setStoredProfile(_ profile: PerformanceProfile, for titleId: String) {
        UserDefaults.standard.set(profile.rawValue, forKey: getPerGameProfileKey(for: titleId))
    }
    
    func getStoredProfile(for titleId: String) -> PerformanceProfile? {
        guard let profileName = UserDefaults.standard.string(forKey: getPerGameProfileKey(for: titleId)) else {
            return nil
        }
        return PerformanceProfile(rawValue: profileName)
    }
}
