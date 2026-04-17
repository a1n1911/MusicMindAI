//
//  AnimatedCoversView.swift
//  MusicMindAI
//
//  Анимация смены обложек треков (слайдшоу)
//

import SwiftUI

struct AnimatedCoversView: View {
    let tracks: [Track]
    var changeInterval: TimeInterval = 7.0
    @State private var selectedTracks: [Track] = []
    @State private var currentIndex = 0
    @State private var isImageLoaded = false
    @State private var slideshowTimer: Timer?
    @State private var cachedImages: [String: UIImage] = [:]
    @State private var preloadIndex = 1
    
    private let coverCount = 10
    private let coverSize: CGFloat = 300
    
    var body: some View {
        ZStack {
            if !selectedTracks.isEmpty {
                let currentTrack = selectedTracks[currentIndex % selectedTracks.count]
                let imageUrl = imageURL(for: currentTrack)
                
                // размытый дубликат (glow эффект) - используем то же изображение из кэша
                if let image = cachedImages[imageUrl?.absoluteString ?? ""] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: coverSize * 1.1, height: coverSize * 1.1)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .opacity(isImageLoaded ? 0.15 : 0)
                        .blur(radius: 40)
                        .offset(y: 10)
                }
                
                // основная обложка
                OptimizedCoverImageView(
                    url: imageUrl,
                    size: coverSize,
                    cachedImage: cachedImages[imageUrl?.absoluteString ?? ""],
                    onImageLoaded: { image in
                        if let image = image, let urlString = imageUrl?.absoluteString {
                            cachedImages[urlString] = image
                        }
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isImageLoaded = true
                        }
                    }
                )
                .id(currentTrack.id)
                .opacity(isImageLoaded ? 1.0 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            setupCovers()
            startSlideshow()
        }
        .onDisappear {
            slideshowTimer?.invalidate()
            slideshowTimer = nil
        }
        .onChange(of: currentIndex) { _ in
            // если всего 1 обложка — не гасим (иначе словим "пустоту" без перезагрузки)
            guard selectedTracks.count > 1 else { return }
            isImageLoaded = false
            preloadNext()
        }
        .onChange(of: tracks) { _ in
            // в CreatePlaylistView список обложек приходит постепенно — подхватываем новые
            setupCovers()
            startSlideshow()
        }
    }
    
    private func setupCovers() {
        // выбираем треки с обложками
        let tracksWithCovers = tracks.filter { track in
            guard let uri = track.coverUri, !uri.isEmpty else { return false }
            return true
        }
        
        guard !tracksWithCovers.isEmpty else {
            print("[AnimatedCovers] No tracks with covers found")
            selectedTracks = []
            slideshowTimer?.invalidate()
            slideshowTimer = nil
            return
        }

        // важно: в CreatePlaylistView список треков приходит постепенно.
        // если каждый раз делать shuffled().prefix(...) — обложки будут "скакать".
        // поэтому сохраняем уже выбранные и только ДОБАВЛЯЕМ новые.
        let existingCoverUris: Set<String> = Set(selectedTracks.compactMap { $0.coverUri }.filter { !$0.isEmpty })
        var newSelected = selectedTracks
        
        if newSelected.isEmpty {
            // первый запуск — выбираем случайные треки
            newSelected = Array(tracksWithCovers.shuffled().prefix(coverCount))
            currentIndex = 0
        } else if newSelected.count < coverCount {
            // добавляем недостающие, не трогая текущие
            let candidates = tracksWithCovers.filter { track in
                guard let uri = track.coverUri, !uri.isEmpty else { return false }
                return !existingCoverUris.contains(uri)
            }
            if !candidates.isEmpty {
                newSelected.append(contentsOf: candidates.shuffled().prefix(coverCount - newSelected.count))
            }
        }
        
        // если вдруг текущий индекс вылез — фиксим
        if !newSelected.isEmpty, currentIndex >= newSelected.count {
            currentIndex = 0
        }
        
        selectedTracks = newSelected
        print("[AnimatedCovers] Selected \(selectedTracks.count) tracks with covers")
        
        // предзагружаем первую и следующую обложки
        if let firstUrl = imageURL(for: selectedTracks[0]) {
            Task {
                if let image = await ImageCacheManager.shared.image(for: firstUrl) {
                    await MainActor.run {
                        cachedImages[firstUrl.absoluteString] = image
                        // если это единственная обложка — сразу показываем
                        if selectedTracks.count == 1 {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isImageLoaded = true
                            }
                        }
                    }
                }
            }
        }
        preloadNext()
        
        // сбрасываем флаг загрузки для первой обложки
        isImageLoaded = false
    }
    
    private func preloadNext() {
        guard !selectedTracks.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % selectedTracks.count
        if let nextUrl = imageURL(for: selectedTracks[nextIndex]) {
            Task {
                _ = await ImageCacheManager.shared.image(for: nextUrl)
            }
        }
    }
    
    private func startSlideshow() {
        slideshowTimer?.invalidate()
        guard selectedTracks.count > 1 else { return }
        
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: changeInterval, repeats: true) { timer in
            // плавно скрываем текущую
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    isImageLoaded = false
                }
                
                // через небольшую задержку меняем на следующую
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 секунды
                guard !selectedTracks.isEmpty else {
                    timer.invalidate()
                    return
                }
                // сбрасываем флаг перед сменой (onChange тоже сработает, но на всякий случай)
                isImageLoaded = false
                currentIndex = (currentIndex + 1) % selectedTracks.count
                // изображение начнет загружаться, и когда загрузится - покажется через onImageLoaded
            }
        }
    }
    
    private func imageURL(for track: Track) -> URL? {
        guard let uri = track.coverUri, !uri.isEmpty else {
            print("[AnimatedCovers] No coverUri for track: \(track.title)")
            return nil
        }
        
        // если уже полный URL
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            let url = URL(string: uri)
            print("[AnimatedCovers] Full URL: \(uri)")
            return url
        }
        
        // если это шаблон типа "%%", заменяем на размер и добавляем базовый URL
        // обычно это что-то вроде "avatars.yandex.net/get-music-content/.../%%"
        if uri.contains("%%") {
            let size = "400x400" // размер обложки для большого экрана
            let urlString = uri.replacingOccurrences(of: "%%", with: size)
            // если нет протокола, добавляем https://
            let finalURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
            let url = URL(string: finalURL)
            print("[AnimatedCovers] Template URL: \(uri) -> \(finalURL)")
            return url
        }
        
        // если это относительный путь, пробуем добавить базовый URL
        if uri.hasPrefix("/") || uri.contains("yandex") {
            let urlString = uri.hasPrefix("http") ? uri : "https://\(uri)"
            let url = URL(string: urlString)
            print("[AnimatedCovers] Relative URL: \(uri) -> \(urlString)")
            return url
        }
        
        // если URI начинается с //, добавляем https:
        if uri.hasPrefix("//") {
            let urlString = "https:\(uri)"
            let url = URL(string: urlString)
            print("[AnimatedCovers] Protocol-relative URL: \(uri) -> \(urlString)")
            return url
        }
        
        print("[AnimatedCovers] Could not parse URI: \(uri)")
        return nil
    }
}

