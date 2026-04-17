//
//  MusicMindAIApp.swift
//  MusicMindAI
//
//  Created by Alan R on 03.02.2026.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct MusicMindAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "selected_theme") ?? "") ?? .cyberpunk
            WindowManager.shared.setupWindowBackground(color: ThemeSpec.spec(for: theme).windowBackgroundUIColor)
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .background(
                    themeManager.currentSpec.backgroundGradient
                        .ignoresSafeArea(.all, edges: .all)
                )
                .task {
                    await WindowManager.shared.setupWindowBackgroundAsync(color: themeManager.currentSpec.windowBackgroundUIColor)
                }
                .onAppear {
                    WindowManager.shared.setupWindowBackground(color: themeManager.currentSpec.windowBackgroundUIColor)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
