//
//  VKMusicService.swift
//  MusicMindAI
//
//  Загрузка треков из VK Музыки по токену + user-agent (API как в vkpymusic).
//

import Foundation
import OSLog

// MARK: - API response models

private struct VKApiResponse<T: Decodable>: Decodable {
    let response: T?
}

private struct VKApiError: Decodable {
    let error: VKErrorPayload?
}

private struct VKErrorPayload: Decodable {
    let errorCode: Int?
    let errorMsg: String?
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMsg = "error_msg"
    }
}

private struct VKProfileInfo: Decodable {
    let id: Int?
}

private struct VKAudioItem: Decodable {
    let id: Int?
    let ownerId: Int?
    let title: String?
    let artist: String?
    let duration: Int?
    let url: String?
    enum CodingKeys: String, CodingKey {
        case id, title, artist, duration, url
        case ownerId = "owner_id"
    }
}

private struct VKAudioResponse: Decodable {
    let items: [VKAudioItem]?
}

// MARK: - Service

actor VKMusicService {
    private let baseURL = AppConstants.VKMusic.baseURL
    private let version = AppConstants.VKMusic.apiVersion
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "VKMusicService")
    private let urlSession: URLSession

    init(urlSession: URLSession? = nil) {
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.urlSession = URLSession(configuration: config)
        }
    }

    func fetchUserId(token: String, userAgent: String) async -> String? {
        var components = URLComponents(string: "\(baseURL)/account.getProfileInfo")
        components?.queryItems = [
            URLQueryItem(name: "access_token", value: token),
            URLQueryItem(name: "v", value: version),
            URLQueryItem(name: "https", value: "1"),
            URLQueryItem(name: "lang", value: "ru"),
        ]
        guard let url = components?.url else {
            logger.error("fetchUserId: invalid URL")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if let err = try? JSONDecoder().decode(VKApiError.self, from: data),
                   let payload = err.error {
                    throw VKMusicError.apiError(code: payload.errorCode ?? 0, message: payload.errorMsg ?? "Unknown")
                }
                throw VKMusicError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(VKApiResponse<VKProfileInfo>.self, from: data)
            guard let info = decoded.response, let id = info.id else {
                logger.warning("fetchUserId: no id in response")
                return nil
            }
            logger.info("fetchUserId: ok uid=\(id)")
            return String(id)
        } catch {
            logger.error("fetchUserId error: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchTracks(token: String, userAgent: String, userId: String?) async throws -> [Track] {
        var uid = userId
        if uid == nil {
            uid = await fetchUserId(token: token, userAgent: userAgent)
        }
        guard let uid = uid, let ownerId = Int(uid) else {
            throw VKMusicError.noUserId
        }

        var allTracks: [Track] = []
        var offset = 0
        let count = 100

        while true {
            var components = URLComponents(string: "\(baseURL)/audio.get")
            components?.queryItems = [
                URLQueryItem(name: "access_token", value: token),
                URLQueryItem(name: "owner_id", value: String(ownerId)),
                URLQueryItem(name: "count", value: String(count)),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "v", value: version),
                URLQueryItem(name: "https", value: "1"),
                URLQueryItem(name: "lang", value: "ru"),
                URLQueryItem(name: "extended", value: "1"),
            ]
            guard let url = components?.url else {
                throw VKMusicError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if let err = try? JSONDecoder().decode(VKApiError.self, from: data),
                   let payload = err.error {
                    throw VKMusicError.apiError(code: payload.errorCode ?? 0, message: payload.errorMsg ?? "Unknown")
                }
                throw VKMusicError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(VKApiResponse<VKAudioResponse>.self, from: data)
            let items = decoded.response?.items ?? []
            if items.isEmpty { break }

            for item in items {
                allTracks.append(mapToTrack(item))
            }
            offset += items.count
            if items.count < count { break }
        }

        var seen = Set<String>()
        let unique = allTracks.filter { track in
            let key = "\(track.title.lowercased())-\(track.artists.lowercased())"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        logger.info("fetchTracks: всего \(unique.count) уникальных треков")
        return unique
    }

    private func mapToTrack(_ item: VKAudioItem) -> Track {
        let durationSec = item.duration ?? 0
        return Track(
            backendId: item.id,
            title: item.title ?? "Unknown",
            artists: item.artist ?? "Unknown",
            durationMs: durationSec * 1000,
            coverUri: nil,
            available: true
        )
    }
}

enum VKMusicError: LocalizedError {
    case noUserId
    case invalidURL
    case invalidResponse
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noUserId: return "Не удалось получить user_id VK"
        case .invalidURL: return "Неверный URL запроса"
        case .invalidResponse: return "Неверный ответ VK API"
        case .apiError(let code, let msg): return "VK API \(code): \(msg)"
        }
    }
}
