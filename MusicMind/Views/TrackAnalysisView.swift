//
//  TrackAnalysisView.swift
//  MusicMindAI
//
//  Экран с анализом одного трека
//

import SwiftUI

struct TrackAnalysisView: View {
    let track: Track
    @State private var analysis: TrackAnalysis?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let geminiService = GeminiService()
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            CyberpunkTheme.backgroundGradient
                .ignoresSafeArea(.all)
            
            // индикатор для свайпа
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                Spacer()
            }
            
            if isLoading {
                VStack(spacing: 24) {
                    ProgressView()
                        .tint(CyberpunkTheme.neonPink)
                        .scaleEffect(1.5)
                    
                    Text("Анализирую трек...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else if let error = errorMessage {
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(CyberpunkTheme.neonPink)
                    
                    Text("Ошибка анализа")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(error)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Закрыть")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(CyberpunkTheme.neonPink.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(CyberpunkTheme.neonPink, lineWidth: 2)
                                    )
                            )
                    }
                    .padding(.horizontal, 32)
                }
            } else if let analysis = analysis {
                ScrollView {
                    VStack(spacing: 24) {
                        // обложка и название трека
                        VStack(spacing: 12) {
                            AsyncImage(url: coverURL) { phase in
                                switch phase {
                                case .empty, .failure:
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(CyberpunkTheme.electricBlue.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .font(.system(size: 48))
                                                .foregroundStyle(.white.opacity(0.5))
                                        )
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: CyberpunkTheme.neonPink.opacity(0.3), radius: 20)
                            
                            VStack(spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(track.artists)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 40)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : -20)
                        
                        // кнопка YouTube
                        Button {
                            openYouTubeSearch()
                        } label: {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                
                                Text("Найти в YouTube")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // настроение и энергия
                        HStack(spacing: 16) {
                            InfoCard(
                                title: "Настроение",
                                value: analysis.mood,
                                icon: "heart.fill"
                            )
                            
                            InfoCard(
                                title: "Энергия",
                                value: analysis.energy,
                                icon: "bolt.fill"
                            )
                        }
                        .padding(.horizontal, 16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // жанр
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Жанр")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Text(analysis.genre)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(CyberpunkTheme.neonPink.opacity(0.2))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(CyberpunkTheme.neonPink.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // описание
                        SectionCard(
                            title: "Описание",
                            content: analysis.description,
                            icon: "doc.text.fill"
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // вайб
                        SectionCard(
                            title: "Вайб",
                            content: analysis.vibe,
                            icon: "sparkles"
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // занятия
                        if !analysis.activities.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Когда включать")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(analysis.activities, id: \.self) { activity in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(CyberpunkTheme.neonPink)
                                            Text(activity)
                                                .font(.system(size: 16))
                                                .foregroundStyle(.white.opacity(0.9))
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(CyberpunkTheme.neonPink.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }
                        
                        // похожие артисты
                        if !analysis.similarArtists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Похожие артисты")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(analysis.similarArtists, id: \.self) { artist in
                                        Text(artist)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(CyberpunkTheme.electricBlue.opacity(0.3))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(CyberpunkTheme.electricBlue.opacity(0.5), lineWidth: 1)
                                                    )
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }
                        
                        // лучший момент
                        SectionCard(
                            title: "На что обратить внимание",
                            content: analysis.bestMoment,
                            icon: "eye.fill"
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // необычные факты о треке
                        if !analysis.unusualFacts.isEmpty {
                            SectionCard(
                                title: "Необычные факты",
                                content: analysis.unusualFacts,
                                icon: "lightbulb.fill"
                            )
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }
                        
                        // биография артиста
                        if !analysis.artistBio.isEmpty {
                            SectionCard(
                                title: "Об исполнителе",
                                content: analysis.artistBio,
                                icon: "person.circle.fill"
                            )
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }
                        
                        // фильмы где использовалась песня
                        if !analysis.moviesUsedIn.isEmpty && !analysis.moviesUsedIn.lowercased().contains("не использовалась") {
                            SectionCard(
                                title: "В каких фильмах",
                                content: analysis.moviesUsedIn,
                                icon: "film.fill"
                            )
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                        }
                        
                        // кнопка закрытия
                        Button {
                            dismiss()
                        } label: {
                            Text("Закрыть")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(CyberpunkTheme.neonPink.opacity(0.3))
                                        .overlay(
                                            Capsule()
                                                .stroke(CyberpunkTheme.neonPink, lineWidth: 2)
                                        )
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                }
            }
        }
        .task {
            await loadAnalysis()
        }
        .onChange(of: analysis) { _ in
            if analysis != nil {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
            }
        }
    }
    
    private var coverURL: URL? {
        guard let uri = track.coverUri, !uri.isEmpty else { return nil }
        
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            return URL(string: uri)
        }
        
        if uri.contains("%%") {
            let size = "400x400"
            let urlString = uri.replacingOccurrences(of: "%%", with: size)
            if !urlString.hasPrefix("http") {
                return URL(string: "https://\(urlString)")
            }
            return URL(string: urlString)
        }
        
        if uri.hasPrefix("/") || uri.contains("yandex") {
            let urlString = uri.hasPrefix("http") ? uri : "https://\(uri)"
            return URL(string: urlString)
        }
        
        return nil
    }
    
    private func openYouTubeSearch() {
        let query = "\(track.title) \(track.artists)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.youtube.com/results?search_query=\(query)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    @MainActor
    private func loadAnalysis() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await geminiService.analyzeTrack(track)
            analysis = result
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    TrackAnalysisView(track: Track(
        title: "Bohemian Rhapsody",
        artists: "Queen",
        durationMs: 355000,
        coverUri: nil
    ))
    .preferredColorScheme(.dark)
}
