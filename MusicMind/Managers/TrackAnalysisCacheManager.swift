//
//  TrackAnalysisCacheManager.swift
//  MusicMindAI
//
//  Менеджер для кэширования анализов треков
//

import Foundation
import OSLog

actor TrackAnalysisCacheManager {
    static let shared = TrackAnalysisCacheManager()
    
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackAnalysisCacheManager")
    private let fileManager = FileManager.default
    private let cacheFileName = "track_analyses.json"
    
    private var cacheURL: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(cacheFileName)
    }
    
    private var inMemoryCache: [String: TrackAnalysis] = [:]
    
    private init() {
        Task {
            await loadCache()
        }
    }
    
    func getAnalysis(for track: Track) async -> TrackAnalysis? {
        let key = track.id
        
        // проверяем память
        if let cached = inMemoryCache[key] {
            logger.debug("getAnalysis: cache hit (memory) для трека \(track.title)")
            return cached
        }
        
        // загружаем из файла если нужно
        await loadCache()
        return inMemoryCache[key]
    }
    
    func saveAnalysis(_ analysis: TrackAnalysis) async {
        let key = analysis.track.id
        inMemoryCache[key] = analysis
        
        // сохраняем в файл
        await saveCache()
        
        logger.info("saveAnalysis: сохранён анализ для трека \(analysis.track.title)")
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
            let analyses = try decoder.decode([TrackAnalysis].self, from: data)
            
            // загружаем в память
            for analysis in analyses {
                inMemoryCache[analysis.track.id] = analysis
            }
            
            logger.info("loadCache: загружено \(analyses.count) анализов из кэша")
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
            let analyses = Array(inMemoryCache.values)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(analyses)
            try data.write(to: url, options: .atomic)
            logger.debug("saveCache: сохранено \(analyses.count) анализов")
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
