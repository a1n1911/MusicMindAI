//
//  VKLibraryViewModel.swift
//  MusicMindAI
//
//  ViewModel для библиотеки VK Музыки (audio.get по owner_id).
//

import Foundation
import SwiftUI
import Combine
import OSLog

final class VKLibraryViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var newlyAddedCount: Int = 0

    private let vkService = VKMusicService()
    private let trackRepository = TrackRepository.shared
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "VKLibraryVM")

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

    private static let cacheFileName = AppConstants.Cache.vkTracksFileName

    @MainActor
    func loadTracks(token: String, userAgent: String, userId: String?) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        if let cached = await trackRepository.loadCachedTracks(cacheFileName: Self.cacheFileName) {
            tracks = cached
            isLoading = false
            Task { _ = await refreshTracks(token: token, userAgent: userAgent, userId: userId) }
            return
        }

        _ = await refreshTracks(token: token, userAgent: userAgent, userId: userId)
    }

    @MainActor
    func refreshTracks(token: String, userAgent: String, userId: String?) async -> Int {
        let previousCount = tracks.count
        isLoading = true

        do {
            let fetched = try await vkService.fetchTracks(token: token, userAgent: userAgent, userId: userId)
            await trackRepository.saveTracks(fetched, cacheFileName: Self.cacheFileName)

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tracks = fetched
            }
            newlyAddedCount = max(0, fetched.count - previousCount)
            errorMessage = nil
            isLoading = false
            return newlyAddedCount
        } catch {
            logger.error("refreshTracks error: \(error.localizedDescription)")
            if let vkError = error as? VKMusicError {
                errorMessage = vkError.localizedDescription
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
        
        let fileName = "vk_music_tracks_\(timestamp).csv"
        return try await CSVExporter.saveTracks(tracks, to: fileName)
    }
}
