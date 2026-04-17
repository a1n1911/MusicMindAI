//
//  RecommendationsCacheManager.swift
//  MusicMindAI
//
//  Менеджер для кэширования рекомендаций
//

import Foundation
import OSLog

actor RecommendationsCacheManager {
    static let shared = RecommendationsCacheManager()
    
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "RecommendationsCacheManager")
    private let fileManager = FileManager.default
    private let cacheFileName = "recommendations.json"
    
    private var cacheURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(cacheFileName)
    }
    
    private var inMemoryCache: [UUID: [String]] = [:]
    
    private init() {
        Task {
            await loadCache()
        }
    }
    
    func getRecommendations(for profileId: UUID) async -> [String]? {
        // проверяем память
        if let cached = inMemoryCache[profileId] {
            logger.debug("getRecommendations: cache hit (memory) для профиля \(profileId)")
            return cached
        }
        
        // загружаем из файла если нужно
        await loadCache()
        return inMemoryCache[profileId]
    }
    
    func saveRecommendations(_ recommendations: [String], for profileId: UUID) async {
        inMemoryCache[profileId] = recommendations
        
        // сохраняем в файл
        await saveCache()
        
        logger.info("saveRecommendations: сохранено \(recommendations.count) рекомендаций для профиля \(profileId)")
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
            
            // загружаем как словарь [String: [String]]
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                for (key, recommendations) in json {
                    if let profileId = UUID(uuidString: key) {
                        inMemoryCache[profileId] = recommendations
                    }
                }
                logger.info("loadCache: загружено \(self.inMemoryCache.count) наборов рекомендаций из кэша")
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
            // сохраняем как словарь [String: [String]]
            var jsonDict: [String: [String]] = [:]
            for (profileId, recommendations) in inMemoryCache {
                jsonDict[profileId.uuidString] = recommendations
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
            try jsonData.write(to: url, options: .atomic)
            logger.debug("saveCache: сохранено \(self.inMemoryCache.count) наборов рекомендаций")
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
