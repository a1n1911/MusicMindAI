//
//  ContentView.swift
//  MusicMindAI
//
//  TabView: Library (треки + сфера + подпись), Auth — киберпанк тема.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Query private var items: [Item]

    @StateObject private var authManager = AuthManager()
    
    // ленивая инициализация ViewModels - создаются только при первом обращении
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var soundCloudLibraryViewModel = SoundCloudLibraryViewModel()
    @StateObject private var vkLibraryViewModel = VKLibraryViewModel()
    @StateObject private var migrationViewModel = MigrationViewModel()
    
    // computed properties для удобства доступа
    private var libraryVM: LibraryViewModel { libraryViewModel }
    private var soundCloudVM: SoundCloudLibraryViewModel { soundCloudLibraryViewModel }
    private var vkVM: VKLibraryViewModel { vkLibraryViewModel }

    @State private var selectedTab = 0
    @State private var showAuth = false
    @State private var showSoundCloudAuth = false
    @State private var showVKAuth = false
    @State private var showAnalysis = false
    @State private var selectedTrack: Track?
    @State private var showUpdateAlert = false
    @State private var showSoundCloudUpdateAlert = false
    @State private var showVKUpdateAlert = false
    @State private var migrationSourceService: MusicService? = nil
    @State private var migrationDestinationService: MusicService? = nil
    @State private var addedTracksCount = 0
    @State private var updateMessage = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            libraryTab
                .tabItem { Label("Яндекс", systemImage: "music.note.list") }
                .tag(0)
            soundCloudLibraryTab
                .tabItem { Label("SoundCloud", systemImage: "cloud") }
                .tag(1)
            vkLibraryTab
                .tabItem { Label("VK", systemImage: "music.note.list") }
                .tag(2)
            migrationTab
                .tabItem { Label("Миграция", systemImage: "arrow.triangle.2.circlepath") }
                .tag(3)
            authTab
                .tabItem { Label("Сервисы", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .preferredColorScheme(.dark)
        .tint(themeManager.currentSpec.accent)
        .toolbarBackground(themeManager.currentSpec.primary.opacity(0.95), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(TabBarIconColorPatcher(selectedTab: selectedTab))
        .sheet(isPresented: $showAuth) {
            YandexAuthView { result in
                authManager.setAuthResult(result)
                showAuth = false
                if result.cookies != nil { selectedTab = 0 }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSoundCloudAuth) {
            SoundCloudAuthView { token in
                authManager.setSoundCloudToken(token)
                showSoundCloudAuth = false
                if token != nil { selectedTab = 1 }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showVKAuth) {
            VKAuthView { token, userAgent in
                authManager.setVKAuth(token: token, userAgent: userAgent)
                showVKAuth = false
                if token != nil { selectedTab = 2 }
            }
            .presentationDetents([.large])
        }
        .task(id: authManager.cookies) {
            await loadTracksIfNeeded()
        }
        .task(id: authManager.soundCloudOAuthToken) {
            await loadSoundCloudTracksIfNeeded()
        }
        .task(id: authManager.vkToken) {
            await loadVKTracksIfNeeded()
        }
        .fullScreenCover(isPresented: $showAnalysis) {
            AnalysisLoadingView(tracks: analysisTracksForSelectedTab)
        }
        .onChange(of: themeManager.selectedTheme) { _, _ in
            WindowManager.shared.setupWindowBackground(color: themeManager.currentSpec.windowBackgroundUIColor)
        }
        .sheet(item: $selectedTrack) { track in
            TrackAnalysisView(track: track)
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Обновление", isPresented: $showVKUpdateAlert) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(updateMessage)
        }
    }
    
    private var analysisTracksForSelectedTab: [Track] {
        switch selectedTab {
        case 1: return soundCloudVM.tracks
        case 2: return vkVM.tracks
        default: return libraryVM.tracks
        }
    }

    @MainActor
    private func loadTracksIfNeeded() async {
        guard let cookies = authManager.cookies else {
            libraryVM.clearTracks()
            return
        }
        
        await libraryVM.loadTracks(
            cookies: cookies,
            userId: authManager.userId
        )
        
        // загружаем плейлисты
        await libraryVM.loadPlaylists(
            cookies: cookies,
            userId: authManager.userId
        )
    }
    
    @MainActor
    private func refreshTracks() async {
        guard let cookies = authManager.cookies else { return }
        let addedCount = await libraryVM.refreshTracks(cookies: cookies, userId: authManager.userId)
        updateMessage = addedCount > 0 ? "Добавлено: \(addedCount) треков" : "ничего нового 🤷"
        showUpdateAlert = true
        
        // обновляем плейлисты тоже
        await libraryVM.loadPlaylists(
            cookies: cookies,
            userId: authManager.userId
        )
    }
    
    @MainActor
    private func loadSoundCloudTracksIfNeeded() async {
        guard let token = authManager.soundCloudOAuthToken else {
            soundCloudVM.clearTracks()
            return
        }
        await soundCloudVM.loadTracks(oauthToken: token, userId: nil)
    }
    
    @MainActor
    private func refreshSoundCloudTracks() async {
        guard let token = authManager.soundCloudOAuthToken else { return }
        let addedCount = await soundCloudVM.refreshTracks(oauthToken: token, userId: nil)
        updateMessage = addedCount > 0 ? "Добавлено: \(addedCount) треков" : "ничего нового 🤷"
        showSoundCloudUpdateAlert = true
    }
    
    @MainActor
    private func loadVKTracksIfNeeded() async {
        guard let token = authManager.vkToken, let userAgent = authManager.vkUserAgent else {
            vkVM.clearTracks()
            return
        }
        await vkVM.loadTracks(token: token, userAgent: userAgent, userId: nil)
    }
    
    @MainActor
    private func refreshVKTracks() async {
        guard let token = authManager.vkToken, let userAgent = authManager.vkUserAgent else { return }
        let addedCount = await vkVM.refreshTracks(token: token, userAgent: userAgent, userId: nil)
        updateMessage = addedCount > 0 ? "Добавлено: \(addedCount) треков" : "ничего нового 🤷"
        showVKUpdateAlert = true
    }

    private var libraryTab: some View {
        LibraryTabView(
            viewModel: libraryVM,
            authManager: authManager,
            onAuthTap: { showAuth = true },
            onAnalysisTap: { showAnalysis = true },
            onTrackTap: { selectedTrack = $0 },
            onRefresh: { await refreshTracks() },
            updateMessage: updateMessage,
            showUpdateAlert: $showUpdateAlert
        )
    }
    
    private var soundCloudLibraryTab: some View {
        SoundCloudTabView(
            viewModel: soundCloudVM,
            authManager: authManager,
            onAuthTap: { showSoundCloudAuth = true },
            onAnalysisTap: { showAnalysis = true },
            onTrackTap: { selectedTrack = $0 },
            onRefresh: { await refreshSoundCloudTracks() },
            updateMessage: updateMessage,
            showUpdateAlert: $showSoundCloudUpdateAlert
        )
    }
    
    private var vkLibraryTab: some View {
        VKTabView(
            viewModel: vkVM,
            authManager: authManager,
            onAuthTap: { showVKAuth = true },
            onAnalysisTap: { showAnalysis = true },
            onTrackTap: { selectedTrack = $0 },
            onRefresh: { await refreshVKTracks() },
            updateMessage: updateMessage,
            showUpdateAlert: $showVKUpdateAlert
        )
    }
    

    private var migrationTab: some View {
        NavigationStack {
            MigrationView(
                source: $migrationSourceService,
                destination: $migrationDestinationService,
                viewModel: migrationViewModel,
                sourceTracks: migrationSourceTracks,
                cookies: authManager.cookies,
                userId: authManager.userId,
                onStart: {
                    migrationViewModel.startMigration(
                        tracks: migrationSourceTracks,
                        cookies: authManager.cookies ?? "",
                        userId: authManager.userId
                    )
                }
            )
        }
    }

    private var migrationSourceTracks: [Track] {
        switch migrationSourceService {
        case .soundcloud: return soundCloudVM.tracks
        case .vk: return vkVM.tracks
        default: return []
        }
    }

    private var authTab: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 20) {
                        // заголовок
                        VStack(spacing: 8) {
                            Text("Music Mind")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("подключите стриминги, чтобы MusicMind проанализировал вашу медиатеку")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 24)

                        // карточки сервисов
                        VStack(spacing: 16) {
                            ServiceCardView(
                                service: .yandex,
                                isConnected: authManager.isAuthenticated,
                                onConnect: {
                                    showAuth = true
                                },
                                onLogout: authManager.isAuthenticated ? {
                                    authManager.logout()
                                } : nil
                            )
                            
                            ServiceCardView(
                                service: .spotify,
                                isConnected: false,
                                onConnect: {
                                    // TODO: реализовать авторизацию Spotify
                                },
                                onLogout: nil
                            )
                            
                            ServiceCardView(
                                service: .soundcloud,
                                isConnected: authManager.isSoundCloudAuthenticated,
                                onConnect: {
                                    showSoundCloudAuth = true
                                },
                                onLogout: authManager.isSoundCloudAuthenticated ? {
                                    authManager.logoutSoundCloud()
                                } : nil
                            )
                            
                            ServiceCardView(
                                service: .vk,
                                isConnected: authManager.isVKAuthenticated,
                                onConnect: {
                                    showVKAuth = true
                                },
                                onLogout: authManager.isVKAuthenticated ? {
                                    authManager.logoutVK()
                                } : nil
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40) // заменяем Spacer на padding
                    }
                }
            }
            .background {
                themeManager.currentSpec.backgroundGradient
                    .ignoresSafeArea(.all)
            }
            .navigationTitle("Мои сервисы")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(themeManager.currentSpec.primary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ThemeSwitcherView()
                }
            }
        }
    }
}

