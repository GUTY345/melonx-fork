//
//  M3GameProfile.swift
//  MeloNX
//
//  Per-game mobile performance profiles optimized for the first target devices.
//

import Foundation

enum MobileDevicePerformanceClass: String, Codable {
    case iPhone16Plus
    case iPadAirM3
    case iPadAppleSilicon
    case iPhoneA18
    case other
    
    static var current: MobileDevicePerformanceClass {
        let identifier = UIDevice.modelIdentifier
        let displayName = UIDevice.modelName
        let combined = "\(identifier) \(displayName)".lowercased()
        
        if combined.contains("iphone 16 plus") || identifier == "iPhone17,4" {
            return .iPhone16Plus
        }
        
        if combined.contains("ipad air") && combined.contains("m3") {
            return .iPadAirM3
        }
        
        if combined.contains("iphone 16") || combined.contains("a18") {
            return .iPhoneA18
        }
        
        if combined.contains("ipad") && (combined.contains("m1") || combined.contains("m2") || combined.contains("m3") || combined.contains("m4")) {
            return .iPadAppleSilicon
        }
        
        return .other
    }
    
    var defaultProfile: MobileGameProfile {
        switch self {
        case .iPhone16Plus:
            return MobileGameProfile(
                id: defaultProfileId,
                resScale: 0.8,
                maxAnisotropy: 4,
                disablePTC: false,
                expandRam: false,
                thermalStabilityProfile: true,
                notes: "iPhone 16 Plus baseline: A18 6-core CPU, 5-core GPU, 60Hz display"
            )
        case .iPadAirM3:
            return MobileGameProfile(
                id: defaultProfileId,
                resScale: 0.9,
                maxAnisotropy: 8,
                disablePTC: false,
                expandRam: false,
                thermalStabilityProfile: true,
                notes: "iPad Air M3 baseline: 8-core CPU, 9-core GPU, 8GB RAM"
            )
        case .iPadAppleSilicon:
            return MobileGameProfile(
                id: defaultProfileId,
                resScale: 0.85,
                maxAnisotropy: 4,
                disablePTC: false,
                expandRam: false,
                thermalStabilityProfile: true,
                notes: "Generic Apple Silicon iPad baseline"
            )
        case .iPhoneA18:
            return MobileGameProfile(
                id: defaultProfileId,
                resScale: 0.75,
                maxAnisotropy: 2,
                disablePTC: false,
                expandRam: false,
                thermalStabilityProfile: true,
                notes: "Generic A18 iPhone baseline"
            )
        case .other:
            return MobileGameProfile(
                id: defaultProfileId,
                resScale: 0.75,
                maxAnisotropy: 2,
                disablePTC: false,
                expandRam: false,
                thermalStabilityProfile: true,
                notes: "Safe generic mobile baseline"
            )
        }
    }
    
    var defaultProfileId: String {
        "\(rawValue).default"
    }
}

struct MobileGameProfile: Codable, Identifiable {
    let id: String
    var resScale: Double
    var maxAnisotropy: Float
    var disablePTC: Bool
    var expandRam: Bool
    var thermalStabilityProfile: Bool
    var notes: String
    
    static let iPhone16PlusPerformance = MobileGameProfile(
        id: "iPhone16Plus.performance",
        resScale: 0.7,
        maxAnisotropy: 2,
        disablePTC: false,
        expandRam: false,
        thermalStabilityProfile: true,
        notes: "Lower-power profile for sustained A18 gameplay"
    )
    
    static let iPadAirM3Quality = MobileGameProfile(
        id: "iPadAirM3.quality",
        resScale: 1.0,
        maxAnisotropy: 8,
        disablePTC: false,
        expandRam: false,
        thermalStabilityProfile: false,
        notes: "Higher visual quality profile for cool iPad Air M3 sessions"
    )
}

struct M3GameProfile: Codable, Identifiable {
    let id: String
    var resScale: Double
    var maxAnisotropy: Float
    var disablePTC: Bool
    var thermalStabilityProfile: Bool
    var notes: String
    
    static func `default`() -> M3GameProfile {
        M3GameProfile(
            id: "default",
            resScale: 1.0,
            maxAnisotropy: 0,
            disablePTC: false,
            thermalStabilityProfile: true,
            notes: "Default M3 profile"
        )
    }
    
    static let balanced = M3GameProfile(
        id: "balanced",
        resScale: 0.9,
        maxAnisotropy: 8.0,
        disablePTC: false,
        thermalStabilityProfile: true,
        notes: "Balanced quality and performance"
    )
    
    static let performance = M3GameProfile(
        id: "performance",
        resScale: 0.8,
        maxAnisotropy: 4.0,
        disablePTC: false,
        thermalStabilityProfile: true,
        notes: "Prioritizes framerate"
    )
    
