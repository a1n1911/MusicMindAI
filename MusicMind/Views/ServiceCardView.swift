//
//  ServiceCardView.swift
//  MusicMindAI
//
//  Карточка сервиса для экрана "Сервисы"
//

import SwiftUI

struct ServiceCardView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let service: MusicService
    let isConnected: Bool
    let onConnect: () -> Void
    let onLogout: (() -> Void)?

    private var spec: ThemeSpec { themeManager.currentSpec }

    var body: some View {
        HStack(spacing: 16) {
            // логотип
            ZStack {
                Circle()
                    .fill(service.color)
                    .frame(width: 50, height: 50)
                
                if let icon = service.icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                } else {
                    Text(service.letter)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            // название
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.headline)
                    .foregroundStyle(spec.textPrimary)
                
                if isConnected {
                    Text("библиотека синхронизована")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.9))
                }
            }
            
            Spacer()
            
            // статус/кнопка
            if isConnected {
                if let onLogout = onLogout {
                    Button(action: onLogout) {
                        Text("выйти")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(spec.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(spec.accent.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(spec.accent.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            } else {
                Button(action: onConnect) {
                    Text("войти")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(spec.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(spec.accentGradient)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(GlassCardBackground(spec: spec, cornerRadius: 16))
        .shadow(color: .black.opacity(spec.cardShadowOpacity), radius: spec.cardShadowRadius, x: 0, y: 4)
    }
}

enum MusicService {
    case yandex
    case spotify
    case soundcloud
    case vk
    
    var name: String {
        switch self {
        case .yandex: return "яндекс.музыка"
        case .spotify: return "spotify"
        case .soundcloud: return "soundcloud"
        case .vk: return "VK Музыка"
        }
    }
    
    var color: Color {
        switch self {
        case .yandex: return .red
        case .spotify: return .green
        case .soundcloud: return Color(hex: 0xFF5500) // оранжевый
        case .vk: return Color(hex: 0x0077FF) // синий VK
        }
    }
    
    var icon: String? {
        switch self {
        case .spotify: return "music.note"
        case .soundcloud: return "cloud"
        case .vk: return "music.note.list"
        default: return nil
        }
    }
    
    var letter: String {
        switch self {
        case .yandex: return "Я"
        case .vk: return "VK"
        default: return ""
        }
    }
}

#Preview {
    ZStack {
        ThemeSpec.spec(for: .cyberpunk).backgroundGradient
            .ignoresSafeArea()
        VStack(spacing: 16) {
            ServiceCardView(
                service: .yandex,
                isConnected: true,
                onConnect: {},
                onLogout: {}
            )
            
            ServiceCardView(
                service: .spotify,
                isConnected: false,
                onConnect: {},
                onLogout: nil
            )
            
            ServiceCardView(
                service: .soundcloud,
                isConnected: false,
                onConnect: {},
                onLogout: nil
            )
            
            ServiceCardView(
                service: .vk,
                isConnected: false,
                onConnect: {},
                onLogout: nil
            )
        }
        .padding()
        .environmentObject(ThemeManager())
    }
}
