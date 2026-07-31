//
//  MeloMTKView.swift
//  MeloNX
//
//  Created by Stossy11 on 03/03/2025.
//

import MetalKit
import UIKit

class MeloMTKView: MTKView {
    private var activeTouches: [UITouch] = []

    private var aspectRatio: AspectRatio = .fixed16x9

    func setAspectRatio(_ ratio: AspectRatio) {
        self.aspectRatio = ratio
        RyujinxBridge.setViewSize(width: Int(self.bounds.width), height: Int(self.bounds.height))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        for touch in touches {
            let location = touch.location(in: self)
            let index = activeTouches.count
            activeTouches.append(touch)
            RyujinxBridge.touchBegan(x: Float(location.x), y: Float(location.y), index: index)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            guard let touchIndex = activeTouches.firstIndex(of: touch) else {
                continue
            }
            
            RyujinxBridge.touchEnded(index: touchIndex)
            activeTouches.remove(at: touchIndex)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else { return }
        
        for touch in touches {
            guard let touchIndex = activeTouches.firstIndex(of: touch) else {
                continue
            }
            
            let location = touch.location(in: self)
            RyujinxBridge.touchMoved(x: Float(location.x), y: Float(location.y), index: touchIndex)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        let disabled = UserDefaults.standard.bool(forKey: "disableTouch")
        guard !disabled else {
            for touch in touches {
                if let index = activeTouches.firstIndex(of: touch) {
                    activeTouches.remove(at: index)
                }
            }
            return
        }
        
        for touch in touches {
            guard let touchIndex = activeTouches.firstIndex(of: touch) else {
                continue
            }
            
            RyujinxBridge.touchEnded(index: touchIndex)
            activeTouches.remove(at: touchIndex)
        }
    }
    

    func resetTouchTracking() {
        activeTouches.removeAll()
    }
}