// MARK: - Tab bar icon colors (liquid glass, native bar)

private struct TabBarIconColorPatcher: UIViewRepresentable {
    let selectedTab: Int

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            let rootView = window.rootViewController?.view ?? window
            guard let tabBar = findTabBar(in: rootView) else { return }
            guard let items = tabBar.items, items.count >= 5 else { return }

            let configs: [(String, UIColor)] = [
                ("music.note.list", UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)),           // яндекс — жёлтый
                ("cloud", UIColor(red: 1, green: 0.33, blue: 0, alpha: 1)),                    // soundcloud — оранжевый
                ("music.note.list", UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)),          // vk — синий
                ("arrow.triangle.2.circlepath", UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1)),
                ("person.crop.circle", UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1))
            ]

            let white = UIColor.white
            for (idx, (name, color)) in configs.enumerated() where idx < items.count {
                items[idx].image = UIImage(systemName: name)?
                    .withTintColor(white, renderingMode: .alwaysOriginal)
                items[idx].selectedImage = UIImage(systemName: name)?
                    .withTintColor(color, renderingMode: .alwaysOriginal)
            }
        }
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        for sub in view.subviews {
            if let bar = findTabBar(in: sub) { return bar }
        }
        return nil
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .modelContainer(for: Item.self, inMemory: true)
}
