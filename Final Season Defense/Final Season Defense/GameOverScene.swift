//
//  GameOverScene.swift
//  Final Season Defense
//
//  Created by Yuliang Liu on 11/18/25.
//

import SpriteKit

class GameOverScene: SKScene {
    
    var win: Bool = false
    var score: Int = 0
    var deathReason: String = ""
    private var bgmNode: SKAudioNode?
    
    override func didMove(to view: SKView) {
        setupBackground()
        setupContent()
        setupAudio()
        print("DEATH REASON = \(deathReason)")
    }
    
    private func setupBackground() {
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
        
        // Reuse background but darken it slightly to show it's an overlay feel
        let bgTexture = SKTexture(imageNamed: "rush_rhees_pixel")
        bgTexture.filteringMode = .nearest
        
        let backgroundNode = SKSpriteNode(texture: bgTexture)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = 0
        backgroundNode.size = self.size
        backgroundNode.color = .black
        backgroundNode.colorBlendFactor = 0.5 // Darken effect
        addChild(backgroundNode)
    }
    
    private func setupContent() {
        let urYellow = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        titleLabel.fontSize = 18
        titleLabel.fontColor = urYellow
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        titleLabel.zPosition = 100
        
        // Rocky Image
        let rockyNode = SKSpriteNode()
        rockyNode.size = CGSize(width: 64, height: 64)
        rockyNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rockyNode.zPosition = 100
        
        // Subtitle
        let subLabel = SKLabelNode(fontNamed: "Menlo")
        subLabel.fontSize = 12
        subLabel.fontColor = .white
        subLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        subLabel.zPosition = 100
        
        if win {
            titleLabel.text = "Final Crushed!"
            rockyNode.texture = SKTexture(imageNamed: "rocky_win")
            subLabel.text = "Tap to Play Again"
            
            // Win animation: Jump
            let jump = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 10, duration: 0.2),
                SKAction.moveBy(x: 0, y: -10, duration: 0.2)
            ])
            rockyNode.run(SKAction.repeatForever(jump))
            
        } else {
            titleLabel.text = "You Failed..."
            rockyNode.texture = SKTexture(imageNamed: "rocky_lose")
            subLabel.text = "Tap to Retry"
            
            // Lose animation: Shake
            let left = SKAction.rotate(byAngle: 0.1, duration: 0.1)
            let right = SKAction.rotate(byAngle: -0.2, duration: 0.2)
            let back = SKAction.rotate(byAngle: 0.1, duration: 0.1)
            let shake = SKAction.sequence([left, right, back])
            rockyNode.run(SKAction.repeatForever(SKAction.sequence([shake, SKAction.wait(forDuration: 1.0)])))
        }
        
        rockyNode.texture?.filteringMode = .nearest
        
        addChild(titleLabel)
        addChild(rockyNode)
        addChild(subLabel)
        
        // Score display
        let scoreLabel = SKLabelNode(fontNamed: "Menlo")
        scoreLabel.text = "Score: \(score)"
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.65)
        scoreLabel.zPosition = 100
        addChild(scoreLabel)
        
        // Reason display
        let reasonLabel = SKLabelNode(fontNamed: "Menlo")
        reasonLabel.text = deathReason
        reasonLabel.fontSize = 10
        reasonLabel.fontColor = SKColor.red
        reasonLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        reasonLabel.zPosition = 999
        addChild(reasonLabel)
    }
    
    private func setupAudio() {
        // Background music for game over screen
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Return to Menu
        let menuScene = MenuScene(size: self.size)
        menuScene.scaleMode = self.scaleMode
        let transition = SKTransition.flipVertical(withDuration: 0.5)
        view?.presentScene(menuScene, transition: transition)
    }
}

