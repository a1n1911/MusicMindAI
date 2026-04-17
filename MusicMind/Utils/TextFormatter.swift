//
//  TextFormatter.swift
//  MusicMindAI
//
//  Утилита для форматирования текста от Gemini
//

import Foundation

struct TextFormatter {
    static func format(_ text: String) -> String {
        var formatted = text
        
        // убираем markdown форматирование если есть
        formatted = formatted.replacingOccurrences(of: "**", with: "")
        formatted = formatted.replacingOccurrences(of: "*", with: "")
        formatted = formatted.replacingOccurrences(of: "__", with: "")
        formatted = formatted.replacingOccurrences(of: "_", with: "")
        formatted = formatted.replacingOccurrences(of: "`", with: "")
        
        // убираем лишние пробелы
        formatted = formatted.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // исправляем пунктуацию (добавляем пробелы после знаков препинания перед буквами)
        formatted = formatted.replacingOccurrences(of: "([.,!?;:])([А-Яа-яA-Za-z])", with: "$1 $2", options: .regularExpression)
        
        // убираем пробелы перед знаками препинания
        formatted = formatted.replacingOccurrences(of: " +([.,!?;:])", with: "$1", options: .regularExpression)
        
        // делаем первую букву заглавной в начале текста и после точек
        if !formatted.isEmpty {
            var result = ""
            var capitalizeNext = true
            
            for char in formatted {
                if capitalizeNext && char.isLetter {
                    result.append(char.uppercased())
                    capitalizeNext = false
                } else {
                    result.append(char)
                    if char == "." || char == "!" || char == "?" {
                        capitalizeNext = true
                    }
                }
            }
            formatted = result
        }
        
        // убираем лишние переносы строк (больше 2 подряд)
        formatted = formatted.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        // обрезаем пробелы в начале и конце
        formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // убираем пустые строки в начале и конце
        while formatted.hasPrefix("\n") {
            formatted = String(formatted.dropFirst())
        }
        while formatted.hasSuffix("\n") {
            formatted = String(formatted.dropLast())
        }
        
        return formatted
    }
    
    static func formatList(_ items: [String]) -> [String] {
        return items.map { format($0) }
    }
}
