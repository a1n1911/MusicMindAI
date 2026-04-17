//
//  YandexMusicService.swift
//  MusicMindAI
//
//  Загрузка треков по cookies: account/status → user_id, playlist-with-likes → [Track].
//

import Foundation
import OSLog

// MARK: - API response models

private struct AccountStatusResponse: Codable, Sendable {
    let account: AccountInfo?
    let result: ResultWrapper?
    struct AccountInfo: Codable, Sendable {
        let uid: Int?
        let id: Int?
    }
    struct ResultWrapper: Codable, Sendable {
        let account: AccountInfo?
    }
}

private struct PlaylistWithLikesResponse: Codable, Sendable {
    let tracks: [YandexTrackItem]?
    let summary: Summary?
    struct Summary: Codable, Sendable {
        let count: Int?
    }
}

private struct LibraryTracksResponse: Codable, Sendable {
    let library: Library?
    struct Library: Codable, Sendable {
        let tracks: [YandexTrackItem]?
    }
}

// ответ search/instant/mixed для миграции (поиск по title + artists)
private struct SearchInstantResponse: Codable, Sendable {
    let results: [SearchResultItem]?
    struct SearchResultItem: Codable, Sendable {
        let type: String?
        let track: SearchTrack?
    }
    struct SearchTrack: Codable, Sendable {
        let id: Int?
        let albums: [SearchAlbum]?
    }
    struct SearchAlbum: Codable, Sendable {
        let id: Int?
    }
}

// MARK: - Service

