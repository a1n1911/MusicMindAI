//
//  GeminiService.swift
//  MusicMindAI
//
//  Сервис для работы с Gemini API для анализа музыкального портрета
//

import Foundation
import OSLog

actor GeminiService {
    private let apiKey: String?
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "GeminiService")
    private let urlSession: URLSession
    
    init(urlSession: URLSession? = nil) {
        self.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        if let urlSession = urlSession {
            self.urlSession = urlSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 120
            self.urlSession = URLSession(configuration: configuration)
        }
    }
    
    func generateMusicalProfile(from tracks: [Track], forceRefresh: Bool = false) async throws -> MusicalProfile {
        logger.info("generateMusicalProfile: начало анализа \(tracks.count) треков, forceRefresh=\(forceRefresh)")
        
        // проверяем кэш если не принудительное обновление
        if !forceRefresh {
            if let cached = await ProfileCacheManager.shared.getProfile(for: tracks) {
                logger.info("generateMusicalProfile: найден кэш для \(tracks.count) треков")
                return cached
            }
        }
        
        // формируем промпт для анализа
        let prompt = buildAnalysisPrompt(tracks: tracks)
        
        // делаем запрос к Gemini
        let response = try await makeRequest(prompt: prompt)
        
        // парсим ответ
        let profile = try parseProfile(from: response)
        
        // сохраняем в кэш
        await ProfileCacheManager.shared.saveProfile(profile, for: tracks)
        
        logger.info("generateMusicalProfile: анализ завершён")
        return profile
    }
    
    func analyzeTrack(_ track: Track) async throws -> TrackAnalysis {
        logger.info("analyzeTrack: начало анализа трека \(track.title)")
        
        // проверяем кэш
        if let cached = await TrackAnalysisCacheManager.shared.getAnalysis(for: track) {
            logger.info("analyzeTrack: найден кэш для трека \(track.title)")
            return cached
        }
        
        // формируем промпт для анализа одного трека
        let prompt = buildTrackAnalysisPrompt(track: track)
        
        // делаем запрос к Gemini
        let response = try await makeRequest(prompt: prompt)
        
        // парсим ответ
        let analysis = try parseTrackAnalysis(from: response, track: track)
        
        // сохраняем в кэш
        await TrackAnalysisCacheManager.shared.saveAnalysis(analysis)
        
        logger.info("analyzeTrack: анализ завершён")
        return analysis
    }
    
    func getRecommendations(for profile: MusicalProfile, forceRefresh: Bool = false) async throws -> [String] {
        logger.info("getRecommendations: запрос рекомендаций для профиля, forceRefresh=\(forceRefresh)")
        
        // проверяем кэш если не принудительное обновление
        if !forceRefresh {
            if let cached = await RecommendationsCacheManager.shared.getRecommendations(for: profile.id) {
                logger.info("getRecommendations: найдены кэшированные рекомендации для профиля \(profile.id)")
                return cached
            }
        }
        
        // формируем промпт для рекомендаций
        let prompt = buildRecommendationsPrompt(profile: profile)
        
        // делаем запрос к Gemini
        let response = try await makeRequest(prompt: prompt)
        
        // парсим ответ
        let recommendations = try parseRecommendations(from: response)
        
        // сохраняем в кэш
        await RecommendationsCacheManager.shared.saveRecommendations(recommendations, for: profile.id)
        
        logger.info("getRecommendations: получено \(recommendations.count) рекомендаций")
        return recommendations
    }
    
    private func buildAnalysisPrompt(tracks: [Track]) -> String {
        // собираем статистику
        let artists = tracks.map { $0.artists }
        let uniqueArtists = Set(artists)
        let totalDuration = tracks.reduce(0) { $0 + $1.durationMs }
        let avgDuration = tracks.isEmpty ? 0 : totalDuration / tracks.count
        
        // топ артистов (первые 20)
        let artistCounts = Dictionary(grouping: artists, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(20)
        
        let topArtists = artistCounts.map { "\($0.key) (\($0.value) треков)" }.joined(separator: ", ")
        
        // формируем CSV список всех треков
        let tracksCSV = tracks.map { track in
            // экранируем кавычки и запятые в названии и артисте
            let escapedTitle = track.title.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedArtist = track.artists.replacingOccurrences(of: "\"", with: "\"\"")
            
            // если есть запятая или кавычка, оборачиваем в кавычки
            let title = (escapedTitle.contains(",") || escapedTitle.contains("\"")) ? "\"\(escapedTitle)\"" : escapedTitle
            let artist = (escapedArtist.contains(",") || escapedArtist.contains("\"")) ? "\"\(escapedArtist)\"" : escapedArtist
            
            return "\(title),\(artist)"
        }.joined(separator: "\n")
        
        return """
        проанализируй музыкальный вкус пользователя на основе его плейлиста и верни результат в формате JSON.
        
        задача:
        - проанализируй список треков ниже (формат CSV: название,артист)
        - определи общее настроение, жанры, стиль прослушивания
        - опиши личность пользователя через призму его музыкального вкуса
        - найди паттерны и особенности в выборе музыки
        - выдели сильные стороны вкуса
        - найди необычные факты и интересные связи между треками, артистами, жанрами
        - предложи вектор для дальнейших рекомендаций
        
        данные для анализа:
        всего треков в плейлисте: \(tracks.count)
        
        список треков (CSV формат):
        \(tracksCSV)
        
        требования к ответу:
        - верни ТОЛЬКО валидный JSON без markdown разметки (никаких ```json или ```)
        - никакого текста до или после JSON
        - используй естественный, живой язык в текстовых полях (без официоза)
        - если сомневаешься в жанре или настроении — выбирай наиболее вероятный вариант
        
        формат JSON ответа:
        {
          "mood": "короткое описание общего настроения (2-4 слова)",
          "genres": ["основной жанр", "второй жанр", "третий жанр"],
          "personality": "описание личности пользователя через его музыкальный вкус (2-3 предложения, живым языком)",
          "listeningStyle": "как и зачем пользователь слушает музыку (1-2 предложения)",
          "strength": "главная сильная сторона этого музыкального вкуса (1 предложение)",
          "topArtists": ["артист1", "артист2", "артист3"],
          "musicalTaste": "детальный разбор музыкального вкуса: что его характеризует, какие паттерны видны (3-4 предложения)",
          "recommendationVector": [
            "направление для дальнейших рекомендаций (например: 'экспериментальный звук', 'более глубокие тексты')",
            "второе направление (например: 'похожие артисты из другого региона', 'более энергичные треки')"
          ],
          "unusualFacts": "необычные факты и интересные связи между треками, артистами, жанрами в плейлисте. найди что-то уникальное, неожиданное или интересное (2-3 предложения)"
        }
        """
    }
    
    private func makeRequest(prompt: String) async throws -> GeminiResponse {
        guard let apiKey, !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("makeRequest: ошибка сериализации \(error.localizedDescription)")
            throw GeminiError.encodingFailed
        }
        
        // retry логика для rate limiting
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiError.invalidResponse
                }
                
                logger.info("makeRequest: статус \(httpResponse.statusCode), размер ответа \(data.count)")
                
                // если 429 - пробуем повторить с задержкой
                if httpResponse.statusCode == 429 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        logger.warning("makeRequest: rate limit (429), попытка \(attempt + 1)/\(maxRetries), \(errorData)")
                    }
                    
                    if attempt < maxRetries - 1 {
                        // exponential backoff: 2^attempt секунд (2, 4, 8 секунд)
                        let delay = pow(2.0, Double(attempt + 1))
                        logger.info("makeRequest: ждём \(delay) секунд перед повтором")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        // последняя попытка тоже не удалась
                        throw GeminiError.apiError(statusCode: 429)
                    }
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        logger.error("makeRequest: ошибка API \(errorData)")
                    }
                    throw GeminiError.apiError(statusCode: httpResponse.statusCode)
                }
                
                let decoder = JSONDecoder()
                let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
                return geminiResponse
                
            } catch let error as DecodingError {
                logger.error("makeRequest: ошибка декодирования \(error)")
                throw GeminiError.decodingFailed
            } catch let error as GeminiError {
                // если это наша ошибка и не 429, сразу пробрасываем
                if case .apiError(let code) = error, code == 429, attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt + 1))
                    logger.info("makeRequest: ждём \(delay) секунд перед повтором")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                // для сетевых ошибок тоже можно повторить, но только если не cancelled
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    logger.error("makeRequest: запрос отменён")
                    throw GeminiError.networkError(error)
                }
                
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt + 1))
                    logger.warning("makeRequest: ошибка сети, попытка \(attempt + 1)/\(maxRetries), ждём \(delay) секунд: \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    logger.error("makeRequest: ошибка сети после \(maxRetries) попыток: \(error.localizedDescription)")
                    throw GeminiError.networkError(error)
                }
            }
        }
        
        // если дошли сюда, значит все попытки исчерпаны
        if let lastError = lastError {
            throw GeminiError.networkError(lastError)
        }
        throw GeminiError.networkError(NSError(domain: "GeminiService", code: -1))
    }
    
    private func parseProfile(from response: GeminiResponse) throws -> MusicalProfile {
        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }
        
        logger.debug("parseProfile: получен текст длиной \(text.count)")
        
        // пытаемся извлечь JSON из ответа (может быть обёрнут в markdown)
        let jsonString = extractJSON(from: text)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        do {
            // создаём промежуточную структуру для декодирования
            struct MusicalProfileRaw: Codable {
                let mood: String
                let genres: [String]
                let personality: String
                let listeningStyle: String
                let strength: String
                let topArtists: [String]
                let musicalTaste: String
                let recommendationVector: [String]
                let unusualFacts: String
            }
            
            let decoder = JSONDecoder()
            let raw = try decoder.decode(MusicalProfileRaw.self, from: jsonData)
            
            // форматируем текстовые поля
            let profile = MusicalProfile(
                mood: TextFormatter.format(raw.mood),
                genres: TextFormatter.formatList(raw.genres),
                personality: TextFormatter.format(raw.personality),
                listeningStyle: TextFormatter.format(raw.listeningStyle),
                strength: TextFormatter.format(raw.strength),
                topArtists: TextFormatter.formatList(raw.topArtists),
                musicalTaste: TextFormatter.format(raw.musicalTaste),
                recommendationVector: TextFormatter.formatList(raw.recommendationVector),
                unusualFacts: TextFormatter.format(raw.unusualFacts)
            )
            
            return profile
        } catch {
            logger.error("parseProfile: ошибка парсинга JSON \(error)")
            // fallback: создаём базовый профиль из текста
            let formattedText = TextFormatter.format(text)
            return MusicalProfile(
                mood: "разнообразный",
                genres: [],
                personality: formattedText,
                listeningStyle: "слушает для настроения",
                strength: "разнообразие вкуса",
                topArtists: [],
                musicalTaste: formattedText,
                recommendationVector: ["продолжай исследовать новую музыку"],
                unusualFacts: "интересные связи между треками в плейлисте"
            )
        }
    }
    
    private func buildTrackAnalysisPrompt(track: Track) -> String {
        return """
        проанализируй конкретный музыкальный трек и верни результат в формате JSON.
        
        задача:
        - определи настроение, жанр, энергетику трека
        - опиши визуальный образ или сцену, которую вызывает трек
        - найди ключевой момент, на который стоит обратить внимание
        - объясни, почему трек может цеплять
        - найди необычные факты о треке (история создания, интересные детали, связи с другими треками или событиями)
        - напиши краткую биографию исполнителя (основные факты, стиль, влияние)
        - найди в каких фильмах использовалась эта песня (если использовалась)
        - предложи сценарии использования
        - найди похожих артистов
        
        трек для анализа:
        название: "\(track.title)"
        артист: \(track.artists)
        
        требования к ответу:
        - верни ТОЛЬКО валидный JSON без markdown разметки (никаких ```json или ```)
        - никакого текста до или после JSON
        - используй естественный, живой язык в описаниях
        - будь конкретным и точным в анализе
        
        формат JSON ответа:
        {
          "mood": "основное настроение трека (например: 'меланхоличное', 'энергичное', 'расслабленное')",
          "genre": "жанр простыми словами (например: 'инди-рок', 'электронная поп-музыка', 'хип-хоп')",
          "energy": "низкая | средняя | высокая",
          "vibe": "визуальный образ или сцена, которую вызывает трек (например: 'ночная поездка по городу', 'уютное кафе в дождь')",
          "bestMoment": "на что стоит обратить внимание в треке (например: 'переход в припеве', 'басовая линия', 'вокальная партия')",
          "description": "почему этот трек цепляет и что в нём особенного (2 предложения)",
          "activities": [
            "когда и зачем включать этот трек (например: 'для фона во время работы', 'для вечерней прогулки')",
            "ещё один сценарий использования"
          ],
          "similarArtists": ["артист с похожим звучанием", "ещё один похожий артист"],
          "unusualFacts": "необычные факты о треке: история создания, интересные детали, связи с другими треками или событиями, что-то уникальное или неожиданное (2-3 предложения)",
          "artistBio": "краткая биография исполнителя: основные факты из карьеры, музыкальный стиль, влияние на музыку, ключевые достижения (3-4 предложения)",
          "moviesUsedIn": "в каких фильмах использовалась эта песня. если песня не использовалась в фильмах, напиши 'не использовалась в фильмах'. если использовалась, укажи названия фильмов и в каких сценах (2-3 предложения)"
        }
        """
    }
    
    private func parseTrackAnalysis(from response: GeminiResponse, track: Track) throws -> TrackAnalysis {
        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }
        
        logger.debug("parseTrackAnalysis: получен текст длиной \(text.count)")
        
        // пытаемся извлечь JSON из ответа
        let jsonString = extractJSON(from: text)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        do {
            // создаём промежуточную структуру для декодирования
            struct TrackAnalysisRaw: Codable {
                let mood: String
                let genre: String
                let energy: String
                let vibe: String
                let bestMoment: String
                let description: String
                let activities: [String]
                let similarArtists: [String]
                let unusualFacts: String
                let artistBio: String
                let moviesUsedIn: String
            }
            
            let decoder = JSONDecoder()
            let raw = try decoder.decode(TrackAnalysisRaw.self, from: jsonData)
            
            // создаём финальный анализ с правильным track
            let analysis = TrackAnalysis(
                track: track,
                mood: TextFormatter.format(raw.mood),
                genre: TextFormatter.format(raw.genre),
                energy: TextFormatter.format(raw.energy),
                vibe: TextFormatter.format(raw.vibe),
                bestMoment: TextFormatter.format(raw.bestMoment),
                description: TextFormatter.format(raw.description),
                activities: TextFormatter.formatList(raw.activities),
                similarArtists: TextFormatter.formatList(raw.similarArtists),
                unusualFacts: TextFormatter.format(raw.unusualFacts),
                artistBio: TextFormatter.format(raw.artistBio),
                moviesUsedIn: TextFormatter.format(raw.moviesUsedIn)
            )
            
            return analysis
        } catch {
            logger.error("parseTrackAnalysis: ошибка парсинга JSON \(error)")
            // fallback: создаём базовый анализ
            return TrackAnalysis(
                track: track,
                mood: "разнообразный",
                genre: "поп",
                energy: "средняя",
                vibe: "атмосферный звук",
                bestMoment: "обрати внимание на мелодию",
                description: "интересный трек с уникальной атмосферой",
                activities: ["слушать музыку"],
                similarArtists: [],
                unusualFacts: "интересный трек с уникальной историей",
                artistBio: "талантливый исполнитель с уникальным стилем",
                moviesUsedIn: "не использовалась в фильмах"
            )
        }
    }
    
    private func buildRecommendationsPrompt(profile: MusicalProfile) -> String {
        return """
        составь список из 10 конкретных музыкальных рекомендаций на основе музыкального портрета пользователя.
        
        музыкальный портрет пользователя:
        настроение: \(profile.mood)
        жанры: \(profile.genres.joined(separator: ", "))
        стиль прослушивания: \(profile.listeningStyle)
        сильная сторона вкуса: \(profile.strength)
        топ артисты: \(profile.topArtists.prefix(5).joined(separator: ", "))
        описание вкуса: \(profile.musicalTaste)
        вектор рекомендаций: \(profile.recommendationVector.joined(separator: ", "))
        
        критерии для рекомендаций:
        - рекомендации должны соответствовать музыкальному портрету
        - учитывай вектор рекомендаций из портрета
        - выбирай конкретные треки (не альбомы или артистов целиком)
        - разнообразь рекомендации: часть должна быть похожа на текущий вкус, часть — расширять его
        - избегай слишком очевидных выборов
        - рекомендации должны быть реальными треками, которые существуют
        
        требования к ответу:
        - верни ТОЛЬКО валидный JSON без markdown разметки (никаких ```json или ```)
        - никакого текста до или после JSON
        - верни ровно 10 рекомендаций
        - формат каждой рекомендации: "название трека — артист"
        
        формат JSON ответа:
        {
          "recommendations": [
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист",
            "название трека — артист"
          ]
        }
        """
    }
    
    private func parseRecommendations(from response: GeminiResponse) throws -> [String] {
        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }
        
        logger.debug("parseRecommendations: получен текст длиной \(text.count)")
        
        // пытаемся извлечь JSON из ответа
        let jsonString = extractJSON(from: text)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        do {
            struct RecommendationsResponse: Codable {
                let recommendations: [String]
            }
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(RecommendationsResponse.self, from: jsonData)
            
            // форматируем рекомендации
            return response.recommendations.map { TextFormatter.format($0) }
        } catch {
            logger.error("parseRecommendations: ошибка парсинга JSON \(error)")
            // fallback: пытаемся извлечь список из текста
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("{") && !$0.hasPrefix("}") && !$0.hasPrefix("[") && !$0.hasPrefix("]") }
                .prefix(10)
            
            return Array(lines.map { TextFormatter.format($0) })
        }
    }
    
    func generatePlaylistTracks(query: String, count: Int = 10) async throws -> (title: String, tracks: [String]) {
        logger.info("generatePlaylistTracks: запрос плейлиста, count=\(count)")
        
        let prompt = buildPlaylistPrompt(query: query, count: count)
        let response = try await makeRequest(prompt: prompt)
        let result = try parsePlaylistTracks(from: response)
        
        logger.info("generatePlaylistTracks: получено \(result.tracks.count) треков, название: \(result.title)")
        return result
    }
    
    private func buildPlaylistPrompt(query: String, count: Int) -> String {
        return """
        пользователь просит создать плейлист. проанализируй запрос и верни список конкретных треков в формате JSON.
        
        запрос пользователя: "\(query)"
        
        задача:
        - подбери \(count) конкретных треков, которые соответствуют запросу
        - учитывай жанр, настроение, темп, стиль из запроса
        - выбирай реальные треки, которые существуют
        - формат каждой рекомендации: "название трека — артист"
        - разнообразь подборку, но сохраняй соответствие запросу
        
        требования к ответу:
        - верни ТОЛЬКО валидный JSON без markdown разметки (никаких ```json или ```)
        - никакого текста до или после JSON
        - верни ровно \(count) треков
        - также предложи название для плейлиста на основе запроса (краткое, ёмкое, отражающее суть)
        
        формат JSON ответа:
        {
          "title": "название плейлиста (краткое, отражающее запрос)",
          "tracks": [
            "название трека — артист",
            "название трека — артист",
            "название трека — артист"
          ]
        }
        """
    }
    
    private func parsePlaylistTracks(from response: GeminiResponse) throws -> (title: String, tracks: [String]) {
        guard let text = response.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }
        
        logger.debug("parsePlaylistTracks: получен текст длиной \(text.count)")
        
        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.invalidJSON
        }
        
        do {
            struct PlaylistResponse: Codable {
                let title: String
                let tracks: [String]
            }
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(PlaylistResponse.self, from: jsonData)
            
            return (title: TextFormatter.format(response.title), tracks: response.tracks.map { TextFormatter.format($0) })
        } catch {
            logger.error("parsePlaylistTracks: ошибка парсинга JSON \(error)")
            throw GeminiError.invalidJSON
        }
    }
    
    private func extractJSON(from text: String) -> String {
        // убираем markdown code blocks если есть
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Response Models

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case encodingFailed
    case invalidResponse
    case apiError(statusCode: Int)
    case decodingFailed
    case networkError(Error)
    case emptyResponse
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Не задан GEMINI_API_KEY. Добавьте ключ в переменные окружения Scheme."
        case .invalidURL:
            return "Неверный URL API"
        case .encodingFailed:
            return "Ошибка подготовки запроса"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .apiError(let code):
            return "Ошибка API: \(code)"
        case .decodingFailed:
            return "Ошибка обработки ответа"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .emptyResponse:
            return "Пустой ответ от AI"
        case .invalidJSON:
            return "Неверный формат данных"
        }
    }
}
