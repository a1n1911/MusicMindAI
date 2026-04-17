//
//  CyberpunkTheme.swift
//  MusicMindAI
//
//  Палитра и стили: семантические токены для Cyberpunk и Glass Aurora.
//

import SwiftUI
import UIKit

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case cyberpunk = "cyberpunk"
    case glassAurora = "glass_aurora"

    var displayName: String {
        switch self {
        case .cyberpunk: return "Cyberpunk"
        case .glassAurora: return "Glass Aurora"
        }
    }
}

// MARK: - Theme Spec (semantic tokens)

struct ThemeSpec {
    let backgroundGradient: LinearGradient
    let surface: Color
    let primary: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let accentGradient: LinearGradient
    let windowBackgroundUIColor: UIColor
    let cardBorderOpacity: Double
    let cardShadowRadius: CGFloat
    let cardShadowOpacity: Double

    static func spec(for theme: AppTheme) -> ThemeSpec {
        switch theme {
        case .cyberpunk: return Self.cyberpunk
        case .glassAurora: return Self.glassAurora
        }
    }

    // MARK: Cyberpunk
    private static let cyberpunk = ThemeSpec(
        backgroundGradient: LinearGradient(
            colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0F3460).opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        surface: Color(hex: 0x0F3460).opacity(0.3),
        primary: Color(hex: 0x1A1A2E),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.7),
        accent: Color(hex: 0xE94560),
        accentGradient: LinearGradient(
            colors: [Color(hex: 0xE94560), Color(hex: 0xE94560).opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        ),
        windowBackgroundUIColor: UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1),
        cardBorderOpacity: 0.2,
        cardShadowRadius: 8,
        cardShadowOpacity: 0.2
    )

    // MARK: Glass Aurora — мягкий холодный градиент, приглушённый cyan/blue
    private static let glassAurora = ThemeSpec(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: 0x1e293b),
                Color(hex: 0x312e81).opacity(0.95),
                Color(hex: 0x0f172a),
                Color(hex: 0x155e75).opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        surface: Color(hex: 0x334155).opacity(0.25),
        primary: Color(hex: 0x1e293b),
        textPrimary: Color(hex: 0xf1f5f9),
        textSecondary: Color(hex: 0x94a3b8),
        accent: Color(hex: 0x06b6d4),
        accentGradient: LinearGradient(
            colors: [Color(hex: 0x06b6d4), Color(hex: 0x0ea5e9).opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        ),
        windowBackgroundUIColor: UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1),
        cardBorderOpacity: 0.35,
        cardShadowRadius: 12,
        cardShadowOpacity: 0.12
    )
}

// MARK: - Glass Card Background (theme-aware)

struct GlassCardBackground: View {
    let spec: ThemeSpec
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(spec.cardBorderOpacity), lineWidth: 1)
            )
    }
}

// MARK: - Legacy static (for gradual migration; prefer ThemeSpec via ThemeManager)

enum CyberpunkTheme {
    static let deepPurple = Color(hex: 0x1A1A2E)
    static let electricBlue = Color(hex: 0x0F3460)
    static let neonPink = Color(hex: 0xE94560)

    static let backgroundGradient = LinearGradient(
        colors: [deepPurple, electricBlue.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [neonPink, neonPink.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let windowBackgroundUIColor = UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1)

    /// Использовать через ThemeSpec: GlassCardBackground(spec: themeManager.currentSpec, cornerRadius: 16)
    struct GlassCardBackgroundLegacy: View {
        var cornerRadius: CGFloat = 16
        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Color+Hex

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
