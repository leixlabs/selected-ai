//
//  SettingsView.swift
//  selectedai
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }

            SkillsSettingsView()
                .tabItem { Label("技能", systemImage: "wand.and.stars") }

            ProviderSettingsView()
                .tabItem { Label("Provider", systemImage: "cpu") }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
