//
//  WindowManager.swift
//  MusicMindAI
//
//  Централизованное управление настройкой окна
//

import UIKit
import SwiftUI

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    
    private init() {}
    
    func setupWindowBackground(color: UIColor? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        let bg = color ?? CyberpunkTheme.windowBackgroundUIColor
        windowScene.windows.forEach { window in
            window.backgroundColor = bg
        }
    }
    
    func setupWindowBackgroundAsync(color: UIColor? = nil) async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
        setupWindowBackground(color: color)
    }
}
