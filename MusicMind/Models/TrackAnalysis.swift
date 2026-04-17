//
//  TrackAnalysis.swift
//  MusicMindAI
//
//  Модель анализа одного трека
//

import Foundation

struct TrackAnalysis: Codable, Identifiable, Equatable {
    let id: UUID
    let track: Track
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
    
    init(
        id: UUID = UUID(),
        track: Track,
        mood: String,
        genre: String,
        energy: String,
        vibe: String,
        bestMoment: String,
        description: String,
        activities: [String],
        similarArtists: [String],
        unusualFacts: String,
        artistBio: String,
        moviesUsedIn: String
    ) {
        self.id = id
        self.track = track
        self.mood = mood
        self.genre = genre
        self.energy = energy
        self.vibe = vibe
        self.bestMoment = bestMoment
        self.description = description
        self.activities = activities
        self.similarArtists = similarArtists
        self.unusualFacts = unusualFacts
        self.artistBio = artistBio
        self.moviesUsedIn = moviesUsedIn
    }
}
