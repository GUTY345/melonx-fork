//
//  MetalView.swift
//  MeloNX
//
//  Created by Stossy11 on 09/02/2025.
//

import SwiftUI
import MetalKit
import Metal

struct MetalView: UIViewRepresentable {
    var airplay: Bool = Air.shared.connected
    @ObservedObject private var thermalGovernor = ThermalGovernor.shared
    
    func makeUIView(context: Context) -> UIView {
        return Self.createView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? MeloMTKView {
            let fpsCap = thermalGovernor.currentFPSPace
            switch fpsCap {
            case .fps30:
                view.preferredFramesPerSecond = 30
            case .fps60:
                view.preferredFramesPerSecond = 60
            case .unlimited:
                view.preferredFramesPerSecond = 0
            }
        }
    }
    
    @discardableResult
    static func createView() -> UIView {
        if Ryujinx.shared.emulationUIView == nil {
            let view = MeloMTKView()
            
            guard let metalLayer = view.layer as? CAMetalLayer else {
                fatalError("[Swift] Error: MTKView's layer is not a CAMetalLayer")
            }
            
            UIApplication.shared.isIdleTimerDisabled = true
            
            metalLayer.presentsWithTransaction = false
            metalLayer.allowsNextDrawableTimeout = false
            if #available(iOS 11.0, *) {
                metalLayer.maximumDrawableCount = 3
            }
            
            let stabilityProfile = UserDefaults.standard.object(forKey: "THERMAL_STABILITY_PROFILE") as? Bool ?? true
            view.preferredFramesPerSecond = stabilityProfile ? 30 : 60
            
            let framesSelector = NSSelectorFromString("setNominalFramesPerSecond:")
            
            if metalLayer.responds(to: framesSelector) {
                metalLayer.perform(framesSelector, with: NSNumber(value: stabilityProfile ? 30 : 60))
            }
            
            let setterSelector = NSSelectorFromString("setDisplaySyncEnabled:")
            
            if metalLayer.responds(to: setterSelector) {
                metalLayer.perform(setterSelector, with: NSNumber(value: stabilityProfile))
            }
            
            notnil(metalLayer.device) ? () : (metalLayer.device = MTLCreateSystemDefaultDevice())
            
            let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()
            
            RyujinxBridge.setNativeWindow(layerPtr)
            
            Ryujinx.shared.emulationUIView = view
            Ryujinx.shared.metalLayer = metalLayer
            return view
        }
        
        return Ryujinx.shared.emulationUIView!
    }
}
