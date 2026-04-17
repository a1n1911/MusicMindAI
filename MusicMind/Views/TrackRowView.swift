//
//  TrackRowView.swift
//  MusicMindAI
//
//  Компонент для отображения одного трека в списке.
//

import SwiftUI

struct TrackRowView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let track: Track
    let index: Int
    let service: MusicService?
    let onTap: () -> Void

    private var spec: ThemeSpec { themeManager.currentSpec }

    @Environment(\.openURL) private var openURL
    
    @State private var isVisible = false
    @State private var imageLoaded = false
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false
    @State private var isDragging = false
    
    init(track: Track, index: Int = 0, service: MusicService? = nil, onTap: @escaping () -> Void = {}) {
        self.track = track
        self.index = index
        self.service = service
        self.onTap = onTap
    }
    
    private let swipeButtonWidth: CGFloat = 80
    private let maxSwipeDistance: CGFloat = 160
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // кнопки действий при свайпе (скрыты за правым краем по умолчанию)
            HStack(spacing: 0) {
                // кнопка YouTube
                Button {
                    openYouTubeSearch()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                        Text("YouTube")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: swipeButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red.opacity(0.8))
                }
                
                // кнопка Поделиться
                Button {
                    showShareSheet = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Text("Поделиться")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .frame(width: swipeButtonWidth)
                    .frame(maxHeight: .infinity)
                    .background(spec.accent.opacity(0.8))
                }
            }
            .frame(width: maxSwipeDistance)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .offset(x: maxSwipeDistance + dragOffset)
            
            // основная карточка
            HStack(spacing: 12) {
                // обложка с skeleton loading и кэшированием
                CachedCoverImage(
                    url: coverURL,
                    size: CGSize(width: 56, height: 56),
                    onImageLoaded: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            imageLoaded = true
                        }
                    }
                )
                .opacity(imageLoaded ? 1 : 0)
                
                // название и артист
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline)
                        .foregroundStyle(spec.textPrimary)
                        .lineLimit(1)

                    Text(track.artists)
                        .font(.subheadline)
                        .foregroundStyle(spec.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // продолжительность + play
                HStack(spacing: 10) {
                    Text(formatDuration(track.durationSec))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(spec.textSecondary)
                        .monospacedDigit()
                    
                    if service == .yandex, let url = yandexTrackURL {
                        Button {
                            openURL(url)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(spec.surface)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.white.opacity(spec.cardBorderOpacity), lineWidth: 0.5)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("play")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.white.opacity(spec.cardBorderOpacity), lineWidth: 0.5)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture {
                if !isDragging && dragOffset == 0 {
                    onTap()
                }
            }
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        let horizontalMovement = abs(value.translation.width)
                        let verticalMovement = abs(value.translation.height)
                        
                        // активируем свайп только если:
                        // 1. горизонтальное движение больше 40px
                        // 2. горизонтальное движение в 2.5 раза больше вертикального
                        // это гарантирует что вертикальная прокрутка не блокируется
                        if horizontalMovement > 40 && horizontalMovement > verticalMovement * 2.5 {
                            isDragging = true
                            let newOffset = min(0, max(-maxSwipeDistance, value.translation.width))
                            dragOffset = newOffset
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = -60
                        let horizontalMovement = abs(value.translation.width)
                        let verticalMovement = abs(value.translation.height)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isDragging = false
                        }
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // проверяем что это был явно горизонтальный жест
                            if horizontalMovement > 40 && horizontalMovement > verticalMovement * 2.5 && value.translation.width < threshold {
                                dragOffset = -maxSwipeDistance
                            } else {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.03)) {
                isVisible = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareTrackSheet(track: track)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var coverURL: URL? {
        guard let uri = track.coverUri, !uri.isEmpty else { return nil }
        
        // если уже полный URL
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            return URL(string: uri)
        }
        
        // если это шаблон типа "%%", заменяем на размер и добавляем базовый URL
        // обычно это что-то вроде "avatars.yandex.net/get-music-content/.../%%"
        if uri.contains("%%") {
            let size = "200x200" // размер обложки
            let urlString = uri.replacingOccurrences(of: "%%", with: size)
            // если нет протокола, добавляем https://
            if !urlString.hasPrefix("http") {
                return URL(string: "https://\(urlString)")
            }
            return URL(string: urlString)
        }
        
        // если это относительный путь, пробуем добавить базовый URL
        if uri.hasPrefix("/") || uri.contains("yandex") {
            let urlString = uri.hasPrefix("http") ? uri : "https://\(uri)"
            return URL(string: urlString)
        }
        
        return nil
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var yandexTrackURL: URL? {
        guard let trackId = track.backendId else { return nil }
        if let albumId = track.albumId {
            return URL(string: "https://music.yandex.ru/album/\(albumId)/track/\(trackId)")
        }
        return URL(string: "https://music.yandex.ru/track/\(trackId)")
    }
    
    private func openYouTubeSearch() {
        let query = "\(track.title) \(track.artists)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.youtube.com/results?search_query=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Share Track Sheet

struct ShareTrackSheet: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("переместить трек")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(shareSheetSpec.textPrimary)
                    Text("\(track.title)")
                        .font(.headline)
                        .foregroundStyle(shareSheetSpec.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(track.artists)
                        .font(.subheadline)
                        .foregroundStyle(shareSheetSpec.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .padding(.top, 8)
                VStack(spacing: 16) {
                    ServiceShareButton(service: .yandex, track: track)
                    ServiceShareButton(service: .spotify, track: track)
                    ServiceShareButton(service: .soundcloud, track: track)
                    ServiceShareButton(service: .vk, track: track)
                }
                .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(shareSheetSpec.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("готово") {
                        dismiss()
                    }
                    .foregroundStyle(shareSheetSpec.accent)
                }
            }
        }
    }

    @EnvironmentObject private var themeManager: ThemeManager
    private var shareSheetSpec: ThemeSpec { themeManager.currentSpec }
}

// MARK: - Service Share Button

struct ServiceShareButton: View {
    let service: MusicService
    let track: Track
    
    var body: some View {
        Button {
            handleShare(to: service)
        } label: {
            HStack(spacing: 16) {
                // иконка сервиса
                ZStack {
                    Circle()
                        .fill(service.color)
                        .frame(width: 44, height: 44)
                    
                    if let icon = service.icon {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.white)
                    } else {
                        Text(service.letter)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                
                // название
                Text(service.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func handleShare(to service: MusicService) {
        // TODO: реализовать логику перемещения трека в выбранный сервис
        print("переместить трек '\(track.title)' в \(service.name)")
    }
}

// MARK: - Cached Cover Image

struct CachedCoverImage: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private var cachedCoverSpec: ThemeSpec { themeManager.currentSpec }

    let url: URL?
    let size: CGSize
    let onImageLoaded: () -> Void

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // skeleton placeholder
            if !isLoading && loadedImage == nil {
                SkeletonView()
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // placeholder при отсутствии URL
            if url == nil {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cachedCoverSpec.surface)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    )
                    .frame(width: size.width, height: size.height)
                    .onAppear {
                        onImageLoaded()
                    }
            }
            
            // реальная обложка из кэша
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(width: size.width, height: size.height)
        .task {
            guard let url = url, !isLoading else { return }
            isLoading = true
            
            if let cachedImage = await ImageCacheManager.shared.image(for: url) {
                loadedImage = cachedImage
                onImageLoaded()
            } else {
                // если загрузка не удалась, показываем placeholder
                onImageLoaded()
            }
            isLoading = false
        }
    }
}

// MARK: - Skeleton Loading View

struct SkeletonView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private var skeletonSpec: ThemeSpec { themeManager.currentSpec }

    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        skeletonSpec.surface.opacity(0.8),
                        skeletonSpec.surface,
                        skeletonSpec.surface.opacity(0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 100)
                    .offset(x: shimmerOffset)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 300
                }
            }
    }
}

#Preview {
    ZStack {
        ThemeSpec.spec(for: .cyberpunk).backgroundGradient
            .ignoresSafeArea()
        ScrollView {
            VStack(spacing: 10) {
                TrackRowView(track: Track(
                    backendId: 1710818,
                    albumId: 225654,
                    title: "Bohemian Rhapsody",
                    artists: "Queen",
                    durationMs: 355000,
                    coverUri: nil
                ), index: 0, service: .yandex)
                
                TrackRowView(track: Track(
                    backendId: 1710818,
                    albumId: 225654,
                    title: "Another One Bites the Dust",
                    artists: "Queen",
                    durationMs: 215000,
                    coverUri: nil
                ), index: 1, service: .yandex)
            }
            .padding()
        }
        .environmentObject(ThemeManager())
    }
}
