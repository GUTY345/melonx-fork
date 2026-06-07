//
//  SystemAppletLauncher.swift
//  MeloNX
//
//  Created by Codex on 07/06/2026.
//

import Foundation

enum SystemAppletLauncher {
    static let switchHomeTitleId = "0100000000001000"
    static let miiMakerTitleId = "0100000000001009"
    
    static func launchSwitchHome(using gameHandler: LaunchGameHandler, firmware: String = Ryujinx.shared.fetchFirmwareVersion()) {
        launch(
            titleName: "Switch Home",
            titleId: switchHomeTitleId,
            firmware: firmware,
            using: gameHandler
        )
    }
    
    static func launchMiiMaker(using gameHandler: LaunchGameHandler, firmware: String = Ryujinx.shared.fetchFirmwareVersion()) {
        launch(
            titleName: "Mii Maker",
            titleId: miiMakerTitleId,
            firmware: firmware,
            using: gameHandler
        )
    }
    
    private static func launch(titleName: String, titleId: String, firmware: String, using gameHandler: LaunchGameHandler) {
        guard gameHandler.currentGame == nil, !Ryujinx.shared.isRunning else {
            return
        }
        
        gameHandler.profileSelected = true
        gameHandler.currentGame = systemAppletGame(titleName: titleName, titleId: titleId, firmware: firmware)
    }
    
    private static func systemAppletGame(titleName: String, titleId: String, firmware: String) -> Game {
        let appletURL = URL(string: "0x\(titleId)")!
        
        return Game(
            containerFolder: URL(fileURLWithPath: "none"),
            fileType: .item,
            fileURL: appletURL,
            titleName: titleName,
            titleId: titleId,
            developer: "Nintendo",
            version: firmware
        )
    }
}