    static let quality = M3GameProfile(
        id: "quality",
        resScale: 1.0,
        maxAnisotropy: 16.0,
        disablePTC: false,
        thermalStabilityProfile: false,
        notes: "Prioritizes visual fidelity"
    )
}

class M3ProfileManager: ObservableObject {
    static let shared = M3ProfileManager()
    
    private let profilesKey = "m3_game_profiles"
    private let defaultsKey = "m3_profile_default"
    
    @Published var profiles: [String: M3GameProfile] = [:]
    @Published var activeProfileId: String = "default"
    
    private var builtInProfiles: [String: M3GameProfile] = [
        "default": .default(),
        "balanced": .balanced,
        "performance": .performance,
        "quality": .quality
    ]
    
    init() {
        loadProfiles()
    }
    
    func loadProfiles() {
        var loaded: [String: M3GameProfile] = [:]
        
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([String: M3GameProfile].self, from: data) {
            loaded = decoded
        }
        
        if loaded.isEmpty {
            profiles = builtInProfiles
            saveProfiles()
        } else {
            profiles = loaded
        }
    }
    
    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }
    
    func profile(for titleId: String) -> M3GameProfile {
        return profiles[titleId] ?? profiles[titleId.lowercased()] ?? profiles["default"] ?? .default()
    }
    
    func setProfile(_ profile: M3GameProfile, for titleId: String) {
        profiles[titleId] = profile
        saveProfiles()
    }
    
    func resetProfile(for titleId: String) {
        profiles.removeValue(forKey: titleId)
        saveProfiles()
    }
    
    func resetAllProfiles() {
        profiles.removeAll()
        saveProfiles()
    }
    
    func applyProfile(_ profile: M3GameProfile, to config: inout Ryujinx.Arguments) {
        config.resscale = profile.resScale
        config.maxAnisotropy = Double(profile.maxAnisotropy)
        config.disablePTC = profile.disablePTC
        
        if profile.thermalStabilityProfile {
            if config.resscale > 1.0 {
                config.resscale = 1.0
            }
        }
    }
}

class MobileProfileManager: ObservableObject {
    static let shared = MobileProfileManager()
    
    private let profilesKey = "mobile_game_profiles_v1"
    
    @Published var profiles: [String: MobileGameProfile] = [:]
    
    private var builtInProfiles: [String: MobileGameProfile] {
        let currentDefault = MobileDevicePerformanceClass.current.defaultProfile
        return [
            currentDefault.id: currentDefault,
            MobileGameProfile.iPhone16PlusPerformance.id: .iPhone16PlusPerformance,
            MobileGameProfile.iPadAirM3Quality.id: .iPadAirM3Quality
        ]
    }
    
    init() {
        loadProfiles()
    }
    
    func loadProfiles() {
        var loaded: [String: MobileGameProfile] = [:]
        
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([String: MobileGameProfile].self, from: data) {
            loaded = decoded
        }
        
        profiles = builtInProfiles.merging(loaded) { _, custom in custom }
        saveProfiles()
    }
    
    func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }
    
    func profile(for titleId: String, deviceClass: MobileDevicePerformanceClass = .current) -> MobileGameProfile {
        let exactDeviceKey = "\(deviceClass.rawValue):\(titleId)"
        let lowerDeviceKey = "\(deviceClass.rawValue):\(titleId.lowercased())"
        
        return profiles[exactDeviceKey]
            ?? profiles[lowerDeviceKey]
            ?? profiles[titleId]
            ?? profiles[titleId.lowercased()]
            ?? profiles[deviceClass.defaultProfileId]
            ?? deviceClass.defaultProfile
    }
    
    func setProfile(_ profile: MobileGameProfile, for titleId: String, deviceClass: MobileDevicePerformanceClass = .current) {
        profiles["\(deviceClass.rawValue):\(titleId)"] = profile
        saveProfiles()
    }
    
    func resetProfile(for titleId: String, deviceClass: MobileDevicePerformanceClass = .current) {
        profiles.removeValue(forKey: "\(deviceClass.rawValue):\(titleId)")
        profiles.removeValue(forKey: "\(deviceClass.rawValue):\(titleId.lowercased())")
        saveProfiles()
    }
    
    func applyProfile(_ profile: MobileGameProfile, to config: inout Ryujinx.Arguments) {
        config.resscale = profile.resScale
        config.maxAnisotropy = Double(profile.maxAnisotropy)
        config.disablePTC = profile.disablePTC
        config.expandRam = profile.expandRam
        
        if profile.thermalStabilityProfile {
            config.resscale = min(config.resscale, 1.0)
        }
    }
}
