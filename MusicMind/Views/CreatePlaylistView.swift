//
//  CreatePlaylistView.swift
//  MusicMindAI
//
//  Окно для создания плейлиста через Gemini
//

import SwiftUI
import Combine

struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePlaylistViewModel
    @State private var currentMessageIndex = 0
    @State private var currentSuggestionIndex = 0
    @State private var suggestionChips: [String] = []
    @State private var progress: Double = 0.0
    @State private var startTime: Date?
    @FocusState private var isQueryFocused: Bool
    @State private var showInlineSuccess = false
    
    private let minimumWaitTime: TimeInterval = 12.0 // минимум 12 секунд
    private let suggestionTimer = Timer.publish(every: 3.8, on: .main, in: .common).autoconnect()
    
    private let playlistMessages = [
        "подбираем идеальный плейлист...",
        "анализируем твой запрос...",
        "ищем подходящие треки...",
        "составляем уникальную подборку...",
        "проверяем каждый трек...",
        "создаем атмосферу...",
        "находим идеальное сочетание...",
        "формируем плейлист мечты...",
        "добавляем финальные штрихи...",
        "почти готово..."
    ]
    
    private let suggestions = [
        "музыка slowed reverb для секса",
        "музыка в низком темпе для хорошего настроения",
        "музыка для бокса",
        "джаз для вечернего релакса",
        "энергичная музыка для тренировки",
        "меланхоличная музыка для дождливого дня",
        "инструментальная музыка для работы",
        "хип-хоп для вечеринки",
        "классическая музыка для концентрации",
        "электронная музыка для танцев"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("создать плейлист")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("опиши, какой плейлист ты хочешь.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button {
                            viewModel.query = currentSuggestion
                        } label: {
                            Text("например: «\(currentSuggestion)»")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentTransition(.opacity)
                                .animation(.easeInOut(duration: 0.35), value: currentSuggestionIndex)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCreating)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                TextField("введи запрос...", text: $viewModel.query, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isQueryFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isQueryFocused = false
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .lineLimit(3...6)
                    .disabled(viewModel.isCreating)
                    .onChange(of: viewModel.query) { _ in
                        // если юзер меняет запрос — сбрасываем превью (чтобы не было "левого" списка)
                        Task { @MainActor in
                            viewModel.resetGeneratedPreview()
                        }
                    }

                // сколько треков добавить
                if !viewModel.isCreating && !showInlineSuccess {
                    HStack(spacing: 12) {
                        Text("треков: \(viewModel.desiredTrackCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer(minLength: 0)
                        
                        Stepper("", value: $viewModel.desiredTrackCount, in: 5...20)
                            .labelsHidden()
                            .tint(CyberpunkTheme.neonPink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .onChange(of: viewModel.desiredTrackCount) { _ in
                        // если юзер меняет количество — сбрасываем превью, чтобы не было рассинхрона
                        Task { @MainActor in
                            viewModel.resetGeneratedPreview()
                        }
                    }
                }
                
                // предложения
                if viewModel.query.isEmpty && !viewModel.isCreating {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("примеры запросов:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestionChips, id: \.self) { suggestion in
                                    Button {
                                        viewModel.query = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                CyberpunkTheme.neonPink.opacity(0.2),
                                                                CyberpunkTheme.electricBlue.opacity(0.2)
                                                            ],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // превью: какие треки собираемся добавить (до подтверждения)
                if !viewModel.generatedTrackQueries.isEmpty && !viewModel.isCreating {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("вот что я собираюсь добавить:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            
                            if !viewModel.generatedTitle.isEmpty {
                                Text("плейлист: \(viewModel.generatedTitle)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                                    .lineLimit(2)
                            }
                            
                            Text("\(viewModel.generatedTrackQueries.count) треков — если ок, жми «добавить» снизу")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(Array(viewModel.generatedTrackQueries.enumerated()), id: \.offset) { index, trackQuery in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 22, alignment: .trailing)
                                        
                                        Text(trackQuery)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial.opacity(0.3))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 260)
                        .scrollIndicators(.hidden)
                    }
                }
                
                if viewModel.isCreating || showInlineSuccess {
                    VStack(spacing: 24) {
                        // обложки найденных треков (появляются во время добавления)
                        if !viewModel.loadingCoverTracks.isEmpty {
                            AnimatedCoversView(tracks: viewModel.loadingCoverTracks, changeInterval: 2.2)
                                .frame(height: 300)
                                .padding(.bottom, 4)
                        }

                        // заголовок
                        Group {
                            if showInlineSuccess {
                                Text("готово")
                            } else {
                                Text("Music Mind создает плейлист...")
                            }
                        }
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        
                        // динамическое сообщение
                        if !showInlineSuccess {
                            Text(currentMessage)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .frame(minHeight: 50)
                                .animation(.easeInOut(duration: 0.5), value: currentMessageIndex)
                        }
                        
                        // прогресс бар
                        VStack(spacing: 12) {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: CyberpunkTheme.neonPink))
                                .frame(width: 250)
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)

                        if showInlineSuccess, let uuid = viewModel.playlistUuid, viewModel.errorMessage == nil {
                            Button {
                                isQueryFocused = false
                                if let url = URL(string: "https://music.yandex.ru/playlists/\(uuid)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("перейти")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.white.opacity(0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                            
                            Text("плейлист уже в библиотеке")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // дополнительная информация
                        if viewModel.totalTracksCount > 0 {
                            Text("обработано \(viewModel.foundTracksCount) из \(viewModel.totalTracksCount) треков")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        if !viewModel.generatedTitle.isEmpty {
                            VStack(spacing: 4) {
                                Text("название плейлиста:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(viewModel.generatedTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 20)
                    .onAppear {
                        startTime = Date()
                        startMessageAnimation()
                        Task {
                            await updateProgress()
                        }
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(CyberpunkTheme.neonPink)
                        .padding(.horizontal, 20)
                }

                Spacer()
                
                Button {
                    isQueryFocused = false
                    if showInlineSuccess {
                        dismiss()
                        return
                    }
                    showInlineSuccess = false
                    progress = 0.0
                    currentMessageIndex = 0
                    startTime = Date()
                    startMessageAnimation()
                    Task {
                        // запускаем обновление прогресса параллельно
                        async let progressTask = updateProgress()
                        
                        if viewModel.generatedTrackQueries.isEmpty {
                            // шаг 1: сгенерить список
                            async let generateTask = viewModel.createPlaylist()
                            await progressTask
                            await generateTask
                        } else {
                            // шаг 2: юзер подтвердил — добавляем в яндекс
                            async let addTask = viewModel.addGeneratedTracksToPlaylist()
                            await progressTask
                            await addTask
                            
                            if viewModel.errorMessage == nil && viewModel.playlistUuid != nil {
                                // завершаем прогресс
                                progress = 1.0
                                // небольшая задержка, чтобы анимация успела "дойти" до 100%
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                await MainActor.run { showInlineSuccess = true }
                            }
                        }
                    }
                } label: {
                    Text(showInlineSuccess ? "закрыть" : (viewModel.generatedTrackQueries.isEmpty ? "создать" : "добавить"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            CyberpunkTheme.neonPink,
                                            CyberpunkTheme.electricBlue
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: CyberpunkTheme.neonPink.opacity(0.4), radius: 12, y: 6)
                        }
                }
                .disabled((viewModel.generatedTrackQueries.isEmpty && viewModel.query.isEmpty) || viewModel.isCreating)
                .opacity(((viewModel.generatedTrackQueries.isEmpty && viewModel.query.isEmpty) || viewModel.isCreating) ? 0.5 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background {
                CyberpunkTheme.backgroundGradient
                    .ignoresSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isQueryFocused = false
                    }
            }
            .onAppear {
                // стартуем не всегда с одной и той же идеи + фиксируем чипсы, чтобы не "плясали" от перерисовок
                if !suggestions.isEmpty {
                    currentSuggestionIndex = Int.random(in: 0..<suggestions.count)
                }
                suggestionChips = Array(suggestions.shuffled().prefix(5))
            }
            .onReceive(suggestionTimer) { _ in
                // крутим подсказки только когда юзер еще не пишет и мы не в процессе создания
                guard viewModel.query.isEmpty, !viewModel.isCreating, !suggestions.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    currentSuggestionIndex = (currentSuggestionIndex + 1) % suggestions.count
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if isQueryFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("готово") {
                            isQueryFocused = false
                        }
                        .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("отмена") {
                        isQueryFocused = false
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var currentMessage: String {
        guard !playlistMessages.isEmpty else {
            return "подбираем идеальный плейлист..."
        }
        return playlistMessages[currentMessageIndex % playlistMessages.count]
    }

    private var currentSuggestion: String {
        guard !suggestions.isEmpty else { return "музыка для вечернего релакса" }
        return suggestions[currentSuggestionIndex % suggestions.count]
    }

    private func startMessageAnimation() {
        // смена сообщений каждые 1.2 секунды (12 секунд / 10 сообщений)
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { timer in
            guard viewModel.isCreating else {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                currentMessageIndex += 1
            }
        }
    }
    
    private func updateProgress() async {
        let start = startTime ?? Date()
        let duration = minimumWaitTime
        
        while viewModel.isCreating {
            let elapsed = Date().timeIntervalSince(start)
            let calculatedProgress = min(0.95, elapsed / duration) // максимум 95% до завершения
            
            await MainActor.run {
                withAnimation(.linear(duration: 0.3)) {
                    progress = calculatedProgress
                }
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // обновляем каждые 0.1 секунды
        }
        
        // завершаем прогресс
        await MainActor.run {
            progress = 1.0
        }
    }
}
