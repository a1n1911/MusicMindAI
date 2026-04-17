//
//  SoundCloudLibraryViewModel.swift
//  MusicMindAI
//
//  ViewModel для библиотеки SoundCloud (track_likes)
//

import Foundation
import SwiftUI
import Combine
import OSLog

final class SoundCloudLibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newlyAddedCount: Int = 0
    
    private let soundCloudService = SoundCloudService()
    private let trackRepository = TrackRepository.shared
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "SoundCloudLibraryVM")
    
    var hasTracks: Bool { !tracks.isEmpty }
    var tracksCount: Int { tracks.count }
    
    var subtitle: String {
        if isLoading { return "Загрузка треков..." }
        if let msg = errorMessage { return "Ошибка: \(msg)" }
        if tracks.isEmpty { return "Треков не найдено" }
        return "Треков: \(tracks.count)"
    }
    
    var subtitleColor: Color {
        if errorMessage != nil { return CyberpunkTheme.neonPink.opacity(0.95) }
        if tracks.isEmpty { return .white.opacity(0.7) }
        return CyberpunkTheme.neonPink.opacity(0.9)
    }
    
    var shouldShowEmptyState: Bool { tracks.isEmpty && !isLoading }
    
    private static let cacheFileName = AppConstants.Cache.soundCloudTracksFileName
    
    @MainActor
    func loadTracks(oauthToken: String, userId: String?) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        if let cached = await trackRepository.loadCachedTracks(cacheFileName: Self.cacheFileName) {
            tracks = cached
            isLoading = false
            Task { _ = await refreshTracks(oauthToken: oauthToken, userId: userId) }
            return
        }
        
        _ = await refreshTracks(oauthToken: oauthToken, userId: userId)
    }
    
    @MainActor
    func refreshTracks(oauthToken: String, userId: String?) async -> Int {
        logger.info("refreshTracks: start tokenLen=\(oauthToken.count) userId=\(userId ?? "nil")")
        let previousCount = tracks.count
        isLoading = true
        
        do {
            let fetched = try await soundCloudService.fetchTracks(oauthToken: oauthToken, userId: userId)
            await trackRepository.saveTracks(fetched, cacheFileName: Self.cacheFileName)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tracks = fetched
            }
            newlyAddedCount = max(0, fetched.count - previousCount)
            errorMessage = nil
            isLoading = false
            return newlyAddedCount
        } catch {
            logger.error("refreshTracks error: \(error.localizedDescription) \(error)")
            if let scError = error as? SoundCloudError {
                errorMessage = scError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            if let cached = await trackRepository.loadCachedTracks(cacheFileName: Self.cacheFileName) {
                tracks = cached
            }
            isLoading = false
            return 0
        }
    }
    
    @MainActor
    func clearTracks() {
        tracks = []
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
        
        let fileName = "soundcloud_tracks_\(timestamp).csv"
        return try await CSVExporter.saveTracks(tracks, to: fileName)
    }
}
