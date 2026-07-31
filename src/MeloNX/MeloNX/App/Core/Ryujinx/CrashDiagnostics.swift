//
//  CrashDiagnostics.swift
//  MeloNX
//
//  Categorizes crash causes for better troubleshooting
//

import SwiftUI
import Foundation

enum CrashDiagnostic: Equatable {
    case jitFailure(String)
    case memoryPressure(UInt64)
    case firmwareMissing(String)
    case dlcError(String)
    case appletFailure(String)
    case unknown(String)
    
    var category: String {
        switch self {
        case .jitFailure: return "JIT Failure"
        case .memoryPressure: return "Memory Pressure"
        case .firmwareMissing: return "Firmware Missing"
        case .dlcError: return "DLC Error"
        case .appletFailure: return "Applet Compatibility"
        case .unknown: return "Unknown"
        }
    }
    
    var description: String {
        switch self {
        case .jitFailure(let detail):
            return "JIT allocation failed: \(detail)\n\nCheck JIT method (StikDebug/StikJIT/TrollStore) and entitlements."
        case .memoryPressure(let usedMB):
            return "Memory pressure detected (using \(usedMB) MB)\n\nReduce resolution scale or enable Mobile Performance Profile."
        case .firmwareMissing(let version):
            return "Firmware version \(version) not properly installed or missing system content.\n\nRe-import firmware in Settings."
        case .dlcError(let detail):
            return "DLC error: \(detail)\n\nVerify DLC files match the game and are properly imported."
        case .appletFailure(let detail):
            return "System applet failed to load: \(detail)\n\nApplet compatibility is experimental. Ensure firmware is properly installed and try restarting the app."
        case .unknown(let error):
            return "Unknown error: \(error)\n\nCheck logs for details."
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .jitFailure:
            return "Try different JIT method, ensure increased-memory-limit entitlement, or use a sideloading method that supports JIT."
        case .memoryPressure:
            return "Lower resolution scale to 0.5x-0.7x, disable PTC temporarily, close other apps, or enable Low Power Mode."
        case .firmwareMissing:
            return "Import firmware in Setup or Settings → Firmware Manager. Ensure all system NCA files are present."
        case .dlcError:
            return "Remove and re-add the DLC file, verify the title ID matches the base game, or disable DLC temporarily."
        case .appletFailure:
            return "System applets are less tested than games. Try launching a regular game first, then return to try the applet again."
        case .unknown:
            return "Check the crash log and file an issue on GitHub with the error details."
        }
    }
    
    static func analyzeCrash(errorMessage: String, errorType: String? = nil) -> CrashDiagnostic {
        let msg = errorMessage.lowercased()
        let type = errorType?.lowercased() ?? ""
        
        if msg.contains("applet") || msg.contains("home menu") || msg.contains("system title") {
            return .appletFailure(errorMessage)
        }
        
        if msg.contains("jit") || msg.contains("dualmap") || msg.contains("mapped") ||
           msg.contains("breakpoint") || type.contains("jit") {
            return .jitFailure(errorMessage)
        }
        
        if msg.contains("memory") || msg.contains("out of memory") || msg.contains("malloc") ||
           msg.contains("oom") || errorType == "memory" {
            let used = ProcessInfo.processInfo.physicalMemory / 1024 / 1024
            return .memoryPressure(used)
        }
        
        if msg.contains("firmware") || msg.contains("bis") || msg.contains("system version") ||
           msg.contains("nca not found") {
            return .firmwareMissing(RyujinxBridge.installedFirmwareVersion)
        }
        
        if msg.contains("dlc") || msg.contains("add-on") || msg.contains("download") ||
           msg.contains("ticket") {
            return .dlcError(errorMessage)
        }
        
        return .unknown(errorMessage)
    }
}

struct CrashDiagnosticView: View {
    let diagnostic: CrashDiagnostic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(diagnostic.category)
                .font(.headline)
                .foregroundColor(.red)
            
            Text(diagnostic.description)
                .font(.subheadline)
            
            Text("Suggested fix:")
                .font(.caption)
                .bold()
            
            Text(diagnostic.recoverySuggestion)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}
