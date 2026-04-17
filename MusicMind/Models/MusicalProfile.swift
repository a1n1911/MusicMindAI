//
//  MusicalProfile.swift
//  MusicMindAI
//
//  Модель музыкального портрета пользователя
//

import Foundation

struct MusicalProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let mood: String
    let genres: [String]
    let personality: String
    let listeningStyle: String
    let strength: String
    let topArtists: [String]
    let musicalTaste: String
    let recommendationVector: [String]
    let unusualFacts: String
    let createdAt: Date
    
    // внутренняя структура для декодирования JSON без id
    private enum CodingKeys: String, CodingKey {
        case mood, genres, personality, listeningStyle, strength, topArtists, musicalTaste, recommendationVector, unusualFacts, createdAt
    }
    
    init(
        id: UUID = UUID(),
        mood: String,
        genres: [String],
        personality: String,
        listeningStyle: String,
        strength: String,
        topArtists: [String],
        musicalTaste: String,
        recommendationVector: [String],
        unusualFacts: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.mood = mood
        self.genres = genres
        self.personality = personality
        self.listeningStyle = listeningStyle
        self.strength = strength
        self.topArtists = topArtists
        self.musicalTaste = musicalTaste
        self.recommendationVector = recommendationVector
        self.unusualFacts = unusualFacts
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() // генерируем id при декодировании
        self.mood = try container.decode(String.self, forKey: .mood)
        self.genres = try container.decode([String].self, forKey: .genres)
        self.personality = try container.decode(String.self, forKey: .personality)
        self.listeningStyle = try container.decode(String.self, forKey: .listeningStyle)
        self.strength = try container.decode(String.self, forKey: .strength)
        self.topArtists = try container.decode([String].self, forKey: .topArtists)
        self.musicalTaste = try container.decode(String.self, forKey: .musicalTaste)
        self.recommendationVector = try container.decode([String].self, forKey: .recommendationVector)
        self.unusualFacts = try container.decode(String.self, forKey: .unusualFacts)
        self.createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mood, forKey: .mood)
        try container.encode(genres, forKey: .genres)
        try container.encode(personality, forKey: .personality)
        try container.encode(listeningStyle, forKey: .listeningStyle)
        try container.encode(strength, forKey: .strength)
        try container.encode(topArtists, forKey: .topArtists)
        try container.encode(musicalTaste, forKey: .musicalTaste)
        try container.encode(recommendationVector, forKey: .recommendationVector)
        try container.encode(unusualFacts, forKey: .unusualFacts)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
