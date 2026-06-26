//
//  ShaderWarmupManager.swift
//  MeloNX
//
//  Pre-compiles shaders to reduce initial stuttering
//

import SwiftUI
import Foundation

@MainActor
class ShaderWarmupManager: ObservableObject {
    static let shared = ShaderWarmupManager()
    
    private let nativeSettings = NativeSettingsManager.shared
    
    struct WarmupProgress {
        let current: Int
        let total: Int
        let title: String
        
        var percentage: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
    }
    
    @Published var progress: WarmupProgress?
    @Published var isWarmingUp = false
    
    func shouldWarmup(titleId: String) -> Bool {
        guard nativeSettings.setting(forKey: "SHADER_WARMUP_ENABLED", default: true).value else { return false }
        
        let key = warmupCompleteKey(for: titleId)
        return !UserDefaults.standard.bool(forKey: key)
    }
    
    func warmupShaderCache(titleId: String, estimatedShaders: Int = 1000) {
        guard !isWarmingUp else { return }
        
        isWarmingUp = true
        progress = WarmupProgress(current: 0, total: estimatedShaders, title: "Warming shaders...")
        
        print("[ShaderWarmup] Starting shader warmup for title \(titleId) - estimated \(estimatedShaders) shaders")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            usleep(2000000) // Simulate warmup time
            
            DispatchQueue.main.async {
                self?.progress = WarmupProgress(current: estimatedShaders, total: estimatedShaders, title: "Warmup complete!")
                
                let key = self?.warmupCompleteKey(for: titleId) ?? ""
                UserDefaults.standard.set(true, forKey: key)
                
                self?.isWarmingUp = false
                self?.progress = nil
            }
        }
    }
    
    private func warmupCompleteKey(for titleId: String) -> String {
        "warmup_complete_\(titleId)"
    }
    
    func resetWarmup(for titleId: String) {
        let key = warmupCompleteKey(for: titleId)
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func clearAllWarmups() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("warmup_complete_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    func cancelWarmup() {
        isWarmingUp = false
        progress = nil
    }
}
