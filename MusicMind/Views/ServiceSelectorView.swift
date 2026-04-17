//
//  ServiceSelectorView.swift
//  MusicMind
//
//  Селектор "Откуда" / "Куда" для экрана миграции: стеклянные карточки, меню, неоновая стрелка.
//

import SwiftUI

/// Сервисы, доступные в селекторе миграции (Яндекс, Spotify, SoundCloud, VK).
private let migrationServices: [MusicService] = [.yandex, .spotify, .soundcloud, .vk]

struct ServiceSelectorView: View {
    @Binding var source: MusicService?
    @Binding var destination: MusicService?
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            labelsRow
            cardsRow
            startButton
        }
        .padding(.horizontal, 20)
    }

    private var labelsRow: some View {
        HStack {
            Text("Откуда")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(CyberpunkTheme.neonPink.opacity(0.9))
            Spacer()
            Text("Куда")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(CyberpunkTheme.neonPink.opacity(0.9))
        }
    }

    private var cardsRow: some View {
        HStack(spacing: 16) {
            serviceCard(selection: $source, exclude: destination, label: "Откуда")
            arrowView
            serviceCard(selection: $destination, exclude: source, label: "Куда")
        }
    }

    private func serviceCard(
        selection: Binding<MusicService?>,
        exclude: MusicService?,
        label: String
    ) -> some View {
        let options = migrationServices.filter { $0 != exclude }
        return Menu {
            ForEach(options, id: \.name) { service in
                Button(action: { selection.wrappedValue = service }) {
                    Label(service.name, systemImage: service.icon ?? "music.note")
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                if let service = selection.wrappedValue {
                    serviceIconView(service: service)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title)
                        Text("выбрать")
                            .font(.caption2)
                    }
                    .foregroundStyle(CyberpunkTheme.neonPink.opacity(0.8))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func serviceIconView(service: MusicService) -> some View {
        ZStack {
            Circle()
                .fill(service.color.opacity(0.9))
                .frame(width: 56, height: 56)
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
    }

    private var arrowView: some View {
        Image(systemName: "arrow.right.circle.fill")
            .font(.title)
            .foregroundStyle(CyberpunkTheme.neonPink)
            .shadow(color: CyberpunkTheme.neonPink.opacity(0.9), radius: 8)
            .shadow(color: CyberpunkTheme.neonPink.opacity(0.5), radius: 16)
    }

    private var startButton: some View {
        let isEnabled = source != nil && destination != nil
        return Button(action: onStart) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Начать перенос")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                CyberpunkTheme.neonPink.opacity(isEnabled ? 0.95 : 0.5),
                                CyberpunkTheme.neonPink.opacity(isEnabled ? 0.7 : 0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(CyberpunkTheme.neonPink.opacity(isEnabled ? 0.6 : 0.3), lineWidth: 1)
            )
            .shadow(color: CyberpunkTheme.neonPink.opacity(isEnabled ? 0.4 : 0), radius: 12)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.25), value: isEnabled)
    }
}

#Preview {
    ZStack {
        CyberpunkTheme.backgroundGradient.ignoresSafeArea()
        ServiceSelectorView(
            source: .constant(.yandex),
            destination: .constant(.spotify),
            onStart: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
