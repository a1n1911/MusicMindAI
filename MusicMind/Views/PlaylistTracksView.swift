//
//  PlaylistTracksView.swift
//  MusicMindAI
//
//  Экран со списком треков плейлиста
//

import SwiftUI

struct PlaylistTracksView: View {
    let playlist: Playlist
    let cookies: String
    let userId: String?
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: PlaylistTracksViewModel
    @State private var showDeleteConfirmation = false
    
    let onPlaylistDeleted: (() -> Void)?
    
    init(playlist: Playlist, cookies: String, userId: String?, onPlaylistDeleted: (() -> Void)? = nil) {
        self.playlist = playlist
        self.cookies = cookies
        self.userId = userId
        self.onPlaylistDeleted = onPlaylistDeleted
        _viewModel = StateObject(wrappedValue: PlaylistTracksViewModel(
            playlist: playlist,
            cookies: cookies,
            userId: userId,
            onPlaylistDeleted: onPlaylistDeleted
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CyberpunkTheme.backgroundGradient
                    .ignoresSafeArea(.all)
                
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("загрузка треков...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Text("ошибка")
                            .font(.headline)
                            .foregroundStyle(CyberpunkTheme.neonPink)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if viewModel.tracks.isEmpty {
                    VStack(spacing: 16) {
                        Text("треков нет")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // заголовок
                            VStack(alignment: .leading, spacing: 8) {
                                Text(playlist.title)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                
                                Text("\(viewModel.tracks.count) треков")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // список треков
                            ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                                TrackRowView(track: track, index: index, onTap: {
                                    if let url = track.yandexMusicURL {
                                        UIApplication.shared.open(url)
                                    }
                                })
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 16)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // хлебные крошки
                    HStack(spacing: 8) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Твои плейлисты")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text(playlist.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("удалить плейлист", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .alert("удалить плейлист?", isPresented: $showDeleteConfirmation) {
                Button("удалить", role: .destructive) {
                    Task {
                        await viewModel.deletePlaylist()
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                Button("отмена", role: .cancel) { }
            } message: {
                Text("плейлист «\(playlist.title)» будет удален без возможности восстановления")
            }
            .task {
                await viewModel.loadTracks()
            }
        }
    }
}
