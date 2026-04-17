//
//  Item.swift
//  MusicMindAI
//
//  Created by Alan R on 03.02.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
