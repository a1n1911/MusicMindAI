//
//  VKTabView.swift
//  MusicMindAI
//
//  Таб библиотеки VK Музыки
//

import SwiftUI

struct VKTabView: View {
    @ObservedObject var viewModel: VKLibraryViewModel
    @ObservedObject var authManager: AuthManager
    
    let onAuthTap: () -> Void
    let onAnalysisTap: () -> Void
    let onTrackTap: (Track) -> Void
    let onRefresh: () async -> Void
    let updateMessage: String
    @Binding var showUpdateAlert: Bool
    
    @State private var searchText = ""
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
            .background { CyberpunkTheme.backgroundGradient.ignoresSafeArea(.all) }
            .navigationTitle("VK Музыка")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(CyberpunkTheme.deepPurple, for: .navigationBar)
            .refreshable {
                await onRefresh()
            }
            .alert("Обновление", isPresented: $showUpdateAlert) {
                Button("ОК", role: .cancel) { }
            } message: {
                Text(updateMessage)
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
    }
    
    private func emptyStateView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 20) {
                PulsatingSphereView(
                    subtitle: vkSubtitle,
                    subtitleColor: vkSubtitleColor,
                    isActive: viewModel.isLoading || !authManager.isVKAuthenticated,
                    isUnauthorized: !authManager.isVKAuthenticated
                )
                
                if !authManager.isVKAuthenticated {
                    Button {
                        onAuthTap()
                    } label: {
                        Text("Войти")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(CyberpunkTheme.neonPink.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(CyberpunkTheme.neonPink, lineWidth: 1.5)
                                    )
                            )
                    }
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
                
                // поисковая строка
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                ForEach(Array(filteredTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(track: track, index: index, service: .vk, onTap: {
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
    
    private var vkSubtitle: String {
        if viewModel.isLoading { return "Загрузка треков..." }
        if let msg = viewModel.errorMessage { return "Ошибка: \(msg)" }
        if !authManager.isVKAuthenticated { return "Войдите в VK Музыку" }
        if !viewModel.hasTracks { return "Треков не найдено" }
        return viewModel.subtitle
    }

    private var vkSubtitleColor: Color {
        if viewModel.errorMessage != nil { return CyberpunkTheme.neonPink.opacity(0.95) }
        if !authManager.isVKAuthenticated { return .white.opacity(0.7) }
        return viewModel.subtitleColor
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
