//
//  AnalysisLoadingView.swift
//  MusicMindAI
//
//  Экран анализа с mesh gradient и динамическим текстом.
//

import SwiftUI

struct AnalysisLoadingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private var spec: ThemeSpec { themeManager.currentSpec }

    let tracks: [Track]
    let forceRefresh: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var currentMessageIndex = 0
    @State private var messages: [MessageData] = []
    @State private var profile: MusicalProfile?
    @State private var error: Error?
    @State private var isAnalyzing = true
    @State private var progress: Double = 0.0
    @State private var startTime: Date?
    
    private let geminiService = GeminiService()
    private let minimumWaitTime: TimeInterval = 6.0 // минимум 10 секунд
    
    init(tracks: [Track], forceRefresh: Bool = false) {
        self.tracks = tracks
        self.forceRefresh = forceRefresh
    }
    
    var body: some View {
        ZStack {
            spec.backgroundGradient
                .ignoresSafeArea(.all)
            
            // mesh gradient анимация
            MeshGradientView()
                .environmentObject(themeManager)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // кнопка закрытия
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(spec.textSecondary)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // группа с обложками и текстом
                VStack(spacing: 20) {
                    // анимация обложек
                    AnimatedCoversView(tracks: tracks)
                        .frame(height: 350)
                    
                    // заголовок
                    Text("Music Mind сканирует твой вайб...")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(spec.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    // динамический текст
                    currentMessageText
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(spec.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .frame(minHeight: 50)
                        .animation(.easeInOut(duration: 0.5), value: currentMessageIndex)
                    
                    // прогресс бар
                    VStack(spacing: 12) {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: spec.accent))
                            .frame(width: 200)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(spec.textSecondary)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            messages = generateMessages()
            startAnimations()
            Task {
                await performAnalysis()
            }
        }
        .fullScreenCover(item: $profile) { profile in
            ProfileResultView(profile: profile, onDismiss: {
                dismiss()
            })
        }
    }
    
    private var currentMessageText: Text {
        guard !messages.isEmpty else {
            return Text("Подготовка к анализу...")
        }
        let message = messages[currentMessageIndex % messages.count]
        return message.formattedText
    }
    
    private func generateMessages() -> [MessageData] {
        var msgs: [MessageData] = []
        
        // "Изучаю твои {количество треков} треков..."
        msgs.append(.studyingTracks(count: tracks.count))
        
        // "Понимаю, почему ты любишь {название случайного трека}..."
        if let randomTrack = tracks.randomElement() {
            msgs.append(.lovingTrack(title: randomTrack.title))
        }
        
        // "Сравниваю {случайное названия артиста 1} и {случайное названия артиста 2}..."
        let uniqueArtists = Set(tracks.map { $0.artists.split(separator: ",").first?.trimmingCharacters(in: .whitespaces) ?? "" })
            .filter { !$0.isEmpty }
            .map { String($0) }
        
        if uniqueArtists.count >= 2 {
            let shuffled = uniqueArtists.shuffled()
            msgs.append(.comparingArtists(artist1: shuffled[0], artist2: shuffled[1]))
        }
        
        return msgs.isEmpty ? [.analyzing] : msgs
    }
    
    private func startAnimations() {
        // смена сообщений каждые 3 секунды
        if !messages.isEmpty {
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
                guard isAnalyzing else {
                    timer.invalidate()
                    return
                }
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentMessageIndex += 1
                }
            }
        }
    }
    
    @MainActor
    private func performAnalysis() async {
        guard !tracks.isEmpty else {
            error = NSError(domain: "MusicMind", code: -1, userInfo: [NSLocalizedDescriptionKey: "Нет треков для анализа"])
            isAnalyzing = false
            return
        }
        
        startTime = Date()
        
        // запускаем прогресс бар
        Task {
            await updateProgress()
        }
        
        do {
            // запускаем анализ параллельно
            let analysisTask = Task {
                try await geminiService.generateMusicalProfile(from: tracks, forceRefresh: forceRefresh)
            }
            
            // ждем минимум 10 секунд
            let elapsed = Date().timeIntervalSince(startTime ?? Date())
            let remainingWait = max(0, minimumWaitTime - elapsed)
            
            if remainingWait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingWait * 1_000_000_000))
            }
            
            // ждем завершения анализа (форматирование уже происходит в GeminiService)
            let result = try await analysisTask.value
            
            isAnalyzing = false
            progress = 1.0
            
            // небольшая задержка для завершения анимации
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            profile = result
        } catch {
            self.error = error
            isAnalyzing = false
            
            // показываем ошибку через 2 секунды
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()
        }
    }
    
    private func updateProgress() async {
        let start = startTime ?? Date()
        let duration = minimumWaitTime
        
        while isAnalyzing {
            let elapsed = Date().timeIntervalSince(start)
            let calculatedProgress = min(0.95, elapsed / duration) // максимум 95% до завершения
            
            await MainActor.run {
                withAnimation(.linear(duration: 0.3)) {
                    progress = calculatedProgress
                }
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // обновляем каждые 0.1 секунды
        }
    }
    
}

