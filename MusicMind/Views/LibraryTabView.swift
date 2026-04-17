//
//  LibraryTabView.swift
//  MusicMindAI
//
//  Таб библиотеки Яндекс.Музыки
//

import SwiftUI

struct LibraryTabView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @ObservedObject var authManager: AuthManager
    
    let onAuthTap: () -> Void
    let onAnalysisTap: () -> Void
    let onTrackTap: (Track) -> Void
    let onRefresh: () async -> Void
    let updateMessage: String
    @Binding var showUpdateAlert: Bool
    
    @State private var searchText = ""
    @State private var showCreatePlaylist = false
    @State private var selectedPlaylist: Playlist?
    @State private var playlistCreatedBannerText: String?
    @State private var pendingPlaylistCreatedTitle: String?
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showExportSuccess = false
    @State private var exportedFileURL: URL?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if viewModel.shouldShowEmptyState {
                    emptyStateView(geometry: geometry)
                } else {
                    tracksListView
                }
            }
            .background {
                CyberpunkTheme.backgroundGradient
                    .ignoresSafeArea(.all)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(CyberpunkTheme.deepPurple, for: .navigationBar)
            .alert("Обновление", isPresented: $showUpdateAlert) {
                Button("ОК", role: .cancel) { }
            } message: {
                Text(updateMessage)
            }
            .sheet(item: $selectedPlaylist) { playlist in
                if let cookies = authManager.cookies {
                    PlaylistTracksView(
                        playlist: playlist,
                        cookies: cookies,
                        userId: authManager.userId,
                        onPlaylistDeleted: {
                            // обновляем список плейлистов после удаления
                            Task {
                                await viewModel.loadPlaylists(
                                    cookies: cookies,
                                    userId: authManager.userId
                                )
                            }
                        }
                    )
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showCreatePlaylist, onDismiss: {
                if let title = pendingPlaylistCreatedTitle {
                    pendingPlaylistCreatedTitle = nil
                    showPlaylistCreatedBanner(title: title)
                }
            }) {
                if let cookies = authManager.cookies {
                    CreatePlaylistView(
                        viewModel: CreatePlaylistViewModel(
                            cookies: cookies,
                            userId: authManager.userId,
                            onPlaylistCreated: { event in
                                Task {
                                    await viewModel.loadPlaylists(
                                        cookies: cookies,
                                        userId: authManager.userId
                                    )
                                }
                                pendingPlaylistCreatedTitle = event.title
                            }
                        )
                    )
                    .presentationDetents([.large])
                }
            }
        }
        .alert("Экспорт завершен", isPresented: $showExportSuccess) {
            Button("Открыть файл") {
                if let url = exportedFileURL {
                    openFile(at: url)
                }
            }
            Button("ОК", role: .cancel) { }
        } message: {
            Text("Треки успешно экспортированы в CSV файл")
        }
        .alert("Ошибка экспорта", isPresented: .constant(exportError != nil)) {
            Button("ОК", role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError?.localizedDescription ?? "Неизвестная ошибка")
        }
    }
    
    private func emptyStateView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Music Mind")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Яндекс")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 60)
            
            Spacer()
            
            VStack(spacing: 20) {
                PulsatingSphereView(
                    subtitle: librarySubtitle,
                    subtitleColor: librarySubtitleColor,
                    isActive: viewModel.isLoading || !authManager.isAuthenticated,
                    isUnauthorized: !authManager.isAuthenticated
                )
                
                if !authManager.isAuthenticated {
                    Button {
                        onAuthTap()
                    } label: {
                        Text("Войти")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.0, green: 0.48, blue: 1.0),
                                                Color(red: 0.0, green: 0.4, blue: 0.9)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4), radius: 12, y: 6)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
    
    private var filteredTracks: [Track] {
        if searchText.isEmpty {
            return viewModel.tracks
        }
        let query = searchText.lowercased()
        return viewModel.tracks.filter { track in
            track.title.lowercased().contains(query) ||
            track.artists.lowercased().contains(query)
        }
    }
    
    private var tracksListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Music Mind")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                VStack(spacing: 4) {
                    Text("\(filteredTracks.count)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(searchText.isEmpty ? "треков в коллекции" : "найдено треков")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .opacity(viewModel.hasTracks ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: filteredTracks.count)
                
                VStack(spacing: 20) {
                    Button {
                        onAnalysisTap()
                    } label: {
                        PulsatingSphereView(
                            subtitle: "Нажми для анализа",
                            subtitleColor: .white.opacity(0.8),
                            isActive: true
                        )
                    }
                    
                    // кнопка экспорта CSV
                    Button {
                        Task {
                            await exportToCSV()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(isExporting ? "Экспорт..." : "Экспорт в CSV")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .disabled(isExporting || viewModel.tracks.isEmpty)
                    .opacity(viewModel.tracks.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 40)
                }
                .padding(.vertical, 32)
                
                // плейлисты
                VStack(alignment: .leading, spacing: 12) {
                    Text("Твои плейлисты")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                    
                    if let bannerText = playlistCreatedBannerText {
                        Text(bannerText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial.opacity(0.35))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    if viewModel.isLoadingPlaylists {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("загрузка плейлистов...")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 180)
                    } else if viewModel.playlists.isEmpty {
                        Text("плейлистов нет")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .frame(height: 180)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // карточка создания плейлиста
                                CreatePlaylistCardView {
                                    showCreatePlaylist = true
                                }
                                
                                ForEach(viewModel.playlists) { playlist in
                                    PlaylistCardView(playlist: playlist) {
                                        selectedPlaylist = playlist
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 16)
                
                // поисковая строка
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, index: index, service: .yandex, onTap: {
                        onTrackTap(track)
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
        .refreshable {
            await onRefresh()
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("поиск по трекам...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var librarySubtitle: String {
        if viewModel.isLoading { return "Загрузка треков..." }
        if let errorMessage = viewModel.errorMessage { return "Ошибка: \(errorMessage)" }
        if !authManager.isAuthenticated { return "Войдите в сервис" }
        if !viewModel.hasTracks { return "Треков не найдено" }
        return viewModel.subtitle
    }

    private var librarySubtitleColor: Color {
        if viewModel.errorMessage != nil { return CyberpunkTheme.neonPink.opacity(0.95) }
        if !authManager.isAuthenticated { return .white.opacity(0.7) }
        return viewModel.subtitleColor
    }

    private func showPlaylistCreatedBanner(title: String) {
        let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = raw.hasPrefix("[MusicMindAI] ") ? String(raw.dropFirst("[MusicMindAI] ".count)) : raw
        let text = cleaned.isEmpty ? "плейлист создан" : "плейлист «\(cleaned)» создан"
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
            playlistCreatedBannerText = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeInOut(duration: 0.25)) {
                playlistCreatedBannerText = nil
            }
        }
    }
    
    @MainActor
    private func exportToCSV() async {
        isExporting = true
        exportError = nil
        
        do {
            let fileURL = try await viewModel.exportTracksToCSV()
            exportedFileURL = fileURL
            showExportSuccess = true
        } catch {
            exportError = error
        }
        
        isExporting = false
    }
    
    private func openFile(at url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        // На iOS показываем share sheet
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
        #endif
    }
}
