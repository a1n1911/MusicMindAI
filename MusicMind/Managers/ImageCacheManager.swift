//
//  ImageCacheManager.swift
//  MusicMindAI
//
//  Менеджер для кэширования изображений обложек
//

import Foundation
import UIKit
import OSLog
import ImageIO

actor ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "ImageCacheManager")
    private var loadingTasks: [String: Task<UIImage?, Error>] = [:]
    
    private init() {
        cache.countLimit = 100 // максимум 100 изображений в кэше
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 МБ
    }
    
    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        
        // проверяем кэш
        if let cachedImage = cache.object(forKey: key) {
            logger.debug("image cache hit: \(url.absoluteString)")
            return cachedImage
        }
        
        // проверяем, не загружается ли уже
        if let existingTask = loadingTasks[key as String] {
            logger.debug("image already loading: \(url.absoluteString)")
            return try? await existingTask.value
        }
        
        // создаем новую задачу загрузки
        let task = Task<UIImage?, Error> {
            logger.debug("image loading: \(url.absoluteString)")
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // проверяем статус ответа
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    logger.warning("image load failed: HTTP \(httpResponse.statusCode) for \(url.absoluteString)")
                    return nil
                }
                
                // пробуем декодировать изображение
                guard let image = UIImage(data: data) else {
                    // если не получилось через UIImage, пробуем через ImageIO для WEBP и других форматов
                    if let imageIOImage = decodeImageWithImageIO(data: data) {
                        cache.setObject(imageIOImage, forKey: key)
                        logger.debug("image cached (ImageIO): \(url.absoluteString)")
                        return imageIOImage
                    }
                    logger.warning("image decode failed: \(url.absoluteString), size: \(data.count) bytes")
                    return nil
                }
                
                // сохраняем в кэш
                cache.setObject(image, forKey: key)
                logger.debug("image cached: \(url.absoluteString)")
                
                return image
            } catch {
                // игнорируем отмененные задачи
                if (error as NSError).code == NSURLErrorCancelled {
                    logger.debug("image load cancelled: \(url.absoluteString)")
                } else {
                    logger.error("image load error: \(error.localizedDescription) for \(url.absoluteString)")
                }
                return nil
            }
        }
        
        loadingTasks[key as String] = task
        
        let result = try? await task.value
        loadingTasks.removeValue(forKey: key as String)
        
        return result
    }
    
    func preloadImages(for urls: [URL]) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for url in urls.prefix(5) { // предзагружаем только первые 5
                    group.addTask {
                        _ = await self.image(for: url)
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        logger.info("image cache cleared")
    }
    
    // fallback декодирование через ImageIO для форматов, которые UIImage не поддерживает
    private func decodeImageWithImageIO(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}