// MARK: - Optimized Cover Image View

private struct OptimizedCoverImageView: View {
    let url: URL?
    let size: CGFloat
    let cachedImage: UIImage?
    let onImageLoaded: (UIImage?) -> Void
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasCalledCallback = false
    
    var body: some View {
        Group {
            if let image = loadedImage ?? cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
        .task {
            // если уже есть в кэше, используем его
            if let cached = cachedImage {
                loadedImage = cached
                if !hasCalledCallback {
                    hasCalledCallback = true
                    onImageLoaded(cached)
                }
                return
            }
            
            // иначе загружаем
            guard let url = url, !isLoading else { return }
            isLoading = true
            
            if let image = await ImageCacheManager.shared.image(for: url) {
                loadedImage = image
                if !hasCalledCallback {
                    hasCalledCallback = true
                    onImageLoaded(image)
                }
            } else {
                // даже при ошибке вызываем callback
                if !hasCalledCallback {
                    hasCalledCallback = true
                    onImageLoaded(nil)
                }
            }
            isLoading = false
        }
    }
}

#Preview {
    ZStack {
        CyberpunkTheme.backgroundGradient
            .ignoresSafeArea()
        
        AnimatedCoversView(tracks: [
            Track(title: "Track 1", artists: "Artist 1", durationMs: 180000, coverUri: "https://avatars.yandex.net/get-music-content/123456/example.jpg"),
            Track(title: "Track 2", artists: "Artist 2", durationMs: 200000, coverUri: "https://avatars.yandex.net/get-music-content/123456/example2.jpg"),
        ])
    }
}
