//
//  CreatePlaylistViewModel.swift
//  MusicMindAI
//
//  ViewModel для создания плейлиста через Gemini
//

import Foundation
import SwiftUI
import Combine
import OSLog

struct PlaylistCreatedEvent: Sendable {
    let uuid: String
    let title: String
}

final class CreatePlaylistViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isCreating: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    @Published var desiredTrackCount: Int = 10
    @Published var foundTracksCount: Int = 0
    @Published var totalTracksCount: Int = 0
    @Published var generatedTitle: String = ""
    /// список треков от AI в формате "название — артист" (то, что покажем юзеру перед подтверждением)
    @Published var generatedTrackQueries: [String] = []
    @Published var playlistUuid: String? = nil
    /// обложки найденных треков (для красивой анимации во время добавления)
    @Published var loadingCoverTracks: [Track] = []
    
    private let geminiService: GeminiService
    private let musicService: YandexMusicService
    private let cookies: String
    private let userId: String?
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "CreatePlaylistViewModel")
    
    var onPlaylistCreated: ((PlaylistCreatedEvent) -> Void)?
    
    init(
        geminiService: GeminiService? = nil,
        musicService: YandexMusicService? = nil,
        cookies: String,
        userId: String?,
        onPlaylistCreated: ((PlaylistCreatedEvent) -> Void)? = nil
    ) {
        self.geminiService = geminiService ?? GeminiService()
        self.musicService = musicService ?? YandexMusicService()
        self.cookies = cookies
        self.userId = userId
        self.onPlaylistCreated = onPlaylistCreated
    }
    
    @MainActor
    func createPlaylist() async {
        // теперь это ШАГ 1: только генерим список и показываем юзеру (без создания плейлиста)
        guard !query.isEmpty, !isCreating else { return }
        
        let startTime = Date()
        isCreating = true
        errorMessage = nil
        playlistUuid = nil
        foundTracksCount = 0
        totalTracksCount = 0
        generatedTitle = ""
        generatedTrackQueries = []
        loadingCoverTracks = []
        statusMessage = "генерирую плейлист..."
        
        do {
            // шаг 1: запрашиваем треки у Gemini
            logger.info("createPlaylist: запрос к Gemini для запроса: '\(self.query)'")
            let requestedCount = min(20, max(5, desiredTrackCount))
            let (title, trackQueries) = try await geminiService.generatePlaylistTracks(query: self.query, count: requestedCount)
            
            let trimmed = Array(trackQueries.prefix(requestedCount))
            guard !trimmed.isEmpty else {
                throw CreatePlaylistError.noTracksGenerated
            }
            
            totalTracksCount = trimmed.count
            // добавляем префикс к названию для отображения + создания в яндексе (чтобы было одинаково)
            generatedTitle = "[MusicMindAI] \(title)"
            generatedTrackQueries = trimmed

            statusMessage = "проверь список и нажми «добавить»"
            logger.info("createPlaylist: сгенерирован список из \(trimmed.count) треков, title='\(title)'")
            
        } catch {
            logger.error("createPlaylist: ошибка \(error.localizedDescription)")
            if let createError = error as? CreatePlaylistError {
                errorMessage = createError.localizedDescription
            } else if let yandexError = error as? MusicMind.YandexMusicError {
                errorMessage = yandexError.localizedDescription
            } else if let geminiError = error as? GeminiError {
                errorMessage = geminiError.localizedDescription
            } else {
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
        
        isCreating = false
    }
    
    /// ШАГ 2: юзер подтвердил — теперь реально создаём плейлист и добавляем треки.
    @MainActor
    func addGeneratedTracksToPlaylist() async {
        guard !isCreating, !generatedTrackQueries.isEmpty else { return }
        
        let startTime = Date()
        isCreating = true
        errorMessage = nil
        playlistUuid = nil
        foundTracksCount = 0
        totalTracksCount = generatedTrackQueries.count
        loadingCoverTracks = []
        statusMessage = "ищу треки в Яндекс.Музыке..."
        
        do {
            // шаг 1: ищем треки в Яндекс.Музыке (параллельно батчами)
            var foundTracks: [(trackId: Int, albumId: Int)] = []
            var coversSeenCount = 0
            var coverUrisSeen = Set<String>()

            func considerCoverTrack(_ track: Track) {
                // грузим только 4 случайные обложки из всех найденных (reservoir sampling)
                guard let coverUri = track.coverUri, !coverUri.isEmpty else { return }
                guard !coverUrisSeen.contains(coverUri) else { return }
                coverUrisSeen.insert(coverUri)

                coversSeenCount += 1

                if loadingCoverTracks.count < 4 {
                    loadingCoverTracks.append(track)
                    return
                }

                let j = Int.random(in: 0..<coversSeenCount)
                if j < 4 {
                    loadingCoverTracks[j] = track
                }
            }

            struct SearchJob: Sendable {
                let original: String
                let searchQuery: String
                let fallbackTitle: String?
                let title: String
                let artists: String
            }

            let jobs: [SearchJob] = generatedTrackQueries.map { trackQuery in
                let parts = trackQuery.components(separatedBy: " — ")
                let title = (parts.first ?? trackQuery).trimmingCharacters(in: .whitespacesAndNewlines)
                let artists = (parts.count >= 2 ? parts[1] : "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
                let searchQuery = parts.count >= 2 ? "\(parts[0]) \(parts[1])" : trackQuery
                return SearchJob(
                    original: trackQuery,
                    searchQuery: searchQuery,
                    fallbackTitle: parts.count >= 2 ? parts[0] : nil,
                    title: title.isEmpty ? "Unknown" : title,
                    artists: artists.isEmpty ? "Unknown" : artists
                )
            }

            let batchSize = 4
            var idx = 0

            while idx < jobs.count {
                let end = min(jobs.count, idx + batchSize)
                let batch = Array(jobs[idx..<end])

                let results: [(trackId: Int, albumId: Int, coverUri: String?, title: String, artists: String)] = await withTaskGroup(
                    of: (trackId: Int, albumId: Int, coverUri: String?, title: String, artists: String)?.self,
                    returning: [(trackId: Int, albumId: Int, coverUri: String?, title: String, artists: String)].self
                ) { group in
                    for job in batch {
                        group.addTask { [musicService, cookies, userId] in
                            if let info = try? await musicService.searchTrackWithCover(query: job.searchQuery, cookies: cookies, userId: userId) {
                                return (info.trackId, info.albumId, info.coverUri, job.title, job.artists)
                            }
                            if let fallback = job.fallbackTitle,
                               let info = try? await musicService.searchTrackWithCover(query: fallback, cookies: cookies, userId: userId) {
                                return (info.trackId, info.albumId, info.coverUri, job.title, job.artists)
                            }
                            return nil
                        }
                    }

                    var collected: [(trackId: Int, albumId: Int, coverUri: String?, title: String, artists: String)] = []
                    for await item in group {
                        if let item { collected.append(item) }
                    }
                    return collected
                }

                for r in results {
                    foundTracks.append((trackId: r.trackId, albumId: r.albumId))
                    foundTracksCount = foundTracks.count
                    statusMessage = "найдено \(foundTracks.count) из \(generatedTrackQueries.count) треков..."

                    if let coverUri = r.coverUri, !coverUri.isEmpty {
                        considerCoverTrack(
                            Track(
                                backendId: r.trackId,
                                albumId: r.albumId,
                                title: r.title,
                                artists: r.artists,
                                durationMs: 0,
                                coverUri: coverUri,
                                available: true
                            )
                        )
                    }
                }

                idx = end
            }
            
            // создаем плейлист даже если нашлось меньше треков, чем запрошено
            guard !foundTracks.isEmpty else {
                throw CreatePlaylistError.noTracksFound
            }
            
            if foundTracks.count < generatedTrackQueries.count {
                logger.info("addGeneratedTracksToPlaylist: найдено только \(foundTracks.count) из \(self.generatedTrackQueries.count) треков, создаем плейлист с найденными")
            }
            
            statusMessage = "создаю плейлист..."
            logger.info("addGeneratedTracksToPlaylist: найдено \(foundTracks.count) треков из \(self.generatedTrackQueries.count)")
            
            // шаг 2: создаем плейлист
            let playlistTitle = generatedTitle.isEmpty ? "[MusicMindAI] playlist" : generatedTitle
            let (kind, revision, uuid) = try await musicService.createPlaylist(
                title: playlistTitle,
                cookies: cookies,
                userId: userId
            )
            
            playlistUuid = uuid
            
            statusMessage = "добавляю треки..."
            logger.info("addGeneratedTracksToPlaylist: плейлист создан, kind=\(kind), revision=\(revision)")
            
            // шаг 3: добавляем треки в плейлист
            guard let uid = userId else {
                throw CreatePlaylistError.noUserId
            }
            
            try await musicService.addTracksToPlaylist(
                kind: kind,
                revision: revision,
                trackIds: foundTracks,
                cookies: cookies,
                userId: uid
            )
            
            logger.info("addGeneratedTracksToPlaylist: успешно создан плейлист '\(playlistTitle)' с \(foundTracks.count) треками")
            
            // гарантируем минимум 12 секунд показа прогрессбара
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumWaitTime: TimeInterval = 12.0
            let remainingWait = max(0, minimumWaitTime - elapsed)
            
            if remainingWait > 0 {
                statusMessage = "готово!"
                try? await Task.sleep(nanoseconds: UInt64(remainingWait * 1_000_000_000))
            }
            
            statusMessage = "готово!"
            
            // обновляем список плейлистов
            if !uuid.isEmpty {
                onPlaylistCreated?(PlaylistCreatedEvent(uuid: uuid, title: playlistTitle))
            }
        } catch {
            logger.error("addGeneratedTracksToPlaylist: ошибка \(error.localizedDescription)")
            if let createError = error as? CreatePlaylistError {
                errorMessage = createError.localizedDescription
            } else if let yandexError = error as? MusicMind.YandexMusicError {
                errorMessage = yandexError.localizedDescription
            } else if let geminiError = error as? GeminiError {
                errorMessage = geminiError.localizedDescription
            } else {
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
        }
        
        isCreating = false
    }
    
    @MainActor
    func resetGeneratedPreview() {
        guard !isCreating else { return }
        generatedTrackQueries = []
        generatedTitle = ""
        playlistUuid = nil
        foundTracksCount = 0
        totalTracksCount = 0
        loadingCoverTracks = []
        statusMessage = ""
    }
}

enum CreatePlaylistError: LocalizedError {
    case noTracksGenerated
    case noTracksFound
    case noUserId
    
    var errorDescription: String? {
        switch self {
        case .noTracksGenerated:
            return "Не удалось сгенерировать список треков"
        case .noTracksFound:
            return "Не удалось найти треки в Яндекс.Музыке"
        case .noUserId:
            return "Не удалось получить user_id"
        }
    }
}
