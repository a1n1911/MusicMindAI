//
//  AuthManager.swift
//  MusicMindAI
//
//  Централизованное управление авторизацией
//

import Foundation
import SwiftUI
import Combine
import OSLog
import WebKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var authResult: YandexAuthResult?
    @Published var isAuthenticated: Bool = false
    
    @Published var soundCloudOAuthToken: String?
    @Published var isSoundCloudAuthenticated: Bool = false
    
    @Published var vkToken: String?
    @Published var vkUserAgent: String?
    @Published var isVKAuthenticated: Bool = false
    
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "AuthManager")
    private let userDefaults = UserDefaults.standard
    private let cookiesKey = AppConstants.UserDefaultsKeys.yandexCookies
    private let userIdKey = AppConstants.UserDefaultsKeys.yandexUserId
    private let soundCloudTokenKey = AppConstants.UserDefaultsKeys.soundCloudOAuthToken
    private let vkTokenKey = AppConstants.UserDefaultsKeys.vkToken
    private let vkUserAgentKey = AppConstants.UserDefaultsKeys.vkUserAgent
    
    init() {
        loadSavedAuth()
        loadSavedSoundCloudAuth()
        loadSavedVKAuth()
    }
    
    var cookies: String? {
        authResult?.cookies
    }
    
    var userId: String? {
        authResult?.userId
    }
    
    func setAuthResult(_ result: YandexAuthResult) {
        authResult = result
        isAuthenticated = result.cookies != nil || result.accessToken != nil
        
        if let cookies = result.cookies {
            userDefaults.set(cookies, forKey: cookiesKey)
            logger.info("сохранены cookies, длина=\(cookies.count)")
        }
        
        if let userId = result.userId {
            userDefaults.set(userId, forKey: userIdKey)
            logger.info("сохранён userId=\(userId)")
        }
        
        logger.info("setAuthResult: authenticated=\(self.isAuthenticated)")
    }
    
    func logout() {
        authResult = nil
        isAuthenticated = false
        userDefaults.removeObject(forKey: cookiesKey)
        userDefaults.removeObject(forKey: userIdKey)
        Self.clearWebViewData(forDomains: ["yandex"])
        logger.info("logout: авторизация очищена")
    }
    
    private func loadSavedAuth() {
        guard let cookies = userDefaults.string(forKey: cookiesKey),
              !cookies.isEmpty else {
            logger.debug("loadSavedAuth: нет сохранённых cookies")
            return
        }
        
        let userId = userDefaults.string(forKey: userIdKey)
        authResult = YandexAuthResult(
            accessToken: nil,
            cookies: cookies,
            userId: userId
        )
        isAuthenticated = true
        
        logger.info("loadSavedAuth: восстановлена авторизация, userId=\(userId ?? "nil")")
    }
    
    // MARK: - SoundCloud
    
    func setSoundCloudToken(_ token: String?) {
        soundCloudOAuthToken = token
        isSoundCloudAuthenticated = token != nil && !(token ?? "").isEmpty
        if let t = token, !t.isEmpty {
            userDefaults.set(t, forKey: soundCloudTokenKey)
            let parts = t.split(separator: "-")
            let uid = parts.count >= 2 ? String(parts[1]) : "?"
            logger.info("SoundCloud: токен сохранён len=\(t.count) parsedUserId=\(uid)")
        } else {
            userDefaults.removeObject(forKey: soundCloudTokenKey)
            logger.info("SoundCloud: токен удалён")
        }
    }
    
    func logoutSoundCloud() {
        setSoundCloudToken(nil)
        Self.clearWebViewData(forDomains: ["soundcloud"])
        logger.info("SoundCloud: logout выполнен")
    }
    
    private func loadSavedSoundCloudAuth() {
        guard let token = userDefaults.string(forKey: soundCloudTokenKey), !token.isEmpty else {
            return
        }
        soundCloudOAuthToken = token
        isSoundCloudAuthenticated = true
        logger.info("SoundCloud: восстановлен токен")
    }
    
    // MARK: - VK Music
    
    func setVKAuth(token: String?, userAgent: String?) {
        vkToken = token
        vkUserAgent = userAgent ?? AppConstants.VKMusic.defaultUserAgent
        let valid = (token != nil && !(token ?? "").isEmpty)
        isVKAuthenticated = valid
        if valid {
            userDefaults.set(token, forKey: vkTokenKey)
            userDefaults.set(vkUserAgent, forKey: vkUserAgentKey)
            logger.info("VK: токен и user-agent сохранены")
        } else {
            userDefaults.removeObject(forKey: vkTokenKey)
            userDefaults.removeObject(forKey: vkUserAgentKey)
            logger.info("VK: авторизация удалена")
        }
    }
    
    func logoutVK() {
        setVKAuth(token: nil, userAgent: nil)
        Self.clearWebViewData(forDomains: ["vk.com", "oauth.vk", "id.vk"])
        logger.info("VK: logout выполнен")
    }
    
    private func loadSavedVKAuth() {
        guard let token = userDefaults.string(forKey: vkTokenKey), !token.isEmpty else {
            return
        }
        vkToken = token
        vkUserAgent = userDefaults.string(forKey: vkUserAgentKey) ?? AppConstants.VKMusic.defaultUserAgent
        isVKAuthenticated = true
        logger.info("VK: восстановлен токен")
    }

    /// Очищает cookies, localStorage и прочие данные WKWebView для указанных доменов
    private static func clearWebViewData(forDomains domainPatterns: [String]) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            let toRemove = records.filter { record in
                let name = record.displayName.lowercased()
                return domainPatterns.contains { name.contains($0.lowercased()) }
            }
            guard !toRemove.isEmpty else { return }
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: toRemove) {}
        }
    }
}
