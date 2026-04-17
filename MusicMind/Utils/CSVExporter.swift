//
//  CSVExporter.swift
//  MusicMindAI
//
//  Утилита для экспорта треков в формат CSV
//

import Foundation
import OSLog

struct CSVExporter {
    private static let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "CSVExporter")
    
    /// Экспортирует треки в CSV формат
    static func exportTracks(_ tracks: [Track]) -> String {
        var csvContent = "ID,Title,Artists,Duration (ms),Duration (formatted),Album ID,Cover URI,Available,Yandex URL\n"
        
        for track in tracks {
            let escapedTitle = escapeCSVField(track.title)
            let escapedArtists = escapeCSVField(track.artists)
            let durationFormatted = formatDuration(track.durationMs)
            let albumId = track.albumId?.description ?? ""
            let coverUri = escapeCSVField(track.coverUri ?? "")
            let yandexURL = track.yandexMusicURL?.absoluteString ?? ""
            
            csvContent += "\(track.id),\(escapedTitle),\(escapedArtists),\(track.durationMs),\(durationFormatted),\(albumId),\(coverUri),\(track.available),\(yandexURL)\n"
        }
        
        return csvContent
    }
    
    /// Сохраняет треки в CSV файл
    static func saveTracks(_ tracks: [Track], to fileName: String = "music_tracks.csv") async throws -> URL {
        let csvContent = exportTracks(tracks)
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CSVExportError.directoryNotFound
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        try await Task.detached(priority: .userInitiated) {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }.value
        
        logger.info("CSV файл сохранен: \(fileURL.path)")
        return fileURL
    }
    
    /// Экранирует поля CSV (добавляет кавычки если нужно)
    private static func escapeCSVField(_ field: String) -> String {
        let needsEscaping = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        
        if needsEscaping {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        
        return field
    }
    
    /// Форматирует длительность трека в читаемый вид (мм:сс)
    private static func formatDuration(_ durationMs: Int) -> String {
        let seconds = durationMs / 1000
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

enum CSVExportError: LocalizedError {
    case directoryNotFound
    case noTracksToExport
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Не удалось найти директорию для сохранения файла"
        case .noTracksToExport:
            return "Нет треков для экспорта"
        }
    }
}