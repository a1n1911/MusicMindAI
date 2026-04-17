//
//  TrackRepository.swift
//  MusicMindAI
//
//  Репозиторий для кэширования и управления треками
//

import Foundation
import OSLog

actor TrackRepository {
    static let shared = TrackRepository()
    
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackRepository")
    private let fileManager = FileManager.default
    
    private func cacheURL(fileName: String) -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }
    
    private init() {}
    
    func saveTracks(_ tracks: [Track], cacheFileName: String = AppConstants.Cache.tracksFileName) async {
        guard let url = cacheURL(fileName: cacheFileName) else {
            logger.error("saveTracks: не удалось получить URL кэша")
            return
        }
        
        // выполняем кодирование и запись в фоновой очереди
        await Task.detached(priority: .utility) {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(tracks)
                try data.write(to: url, options: .atomic)
                let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackRepository")
                logger.info("saveTracks: сохранено \(tracks.count) треков в \(url.path)")
            } catch {
                let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackRepository")
                logger.error("saveTracks: ошибка сохранения \(error.localizedDescription)")
            }
        }.value
    }
    
    func loadCachedTracks(cacheFileName: String = AppConstants.Cache.tracksFileName) async -> [Track]? {
        guard let url = cacheURL(fileName: cacheFileName),
              fileManager.fileExists(atPath: url.path) else {
            logger.debug("loadCachedTracks: файл кэша не существует")
            return nil
        }
        
        // чтение в фоновой очереди для больших файлов
        return await Task.detached(priority: .userInitiated) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let tracks = try decoder.decode([Track].self, from: data)
                let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackRepository")
                logger.info("loadCachedTracks: загружено \(tracks.count) треков из кэша")
                return tracks
            } catch {
                let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "TrackRepository")
                logger.error("loadCachedTracks: ошибка загрузки \(error.localizedDescription)")
                return nil
            }
        }.value
    }
    
    func clearCache(cacheFileName: String = AppConstants.Cache.tracksFileName) async {
        guard let url = cacheURL(fileName: cacheFileName),
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
