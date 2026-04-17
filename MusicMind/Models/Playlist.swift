//
//  Playlist.swift
//  MusicMindAI
//
//  Модель плейлиста из Яндекс.Музыки
//

import Foundation

// MARK: - API response models

private struct PlaylistOwner: Codable, Sendable {
    let uid: Int?
    let login: String?
    let name: String?
}

private struct PlaylistCover: Codable, Sendable {
    let type: String?
    let dir: String?
    let version: String?
    let uri: String?
    let custom: Bool?
    let itemsUri: [String]?
}

private struct PlaylistRaw: Codable, Sendable {
    let owner: PlaylistOwner?
    let playlistUuid: String?
    let available: Bool?
    let uid: Int?
    let kind: Int?
    let title: String?
    let description: String?
    let trackCount: Int?
    let durationMs: Int?
    let cover: PlaylistCover?
    let ogImage: String?
    let likesCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case owner, available, uid, kind, title, description, cover, likesCount
        case playlistUuid = "playlistUuid"
        case trackCount = "trackCount"
        case durationMs = "durationMs"
        case ogImage = "ogImage"
    }
}

private struct PlaylistItem: Codable, Sendable {
    let playlist: PlaylistRaw?
    let timestamp: String?
}

private struct PlaylistsResponse: Codable, Sendable {
    let result: [PlaylistItem]?
    let pager: Pager?
    
    struct Pager: Codable, Sendable {
        let total: Int?
        let page: Int?
        let perPage: Int?
    }
}

// формат для landing-blocks/collection/playlists-liked-and-playlists-created
private struct PlaylistsTabsResponse: Codable, Sendable {
    let tabs: [PlaylistTab]?
    
    struct PlaylistTab: Codable, Sendable {
        let type: String?
        let id: String?
        let title: String?
        let items: [PlaylistTabItem]?
    }
    
    struct PlaylistTabItem: Codable, Sendable {
        let type: String?
        let data: PlaylistTabItemData?
    }
    
    struct PlaylistTabItemData: Codable, Sendable {
        let playlist: PlaylistRaw?
        let likesCount: Int?
        let trackCount: Int?
    }
}

// альтернативный формат - массив напрямую
private typealias PlaylistsArrayResponse = [PlaylistItem]

// MARK: - Flat model

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let uuid: String?
    let kind: Int?
    let title: String
    let description: String?
    let ownerName: String
    let trackCount: Int
    let durationMs: Int
    let coverUri: String?
    let coverVersion: String?
    let likesCount: Int
    let available: Bool
    
    init(
        uuid: String? = nil,
        kind: Int? = nil,
        title: String,
        description: String? = nil,
        ownerName: String,
        trackCount: Int = 0,
        durationMs: Int = 0,
        coverUri: String? = nil,
        coverVersion: String? = nil,
        likesCount: Int = 0,
        available: Bool = true
    ) {
        self.uuid = uuid
        self.kind = kind
        self.title = title
        self.description = description
        self.ownerName = ownerName
        self.trackCount = trackCount
        self.durationMs = durationMs
        self.coverUri = coverUri
        self.coverVersion = coverVersion
        self.likesCount = likesCount
        self.available = available
        self.id = uuid ?? UUID().uuidString
    }
    
    fileprivate static func from(_ raw: PlaylistRaw) -> Playlist? {
        guard let title = raw.title else { return nil }
        let ownerName = raw.owner?.name ?? raw.owner?.login ?? "Unknown"
        let coverUri = raw.cover?.uri ?? raw.ogImage
        let coverVersion = raw.cover?.version
        
        return Playlist(
            uuid: raw.playlistUuid,
            kind: raw.kind,
            title: title,
            description: raw.description,
            ownerName: ownerName,
            trackCount: raw.trackCount ?? 0,
            durationMs: raw.durationMs ?? 0,
            coverUri: coverUri,
            coverVersion: coverVersion,
            likesCount: raw.likesCount ?? 0,
            available: raw.available ?? true
        )
    }
    
    static func parseFromResponse(_ data: Data) -> [Playlist] {
        // пробуем сначала формат для landing-blocks (с tabs)
        if let decoded = try? JSONDecoder().decode(PlaylistsTabsResponse.self, from: data),
           let tabs = decoded.tabs {
            var allPlaylists: [Playlist] = []
            for tab in tabs {
                if let items = tab.items {
                    for item in items {
                        guard let data = item.data,
                              let raw = data.playlist else { continue }
                        
                        // используем trackCount из data если есть, иначе из playlist
                        var playlist = Playlist.from(raw)
                        if var p = playlist, let trackCount = data.trackCount {
                            playlist = Playlist(
                                uuid: p.uuid,
                                kind: p.kind,
                                title: p.title,
                                description: p.description,
                                ownerName: p.ownerName,
                                trackCount: trackCount,
                                durationMs: p.durationMs,
                                coverUri: p.coverUri,
                                coverVersion: p.coverVersion,
                                likesCount: data.likesCount ?? p.likesCount,
                                available: p.available
                            )
                        }
                        if let p = playlist {
                            allPlaylists.append(p)
                        }
                    }
                }
            }
            if !allPlaylists.isEmpty {
                return allPlaylists
            }
        }
        
        // пробуем как объект с result
        if let decoded = try? JSONDecoder().decode(PlaylistsResponse.self, from: data),
           let items = decoded.result {
            return items.compactMap { item -> Playlist? in
                guard let raw = item.playlist else { return nil }
                return Playlist.from(raw)
            }
        }
        
        // если не получилось, пробуем как массив напрямую
        if let items = try? JSONDecoder().decode(PlaylistsArrayResponse.self, from: data) {
            return items.compactMap { item -> Playlist? in
                guard let raw = item.playlist else { return nil }
                return Playlist.from(raw)
            }
        }
        
        return []
    }
}
