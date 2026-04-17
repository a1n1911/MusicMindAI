//
//  LibraryViewModel.swift
//  MusicMindAI
//
//  ViewModel для управления состоянием библиотеки треков
//

import Foundation
import SwiftUI
import Combine
import OSLog

final class LibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var isLoadingPlaylists = false
    @Published var error: Error?
    @Published var errorMessage: String?
    @Published var newlyAddedCount: Int = 0
    
    private let musicService: YandexMusicService
    private let trackRepository: TrackRepository
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "LibraryViewModel")
    
    init(musicService: YandexMusicService? = nil, trackRepository: TrackRepository = TrackRepository.shared) {
        self.musicService = musicService ?? YandexMusicService()
        self.trackRepository = trackRepository
    }
    
    var hasTracks: Bool {
        !tracks.isEmpty
    }
    
    var tracksCount: Int {
        tracks.count
    }
    
    var subtitle: String {
        if isLoading { return "Загрузка треков..." }
        if let errorMessage = errorMessage { return "Ошибка: \(errorMessage)" }
        if tracks.isEmpty { return "Треков не найдено" }
        return "Треков: \(tracks.count)"
    }
    
    var subtitleColor: Color {
        if errorMessage != nil { return CyberpunkTheme.neonPink.opacity(0.95) }
        if tracks.isEmpty { return .white.opacity(0.7) }
        return CyberpunkTheme.neonPink.opacity(0.9)
    }
    
    var shouldShowEmptyState: Bool {
        tracks.isEmpty && !isLoading
    }
    
    @MainActor
    func loadTracks(cookies: String, userId: String?) async {
        guard !isLoading else {
            logger.debug("loadTracks: уже загружается, пропускаем")
            return
        }
        
        isLoading = true
        error = nil
        errorMessage = nil
        
        logger.info("loadTracks: начало загрузки, userId=\(userId ?? "nil")")
        
        // сначала пробуем загрузить из кэша
        if let cachedTracks = await trackRepository.loadCachedTracks() {
            logger.info("loadTracks: загружено из кэша \(cachedTracks.count) треков")
            tracks = cachedTracks
            isLoading = false
            
            // обновляем в фоне
            Task {
                _ = await refreshTracks(cookies: cookies, userId: userId)
            }
            return
        }
        
        _ = await refreshTracks(cookies: cookies, userId: userId)
    }
    
    @MainActor
    func refreshTracks(cookies: String, userId: String?) async -> Int {
        let previousCount = tracks.count
        isLoading = true
        
        do {
            let fetchedTracks = try await musicService.fetchTracks(cookies: cookies, userId: userId)
            logger.info("loadTracks: получено \(fetchedTracks.count) треков")
            
            // сохраняем в кэш
            await trackRepository.saveTracks(fetchedTracks)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tracks = fetchedTracks
            }
            
            // вычисляем количество новых треков
            let newCount = max(0, fetchedTracks.count - previousCount)
            newlyAddedCount = newCount
            
            error = nil
            errorMessage = nil
            isLoading = false
            
            return newCount
        } catch {
            logger.error("loadTracks: ошибка \(error.localizedDescription)")
            self.error = error
            
            // улучшенная обработка ошибок
            if let yandexError = error as? YandexMusicError {
                self.errorMessage = yandexError.localizedDescription
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    self.errorMessage = "Нет подключения к интернету"
                case .timedOut:
                    self.errorMessage = "Превышено время ожидания"
                default:
                    self.errorMessage = "Ошибка сети: \(urlError.localizedDescription)"
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
            
            // если есть кэш, показываем его даже при ошибке
            if let cachedTracks = await trackRepository.loadCachedTracks() {
                tracks = cachedTracks
            }
            
            isLoading = false
            return 0
        }
    }
    
    @MainActor
    func loadPlaylists(cookies: String, userId: String?) async {
        guard !isLoadingPlaylists else {
            logger.debug("loadPlaylists: уже загружается, пропускаем")
            return
        }
        
        isLoadingPlaylists = true
        logger.info("loadPlaylists: начало загрузки")
        
        do {
            let fetchedPlaylists = try await musicService.fetchPlaylists(cookies: cookies, userId: userId)
            logger.info("loadPlaylists: получено \(fetchedPlaylists.count) плейлистов")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                playlists = fetchedPlaylists
            }
            
            isLoadingPlaylists = false
        } catch {
            logger.error("loadPlaylists: ошибка \(error.localizedDescription)")
            isLoadingPlaylists = false
        }
    }
    
    @MainActor
    func clearTracks() {
        tracks = []
        playlists = []
        error = nil
        errorMessage = nil
    }
    
    @MainActor
    func exportTracksToCSV() async throws -> URL {
        guard !tracks.isEmpty else {
            throw CSVExportError.noTracksToExport
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let fileName = "yandex_music_tracks_\(timestamp).csv"
        return try await CSVExporter.saveTracks(tracks, to: fileName)
    }
}
