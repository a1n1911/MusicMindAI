//
//  ThemeSwitcherView.swift
//  MusicMindAI
//
//  Переключатель темы в toolbar экрана «Сервисы».
//

import SwiftUI

struct ThemeSwitcherView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Menu {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button {
                    themeManager.setTheme(theme)
                } label: {
                    HStack {
                        Text(theme.displayName)
                        if themeManager.selectedTheme == theme {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 18))
                .foregroundStyle(themeManager.currentSpec.accent)
        }
    }
}
