//
//  MenuScene.swift
//  Final Season Defense
//
//  Created by Yuliang Liu on 11/18/25.
//

import SpriteKit

class MenuScene: SKScene {
    
    private var difficultyButtons: [SKSpriteNode] = []
    private var bgmNode: SKAudioNode?
    
    override func didMove(to view: SKView) {
        setupBackground()
        setupTitle()
        setupRocky()
        setupDifficultyButtons()
        setupAudio()
    }
    
    private func setupBackground() {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
        
        let bgTexture = SKTexture(imageNamed: "rush_rhees_pixel")
        bgTexture.filteringMode = .nearest
        
        let backgroundNode = SKSpriteNode(texture: bgTexture)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = 0
        backgroundNode.size = self.size
        addChild(backgroundNode)
    }
    
    private func setupTitle() {
        let centerX = size.width / 2
        let startY = size.height * 0.75
        let lineSpacing: CGFloat = 25
        
        // First line: "UR"
        let urLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        urLabel.text = "UR"
        urLabel.fontSize = 20
        urLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0) // Yellow
        urLabel.position = CGPoint(x: centerX, y: startY)
        urLabel.zPosition = 100
        addChild(urLabel)
        
        // Second line: "Final Season"
        let seasonLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        seasonLabel.text = "Final Season"
        seasonLabel.fontSize = 20
        seasonLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        seasonLabel.position = CGPoint(x: centerX, y: startY - lineSpacing)
        seasonLabel.zPosition = 100
        addChild(seasonLabel)
        
        // Third line: "Defense"
        let defenseLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        defenseLabel.text = "Defense"
        defenseLabel.fontSize = 20
        defenseLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        defenseLabel.position = CGPoint(x: centerX, y: startY - lineSpacing * 2)
        defenseLabel.zPosition = 100
        addChild(defenseLabel)
    }
    
    private func setupRocky() {
        let rockyTexture = SKTexture(imageNamed: "rocky_idle_back")
        rockyTexture.filteringMode = .nearest
        
        let rocky = SKSpriteNode(texture: rockyTexture)
        rocky.size = CGSize(width: 64, height: 64) // Bigger for menu
        rocky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rocky.zPosition = 10
        addChild(rocky)
        
        // Idle breathing animation
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.8)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.8)
        let sequence = SKAction.sequence([scaleUp, scaleDown])
        rocky.run(SKAction.repeatForever(sequence))
    }
    
    private func setupDifficultyButtons() {
        let difficulties: [GameDifficulty] = [.easy, .medium, .hard]
        let buttonSpacing: CGFloat = 45
        let centerX = size.width / 2
        // Center the buttons vertically - calculate center position for all buttons
        // Screen is 320 tall, so center is around 160
        // We want buttons centered, so start a bit above center
        let startY: CGFloat = 105 // Position for Easy button (top of the three)
        
        for (index, difficulty) in difficulties.enumerated() {
            // Create button background - smaller size to not block the character
            let buttonWidth: CGFloat = 70
            let buttonHeight: CGFloat = 25
            let buttonBackground = SKSpriteNode(color: SKColor(white: 0.2, alpha: 0.8), 
                                               size: CGSize(width: buttonWidth, height: buttonHeight))
            buttonBackground.position = CGPoint(x: centerX, y: startY - CGFloat(index) * buttonSpacing)
            buttonBackground.zPosition = 100
            buttonBackground.name = difficulty.rawValue
            
            // Add border effect
            let border = SKShapeNode(rect: CGRect(x: -buttonWidth/2, y: -buttonHeight/2, width: buttonWidth, height: buttonHeight))
            border.strokeColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
            border.lineWidth = 2
            border.fillColor = .clear
            border.zPosition = 1
            buttonBackground.addChild(border)
            
            // Create label - smaller font
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = difficulty.displayName
            label.fontSize = 11
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.zPosition = 2
            buttonBackground.addChild(label)
            
            // Highlight current selection
            if GameSettings.shared.difficulty == difficulty {
                buttonBackground.color = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.3)
            }
            
            // Add subtle pulse animation
            let scaleUp = SKAction.scale(to: 1.05, duration: 1.0)
            let scaleDown = SKAction.scale(to: 1.0, duration: 1.0)
            let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
            buttonBackground.run(pulse)
            
            addChild(buttonBackground)
            difficultyButtons.append(buttonBackground)
        }
        
        // Add "Tap to Start" label below buttons
        let startLabel = SKLabelNode(fontNamed: "Menlo")
        startLabel.text = "Tap Difficulty to Start"
        startLabel.fontSize = 10
        startLabel.fontColor = .white
        startLabel.position = CGPoint(x: centerX, y: startY - CGFloat(difficulties.count) * buttonSpacing - 20)
        startLabel.zPosition = 100
        addChild(startLabel)
        
        // Blink animation
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.8)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        let blink = SKAction.sequence([fadeOut, fadeIn])
        startLabel.run(SKAction.repeatForever(blink))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNode = atPoint(location)
        
        // Find the button node by traversing up the parent chain
        // (in case user tapped on a child node like label or border)
        var currentNode: SKNode? = touchedNode
        var buttonNode: SKSpriteNode? = nil
        
        while let node = currentNode {
            if let spriteNode = node as? SKSpriteNode,
               let name = node.name,
               GameDifficulty(rawValue: name) != nil {
                buttonNode = spriteNode
                break
            }
            currentNode = node.parent
        }
        
        // Check if we found a valid difficulty button
        if let button = buttonNode,
           let buttonName = button.name,
           let difficulty = GameDifficulty(rawValue: buttonName) {
            
            // Play tap sound effect
            run(SKAction.playSoundFileNamed("clickModeButton", waitForCompletion: false))
            
            // Update selected difficulty
            GameSettings.shared.difficulty = difficulty
            
            // Update button highlights
            updateButtonHighlights(selectedDifficulty: difficulty)
            
            // Small delay for visual feedback, then transition
            let wait = SKAction.wait(forDuration: 0.2)
            let transitionAction = SKAction.run { [weak self] in
                guard let self = self else { return }
                let gameScene = GameScene(size: self.size)
                gameScene.scaleMode = self.scaleMode
                let transition = SKTransition.crossFade(withDuration: 1.0)
                self.view?.presentScene(gameScene, transition: transition)
            }
            run(SKAction.sequence([wait, transitionAction]))
        }
    }
    
    private func updateButtonHighlights(selectedDifficulty: GameDifficulty) {
        for button in difficultyButtons {
            if button.name == selectedDifficulty.rawValue {
                button.color = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.3)
                // Add selection animation
                let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
                button.run(SKAction.sequence([scaleUp, scaleDown]))
            } else {
                button.color = SKColor(white: 0.2, alpha: 0.8)
            }
        }
    }
    
    private func setupAudio() {
        // Background music for menu
        if let bgmURL = Bundle.main.url(forResource: "bgm", withExtension: "mp3") {
            bgmNode = SKAudioNode(url: bgmURL)
            bgmNode?.autoplayLooped = true
            if let bgm = bgmNode {
                addChild(bgm)
            }
        } else {
            print("Warning: bgm.mp3 not found in bundle.")
        }
    }
}

