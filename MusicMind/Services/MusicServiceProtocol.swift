//
//  MusicServiceProtocol.swift
//  MusicMindAI
//
//  Протокол для музыкальных сервисов
//

import Foundation

protocol MusicServiceProtocol: Actor {
    func fetchUserId(cookies: String) async -> String?
    func fetchTracks(cookies: String, userId: String?) async throws -> [Track]
}
