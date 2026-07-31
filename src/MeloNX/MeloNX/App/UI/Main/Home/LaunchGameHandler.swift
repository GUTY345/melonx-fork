//
//  LaunchGameHandler.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import Combine
import Foundation
import SwiftUI

class LaunchGameHandler: ObservableObject {
    @Published var currentGame: Game? = nil {
        didSet {
            if currentGame == nil {
                isStartingGame = false
            }
        }
    }
    @Published var profileSelected = false
    @Published var showApp: Bool = true
    @Published var isPortrait: Bool = true
    @AppStorage("gametorun") var gametorun: String = ""
    @AppStorage("gametorun-date") var gametorunDate: String = ""
    
    static var succeededJIT: Bool = true
    
    private static let jitEntitlement = "com.apple.developer.kernel.increased-memory-limit"
    
    private let ryujinx = Ryujinx.shared
    private let nativeSettings = NativeSettingsManager.shared
    private let settingsManager = SettingsManager.shared
    private let persettings = PerGameSettingsManager.shared
    private let controllerManager = ControllerManager.shared
    private var isStartingGame = false
    
    private var config: Ryujinx.Arguments {
        settingsManager.config
    }
    
    private var hasJITEntitlement: Bool {
        ProcessInfo.processInfo.isiOSAppOnMac ? true : checkAppEntitlement(Self.jitEntitlement)
    }

    private var currentGameHasJIT: Bool {
        guard currentGame != nil else { return false }
        return nativeSettings.ignoreJIT.value || ryujinx.jitenabled
    }
    
    var isGameReady: Bool {
        currentGame != nil
            && currentGameHasJIT
            && (nativeSettings.showProfileonGame.value ? profileSelected : true)
    }
    
    var shouldLaunchGame: Bool {
        isGameReady && hasJITEntitlement
    }
    
    var shouldShowEntitlement: Bool {
        isGameReady && !hasJITEntitlement
    }
    
    var shouldShowPopover: Bool {
        currentGame != nil
            && ryujinx.jitenabled
            && !profileSelected
            && nativeSettings.showProfileonGame.value
            && hasJITEntitlement
    }
    
    var shouldCheckJIT: Bool {
        currentGame != nil
            && !ryujinx.jitenabled
            && !(nativeSettings.ignoreJIT.value as Bool)
            && hasJITEntitlement
            && currentGame?.isSystemApplet != true
    }
    
    
    
    func enableJIT() {
        guard let currentGame else { return }
        enableJIT(for: currentGame)
    }
    
    func enableJIT(for game: Game) {
        ryujinx.checkForJIT()
        print("Has TXM? \(ProcessInfo.processInfo.hasTXM)")
        
        if !ryujinx.jitenabled {
            if nativeSettings.useTrollStore.value {
                gametorunDate = "\(Date().timeIntervalSince1970)"
                gametorun = currentGame?.titleId ?? ""
                askForJIT()
            } else if nativeSettings.stikJIT.value {
                gametorunDate = "\(Date().timeIntervalSince1970)"
                gametorun = currentGame?.titleId ?? ""
                enableJITStik()
            } else {
                // nothing
            }
        }
    }
    
    @MainActor
    func startGame() {
        guard !isStartingGame, let currentGame else { return }
        isStartingGame = true
        
        configureEnvironmentVariables(for: currentGame)
        enableJIT(for: currentGame)
        
        guard ryujinx.jitenabled || nativeSettings.ignoreJIT.value else {
            isStartingGame = false
            return
        }
        
        MusicSelectorView.stopMusic()
        nativeSettings.isVirtualController.value = controllerManager.hasVirtualController()
        MetalView.createView()
        persettings.loadSettings()
        
        var config = persettings.config[currentGame.titleId] ?? self.config
        
        controllerManager.registerControllerTypeForMatchingControllers()
        if nativeSettings.setting(forKey: "MOBILE_PERFORMANCE_PROFILE", default: true).value {
            let thermalStability = nativeSettings.setting(forKey: "THERMAL_STABILITY_PROFILE", default: true).value
            config.normalizeForLaunch(thermalStability: thermalStability)
        }
        if currentGame.isSystemApplet {
            config.ignoreMissingServices = true
            config.disablePTC = true
            config.resscale = 1.0
        }
        
        let mobileProfile = MobileProfileManager.shared.profile(for: currentGame.titleId)
        MobileProfileManager.shared.applyProfile(mobileProfile, to: &config)
        
        if ShaderWarmupManager.shared.shouldWarmup(titleId: currentGame.titleId) {
            ShaderWarmupManager.shared.warmupShaderCache(titleId: currentGame.titleId)
        }
        
        AutoPerformanceGovernor.shared.startMonitoring(for: currentGame.titleId)
        ThermalGovernor.shared.startMonitoring()
        
        config.gamepath = currentGame.fileURL.path
        config.inputids = Array(Set(controllerManager.selectedControllers))
        
        if config.inputids.isEmpty {
            config.inputids.append("0")
        }
        
        print("Starting \(currentGame.isSystemApplet ? "system applet" : "game") \(currentGame.titleId) with path: \(config.gamepath)")
        print(config.inputids)
        
        do {
            try ryujinx.start(with: config)
        } catch {
            isStartingGame = false
            let diagnostic = CrashDiagnostic.analyzeCrash(errorMessage: error.localizedDescription, errorType: nil)
            print("[CrashDiagnostic] \(diagnostic.category): \(diagnostic.description)")
            ryujinx.lastCrashDiagnostic = diagnostic
            print("Failed to start game '\(currentGame.titleId)': \(error)")
        }
    }
    
    private func configureEnvironmentVariables(for game: Game) {
        let useDualMappedJIT: Bool
        if #available(iOS 19, *) {
            useDualMappedJIT = nativeSettings.setting(forKey: "DUAL_MAPPED_JIT", default: true).value
        } else {
            useDualMappedJIT = nativeSettings.setting(forKey: "DUAL_MAPPED_JIT", default: false).value
        }
        
        if useDualMappedJIT {
            setenv("DUAL_MAPPED_JIT", "1", 1)
            print("Launching \(game.isSystemApplet ? "system applet" : "game") \(game.titleId) with DUAL_MAPPED_JIT=1")
            Self.succeededJIT = RyujinxBridge.initialize_dualmapped()
        } else {
            setenv("DUAL_MAPPED_JIT", "0", 1)
            print("Launching \(game.isSystemApplet ? "system applet" : "game") \(game.titleId) with DUAL_MAPPED_JIT=0")
        }
        
        configureMoltenVKEnvironment()
    }
    
    private func configureMoltenVKEnvironment() {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", "1", 1)
            return
        }
        
        let supportsArgumentBuffersTier2 = device.argumentBuffersSupport.rawValue >= MTLArgumentBuffersTier.tier2.rawValue
        setenv("MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS", supportsArgumentBuffersTier2 ? "1" : "0", 1)
    }
}
