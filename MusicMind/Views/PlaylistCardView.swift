//
//  PlaylistCardView.swift
//  MusicMindAI
//
//  Карточка плейлиста для горизонтального скролла
//

import SwiftUI

struct PlaylistCardView: View {
    let playlist: Playlist
    let onShowTracks: (() -> Void)?
    
    init(playlist: Playlist, onShowTracks: (() -> Void)? = nil) {
        self.playlist = playlist
        self.onShowTracks = onShowTracks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // обложка с кнопкой открытия ссылки
            Link(destination: playlistURL) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        CyberpunkTheme.neonPink.opacity(0.3),
                                        CyberpunkTheme.electricBlue.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                    
                    // кнопка открытия треков
                    Button {
                        onShowTracks?()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.6))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(6)
                }
            }
            .buttonStyle(.plain)
            
            // название
            Text(playlist.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
            
            // количество треков
            Text("\(playlist.trackCount) треков")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
        }
    }
    
    private var playlistURL: URL {
        if let uuid = playlist.uuid {
            return URL(string: "https://music.yandex.ru/playlists/\(uuid)")!
        }
        return URL(string: "https://music.yandex.ru/collection")!
    }
    
    private var coverURL: URL? {
        guard let uri = playlist.coverUri else { return nil }
        // заменяем %% на размер, если нужно
        var urlString = uri.replacingOccurrences(of: "%%", with: "300x300")
        // добавляем https:// если его нет
        if !urlString.hasPrefix("http") {
            urlString = "https://\(urlString)"
        }
        
        // cache-busting: если юзер поменял обложку в яндексе, version меняется,
        // а uri часто остается тем же — добавляем query param чтобы AsyncImage обновлялся
        if let v = playlist.coverVersion, !v.isEmpty, var components = URLComponents(string: urlString) {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "v" }
            items.append(URLQueryItem(name: "v", value: v))
            components.queryItems = items
            return components.url
        }
        
        return URL(string: urlString)
    }
}
