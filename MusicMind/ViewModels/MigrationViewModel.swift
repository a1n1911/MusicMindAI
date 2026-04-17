//
//  MigrationViewModel.swift
//  MusicMind
//
//  Миграция треков (например SoundCloud → Яндекс): поиск + добавление в лайки.
//

import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
final class MigrationViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var currentIndex: Int = 0
    @Published var totalCount: Int = 0
    @Published var isRunning: Bool = false
    @Published var migratedCount: Int = 0
    @Published var failedCount: Int = 0
    @Published var errorMessage: String?
    @Published var isFinished: Bool = false

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }

    private let musicService = YandexMusicService()
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "MigrationVM")
    private var migrationTask: Task<Void, Never>?
    private var isCancelled = false

    func startMigration(tracks: [Track], cookies: String, userId: String?) {
        guard !tracks.isEmpty, !isRunning else { return }

        isCancelled = false
        isFinished = false
        errorMessage = nil
        migratedCount = 0
        failedCount = 0
        totalCount = tracks.count
        currentIndex = 0
        currentTrack = tracks.first
        isRunning = true

        migrationTask = Task { @MainActor in
            let uid: String?
            if let userId = userId {
                uid = userId
            } else {
                uid = await musicService.fetchUserId(cookies: cookies)
            }
            guard let uid else {
                errorMessage = "Не удалось получить user_id Яндекса"
                isRunning = false
                return
            }
            
            // батчинг: обрабатываем треки батчами по 5 параллельно
            let batchSize = 5
            let batches = tracks.chunked(into: batchSize)
            
            for (batchIndex, batch) in batches.enumerated() {
                if isCancelled { break }
                
                // обновляем прогресс для первого трека батча
                if let firstTrack = batch.first {
                    currentIndex = batchIndex * batchSize
                    currentTrack = firstTrack
                }
                
                // обрабатываем батч параллельно
                await withTaskGroup(of: MigrationResult.self) { group in
                    for track in batch {
                        if isCancelled { break }
                        group.addTask {
                            await self.migrateTrack(track, cookies: cookies, userId: uid)
                        }
                    }
                    
                    // собираем результаты
                    for await result in group {
                        if result.success {
                            await MainActor.run {
                                migratedCount += 1
                            }
                        } else {
                            await MainActor.run {
                                failedCount += 1
                            }
                        }
                    }
                }
                
                // небольшая задержка между батчами для избежания rate limiting
                if batchIndex < batches.count - 1 && !isCancelled {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 сек между батчами
                }
            }
            
            isRunning = false
            isFinished = true
            currentTrack = nil
        }
    }
    
    private struct MigrationResult {
        let success: Bool
    }
    
    private func migrateTrack(_ track: Track, cookies: String, userId: String) async -> MigrationResult {
        let query = "\(track.title) \(track.artists)"
        do {
            if let (trackId, albumId) = try await musicService.searchTrack(query: query, cookies: cookies, userId: userId) {
                try await musicService.addTrackToLikes(trackId: trackId, albumId: albumId, cookies: cookies, userId: userId)
                return MigrationResult(success: true)
            } else {
                logger.debug("searchTrack: не найден \(query)")
                return MigrationResult(success: false)
            }
        } catch {
            logger.error("миграция трека \(query): \(error.localizedDescription)")
            return MigrationResult(success: false)
        }
    }

    func cancelMigration() {
        isCancelled = true
        migrationTask?.cancel()
    }

    func reset() {
        cancelMigration()
        currentTrack = nil
        currentIndex = 0
        totalCount = 0
        isRunning = false
        migratedCount = 0
        failedCount = 0
        errorMessage = nil
        isFinished = false
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
