//
//  selectedaiApp.swift
//  selectedai
//
//  Created by lei on 2026/7/31.
//

import SwiftUI

@main
struct selectedaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app — no main window.
        // Settings window will be added in Milestone 9.
        Settings {
            EmptyView()
        }
    }
}
