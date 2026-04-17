//
//  ProfileCacheManager.swift
//  MusicMindAI
//
//  Менеджер для кэширования музыкальных профилей
//

import Foundation
import OSLog

actor ProfileCacheManager {
    static let shared = ProfileCacheManager()
    
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "ProfileCacheManager")
    private let fileManager = FileManager.default
    private let cacheFileName = "musical_profiles.json"
    
    private var cacheURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(cacheFileName)
    }
    
    private var inMemoryCache: [String: MusicalProfile] = [:]
    
    private init() {
        Task {
            await loadCache()
        }
    }
    
    /// Генерирует ключ кэша на основе списка треков
    private func cacheKey(for tracks: [Track]) -> String {
        // используем количество треков и хэш от первых 10 треков для уникальности
        let trackIds = tracks.prefix(10).map { $0.id }.joined(separator: "-")
        let hash = trackIds.hashValue
        return "profile_\(tracks.count)_\(hash)"
    }
    
    func getProfile(for tracks: [Track]) async -> MusicalProfile? {
        let key = cacheKey(for: tracks)
        
        // проверяем память
        if let cached = inMemoryCache[key] {
            logger.debug("getProfile: cache hit (memory) для \(tracks.count) треков")
            return cached
        }
        
        // загружаем из файла если нужно
        await loadCache()
        return inMemoryCache[key]
    }
    
    func saveProfile(_ profile: MusicalProfile, for tracks: [Track]) async {
        let key = cacheKey(for: tracks)
        inMemoryCache[key] = profile
        
        // сохраняем в файл
        await saveCache()
        
        logger.info("saveProfile: сохранён профиль для \(tracks.count) треков")
    }
    
    private func loadCache() async {
        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            logger.debug("loadCache: файл кэша не существует")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // загружаем как словарь [String: Data]
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in json {
                    if let profileData = try? JSONSerialization.data(withJSONObject: value) {
                        let profile = try decoder.decode(MusicalProfile.self, from: profileData)
                        inMemoryCache[key] = profile
                    }
                }
                logger.info("loadCache: загружено \(self.inMemoryCache.count) профилей из кэша")
            }
        } catch {
            logger.error("loadCache: ошибка загрузки \(error.localizedDescription)")
        }
    }
    
    private func saveCache() async {
        guard let url = cacheURL else {
            logger.error("saveCache: не удалось получить URL кэша")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            // сохраняем как словарь [String: Data]
            var jsonDict: [String: Any] = [:]
            for (key, profile) in inMemoryCache {
                let data = try encoder.encode(profile)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    jsonDict[key] = json
                }
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
            try jsonData.write(to: url, options: .atomic)
            logger.debug("saveCache: сохранено \(self.inMemoryCache.count) профилей")
        } catch {
            logger.error("saveCache: ошибка сохранения \(error.localizedDescription)")
        }
    }
    
    func clearCache() async {
        inMemoryCache.removeAll()
        
        guard let url = cacheURL,
              fileManager.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: url)
            logger.info("clearCache: кэш очищен")
        } catch {
            logger.error("clearCache: ошибка удаления \(error.localizedDescription)")
        }
    }
}
