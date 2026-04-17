//
//  ThemeManager.swift
//  MusicMindAI
//
//  Централизованный менеджер темы с сохранением выбора в UserDefaults.
//

import SwiftUI
import Combine

private let selectedThemeKey = "selected_theme"

final class ThemeManager: ObservableObject {
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: selectedThemeKey)
        }
    }

    var currentSpec: ThemeSpec {
        ThemeSpec.spec(for: selectedTheme)
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: selectedThemeKey)
        self.selectedTheme = AppTheme(rawValue: raw ?? "") ?? .cyberpunk
    }

    func setTheme(_ theme: AppTheme) {
        selectedTheme = theme
    }
}
