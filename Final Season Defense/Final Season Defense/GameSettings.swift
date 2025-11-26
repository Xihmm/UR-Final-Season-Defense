//
//  GameSettings.swift
//  Final Season Defense
//
//  Created for difficulty system and game configuration
//

import SpriteKit

enum GameDifficulty: String, CaseIterable {
    case easy
    case medium
    case hard
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var enemySpawnInterval: TimeInterval {
        switch self {
        case .easy: return 1.5
        case .medium: return 1.0
        case .hard: return 0.5
        }
    }
    
    var enemySpeed: CGFloat {
        switch self {
        case .easy: return -35.0
        case .medium: return -40.0
        case .hard: return -50.0
        }
    }
    
    var bossSpawnTime: TimeInterval? {
        switch self {
        case .easy, .medium: return nil
        case .hard: return 30.0 // Professor spawns at 30 seconds
        }
    }
    
    var gameDuration: TimeInterval {
        switch self {
        case .easy, .medium: return 15.0
        case .hard: return 45.0 // Extended duration in Hard mode to allow boss battle (30s + 15s)
        }
    }
    
    var hasBoss: Bool {
        return bossSpawnTime != nil
    }
}

class GameSettings {
    static var shared = GameSettings()
    
    var difficulty: GameDifficulty = .medium
    
    private init() {}
}

