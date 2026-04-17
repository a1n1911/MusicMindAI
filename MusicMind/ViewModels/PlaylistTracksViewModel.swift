//
//  PlaylistTracksViewModel.swift
//  MusicMindAI
//
//  ViewModel для загрузки треков плейлиста
//

import Foundation
import SwiftUI
import Combine
import OSLog

final class PlaylistTracksViewModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let playlist: Playlist
    private let musicService: YandexMusicService
    private let cookies: String
    private let userId: String?
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "PlaylistTracksViewModel")
    
    var onPlaylistDeleted: (() -> Void)?
    
    init(
        playlist: Playlist,
        cookies: String,
        userId: String?,
        musicService: YandexMusicService? = nil,
        onPlaylistDeleted: (() -> Void)? = nil
    ) {
        self.playlist = playlist
        self.cookies = cookies
        self.userId = userId
        self.musicService = musicService ?? YandexMusicService()
        self.onPlaylistDeleted = onPlaylistDeleted
    }
    
    @MainActor
    func loadTracks() async {
        guard !isLoading else { return }
        
        // нужен kind для получения треков
        guard let kind = extractKindFromPlaylist() else {
            logger.warning("loadTracks: не удалось получить kind из плейлиста")
            errorMessage = "Не удалось загрузить треки"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTracks = try await musicService.fetchPlaylistTracks(
                kind: kind,
                cookies: cookies,
                userId: userId
            )
            
            logger.info("loadTracks: загружено \(fetchedTracks.count) треков")
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                tracks = fetchedTracks
            }
            
            isLoading = false
        } catch {
            logger.error("loadTracks: ошибка \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func extractKindFromPlaylist() -> Int? {
        return playlist.kind
    }
    
    @MainActor
    func deletePlaylist() async {
        guard let kind = playlist.kind else {
            errorMessage = "Не удалось определить плейлист для удаления"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await musicService.deletePlaylist(
                kind: kind,
                cookies: cookies,
                userId: userId
            )
            
            logger.info("deletePlaylist: успешно удален плейлист kind=\(kind)")
            onPlaylistDeleted?()
            isLoading = false
        } catch {
            logger.error("deletePlaylist: ошибка \(error.localizedDescription)")
            if let yandexError = error as? MusicMind.YandexMusicError {
                errorMessage = yandexError.localizedDescription
            } else {
                errorMessage = "Ошибка: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}