// MARK: - Message Data

enum MessageData {
    case studyingTracks(count: Int)
    case lovingTrack(title: String)
    case comparingArtists(artist1: String, artist2: String)
    case analyzing
    
    var formattedText: Text {
        switch self {
        case .studyingTracks(let count):
            return Text("Изучаю твои ") + Text("\(count)").italic() + Text(" треков...")
        case .lovingTrack(let title):
            return Text("Понимаю, почему ты любишь ") + Text(title).italic() + Text("...")
        case .comparingArtists(let artist1, let artist2):
            return Text("Сравниваю ") + Text(artist1).italic() + Text(" и ") + Text(artist2).italic() + Text("...")
        case .analyzing:
            return Text("Анализирую твою музыку...")
        }
    }
}

// MARK: - Mesh Gradient View

struct MeshGradientView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private var spec: ThemeSpec { themeManager.currentSpec }

    @State private var animPhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // размытые цветные пятна
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    gradientColor(for: index).opacity(0.7),
                                    gradientColor(for: index).opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .position(animatedPosition(for: index, in: geometry.size))
                        .blur(radius: 60)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                animPhase = 2 * .pi
            }
        }
    }
    
    private func animatedPosition(for index: Int, in size: CGSize) -> CGPoint {
        let basePos = positions[index]
        let phase = animPhase + Double(index) * 0.5
        let radius: CGFloat = 80
        
        let x = size.width * basePos.x + cos(phase) * radius * CGFloat(index % 2 == 0 ? 1 : -1)
        let y = size.height * basePos.y + sin(phase * 1.3) * radius * CGFloat(index % 3 == 0 ? 1 : -1)
        
        return CGPoint(x: x, y: y)
    }
    
    private func gradientColor(for index: Int) -> Color {
        switch index % 4 {
        case 0: return spec.accent
        case 1: return spec.surface
        case 2: return Color.purple.opacity(0.9)
        default: return spec.accent.opacity(0.7)
        }
    }
    
    private var positions: [CGPoint] {
        [
            CGPoint(x: 0.15, y: 0.25),
            CGPoint(x: 0.85, y: 0.15),
            CGPoint(x: 0.2, y: 0.75),
            CGPoint(x: 0.8, y: 0.85),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.35, y: 0.6)
        ]
    }
}

#Preview {
    AnalysisLoadingView(tracks: [
        Track(title: "Test Track 1", artists: "Artist 1", durationMs: 180000),
        Track(title: "Test Track 2", artists: "Artist 2", durationMs: 200000),
        Track(title: "Test Track 3", artists: "Artist 3", durationMs: 190000)
    ])
    .environmentObject(ThemeManager())
    .preferredColorScheme(.dark)
}