actor YandexMusicService: MusicServiceProtocol {
    private let baseURL = AppConstants.YandexMusic.baseURL
    private let accountStatusURLs = AppConstants.YandexMusic.accountStatusURLs
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "YandexMusicService")
    private let urlSession: URLSession
    
    init(urlSession: URLSession? = nil) {
        // создаем отдельную сессию для thread-safety
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.urlSession = URLSession(configuration: configuration)
        }
    }

    func fetchUserId(cookies: String) async -> String? {
        guard let url = URL(string: accountStatusURLs[0]) else {
            logger.error("fetchUserId: invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        setCommonHeaders(&request)
        logRequest(request, label: "account/status")

        do {
            let (data, response) = try await urlSession.data(for: request)
            logResponse(label: "account/status", response: response, data: data)
            let decoded = try JSONDecoder().decode(AccountStatusResponse.self, from: data)
            if let uid = decoded.account?.uid ?? decoded.account?.id {
                logger.info("fetchUserId: ok uid=\(uid)")
                return String(uid)
            }
            if let uid = decoded.result?.account?.uid ?? decoded.result?.account?.id {
                logger.info("fetchUserId: ok (result) uid=\(uid)")
                return String(uid)
            }
            // fallback: search in raw JSON for numeric uid
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let uid = findUidInJson(json) {
                logger.info("fetchUserId: ok (raw json) uid=\(uid)")
                return uid
            }
            logger.warning("fetchUserId: no uid in response")
        } catch {
            logger.error("fetchUserId error: \(error.localizedDescription)")
        }
        return nil
    }

    /// Поиск трека по тексту (title + artists). Возвращает (trackId, albumId) для добавления в лайки.
    func searchTrack(query: String, cookies: String, userId: String?) async throws -> (trackId: Int, albumId: Int)? {
        var uid = userId
        if uid == nil { uid = await fetchUserId(cookies: cookies) }
        guard let uid = uid else { throw YandexMusicError.noUserId }

        guard var components = URLComponents(string: "\(baseURL)/search/instant/mixed") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: "album,artist,playlist,track,ugc_track,wave,podcast,podcast_episode,clip"),
            URLQueryItem(name: "page", value: "0"),
            URLQueryItem(name: "filter", value: "track"),
            URLQueryItem(name: "pageSize", value: "36"),
            URLQueryItem(name: "withLikesCount", value: "true"),
            URLQueryItem(name: "withBestResults", value: "false")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        logRequest(request, label: "search/instant/mixed")

        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "search/instant/mixed", response: response, data: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("searchTrack: bad status")
            return nil
        }

        // сначала пробуем Codable
        if let decoded = try? JSONDecoder().decode(SearchInstantResponse.self, from: data),
           let results = decoded.results {
            for item in results {
                guard item.type == "track", let track = item.track, let trackId = track.id,
                      let albums = track.albums, let first = albums.first, let albumId = first.id else { continue }
                return (trackId, albumId)
            }
            return nil
        }
        // fallback: сырой JSON (API иногда отдаёт другой формат — id строкой, вложенность и т.д.)
        return parseSearchResultFromRawJSON(data)
    }

    /// Поиск трека по тексту (title + artists) и возврат обложки (если есть).
    /// Используем для красивого UI во время добавления треков в плейлист.
    func searchTrackWithCover(query: String, cookies: String, userId: String?) async throws -> (trackId: Int, albumId: Int, coverUri: String?)? {
        var uid = userId
        if uid == nil { uid = await fetchUserId(cookies: cookies) }
        guard let uid = uid else { throw YandexMusicError.noUserId }

        guard var components = URLComponents(string: "\(baseURL)/search/instant/mixed") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: "album,artist,playlist,track,ugc_track,wave,podcast,podcast_episode,clip"),
            URLQueryItem(name: "page", value: "0"),
            URLQueryItem(name: "filter", value: "track"),
            URLQueryItem(name: "pageSize", value: "36"),
            URLQueryItem(name: "withLikesCount", value: "true"),
            URLQueryItem(name: "withBestResults", value: "false")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        logRequest(request, label: "search/instant/mixed (cover)")

        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "search/instant/mixed (cover)", response: response, data: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("searchTrackWithCover: bad status")
            return nil
        }

        return parseSearchResultWithCoverFromRawJSON(data)
    }

    private func parseSearchResultFromRawJSON(_ data: Data) -> (trackId: Int, albumId: Int)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return nil }
        for item in results {
            guard (item["type"] as? String) == "track",
                  let trackDict = item["track"] as? [String: Any],
                  let trackId = intFromAny(trackDict["id"]) ?? intFromAny(trackDict["realId"]),
                  let albums = trackDict["albums"] as? [[String: Any]],
                  let firstAlbum = albums.first,
                  let albumId = intFromAny(firstAlbum["id"]) else { continue }
            return (trackId, albumId)
        }
        return nil
    }

    private func parseSearchResultWithCoverFromRawJSON(_ data: Data) -> (trackId: Int, albumId: Int, coverUri: String?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return nil }

        for item in results {
            guard (item["type"] as? String) == "track",
                  let trackDict = item["track"] as? [String: Any] else { continue }

            guard let trackId = intFromAny(trackDict["id"]) ?? intFromAny(trackDict["realId"]),
                  let albums = trackDict["albums"] as? [[String: Any]],
                  let firstAlbum = albums.first,
                  let albumId = intFromAny(firstAlbum["id"]) ?? intFromAny(firstAlbum["albumId"]) else { continue }

            let coverUri: String? = {
                if let s = trackDict["coverUri"] as? String { return s }
                if let cover = trackDict["cover"] as? [String: Any], let s = cover["uri"] as? String { return s }
                if let s = trackDict["ogImage"] as? String { return s }
                return nil
            }()

            return (trackId: trackId, albumId: albumId, coverUri: coverUri)
        }
        return nil
    }

    private func intFromAny(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let n = value as? Int { return n }
        if let s = value as? String, let n = Int(s) { return n }
        return nil
    }

    /// Добавить трек в «Мне нравится». trackId и albumId — из searchTrack.
    func addTrackToLikes(trackId: Int, albumId: Int, cookies: String, userId: String) async throws {
        let trackIdParam = "\(trackId):\(albumId)"
        guard var components = URLComponents(string: "\(baseURL)/users/\(userId)/likes/tracks/add") else {
            throw YandexMusicError.invalidCookies
        }
        components.queryItems = [URLQueryItem(name: "track-id", value: trackIdParam)]
        guard let url = components.url else { throw YandexMusicError.invalidCookies }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(userId, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        request.httpBody = Data()
        logRequest(request, label: "likes/tracks/add")

        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "likes/tracks/add", response: response, data: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("addTrackToLikes: bad status for \(trackIdParam)")
            throw YandexMusicError.emptyResponse
        }
        logger.info("addTrackToLikes: ok \(trackIdParam)")
    }

    func fetchTracks(cookies: String, userId: String?) async throws -> [Track] {
        var uid = userId
        if uid == nil {
            logger.info("fetchTracks: no userId, fetching...")
            uid = await fetchUserId(cookies: cookies)
        }
        guard let uid = uid else {
            logger.error("fetchTracks: no userId after fetch")
            throw YandexMusicError.noUserId
        }
        logger.info("fetchTracks: uid=\(uid) request=playlist-with-likes")

        guard let url = URL(string: "\(baseURL)/landing-blocks/collection/playlist-with-likes") else {
            logger.error("fetchTracks: invalid URL")
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("fetchTracks: failed to create URLComponents")
            throw YandexMusicError.invalidCookies
        }
        urlComponents.queryItems = [URLQueryItem(name: "count", value: "10000")]
        request.url = urlComponents.url
        logRequest(request, label: "playlist-with-likes")

        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "playlist-with-likes", response: response, data: data)
        let http = response as? HTTPURLResponse
        let code = http?.statusCode ?? -1
        logger.info("playlist-with-likes: status=\(code) dataLen=\(data.count)")

        guard let http = http, (200...299).contains(http.statusCode) else {
            logger.warning("playlist-with-likes failed, fallback to likes/tracks")
            return try await fetchLikesTracksFallback(cookies: cookies, userId: uid)
        }

        // пробуем декодировать через Codable
        if let decoded = try? JSONDecoder().decode(PlaylistWithLikesResponse.self, from: data),
           let items = decoded.tracks {
            let list = parseTracks(items)
            logger.info("playlist-with-likes decoded (Codable): raw=\(items.count) parsed=\(list.count)")
            if list.isEmpty && items.count > 0 {
                // если через Codable ничего не получилось, пробуем raw JSON
                logger.debug("Codable parsing failed, trying raw JSON...")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tracksArr = json["tracks"] as? [[String: Any]] {
                    let rawList = parseTracksFromRawJSON(tracksArr)
                    logger.info("raw JSON parsed: \(rawList.count)")
                    return rawList
                }
            }
            return list
        }
        // если Codable не сработал, парсим из сырого JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tracksArr = json["tracks"] as? [[String: Any]] {
            logger.info("parsing from raw JSON, tracks count=\(tracksArr.count)")
            if let first = tracksArr.first {
                logger.debug("first track keys: \(first.keys.joined(separator: ", "))")
            }
            let list = parseTracksFromRawJSON(tracksArr)
            logger.info("playlist-with-likes parsed (raw): \(list.count)")
            return list
        }
        logger.warning("playlist-with-likes decode failed, fallback to likes/tracks")
        return try await fetchLikesTracksFallback(cookies: cookies, userId: uid)
    }

    private func fetchLikesTracksFallback(cookies: String, userId: String) async throws -> [Track] {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/likes/tracks") else {
            logger.error("fetchLikesTracksFallback: invalid URL")
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(userId, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)

        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("fetchLikesTracksFallback: failed to create URLComponents")
            throw YandexMusicError.invalidCookies
        }
        urlComponents.queryItems = [URLQueryItem(name: "if-modified-since-revision", value: "0")]
        request.url = urlComponents.url
        logRequest(request, label: "likes/tracks")

        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "likes/tracks", response: response, data: data)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        logger.info("likes/tracks: status=\(code) dataLen=\(data.count)")

        // пробуем через Codable
        if let decoded = try? JSONDecoder().decode(LibraryTracksResponse.self, from: data),
           let items = decoded.library?.tracks {
            let list = parseTracks(items)
            logger.info("likes/tracks (Codable): raw=\(items.count) parsed=\(list.count)")
            if list.isEmpty && items.count > 0 {
                // пробуем raw JSON
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let library = json["library"] as? [String: Any],
                   let tracksArr = library["tracks"] as? [[String: Any]] {
                    let rawList = parseTracksFromRawJSON(tracksArr)
                    logger.info("likes/tracks (raw): \(rawList.count)")
                    return rawList
                }
            }
            return list
        }
        // если Codable не сработал, пробуем raw JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let library = json["library"] as? [String: Any],
           let tracksArr = library["tracks"] as? [[String: Any]] {
            logger.info("likes/tracks parsing from raw JSON, count=\(tracksArr.count)")
            let list = parseTracksFromRawJSON(tracksArr)
            logger.info("likes/tracks (raw): \(list.count)")
            return list
        }
        logger.error("likes/tracks: decode failed")
        return []
    }

    private func parseTracks(_ items: [YandexTrackItem]) -> [Track] {
        var seen = Set<String>()
        var skippedNoTrack = 0
        var skippedDup = 0
        let result = items.compactMap { item -> Track? in
            guard let raw = item.track else { skippedNoTrack += 1; return nil }
            let track = Track.from(raw)
            let key = "\(track.title.lowercased())-\(track.artists.lowercased())"
            guard !seen.contains(key) else { skippedDup += 1; return nil }
            seen.insert(key)
            return track
        }
        if skippedNoTrack > 0 || skippedDup > 0 {
            logger.debug("parseTracks: skipped no track=\(skippedNoTrack) dup=\(skippedDup) result=\(result.count)")
        }
        return result
    }
    
    private func parseTracksFromRawJSON(_ items: [[String: Any]]) -> [Track] {
        var seen = Set<String>()
        var skipped = 0
        let result = items.compactMap { item -> Track? in
            // как в Python: item.get('track', item) - если есть track, берём его, иначе сам item
            let trackDict = item["track"] as? [String: Any] ?? item
            guard let track = Track.from(item: trackDict) else {
                skipped += 1
                return nil
            }
            let key = "\(track.title.lowercased())-\(track.artists.lowercased())"
            guard !seen.contains(key) else { skipped += 1; return nil }
            seen.insert(key)
            return track
        }
        if skipped > 0 {
            logger.debug("parseTracksFromRawJSON: skipped=\(skipped) result=\(result.count)")
        }
        return result
    }

    private func setCommonHeaders(_ request: inout URLRequest) {
        request.setValue(AppConstants.YandexMusic.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(AppConstants.YandexMusic.acceptHeader, forHTTPHeaderField: "Accept")
        request.setValue(AppConstants.YandexMusic.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(AppConstants.YandexMusic.referer, forHTTPHeaderField: "Referer")
        request.setValue(AppConstants.YandexMusic.clientHeader, forHTTPHeaderField: "x-yandex-music-client")
        request.setValue(AppConstants.YandexMusic.withoutInvocationInfo, forHTTPHeaderField: "x-yandex-music-without-invocation-info")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")
    }

    private static let logBodyMaxLength = 1200

    private func logRequest(_ request: URLRequest, label: String) {
        var msg = "[\(label)] → \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"
        if let body = request.httpBody, !body.isEmpty {
            msg += " body=\(body.count) bytes"
        }
        if request.value(forHTTPHeaderField: "Cookie") != nil {
            msg += " Cookie=***"
        }
        logger.info("\(msg)")
    }

    private func logResponse(label: String, response: URLResponse?, data: Data?) {
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        let len = data?.count ?? 0
        logger.info("[\(label)] ← status=\(code) body=\(len) bytes")
        guard let data = data, !data.isEmpty else { return }
        let preview = String(data: data.prefix(Self.logBodyMaxLength), encoding: .utf8) ?? "<non-utf8>"
        if data.count > Self.logBodyMaxLength {
            logger.debug("[\(label)] body preview: \(preview)...")
        } else {
            logger.debug("[\(label)] body: \(preview)")
        }
    }

    private func findUidInJson(_ obj: Any) -> String? {
        if let dict = obj as? [String: Any] {
            for key in ["uid", "id"] where dict[key] != nil {
                if let v = dict[key] as? Int { return String(v) }
                if let v = dict[key] as? String, Int(v) != nil { return v }
            }
            for v in dict.values {
                if let found = findUidInJson(v) { return found }
            }
        }
        if let arr = obj as? [Any], let first = arr.first {
            return findUidInJson(first)
        }
        return nil
    }
    
    func fetchPlaylists(cookies: String, userId: String?) async throws -> [Playlist] {
        var uid = userId
        if uid == nil {
            logger.info("fetchPlaylists: no userId, fetching...")
            uid = await fetchUserId(cookies: cookies)
        }
        guard let uid = uid else {
            logger.error("fetchPlaylists: no userId after fetch")
            throw YandexMusicError.noUserId
        }
        logger.info("fetchPlaylists: uid=\(uid)")
        
        guard var components = URLComponents(string: "\(baseURL)/landing-blocks/collection/playlists-liked-and-playlists-created") else {
            logger.error("fetchPlaylists: invalid URL")
            throw YandexMusicError.invalidCookies
        }
        components.queryItems = [
            URLQueryItem(name: "count", value: "20")
        ]
        guard let url = components.url else {
            logger.error("fetchPlaylists: failed to create URL")
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        logRequest(request, label: "playlists-liked-and-playlists-created")
        
        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "playlists-liked-and-playlists-created", response: response, data: data)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("fetchPlaylists: bad status")
            throw YandexMusicError.emptyResponse
        }
        
        let playlists = Playlist.parseFromResponse(data)
        logger.info("fetchPlaylists: ok, count=\(playlists.count)")
        return playlists
    }
    
    func createPlaylist(title: String, cookies: String, userId: String?) async throws -> (kind: Int, revision: Int, uuid: String) {
        var uid = userId
        if uid == nil {
            uid = await fetchUserId(cookies: cookies)
        }
        guard let uid = uid else {
            throw YandexMusicError.noUserId
        }
        
        guard var components = URLComponents(string: "\(baseURL)/users/\(uid)/playlists/create") else {
            throw YandexMusicError.invalidCookies
        }
        components.queryItems = [
            URLQueryItem(name: "visibility", value: "public"),
            URLQueryItem(name: "title", value: title)
        ]
        guard let url = components.url else {
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        request.httpBody = Data()
        logRequest(request, label: "playlists/create")
        
        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "playlists/create", response: response, data: data)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("createPlaylist: bad status")
            throw YandexMusicError.emptyResponse
        }
        
        // парсим ответ для получения kind, revision и uuid
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = json["kind"] as? Int,
              let revision = json["revision"] as? Int,
              let uuid = json["playlistUuid"] as? String else {
            logger.warning("createPlaylist: failed to parse kind/revision/uuid")
            throw YandexMusicError.decodingFailed
        }
        
        logger.info("createPlaylist: ok, kind=\(kind), revision=\(revision), uuid=\(uuid)")
        return (kind: kind, revision: revision, uuid: uuid)
    }
    
    func addTracksToPlaylist(kind: Int, revision: Int, trackIds: [(trackId: Int, albumId: Int)], cookies: String, userId: String) async throws {
        guard !trackIds.isEmpty else { return }
        
        // оптимизация: пытаемся добавить пачкой (меньше запросов). если API взбрыкнет — fallback на по-одному.
        do {
            try await addTracksToPlaylistBatched(
                kind: kind,
                revision: revision,
                trackIds: trackIds,
                cookies: cookies,
                userId: userId,
                chunkSize: 25
            )
        } catch {
            logger.warning("addTracksToPlaylist: batch failed, fallback to single. err=\(error.localizedDescription)")
            try await addTracksToPlaylistSingle(kind: kind, revision: revision, trackIds: trackIds, cookies: cookies, userId: userId)
        }
    }

    private func addTracksToPlaylistBatched(
        kind: Int,
        revision: Int,
        trackIds: [(trackId: Int, albumId: Int)],
        cookies: String,
        userId: String,
        chunkSize: Int
    ) async throws {
        var currentRevision = revision
        var index = 0
        
        while index < trackIds.count {
            let end = min(trackIds.count, index + max(1, chunkSize))
            let chunk = Array(trackIds[index..<end])
            
            let tracksPayload: [[String: Any]] = chunk.map { ["id": "\($0.trackId)", "albumId": $0.albumId] }
            let diff: [[String: Any]] = [[
                "op": "insert",
                "at": 0,
                "tracks": tracksPayload
            ]]
            
            guard let diffData = try? JSONSerialization.data(withJSONObject: diff),
                  let diffString = String(data: diffData, encoding: .utf8) else {
                throw YandexMusicError.encodingFailed
            }
            
            guard var components = URLComponents(string: "\(baseURL)/users/\(userId)/playlists/\(kind)/change-relative") else {
                throw YandexMusicError.invalidCookies
            }
            components.queryItems = [
                URLQueryItem(name: "diff", value: diffString),
                URLQueryItem(name: "revision", value: "\(currentRevision)")
            ]
            guard let url = components.url else {
                throw YandexMusicError.invalidCookies
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            request.setValue(userId, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
            setCommonHeaders(&request)
            request.httpBody = Data()
            logRequest(request, label: "playlists/change-relative (batch \(chunk.count))")
            
            let (data, response) = try await urlSession.data(for: request)
            logResponse(label: "playlists/change-relative (batch)", response: response, data: data)
            
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw YandexMusicError.emptyResponse
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newRevision = json["revision"] as? Int else {
                throw YandexMusicError.decodingFailed
            }
            currentRevision = newRevision
            
            logger.info("addTracksToPlaylist: batch ok added=\(chunk.count) revision=\(currentRevision)")
            index = end
        }
    }
    
    private func addTracksToPlaylistSingle(
        kind: Int,
        revision: Int,
        trackIds: [(trackId: Int, albumId: Int)],
        cookies: String,
        userId: String
    ) async throws {
        var currentRevision = revision
        
        for trackId in trackIds {
            guard var components = URLComponents(string: "\(baseURL)/users/\(userId)/playlists/\(kind)/change-relative") else {
                throw YandexMusicError.invalidCookies
            }
            
            let trackDict: [String: Any] = [
                "id": "\(trackId.trackId)",
                "albumId": trackId.albumId
            ]
            let diff: [[String: Any]] = [[
                "op": "insert",
                "at": 0,
                "tracks": [trackDict]
            ]]
            
            guard let diffData = try? JSONSerialization.data(withJSONObject: diff),
                  let diffString = String(data: diffData, encoding: .utf8) else {
                logger.warning("addTracksToPlaylistSingle: failed to serialize diff for track \(trackId.trackId)")
                continue
            }
            
            components.queryItems = [
                URLQueryItem(name: "diff", value: diffString),
                URLQueryItem(name: "revision", value: "\(currentRevision)")
            ]
            guard let url = components.url else {
                logger.warning("addTracksToPlaylistSingle: failed to create URL for track \(trackId.trackId)")
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(cookies, forHTTPHeaderField: "Cookie")
            request.setValue(userId, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
            setCommonHeaders(&request)
            request.httpBody = Data()
            logRequest(request, label: "playlists/change-relative")
            
            let (data, response) = try await urlSession.data(for: request)
            logResponse(label: "playlists/change-relative", response: response, data: data)
            
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                logger.warning("addTracksToPlaylistSingle: bad status for track \(trackId.trackId):\(trackId.albumId)")
                continue
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newRevision = json["revision"] as? Int {
                currentRevision = newRevision
            }
            
            logger.info("addTracksToPlaylistSingle: добавлен трек \(trackId.trackId):\(trackId.albumId), revision=\(currentRevision)")
        }
        
        logger.info("addTracksToPlaylistSingle: завершено, треков: \(trackIds.count)")
    }
    
    func fetchPlaylistTracks(kind: Int, cookies: String, userId: String?) async throws -> [Track] {
        var uid = userId
        if uid == nil {
            uid = await fetchUserId(cookies: cookies)
        }
        guard let uid = uid else {
            throw YandexMusicError.noUserId
        }
        
        guard let url = URL(string: "\(baseURL)/users/\(uid)/playlists/\(kind)") else {
            logger.error("fetchPlaylistTracks: invalid URL")
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        logRequest(request, label: "playlists/\(kind)")
        
        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "playlists/\(kind)", response: response, data: data)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("fetchPlaylistTracks: bad status for kind=\(kind)")
            throw YandexMusicError.emptyResponse
        }
        
        // парсим треки из ответа
        // формат ответа: { "tracks": [...] } или { "playlist": { "tracks": [...] } }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // пробуем tracks напрямую
            if let tracksArr = json["tracks"] as? [[String: Any]] {
                let tracks = parseTracksFromRawJSON(tracksArr)
                logger.info("fetchPlaylistTracks: найдено \(tracks.count) треков (tracks)")
                return tracks
            }
            
            // пробуем через playlist.tracks
            if let playlistDict = json["playlist"] as? [String: Any],
               let tracksArr = playlistDict["tracks"] as? [[String: Any]] {
                let tracks = parseTracksFromRawJSON(tracksArr)
                logger.info("fetchPlaylistTracks: найдено \(tracks.count) треков (playlist.tracks)")
                return tracks
            }
            
            // пробуем через Codable формат
            if let decoded = try? JSONDecoder().decode(PlaylistWithLikesResponse.self, from: data),
               let items = decoded.tracks {
                let tracks = parseTracks(items)
                logger.info("fetchPlaylistTracks: найдено \(tracks.count) треков (Codable)")
                return tracks
            }
        }
        
        logger.warning("fetchPlaylistTracks: не удалось распарсить треки для kind=\(kind)")
        return []
    }
    
    func deletePlaylist(kind: Int, cookies: String, userId: String?) async throws {
        var uid = userId
        if uid == nil {
            uid = await fetchUserId(cookies: cookies)
        }
        guard let uid = uid else {
            throw YandexMusicError.noUserId
        }
        
        guard let url = URL(string: "\(baseURL)/users/\(uid)/playlists/\(kind)/delete") else {
            logger.error("deletePlaylist: invalid URL")
            throw YandexMusicError.invalidCookies
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue(uid, forHTTPHeaderField: "x-yandex-music-multi-auth-user-id")
        setCommonHeaders(&request)
        request.httpBody = Data()
        logRequest(request, label: "playlists/\(kind)/delete")
        
        let (data, response) = try await urlSession.data(for: request)
        logResponse(label: "playlists/\(kind)/delete", response: response, data: data)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            logger.warning("deletePlaylist: bad status for kind=\(kind)")
            throw YandexMusicError.emptyResponse
        }
        
        logger.info("deletePlaylist: ok, kind=\(kind)")
    }
}

enum YandexMusicError: LocalizedError {
    case noUserId
    case invalidCookies
    case emptyResponse
    case decodingFailed
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noUserId:
            return "Не удалось получить user_id"
        case .invalidCookies:
            return "Неверные cookies. Попробуйте войти заново"
        case .emptyResponse:
            return "Пустой ответ от сервера"
        case .decodingFailed:
            return "Ошибка обработки данных"
        case .encodingFailed:
            return "Ошибка подготовки данных"
        }
    }
}
