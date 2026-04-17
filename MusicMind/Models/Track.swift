//
//  Track.swift
//  MusicMindAI
//
//  Модель трека: Codable под ответ API Яндекс.Музыки + плоская модель для UI.
//

import Foundation

// MARK: - API response (сырой ответ Яндекс)

struct YandexTrackArtist: Codable, Sendable {
    let name: String?
}

struct YandexAlbumRaw: Codable, Sendable {
    let id: Int?
}

/// Сырой трек из API (playlist-with-likes, users/likes/tracks).
struct YandexTrackRaw: Codable, Sendable {
    let id: Int?
    let title: String?
    let artists: [YandexTrackArtist]?
    let albums: [YandexAlbumRaw]?
    let durationMs: Int?
    let coverUri: String?
    let available: Bool?
}

/// Обёртка в ответах API: элемент массива может быть { "track": { ... } } или сам трек.
struct YandexTrackItem: Codable, Sendable {
    let track: YandexTrackRaw?
}

// MARK: - Flat model (UI + SwiftData later)

struct Track: Identifiable, Codable, Equatable, Hashable {
    /// Стабильный id: из API или составной (title + artists) для оффлайн.
    let id: String
    let backendId: Int?
    /// Для Яндекс.Музыки (нужно для deep link вида /album/<albumId>/track/<trackId>).
    let albumId: Int?
    let title: String
    let artists: String
    let durationMs: Int
    let coverUri: String?
    let available: Bool

    var durationSec: Int { durationMs / 1000 }
    
    var yandexMusicURL: URL? {
        guard isLikelyYandex, let trackId = backendId else { return nil }
        if let albumId {
            return URL(string: "https://music.yandex.ru/album/\(albumId)/track/\(trackId)")
        }
        // fallback: иногда хватает и такого URL, если albumId не приехал
        return URL(string: "https://music.yandex.ru/track/\(trackId)")
    }
    
    private var isLikelyYandex: Bool {
        if albumId != nil { return true }
        guard let coverUri = coverUri?.lowercased() else { return false }
        return coverUri.contains("yandex")
            || coverUri.contains("music-content")
            || coverUri.contains("avatars.yandex")
    }

    init(
        backendId: Int? = nil,
        albumId: Int? = nil,
        title: String,
        artists: String,
        durationMs: Int = 0,
        coverUri: String? = nil,
        available: Bool = false
    ) {
        self.backendId = backendId
        self.albumId = albumId
        self.title = title
        self.artists = artists
        self.durationMs = durationMs
        self.coverUri = coverUri
        self.available = available
        // вычисляем id один раз при инициализации
        self.id = "\(backendId ?? 0)-\(title)-\(artists)"
    }

    /// Декодирование из сырого ответа API.
    nonisolated static func from(_ raw: YandexTrackRaw) -> Track {
        let artistsString = (raw.artists ?? [])
            .compactMap { $0.name }
            .joined(separator: ", ")
        return Track(
            backendId: raw.id,
            albumId: raw.albums?.first?.id,
            title: raw.title ?? "Unknown",
            artists: artistsString.isEmpty ? "Unknown" : artistsString,
            durationMs: raw.durationMs ?? 0,
            coverUri: raw.coverUri,
            available: raw.available ?? false
        )
    }

    /// Из элемента массива (track или item.track).
    static func from(item: [String: Any]) -> Track? {
        let trackDict = item["track"] as? [String: Any] ?? item
        guard let title = trackDict["title"] as? String else { return nil }
        let artists: String = {
            guard let arr = trackDict["artists"] as? [[String: Any]] else { return "Unknown" }
            let names = arr.compactMap { $0["name"] as? String }
            return names.isEmpty ? "Unknown" : names.joined(separator: ", ")
        }()
        let albumId: Int? = {
            if let albums = trackDict["albums"] as? [[String: Any]],
               let first = albums.first {
                return intFromAny(first["id"]) ?? intFromAny(first["albumId"])
            }
            // иногда может прилетать плоско
            return intFromAny(trackDict["albumId"])
        }()
        return Track(
            backendId: intFromAny(trackDict["id"]) ?? intFromAny(trackDict["realId"]),
            albumId: albumId,
            title: title,
            artists: artists,
            durationMs: trackDict["durationMs"] as? Int ?? 0,
            coverUri: trackDict["coverUri"] as? String,
            available: trackDict["available"] as? Bool ?? false
        )
    }
    
    private static func intFromAny(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let n = value as? Int { return n }
        if let s = value as? String, let n = Int(s) { return n }
        return nil
    }
}
