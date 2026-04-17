//
//  ProfileResultView.swift
//  MusicMindAI
//
//  Экран с результатами анализа музыкального портрета
//

import SwiftUI
import OSLog
import UIKit

struct ProfileResultView: View {
    let profile: MusicalProfile
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showRecommendations = false
    @State private var recommendations: [String] = []
    @State private var isLoadingRecommendations = false
    
    private let geminiService = GeminiService()
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "ProfileResultView")
    
    var body: some View {
        ZStack {
            CyberpunkTheme.backgroundGradient
                .ignoresSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 24) {
                    // заголовок
                    VStack(spacing: 8) {
                        Text("Твой музыкальный портрет")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(profile.mood.capitalized)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(CyberpunkTheme.neonPink)
                    }
                    .padding(.top, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                    
                    // настроение и сильная сторона
                    HStack(spacing: 16) {
                        InfoCard(
                            title: "Настроение",
                            value: profile.mood,
                            icon: "heart.fill"
                        )
                        
                        InfoCard(
                            title: "Сильная сторона",
                            value: profile.strength,
                            icon: "star.fill"
                        )
                    }
                    .padding(.horizontal, 16)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // жанры
                    if !profile.genres.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Жанры")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(profile.genres, id: \.self) { genre in
                                    Text(genre)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(CyberpunkTheme.neonPink.opacity(0.2))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(CyberpunkTheme.neonPink.opacity(0.5), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                    
                    // топ артисты
                    if !profile.topArtists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Топ артисты")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(profile.topArtists.enumerated()), id: \.offset) { index, artist in
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(CyberpunkTheme.neonPink)
                                            .frame(width: 30)
                                        
                                        Text(artist)
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white.opacity(0.9))
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                    
                    // описание личности
                    SectionCard(
                        title: "О тебе",
                        content: profile.personality,
                        icon: "person.fill"
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // музыкальный вкус
                    SectionCard(
                        title: "Твой музыкальный вкус",
                        content: profile.musicalTaste,
                        icon: "music.note"
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // стиль прослушивания
                    SectionCard(
                        title: "Как ты слушаешь",
                        content: profile.listeningStyle,
                        icon: "headphones"
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // необычные факты и связи
                    if !profile.unusualFacts.isEmpty {
                        SectionCard(
                            title: "Необычные факты и связи",
                            content: profile.unusualFacts,
                            icon: "sparkles"
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                    
                    // кнопка рекомендаций
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await loadRecommendations(forceRefresh: false)
                            }
                        } label: {
                            HStack {
                                if isLoadingRecommendations {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Рекомендации")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.3))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            )
                        }
                        .disabled(isLoadingRecommendations)
                        
                        // кнопка обновления
                        Button {
                            Task {
                                await loadRecommendations(forceRefresh: true)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color.green.opacity(0.3))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.green, lineWidth: 2)
                                        )
                                )
                        }
                        .disabled(isLoadingRecommendations)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
            }
            
            // кнопка закрытия сверху
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
        .sheet(isPresented: $showRecommendations) {
            RecommendationsView(
                recommendations: $recommendations,
                profile: profile,
                onRefresh: {
                    await loadRecommendations(forceRefresh: true)
                    return recommendations
                }
            )
        }
    }
    
    @MainActor
    private func loadRecommendations(forceRefresh: Bool = false) async {
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        
        do {
            let recs = try await geminiService.getRecommendations(for: profile, forceRefresh: forceRefresh)
            recommendations = recs
            if !showRecommendations {
                showRecommendations = true
            }
        } catch {
            logger.error("ошибка загрузки рекомендаций: \(error.localizedDescription)")
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(CyberpunkTheme.neonPink)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(CyberpunkTheme.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Section Card

struct SectionCard: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(CyberpunkTheme.neonPink)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text(content)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
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
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            frames = subviews.indices.map { index in
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                let frame = CGRect(x: currentX, y: currentY, width: size.width, height: size.height)
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                
                return frame
            }
            
            size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

// MARK: - Recommendations View

struct RecommendationsView: View {
    @Binding var recommendations: [String]
    let profile: MusicalProfile
    let onRefresh: () async -> [String]?
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                CyberpunkTheme.backgroundGradient
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.green)
                                    .frame(width: 30)
                                
                                Text(recommendation)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // кнопка копирования
                                Button {
                                    copyToClipboard(recommendation)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(Color.blue.opacity(0.3))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.blue, lineWidth: 1.5)
                                                )
                                        )
                                }
                                
                                // кнопка поиска в YouTube
                                Button {
                                    searchInYouTube(recommendation)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(Color.red.opacity(0.3))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.red, lineWidth: 1.5)
                                                )
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Рекомендации")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                isRefreshing = true
                                if let updated = await onRefresh() {
                                    recommendations = updated
                                }
                                isRefreshing = false
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.7))
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                        }
                        .disabled(isRefreshing)
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
    
    private func searchInYouTube(_ query: String) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.youtube.com/results?search_query=\(encodedQuery)"
        
        if let url = URL(string: urlString) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
}

#Preview {
    ProfileResultView(
        profile: MusicalProfile(
            mood: "меланхоличный",
            genres: ["инди-рок", "альтернатива", "пост-рок"],
            personality: "ты человек с глубоким эмоциональным интеллектом, ценишь атмосферность и многослойность в музыке",
            listeningStyle: "слушаешь для настроения и эмоций",
            strength: "разнообразие и глубина вкуса",
            topArtists: ["Radiohead", "Arcade Fire", "The National"],
            musicalTaste: "твой вкус характеризуется любовью к сложным композициям и эмоциональной глубине",
            recommendationVector: ["попробуй послушать новые альбомы", "усиль эмоциональную глубину"],
            unusualFacts: "интересная связь между артистами из разных эпох, объединённых общим настроением"
        ),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
