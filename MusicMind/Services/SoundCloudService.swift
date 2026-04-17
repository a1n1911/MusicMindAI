//
//  SoundCloudService.swift
//  MusicMindAI
//
//  Загрузка треков (track_likes) по OAuth токену
//

import Foundation
import OSLog

// MARK: - API response models

private struct SoundCloudUser: Codable {
    let id: Int?
    let username: String?
}

private struct SoundCloudTrackRaw: Codable {
    let id: Int?
    let title: String?
    let duration: Int?
    let artworkUrl: String?
    let user: SoundCloudUser?
    let publisherMetadata: PublisherMetadata?
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, user
        case artworkUrl = "artwork_url"
        case publisherMetadata = "publisher_metadata"
    }
    
    struct PublisherMetadata: Codable {
        let artist: String?
    }
}

private struct SoundCloudLikeItem: Codable {
    let track: SoundCloudTrackRaw?
}

private struct TrackLikesResponse: Codable {
    let collection: [SoundCloudLikeItem]?
    let nextHref: String?
    
    enum CodingKeys: String, CodingKey {
        case collection
        case nextHref = "next_href"
    }
}

// MARK: - Service

actor SoundCloudService {
    private let baseURL = AppConstants.SoundCloud.baseURL
    private let clientId = AppConstants.SoundCloud.clientId
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "SoundCloudService")
    private let urlSession: URLSession
    
    init(urlSession: URLSession? = nil) {
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.urlSession = URLSession(configuration: configuration)
        }
    }
    
    func fetchUserId(oauthToken: String) async -> String? {
        logger.info("fetchUserId: tokenLen=\(oauthToken.count)")
        if let uid = parseUserIdFromToken(oauthToken) {
            logger.info("fetchUserId: parsed uid=\(uid)")
            return uid
        }
        logger.warning("fetchUserId: parse failed, token prefix=\(oauthToken.prefix(20))...")
        return nil
    }

    /// Парсит user id из токена формата 2-{userId}-{sessionId}-{hash} (как в браузере)
    private func parseUserIdFromToken(_ token: String) -> String? {
        let parts = token.split(separator: "-")
        guard parts.count >= 2, parts[0] == "2" else { return nil }
        let uid = String(parts[1])
        return uid.allSatisfy(\.isNumber) ? uid : nil
    }
    
    func fetchTracks(oauthToken: String, userId: String?) async throws -> [Track] {
        logger.info("fetchTracks: start userId=\(userId ?? "nil")")
        var uid = userId
        if uid == nil {
            uid = await fetchUserId(oauthToken: oauthToken)
        }
        guard let uid = uid else {
            logger.error("fetchTracks: no userId")
            throw SoundCloudError.noUserId
        }
        logger.info("fetchTracks: using uid=\(uid)")
        var allTracks: [Track] = []
        let firstURL = "\(baseURL)/users/\(uid)/track_likes?limit=1000&client_id=\(clientId)&app_version=\(AppConstants.SoundCloud.appVersion)&app_locale=\(AppConstants.SoundCloud.appLocale)"
        logger.info("fetchTracks: firstURL=\(firstURL)")
        var nextURL: URL? = URL(string: firstURL)
        
        while let url = nextURL {
            let (tracks, next) = try await fetchPage(url: url, oauthToken: oauthToken)
            allTracks.append(contentsOf: tracks)
            nextURL = next
        }
        
        // дедупликация по title+artists
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
    
    private func setCommonHeaders(_ request: inout URLRequest, oauthToken: String) {
        request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConstants.SoundCloud.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(AppConstants.SoundCloud.acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue(AppConstants.SoundCloud.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(AppConstants.SoundCloud.referer, forHTTPHeaderField: "Referer")
        request.setValue(AppConstants.SoundCloud.origin, forHTTPHeaderField: "Origin")
    }
    
    private func fetchPage(url: URL, oauthToken: String) async throws -> (tracks: [Track], nextURL: URL?) {
        logger.info("fetchPage: url=\(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setCommonHeaders(&request, oauthToken: oauthToken)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            logger.error("fetchPage: no HTTP response")
            throw SoundCloudError.invalidToken
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("fetchPage: HTTP \(http.statusCode) body=\(body.prefix(500))")
            throw SoundCloudError.invalidToken
        }
        
        let decoded = try JSONDecoder().decode(TrackLikesResponse.self, from: data)
        let tracks = (decoded.collection ?? []).compactMap { item -> Track? in
            guard let raw = item.track else { return nil }
            return mapToTrack(raw)
        }
        
        var next: URL? = nil
        if let nextHref = decoded.nextHref, let nextURL = URL(string: nextHref) {
            next = nextURL
        }
        
        logger.info("fetchPage: ok, tracks=\(tracks.count) nextHref=\(decoded.nextHref ?? "nil")")
        return (tracks, next)
    }
    
    private func mapToTrack(_ raw: SoundCloudTrackRaw) -> Track {
        let artists = raw.publisherMetadata?.artist
            ?? raw.user?.username
            ?? "Unknown"
        let coverUri = raw.artworkUrl
        return Track(
            backendId: raw.id,
            title: raw.title ?? "Unknown",
            artists: artists,
            durationMs: raw.duration ?? 0,
            coverUri: coverUri,
            available: true
        )
    }
}

enum SoundCloudError: LocalizedError {
    case noUserId
    case invalidToken
    
    var errorDescription: String? {
        switch self {
        case .noUserId: return "Не удалось получить user_id"
        case .invalidToken: return "Неверный OAuth токен. Войдите заново"
        }
    }
}
