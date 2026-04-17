//
//  MigrationAnimationView.swift
//  MusicMind
//
//  Анимация миграции: виниловые пластинки летят по дуге из Source в Destination.
//  Коробки с иконками сервисов (SoundCloud → Яндекс), пульс при входе/выходе записи.
//

import SwiftUI

private let vinylCount = 15
private let vinylSize: CGFloat = 68
private let vinylHoleSize: CGFloat = 10
private let vinylRingWidth: CGFloat = 7
private let boxSize: CGFloat = 88
private let arcPeak: CGFloat = -58
private let flightDuration: Double = 1.2
private let staggerDelay: Double = 0.22
private let animAreaHeight: CGFloat = 160

struct MigrationAnimationView: View {
    let tracks: [Track]
    var onStartMigration: (() -> Void)?

    @State private var progress: [Double] = Array(repeating: -1, count: vinylCount)
    @State private var isAnimating = false
    @State private var pulseSource = false
    @State private var pulseDest = false

    private var displayTracks: [Track] {
        let withCovers = tracks.filter { $0.coverUri != nil && !($0.coverUri ?? "").isEmpty }
        let pool = withCovers.isEmpty ? tracks : withCovers
        return Array(pool.shuffled().prefix(vinylCount))
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack(alignment: .top) {
                // две коробки по горизонтали
                HStack(spacing: 0) {
                    sourceBox
                    Spacer(minLength: 20)
                    destinationBox
                }
                .padding(.horizontal, 24)

                // летящие винилы поверх
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let sourceX = 24 + boxSize / 2
                    let destX = w - 24 - boxSize / 2
                    let centerY = h / 2

                    ForEach(Array(displayTracks.enumerated()), id: \.element.id) { index, track in
                        let p = index < progress.count ? progress[index] : -1
                        if p >= 0 {
                            vinylView(track: track)
                                .position(
                                    x: sourceX + (destX - sourceX) * CGFloat(p),
                                    y: centerY + arcY(progress: p)
                                )
                                .rotationEffect(.degrees(p * 360))
                                .animation(.easeInOut(duration: flightDuration), value: p)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                        }
                    }
                }
                .frame(height: animAreaHeight)
            }
            .frame(height: animAreaHeight)

            Button(action: startMigration) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Migration")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CyberpunkTheme.neonPink.opacity(0.9),
                                    CyberpunkTheme.neonPink.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .disabled(isAnimating)
            .opacity(isAnimating ? 0.7 : 1)
        }
        .padding(.vertical, 16)
    }

    private var sourceBox: some View {
        boxView(service: .soundcloud, pulse: pulseSource)
    }

    private var destinationBox: some View {
        boxView(service: .yandex, pulse: pulseDest)
    }

    private func boxView(service: MusicService, pulse: Bool) -> some View {
        ZStack {
            // открытый контейнер (вид сверху)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(CyberpunkTheme.neonPink.opacity(0.4), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        .padding(3)
                )
                .frame(width: boxSize, height: boxSize)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.2), value: pulse)

            // иконка сервиса как в ServiceCardView
            ZStack {
                Circle()
                    .fill(service.color.opacity(0.9))
                    .frame(width: 48, height: 48)
                if let icon = service.icon {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                } else {
                    Text(service.letter)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func arcY(progress: Double) -> CGFloat {
        guard progress >= 0, progress <= 1 else { return 0 }
        return CGFloat(arcPeak * 4 * progress * (1 - progress))
    }

    private func vinylView(track: Track) -> some View {
        ZStack {
            // чёрный винил (кольцо)
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: vinylSize, height: vinylSize)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.18), lineWidth: 1)
                )

            // обложка в центре
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: vinylSize - vinylRingWidth * 2, height: vinylSize - vinylRingWidth * 2)
                .overlay(
                    Group {
                        if let url = coverURL(for: track) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                default:
                                    Image(systemName: "music.note")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: vinylSize - vinylRingWidth * 2, height: vinylSize - vinylRingWidth * 2)
                    .clipShape(Circle())
                )

            // дырочка в центре
            Circle()
                .fill(Color(white: 0.06))
                .frame(width: vinylHoleSize, height: vinylHoleSize)
                .overlay(
                    Circle()
                        .stroke(Color(white: 0.15), lineWidth: 0.5)
                )
        }
        .frame(width: vinylSize, height: vinylSize)
    }

    private func coverURL(for track: Track) -> URL? {
        guard let uri = track.coverUri, !uri.isEmpty else { return nil }
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            return URL(string: uri)
        }
        if uri.contains("%%") {
            let urlString = uri.replacingOccurrences(of: "%%", with: "200x200")
            return URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)")
        }
        if uri.hasPrefix("/") || uri.contains("yandex") {
            return URL(string: uri.hasPrefix("http") ? uri : "https://\(uri)")
        }
        return nil
    }

    private func startMigration() {
        guard !isAnimating else { return }
        isAnimating = true
        progress = Array(repeating: -1, count: vinylCount)

        for i in 0..<vinylCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * staggerDelay) {
                pulseSource = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    pulseSource = false
                }
                // сначала ставим диск в старт (p=0), чтобы view появился
                var p = progress
                p[i] = 0
                progress = p
                // на следующем цикле рендера запускаем анимацию до p=1 (вращение и дуга подхватятся)
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: flightDuration)) {
                        var q = progress
                        q[i] = 1
                        progress = q
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration) {
                    pulseDest = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        pulseDest = false
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(vinylCount) * staggerDelay + flightDuration + 0.3) {
            isAnimating = false
            onStartMigration?()
        }
    }
}

#Preview {
    ZStack {
        CyberpunkTheme.backgroundGradient
            .ignoresSafeArea()
        VStack(spacing: 32) {
            MigrationAnimationView(
                tracks: [
                    Track(title: "Track 1", artists: "Artist 1", durationMs: 180000, coverUri: nil),
                    Track(title: "Track 2", artists: "Artist 2", durationMs: 200000, coverUri: nil),
                ] + (0..<20).map { i in
                    Track(
                        title: "Track \(i)",
                        artists: "Artist \(i)",
                        durationMs: 200000,
                        coverUri: "https://picsum.photos/200"
                    )
                }
            )
        }
    }
}
