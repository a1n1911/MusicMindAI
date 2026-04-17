//
//  MigrationView.swift
//  MusicMind
//
//  Вью миграции: прогрессбар, текущий трек, анимация копирования.
//

import SwiftUI

struct MigrationView: View {
    @Binding var source: MusicService?
    @Binding var destination: MusicService?
    @ObservedObject var viewModel: MigrationViewModel
    let sourceTracks: [Track]
    let cookies: String?
    let userId: String?
    let onStart: () -> Void

    @State private var progressAnimation: CGFloat = 0
    @State private var copyingPulse: Bool = false

    private var sourceName: String { source?.name ?? "?" }
    private var destinationName: String { destination?.name ?? "?" }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                ServiceSelectorView(
                    source: $source,
                    destination: $destination,
                    onStart: onStart
                )
                .padding(.vertical, 8)
                if source != nil && destination != nil {
                    Text("\(sourceTracks.count) треков готовы к переносу")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                if viewModel.isRunning || viewModel.isFinished {
                    progressSection
                    currentTrackSection
                }
                if viewModel.isFinished {
                    resultSection
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background { CyberpunkTheme.backgroundGradient.ignoresSafeArea(.all) }
        .navigationTitle("Миграция")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(CyberpunkTheme.deepPurple, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(CyberpunkTheme.neonPink)
            Text("\(sourceName) → \(destinationName)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.bottom, 8)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Прогресс")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(viewModel.currentIndex)/\(viewModel.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(CyberpunkTheme.neonPink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [CyberpunkTheme.neonPink, CyberpunkTheme.neonPink.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * viewModel.progress, height: 10)
                        .animation(.easeInOut(duration: 0.35), value: viewModel.progress)
                }
            }
            .frame(height: 10)
        }
    }

    private var currentTrackSection: some View {
        VStack(spacing: 12) {
            if viewModel.isRunning {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.body)
                        .foregroundStyle(CyberpunkTheme.neonPink)
                        .scaleEffect(copyingPulse ? 1.1 : 1.0)
                    Text("копируется сейчас")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        copyingPulse = true
                    }
                }
            }
            if let track = viewModel.currentTrack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(track.artists)
                        .font(.subheadline)
                        .foregroundStyle(CyberpunkTheme.neonPink.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(CyberpunkTheme.neonPink.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity
                ))
            }
            if viewModel.isRunning {
                Button(action: { viewModel.cancelMigration() }) {
                    Text("Стоп")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(CyberpunkTheme.neonPink)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    private var resultSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                resultBadge(value: viewModel.migratedCount, label: "добавлено", color: .green)
                resultBadge(value: viewModel.failedCount, label: "не найдено", color: CyberpunkTheme.neonPink)
            }
            .padding(.top, 16)
            Button(action: { viewModel.reset() }) {
                Text("Заново")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(CyberpunkTheme.neonPink.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
    }

    private func resultBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
        )
    }
}
