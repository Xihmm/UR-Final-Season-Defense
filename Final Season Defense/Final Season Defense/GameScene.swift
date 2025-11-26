//
//  GameScene.swift
//  Final Season Defense
//
//  Created by Yuliang Liu on 11/18/25.
//

import SpriteKit

struct PhysicsCategory {
    static let player: UInt32   = 0x1 << 0
    static let enemy: UInt32    = 0x1 << 1
    static let snowball: UInt32 = 0x1 << 2
    static let bossProjectile: UInt32 = 0x1 << 3
}

enum BossProjectileType: String, CaseIterable {
    case exam = "exam"
    case assignment = "assignment"
    case lab = "lab"
    case caseReport = "case_report"
    case project = "project"
    
    var displayName: String {
        switch self {
        case .exam: return "Exam"
        case .assignment: return "Assignment"
        case .lab: return "Lab"
        case .caseReport: return "Case Report"
        case .project: return "Project"
        }
    }
}


private enum GameState {
    case playing
    case gameOver
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes

    private var rocky: SKSpriteNode!

    // Background layers
    private var backgroundNode: SKSpriteNode!
    private var farSnowLayer: SKSpriteNode!
    private var nearSnowLayer: SKSpriteNode!

    private var scoreLabel: SKLabelNode!
    private var score: Int = 0 {
        didSet { scoreLabel.text = "Score: \(score)" }
    }
    
    private var timerLabel: SKLabelNode!
    private var countdownLabel: SKLabelNode!

    // Rocky animation textures
    private var rockyIdleTexture: SKTexture!
    private var rockyThrowTextures: [SKTexture] = []
    private var rockyWinTexture: SKTexture!
    private var rockyLoseTexture: SKTexture!

    // Fire & enemy spawn timing
    private var lastFireTime: TimeInterval = 0
    private let fireCooldown: TimeInterval = 0.15

    private var lastEnemySpawnTime: TimeInterval = 0
    private var enemySpawnInterval: TimeInterval {
        return GameSettings.shared.difficulty.enemySpawnInterval
    }
    
    private var bossSpawned: Bool = false
    private var bossSpawnTime: TimeInterval? {
        return GameSettings.shared.difficulty.bossSpawnTime
    }

    // Track time for touches & spawns
    private var lastUpdateTime: TimeInterval = 0

    // Game state & win condition timing
    private var gameState: GameState = .playing
    private var gameStartTime: TimeInterval = 0
    private var isGameStarted: Bool = false

    // Survive for this duration to win
    private var elapsedTime: TimeInterval = 0
    private var gameDuration: TimeInterval {
        return GameSettings.shared.difficulty.gameDuration
    }
    
    // Boss projectile spawning
    private var lastBossProjectileTime: TimeInterval = 0
    private let bossProjectileInterval: TimeInterval = 2.0 // Every 2 seconds
    private var bossNode: SKSpriteNode?
    private var bossWarningNode: SKNode?
    
    // Background music during gameplay
    private var bgmNode: SKAudioNode?
    
    // Track pending transition to prevent multiple transitions
    private var pendingTransition: DispatchWorkItem?

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        // Reset all game state variables when scene is created
        gameState = .playing
        isGameStarted = false
        elapsedTime = 0
        lastUpdateTime = 0
        gameStartTime = 0
        // Note: score will be set after setupHUD() because it accesses scoreLabel
        lastFireTime = 0
        lastEnemySpawnTime = 0
        bossSpawned = false
        bossNode = nil
        bossWarningNode = nil
        lastBossProjectileTime = 0
        
        // Cancel any pending transitions from previous scene
        pendingTransition?.cancel()
        pendingTransition = nil
        
        // Reduced gravity for slower, more graceful snowball fall
        physicsWorld.gravity = CGVector(dx: 0, dy: -40.0)
        physicsWorld.contactDelegate = self

        setupBackground()
        setupRocky()
        setupHUD()
        // Set score after setupHUD() so scoreLabel is initialized
        score = 0
        setupAudio()
        UserDefaults.standard.set(false, forKey: "didShowTutorial")
        
        if shouldShowTutorial() {
            runTutorialSequence()
            UserDefaults.standard.set(true, forKey: "didShowTutorial")
        }
        
        // Start with "Ready... Go!" animation
        runReadyGoAnimation()
    }
    
    override func willMove(from view: SKView) {
        // Cancel any pending transitions when scene is about to be removed
        pendingTransition?.cancel()
        pendingTransition = nil
        super.willMove(from: view)
    }
    
    private func shouldShowTutorial() -> Bool {
        return !UserDefaults.standard.bool(forKey: "didShowTutorial")
    }
    
    
    private func dottedCurveNode(from start: CGPoint,
                                 to end: CGPoint,
                                 control: CGPoint) -> SKNode {
        
        let container = SKNode()
        container.zPosition = 300
        container.alpha = 0   // fade in with animation
        
        // Number of dots on the curve
        let steps = 24
        
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            
            // Quadratic Bézier:
            // B(t) = (1−t)² * P0 + 2(1−t)t * P1 + t² * P2
            let x = pow(1 - t, 2) * start.x
                  + 2 * t * (1 - t) * control.x
                  + pow(t, 2) * end.x
            
            let y = pow(1 - t, 2) * start.y
                  + 2 * t * (1 - t) * control.y
                  + pow(t, 2) * end.y
            
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.position = CGPoint(x: x, y: y)
            
            container.addChild(dot)
        }
        
        return container
    }

    private func runTutorialSequence() {
        // --- Tutorial Text ---
        let bubble = SKLabelNode(fontNamed: "Menlo")
        bubble.text = "Try tapping here!"
        bubble.fontSize = 12
        bubble.fontColor = .white
        bubble.alpha = 0
        bubble.position = CGPoint(x: size.width * 0.65,
                                  y: size.height * 0.55)
        bubble.zPosition = 300
        addChild(bubble)
        
        
        // --- Tap Indicator (hand icon or fallback circle) ---
        let tapIndicator: SKNode
        if UIImage(named: "hand_tap") != nil {
            let hand = SKSpriteNode(imageNamed: "hand_tap")
            hand.alpha = 0
            hand.setScale(0.7)
            tapIndicator = hand
        } else {
            let circle = SKShapeNode(circleOfRadius: 18)
            circle.strokeColor = .white
            circle.lineWidth = 2
            circle.fillColor = .clear
            circle.alpha = 0
            tapIndicator = circle
        }
        
        tapIndicator.position = CGPoint(x: size.width * 0.65,
                                        y: size.height * 0.43)
        tapIndicator.zPosition = 300
        addChild(tapIndicator)
        
        
        // --- Indicator Pulsing Animation ---
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        
        tapIndicator.run(SKAction.fadeIn(withDuration: 0.5))
        tapIndicator.run(pulse)
        
        
        // --- Dotted Curve Path ---
        let start = CGPoint(x: rocky.position.x,
                            y: rocky.position.y + 15)
        let end = tapIndicator.position
        let control = CGPoint(
            x: (start.x + end.x) / 2,
            y: max(start.y, end.y) + 80   // arc height
        )
        
        let dotted = dottedCurveNode(from: start, to: end, control: control)
        addChild(dotted)
        
        
        // --- Shared Fade In/Out Animation ---
        let fadeIn  = SKAction.fadeIn(withDuration: 0.6)
        let wait    = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let remove  = SKAction.removeFromParent()
        
        // Apply animations
        bubble.run(.sequence([fadeIn, wait, fadeOut, remove]))
        tapIndicator.run(.sequence([wait, fadeOut, remove]))
        dotted.run(.sequence([fadeIn, wait, fadeOut, remove]))
    }




    // MARK: - Setup

    private func setupBackground() {
        // Solid fallback color
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)

        // Main pixel-art background (library at bottom, field at top)
        // Make sure you have an image asset named "rush_rhees_pixel"
        let bgTexture = SKTexture(imageNamed: "rush_rhees_pixel")
        bgTexture.filteringMode = .nearest

        backgroundNode = SKSpriteNode(texture: bgTexture)
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backgroundNode.zPosition = 0
        backgroundNode.size = self.size
        addChild(backgroundNode)

        // Parallax snow / cloud layers (simple translucent overlays moving at different speeds)

        // Far layer: very subtle
        farSnowLayer = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.08),
                                    size: CGSize(width: size.width, height: size.height))
        farSnowLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        farSnowLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        farSnowLayer.zPosition = 1
        addChild(farSnowLayer)

        // Near layer: slightly stronger
        nearSnowLayer = SKSpriteNode(color: SKColor(white: 1.0, alpha: 0.12),
                                     size: CGSize(width: size.width, height: size.height))
        nearSnowLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        nearSnowLayer.position = CGPoint(x: size.width / 2, y: size.height / 2)
        nearSnowLayer.zPosition = 2
        addChild(nearSnowLayer)
    }

    private func setupRocky() {
        // Load textures and enforce nearest filtering for crisp pixels
        rockyIdleTexture = SKTexture(imageNamed: "rocky_idle_back")
        rockyIdleTexture.filteringMode = .nearest

        // Idle "breathing" animation
        let scaleUp = SKAction.scale(to: 1.03, duration: 0.8)
        let scaleDown = SKAction.scale(to: 0.97, duration: 0.8)
        let breatheSeq = SKAction.sequence([scaleUp, scaleDown])
        // Use a specific key so we can potentially stop it, though overlapping with throw is fine
        let idleAction = SKAction.repeatForever(breatheSeq)

        let throw1 = SKTexture(imageNamed: "rocky_throw_1")
        let throw2 = SKTexture(imageNamed: "rocky_throw_2")
        throw1.filteringMode = .nearest
        throw2.filteringMode = .nearest
        rockyThrowTextures = [throw1, throw2]

        // Win / lose pose textures
        rockyWinTexture = SKTexture(imageNamed: "rocky_win")
        rockyWinTexture.filteringMode = .nearest

        rockyLoseTexture = SKTexture(imageNamed: "rocky_lose")
        rockyLoseTexture.filteringMode = .nearest

        rocky = SKSpriteNode(texture: rockyIdleTexture)
        rocky.size = CGSize(width: 32, height: 32)
        // Place Rocky slightly lower on the left side of the library roof
        rocky.position = CGPoint(x: 50, y: 80)
        rocky.zPosition = 10

        rocky.physicsBody = SKPhysicsBody(circleOfRadius: 14)
        rocky.physicsBody?.isDynamic = false
        rocky.physicsBody?.categoryBitMask = PhysicsCategory.player
        rocky.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        rocky.physicsBody?.collisionBitMask = 0

        addChild(rocky)
        
        // Start idle animation
        rocky.run(idleAction, withKey: "idle")
    }

    private func setupHUD() {
        scoreLabel = SKLabelNode(fontNamed: "Menlo")
        scoreLabel.fontSize = 10
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 8, y: size.height - 8)
        scoreLabel.zPosition = 100
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
        
        // Countdown timer label
        timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timerLabel.fontSize = 16
        timerLabel.horizontalAlignmentMode = .right
        timerLabel.verticalAlignmentMode = .top
        timerLabel.position = CGPoint(x: size.width - 8, y: size.height - 8)
        timerLabel.zPosition = 100
        timerLabel.text = "15"
        timerLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        addChild(timerLabel)
        
        // "Ready... Go!" countdown label (initially hidden)
        countdownLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        countdownLabel.fontSize = 24
        countdownLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        countdownLabel.zPosition = 200
        countdownLabel.alpha = 0
        addChild(countdownLabel)
    }
    
    private func runReadyGoAnimation() {
        // Disable game start initially
        isGameStarted = false
        
        let readyText = "Ready..."
        let goText = "Go!"
        
        // Show "Ready..."
        countdownLabel.text = readyText
        countdownLabel.alpha = 0
        countdownLabel.setScale(0.5)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        let readyGroup = SKAction.group([fadeIn, scaleUp])
        
        let wait1 = SKAction.wait(forDuration: 0.7)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let scaleDown = SKAction.scale(to: 0.5, duration: 0.2)
        let readyOut = SKAction.group([fadeOut, scaleDown])
        
        // Show "Go!"
        let showGo = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.countdownLabel.text = goText
            self.countdownLabel.alpha = 0
            self.countdownLabel.setScale(0.5)
        }
        
        let fadeInGo = SKAction.fadeIn(withDuration: 0.2)
        let scaleUpGo = SKAction.scale(to: 1.5, duration: 0.2)
        let goGroup = SKAction.group([fadeInGo, scaleUpGo])
        
        let wait2 = SKAction.wait(forDuration: 0.5)
        let fadeOutGo = SKAction.fadeOut(withDuration: 0.3)
        let scaleDownGo = SKAction.scale(to: 0.3, duration: 0.3)
        let goOut = SKAction.group([fadeOutGo, scaleDownGo])
        
        let startGame = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.isGameStarted = true
            self.gameStartTime = self.lastUpdateTime
            
            // Start background music when game begins
            if let bgm = self.bgmNode {
                self.addChild(bgm)
            }
        }
        
        let sequence = SKAction.sequence([
            readyGroup,
            wait1,
            readyOut,
            showGo,
            goGroup,
            wait2,
            goOut,
            startGame
        ])
        
        countdownLabel.run(sequence)
    }

    private func setupAudio() {
        // Setup background music for gameplay (will start when game begins)
        if let bgmURL = Bundle.main.url(forResource: "bgmDuringTheGame", withExtension: "wav") {
            bgmNode = SKAudioNode(url: bgmURL)
            bgmNode?.autoplayLooped = true
            // Don't add to scene yet - will start when game begins
        } else {
            print("Warning: bgmDuringTheGame.wav not found in bundle.")
        }
    }

    // MARK: - Enemy

    private func spawnEnemy(currentTime: TimeInterval) {
        if currentTime - lastEnemySpawnTime < enemySpawnInterval { return }
        lastEnemySpawnTime = currentTime

        let enemyTexture = SKTexture(imageNamed: "enemy_exam")
        enemyTexture.filteringMode = .nearest

        let enemy = SKSpriteNode(texture: enemyTexture)
        enemy.size = CGSize(width: 32, height: 32)
        enemy.name = "enemy"

        let minX: CGFloat = 32
        let maxX: CGFloat = size.width - 32
        let randomX = CGFloat.random(in: minX...maxX)

        enemy.position = CGPoint(x: randomX, y: size.height + 16)
        enemy.zPosition = 20

        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 14)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.affectedByGravity = false // Enemy floats/moves at constant speed
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.snowball | PhysicsCategory.player
        enemy.physicsBody?.collisionBitMask = 0

        addChild(enemy)

        // Use difficulty-based speed
        let speed = GameSettings.shared.difficulty.enemySpeed
        enemy.physicsBody?.velocity = CGVector(dx: 0, dy: speed)
    }
    
    private func spawnBossEnemy() {
        // Check if boss should spawn and hasn't been spawned yet
        guard let bossTime = bossSpawnTime,
              !bossSpawned,
              elapsedTime >= bossTime else { return }
        
        bossSpawned = true
        
        // Try to load boss texture, fallback to regular enemy if not found
        // NOTE: You can add "professor.png" or "boss_exam.png" to your Assets.xcassets
        let bossTexture: SKTexture
        if UIImage(named: "professor") != nil {
            bossTexture = SKTexture(imageNamed: "professor")
        } else if UIImage(named: "boss_exam") != nil {
            bossTexture = SKTexture(imageNamed: "boss_exam")
        } else {
            // Fallback to regular enemy texture if boss texture is missing
            bossTexture = SKTexture(imageNamed: "enemy_exam")
            print("Warning: professor.png or boss_exam.png not found. Using enemy_exam.png as fallback.")
        }
        bossTexture.filteringMode = .nearest

        let boss = SKSpriteNode(texture: bossTexture)
        boss.size = CGSize(width: 64, height: 64) // Larger size for boss
        boss.name = "boss"
        boss.zPosition = 20

        // Spawn boss at top center - FIXED POSITION (doesn't move)
        // Lower position so professor hat is fully visible
        boss.position = CGPoint(x: size.width / 2, y: size.height - 70) // Lower position for hat visibility

        // Physics body for hit detection only (not for movement)
        boss.physicsBody = SKPhysicsBody(circleOfRadius: 28)
        boss.physicsBody?.isDynamic = false // Stationary - doesn't move
        boss.physicsBody?.affectedByGravity = false
        boss.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        boss.physicsBody?.contactTestBitMask = PhysicsCategory.snowball | PhysicsCategory.player
        boss.physicsBody?.collisionBitMask = 0

        // Store HP as userData - increased HP for more challenge
        boss.userData = NSMutableDictionary()
        boss.userData?["hp"] = 5
        boss.userData?["maxHP"] = 5

        addChild(boss)
        
        // Store boss reference for projectile spawning
        bossNode = boss
        
        // Add "Professor" label above boss
        let bossLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        bossLabel.text = "Professor"
        bossLabel.fontSize = 12
        bossLabel.fontColor = SKColor.red
        bossLabel.position = CGPoint(x: 0, y: 40)
        bossLabel.zPosition = 21
        boss.addChild(bossLabel)
        
        // Add Professor hat/cap visual indicator
        let hat = SKSpriteNode(color: SKColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0), size: CGSize(width: 50, height: 20))
        hat.position = CGPoint(x: 0, y: 25) // On top of boss
        hat.zPosition = 22
        hat.name = "professorHat"
        boss.addChild(hat)
        
        // Add a tassel or decoration to make it more obvious
        let tassel = SKShapeNode(circleOfRadius: 3)
        tassel.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0) // Gold color
        tassel.strokeColor = .clear
        tassel.position = CGPoint(x: 0, y: -10)
        hat.addChild(tassel)
        
        // Add "PROF" text on hat for extra clarity
        let hatLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        hatLabel.text = "PROF"
        hatLabel.fontSize = 8
        hatLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        hatLabel.verticalAlignmentMode = .center
        hatLabel.zPosition = 1
        hat.addChild(hatLabel)
        
        // Enhanced visual effects: Pulsing (no rotation since stationary)
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.6)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.6)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        boss.run(pulse, withKey: "bossPulse")
        
        // Screen shake and sound effect when boss spawns
        screenShake(intensity: 8, duration: 0.5)
        run(SKAction.playSoundFileNamed("hit", waitForCompletion: false))
        
        // Start spawning projectiles
        lastBossProjectileTime = lastUpdateTime
    }
    
    // MARK: - Boss Projectiles
    
    private func spawnBossProjectile(currentTime: TimeInterval) {
        guard let boss = bossNode, boss.parent != nil else { return }
        if currentTime - lastBossProjectileTime < bossProjectileInterval { return }
        lastBossProjectileTime = currentTime
        
        // Show warning animation and sound before throwing
        showBossWarning { [weak self] in
            guard let self = self else { return }
            self.actuallyThrowProjectile(from: boss)
        }
    }
    
    private func showBossWarning(completion: @escaping () -> Void) {
        guard let boss = bossNode else {
            completion()
            return
        }
        
        // Play warning sound
        run(SKAction.playSoundFileNamed("throw", waitForCompletion: false))
        
        // Create warning indicator (exclamation mark or arrow)
        let warningLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        warningLabel.text = "!"
        warningLabel.fontSize = 20
        warningLabel.fontColor = SKColor.red
        warningLabel.position = CGPoint(x: boss.position.x, y: boss.position.y - 15)
        warningLabel.zPosition = 25
        warningLabel.alpha = 0
        addChild(warningLabel)
        
        // Warning animation: fade in, pulse, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        let pulseRepeat = SKAction.repeat(pulse, count: 2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        
        let warningSequence = SKAction.sequence([
            fadeIn,
            pulseRepeat,
            fadeOut,
            remove
        ])
        
        warningLabel.run(warningSequence) {
            completion()
        }
    }
    
    private func actuallyThrowProjectile(from boss: SKSpriteNode) {
        // Randomly select projectile type
        let projectileType = BossProjectileType.allCases.randomElement() ?? .exam
        
        // Try to load projectile texture, fallback to colored sprite
        let projectile: SKSpriteNode
        let textureName = projectileType.rawValue // "exam", "assignment", "lab", "case_report", "project"
        
        if UIImage(named: textureName) != nil {
            let texture = SKTexture(imageNamed: textureName)
            texture.filteringMode = .nearest
            projectile = SKSpriteNode(texture: texture)
        } else {
            // Fallback: create colored sprite based on type
            let color: SKColor
            switch projectileType {
            case .exam:
                color = SKColor.red // Red for exams - DANGEROUS
            case .assignment:
                color = SKColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0) // Blue
            case .lab:
                color = SKColor(red: 0.0, green: 0.8, blue: 0.4, alpha: 1.0) // Green
            case .caseReport:
                color = SKColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1.0) // Brown/tan
            case .project:
                color = SKColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0) // Orange/yellow
            }
            projectile = SKSpriteNode(color: color, size: CGSize(width: 32, height: 32))
        }
        
        projectile.size = CGSize(width: 32, height: 32)
        projectile.position = CGPoint(x: boss.position.x, y: boss.position.y - 30)
        projectile.zPosition = 18
        
        // Add label for projectile type
        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = projectileType.displayName
        label.fontSize = 10
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        projectile.addChild(label)
        
        // Only exam is special - others behave like regular enemies
        if projectileType == .exam {
            // Exam: Special dangerous projectile
            projectile.name = "bossProjectile"
            projectile.physicsBody = SKPhysicsBody(circleOfRadius: 16)
            projectile.physicsBody?.isDynamic = true
            projectile.physicsBody?.affectedByGravity = true
            projectile.physicsBody?.categoryBitMask = PhysicsCategory.bossProjectile
            projectile.physicsBody?.contactTestBitMask = PhysicsCategory.player
            projectile.physicsBody?.collisionBitMask = 0
            
            // Store projectile type in userData
            projectile.userData = NSMutableDictionary()
            projectile.userData?["type"] = projectileType.rawValue
            
            // Exam falls slower so user can see it
            let initialSpeed: CGFloat = -30.0 // Slower so user can react
            projectile.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -5...5), dy: initialSpeed)
            
            // Rotation animation - slower rotation for visibility
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 2.0)
            projectile.run(SKAction.repeatForever(rotate))
        } else {
            // Other types: behave like regular enemies (don't attack library, just fall and rotate)
            projectile.name = "enemy" // Use enemy name so they're treated like enemies
            projectile.physicsBody = SKPhysicsBody(circleOfRadius: 16)
            projectile.physicsBody?.isDynamic = true
            projectile.physicsBody?.affectedByGravity = false // Like enemies, constant speed
            projectile.physicsBody?.categoryBitMask = PhysicsCategory.enemy
            projectile.physicsBody?.contactTestBitMask = PhysicsCategory.snowball | PhysicsCategory.player
            projectile.physicsBody?.collisionBitMask = 0
            
            // Store projectile type in userData for identification
            projectile.userData = NSMutableDictionary()
            projectile.userData?["type"] = projectileType.rawValue
            projectile.userData?["isAcademicProjectile"] = true
            
            // Slower speed so user can see and react - like original enemy speed but slower
            let speed: CGFloat = -25.0 // Much slower than before
            projectile.physicsBody?.velocity = CGVector(dx: 0, dy: speed)
            
            // Rotation animation - like original enemy rotation
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 3.0) // Slower rotation
            projectile.run(SKAction.repeatForever(rotate))
        }
        
        addChild(projectile)
    }
    
    private func handleBossProjectileHitPlayer(contact: SKPhysicsContact) {
        let projectileNode: SKNode?
        
        if contact.bodyA.categoryBitMask == PhysicsCategory.bossProjectile {
            projectileNode = contact.bodyA.node
        } else {
            projectileNode = contact.bodyB.node
        }
        
        guard let projectile = projectileNode else { return }
        
        // Only exam type is dangerous - instant game over
        if let userData = projectile.userData,
           let typeString = userData["type"] as? String,
           let type = BossProjectileType(rawValue: typeString),
           type == .exam {
            // Exam causes instant game over
            triggerGameEnd(win: false, reason: "Hit by Exam!")
            return
        }
        
        // Other projectiles are handled by regular enemy hit handler
        // (They use PhysicsCategory.enemy, so they'll be handled by handleEnemyHitPlayer)
    }

    // MARK: - Snowball

    private func fireSnowball(towards location: CGPoint, currentTime: TimeInterval) {
        if currentTime - lastFireTime < fireCooldown {
            return
        }
        lastFireTime = currentTime

        // Throw sound effect (ensure throw.wav is in the bundle)
        run(SKAction.playSoundFileNamed("throw", waitForCompletion: false))

        // Trigger Rocky's throw animation (texture sequence + action sequence)
        runRockyThrowAnimation()

        let snowballTexture = SKTexture(imageNamed: "snowball")
        snowballTexture.filteringMode = .nearest

        let snowball = SKSpriteNode(texture: snowballTexture)
        snowball.size = CGSize(width: 12, height: 12)
        snowball.position = CGPoint(x: rocky.position.x,
                                    y: rocky.position.y + 16)
        snowball.zPosition = 15
        snowball.name = "snowball"

        let body = SKPhysicsBody(circleOfRadius: 6)
        body.isDynamic = true
        body.affectedByGravity = true // Snowball falls with gravity
        body.categoryBitMask = PhysicsCategory.snowball
        body.contactTestBitMask = PhysicsCategory.enemy
        body.collisionBitMask = 0
        snowball.physicsBody = body

        addChild(snowball)

        // Compute direction from Rocky to touch location
        let dx = location.x - snowball.position.x
        let dy = location.y - snowball.position.y
        let dist = sqrt(dx*dx + dy*dy)
        guard dist > 0 else { return }

        // Calculate a path using a Bezier curve
        // This completely bypasses physics gravity issues and guarantees the arc visually.
        
        let startPoint = snowball.position
        let endPoint = location
        
        // Control point for the quadratic Bezier curve
        // We want it to be somewhere between start and end horizontally,
        // but significantly higher vertically to create the arc.
        let midX = (startPoint.x + endPoint.x) / 2
        let peakHeight: CGFloat = 80.0 // How high the arc goes above the higher point
        let maxY = max(startPoint.y, endPoint.y) + peakHeight
        let controlPoint = CGPoint(x: midX, y: maxY)
        
        // Create a path
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addQuadCurve(to: endPoint, control: controlPoint)
        
        // Calculate duration based on distance so speed feels roughly constant
        // Arc length approximation: distance + extra for height
        // Slower speed (120) for a more visible arc
        let distTotal = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        let duration = TimeInterval(distTotal / 120.0) // 120 pixels per second base speed
        // Clamp minimum duration to ensure the throw is visible
        let finalDuration = max(duration, 0.8)
        
        // Create the action to follow the arc
        // We set asOffset: false because the path points are absolute scene coordinates
        let followArc = SKAction.follow(path, asOffset: false, orientToPath: true, duration: finalDuration)
        
        // Instead of removing immediately, we transition to physics falling
        let enablePhysicsFall = SKAction.run { [weak snowball] in
            guard let sb = snowball else { return }
            
            // Re-enable gravity
            sb.physicsBody?.affectedByGravity = true
            
            // Add air resistance to prevent terminal velocity from getting too high
            sb.physicsBody?.linearDamping = 0.8
            
            // Calculate velocity at the end of the curve
            // Tangent vector at t=1 for quadratic bezier: 2(P2 - P1)
            // Velocity = Tangent / duration
            let p1 = controlPoint
            let p2 = endPoint
            let tangent = CGVector(dx: 2 * (p2.x - p1.x), dy: 2 * (p2.y - p1.y))
            
            // Scale by duration to get pixels/second
            // Note: This is an approximation but works well for visual continuity
            let velocity = CGVector(dx: tangent.dx / CGFloat(finalDuration),
                                    dy: tangent.dy / CGFloat(finalDuration))
            
            sb.physicsBody?.velocity = velocity
        }
        
        // Run action sequence: Fly Arc -> Enable Physics & Fall
        snowball.run(.sequence([followArc, enablePhysicsFall]))
        
        // Disable gravity initially so physics doesn't fight the action
        snowball.physicsBody?.affectedByGravity = false
        snowball.physicsBody?.velocity = .zero
        
        // We keep the physics body for collision detection (isDynamic = true),
        // but we zero out velocity and gravity so SKAction controls the position.
    }

    // Rocky throw animation: uses texture sequence + action sequence, keeping size consistent
    private func runRockyThrowAnimation() {
        // Remember current size (normally 32x32)
        let originalSize = rocky.size

        rocky.removeAction(forKey: "throwAnim")

        let animateThrow = SKAction.animate(with: rockyThrowTextures,
                                            timePerFrame: 0.08,
                                            resize: false,
                                            restore: false)
        let backToIdle = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.rocky.texture = self.rockyIdleTexture
            self.rocky.size = originalSize
        }

        let seq = SKAction.sequence([animateThrow, backToIdle])
        rocky.run(seq, withKey: "throwAnim")
    }

    // Rocky win animation: special pose + bouncing
    private func runRockyWinAnimation() {
        let originalSize = rocky.size
        let originalPosition = rocky.position

        rocky.removeAllActions()
        rocky.texture = rockyWinTexture
        rocky.size = originalSize

        let jumpUp = SKAction.moveBy(x: 0, y: 8, duration: 0.12)
        let jumpDown = SKAction.moveBy(x: 0, y: -8, duration: 0.12)
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.12)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.12)

        let moveSeq = SKAction.sequence([jumpUp, jumpDown])
        let scaleSeq = SKAction.sequence([scaleUp, scaleDown])
        let group = SKAction.group([moveSeq, scaleSeq])

        rocky.position = originalPosition
        rocky.run(SKAction.repeatForever(group), withKey: "rockyWin")
    }

    // Rocky lose animation: special pose + small shake
    private func runRockyLoseAnimation() {
        let originalSize = rocky.size
        let originalPosition = rocky.position

        rocky.removeAllActions()
        rocky.texture = rockyLoseTexture
        rocky.size = originalSize

        let tiltLeft = SKAction.rotate(toAngle: -.pi / 16, duration: 0.08)
        let tiltRight = SKAction.rotate(toAngle: .pi / 16, duration: 0.08)
        let center = SKAction.rotate(toAngle: 0, duration: 0.08)
        let shake = SKAction.sequence([tiltLeft, tiltRight, center])

        let drop = SKAction.moveBy(x: 0, y: -6, duration: 0.18)
        let settle = SKAction.moveBy(x: 0, y: 6, duration: 0.18)
        let moveSeq = SKAction.sequence([drop, settle])

        let group = SKAction.group([shake, moveSeq])

        rocky.position = originalPosition
        rocky.run(SKAction.repeatForever(group), withKey: "rockyLose")
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // If the game has ended, tap to restart
        if gameState == .gameOver {
            let menuScene = MenuScene(size: self.size)
            menuScene.scaleMode = self.scaleMode
            self.view?.presentScene(menuScene,
                                    transition: SKTransition.fade(withDuration: 0.5))
            return
        }
        
        // Don't allow firing until game has started
        if !isGameStarted {
            return
        }

        // Normal gameplay: fire a snowball
        let location = touch.location(in: self)
        fireSnowball(towards: location, currentTime: lastUpdateTime)
    }

    // MARK: - Physics contact

    func didBegin(_ contact: SKPhysicsContact) {
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let combo = maskA | maskB

        switch combo {
        case PhysicsCategory.snowball | PhysicsCategory.enemy:
            handleSnowballHitEnemy(contact: contact)
        case PhysicsCategory.player | PhysicsCategory.enemy:
            handleEnemyHitPlayer(contact: contact)
        case PhysicsCategory.player | PhysicsCategory.bossProjectile:
            handleBossProjectileHitPlayer(contact: contact)
        default:
            break
        }
    }

    private func handleSnowballHitEnemy(contact: SKPhysicsContact) {
        let enemyNode: SKNode?
        let snowballNode: SKNode?

        if contact.bodyA.categoryBitMask == PhysicsCategory.enemy {
            enemyNode = contact.bodyA.node
            snowballNode = contact.bodyB.node
        } else {
            enemyNode = contact.bodyB.node
            snowballNode = contact.bodyA.node
        }

        snowballNode?.removeFromParent()

        guard let enemy = enemyNode else { return }
        
        // Check if this is a boss enemy
        if enemy.name == "boss" {
            handleBossHit(enemy: enemy)
        } else {
            handleRegularEnemyHit(enemy: enemy)
        }
    }
    
    private func handleRegularEnemyHit(enemy: SKNode) {
        score += 1

        // Play throwSnow sound when snowball hits enemy
        run(SKAction.playSoundFileNamed("throwSnow", waitForCompletion: false))

        // Enemy death animation: action sequence (scale + fade + remove)
        let scaleDown = SKAction.scale(to: 0.4, duration: 0.15)
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let group = SKAction.group([scaleDown, fadeOut])
        let remove = SKAction.removeFromParent()
        let deathSequence = SKAction.sequence([group, remove])

        enemy.run(deathSequence)
    }
    
    private func handleBossHit(enemy: SKNode) {
        // Get current HP from userData
        guard let userData = enemy.userData,
              var hp = userData["hp"] as? Int else {
            // Fallback: treat as regular enemy
            handleRegularEnemyHit(enemy: enemy)
            return
        }
        
        hp -= 1
        userData["hp"] = hp
        
        // Cast to SKSpriteNode for visual effects
        guard let enemySprite = enemy as? SKSpriteNode else {
            return
        }

        // Screen shake and throwSnow sound for boss hit
        // Note: SKAction.playSoundFileNamed doesn't support volume control
        screenShake(intensity: 8, duration: 0.2)
        run(SKAction.playSoundFileNamed("throwSnow", waitForCompletion: false))

        // Flash red and shake on hit
        let flashRed = SKAction.colorize(with: SKColor.red, colorBlendFactor: 0.6, duration: 0.1)
        let restoreColor = SKAction.colorize(with: SKColor.red, colorBlendFactor: 0.0, duration: 0.15)
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -3, y: 0, duration: 0.05),
            SKAction.moveBy(x: 6, y: 0, duration: 0.05),
            SKAction.moveBy(x: -3, y: 0, duration: 0.05)
        ])
        let flashSequence = SKAction.group([flashRed, shake])
        let restoreSequence = SKAction.sequence([flashSequence, restoreColor])
        enemySprite.run(restoreSequence)
        
            // Update HP label
            if let hpLabel = enemy.childNode(withName: "hpLabel") as? SKLabelNode {
                hpLabel.text = "HP: \(hp)/\(userData["maxHP"] as? Int ?? 5)"
            } else {
                let hpLabel = SKLabelNode(fontNamed: "Menlo")
                hpLabel.name = "hpLabel"
                hpLabel.text = "HP: \(hp)/\(userData["maxHP"] as? Int ?? 5)"
                hpLabel.fontSize = 10
                hpLabel.fontColor = .yellow
                hpLabel.position = CGPoint(x: 0, y: -35)
                hpLabel.zPosition = 21
                enemy.addChild(hpLabel)
            }
        
        if hp <= 0 {
            // Boss defeated!
            score += 5 // Bonus points for defeating boss
            
            // Big explosion effect
            screenShake(intensity: 15, duration: 0.6)
            run(SKAction.playSoundFileNamed("lose", waitForCompletion: false)) // Use lose sound as explosion
            
            // Boss death animation
            let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
            let scaleDown = SKAction.scale(to: 0.0, duration: 0.4)
            let fadeOut = SKAction.fadeOut(withDuration: 0.4)
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 0.4)
            let group = SKAction.group([scaleDown, fadeOut, rotate])
            let remove = SKAction.removeFromParent()
            let deathSequence = SKAction.sequence([scaleUp, group, remove])
            
            enemySprite.run(deathSequence)
            
            // Clear boss reference
            if bossNode == enemySprite {
                bossNode = nil
            }
        }
    }
    
    private func screenShake(intensity: CGFloat, duration: TimeInterval) {
        // Shake all children nodes instead of camera (more compatible)
        let numberOfShakes = Int(duration * 10)
        var actions: [SKAction] = []
        
        for _ in 0..<numberOfShakes {
            let moveX = CGFloat.random(in: -intensity...intensity)
            let moveY = CGFloat.random(in: -intensity...intensity)
            let shake = SKAction.moveBy(x: moveX, y: moveY, duration: 0.05)
            let shakeBack = SKAction.moveBy(x: -moveX, y: -moveY, duration: 0.05)
            actions.append(SKAction.sequence([shake, shakeBack]))
        }
        
        let shakeSequence = SKAction.sequence(actions)
        
        // Apply shake to background and key nodes
        backgroundNode?.run(shakeSequence)
        rocky?.run(shakeSequence)
    }

    private func handleEnemyHitPlayer(contact: SKPhysicsContact) {
        // Play ouch sound when enemy hits player
        run(SKAction.playSoundFileNamed("ouch", waitForCompletion: false))
        triggerGameEnd(win: false, reason: "Enemy touches Rocky")
    }

    // MARK: - Game end (win / lose)

    private func triggerGameEnd(win: Bool, reason: String = "") {
        // Prevent multiple triggers
        if gameState != .playing { return }
        gameState = .gameOver

        // Stop background music
        bgmNode?.removeFromParent()
        bgmNode = nil

        // Stop enemies from moving further
        enumerateChildNodes(withName: "enemy") { node, _ in
            node.physicsBody?.velocity = .zero
        }
        enumerateChildNodes(withName: "boss") { node, _ in
            node.physicsBody?.velocity = .zero
        }
        
        // Add particle effects and play win/lose sounds
        if win {
            // Play win sound
            run(SKAction.playSoundFileNamed("win", waitForCompletion: false))
            addVictoryParticles()
            runRockyWinAnimation()
        } else {
            // Play lose sound
            run(SKAction.playSoundFileNamed("lose", waitForCompletion: false))
            addDefeatParticles()
            runRockyLoseAnimation()
        }
        
        // Transition to GameOverScene after a short delay
        // Use DispatchQueue to ensure transition happens even if scene actions are paused
        // Cancel any existing pending transition first
        pendingTransition?.cancel()
        
        let transitionWork = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Double-check game state and scene validity to prevent multiple transitions
            guard self.gameState == .gameOver,
                  let view = self.view,
                  view.scene === self else { return }
            
            let gameOverScene = GameOverScene(size: self.size)
            gameOverScene.scaleMode = self.scaleMode
            gameOverScene.win = win
            gameOverScene.score = self.score
            gameOverScene.deathReason = reason
            
            let transition = SKTransition.fade(withDuration: 1.0)
            view.presentScene(gameOverScene, transition: transition)
        }
        
        pendingTransition = transitionWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: transitionWork)
    }
    
    private func addVictoryParticles() {
        // Create particle effect for victory
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "snowball")
        emitter.particleBirthRate = 50
        emitter.numParticlesToEmit = 100
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 1.0
        emitter.particlePosition = rocky.position
        emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 30
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.5
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .alpha
        emitter.zPosition = 150
        
        addChild(emitter)
        
        // Remove emitter after particles finish
        let wait = SKAction.wait(forDuration: 3.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    private func addDefeatParticles() {
        // Create particle effect for defeat
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "snowball")
        emitter.particleBirthRate = 30
        emitter.numParticlesToEmit = 50
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5
        emitter.particlePosition = rocky.position
        emitter.particlePositionRange = CGVector(dx: 100, dy: 100)
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 20
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.7
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.1
        emitter.particleColor = SKColor.red
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .alpha
        emitter.zPosition = 150
        
        addChild(emitter)
        
        // Remove emitter after particles finish
        let wait = SKAction.wait(forDuration: 2.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // If game is over, stop updating gameplay
        if gameState != .playing {
            return
        }
        
        // Don't update gameplay until "Ready... Go!" animation completes
        if !isGameStarted {
            return
        }

        // Track survival time; reaching gameDuration means win
        elapsedTime += dt
        if elapsedTime >= gameDuration {
            triggerGameEnd(win: true)
            return
        }
        
        // Update countdown timer
        let remainingTime = max(0, gameDuration - elapsedTime)
        let secondsRemaining = Int(ceil(remainingTime))
        timerLabel.text = "\(secondsRemaining)"
        
        // Change color as time runs out
        if remainingTime <= 5.0 {
            timerLabel.fontColor = .red
            // Pulse animation for urgency
            if timerLabel.action(forKey: "urgentPulse") == nil {
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
                let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
                timerLabel.run(pulse, withKey: "urgentPulse")
            }
        } else {
            timerLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
            timerLabel.removeAction(forKey: "urgentPulse")
            timerLabel.setScale(1.0)
        }

        // Normal enemy spawn
        spawnEnemy(currentTime: currentTime)
        
        // Boss spawn (Hard mode only)
        spawnBossEnemy()
        
        // Boss projectile spawning (if boss exists)
        if bossNode != nil && bossNode?.parent != nil {
            spawnBossProjectile(currentTime: currentTime)
        }

        // Check enemies: remove off-screen and detect crossing the fail line
        // Fail only when enemies pass below the library building
        let failLineY: CGFloat = 40.0

        enumerateChildNodes(withName: "enemy") { node, _ in
            // Remove enemies that have fallen far below the screen
            if node.position.y < -40 {
                node.removeFromParent()
                return
            }

            // Check if this is an academic projectile (assignment, lab, etc.) - they don't cause game over
            let isAcademicProjectile = node.userData?["isAcademicProjectile"] as? Bool ?? false
            
            // Only regular enemies cause game over when passing fail line
            // Academic projectiles (except exam) don't attack library
            if !isAcademicProjectile && node.position.y <= failLineY {
                self.triggerGameEnd(win: false, reason: "Enemy passes below fail line")
            }
        }
        
        // Check boss enemies separately
        enumerateChildNodes(withName: "boss") { node, _ in
            // Remove boss that has fallen far below the screen
            if node.position.y < -40 {
                node.removeFromParent()
                return
            }

            // If boss reaches the fail line, player loses
            if node.position.y <= failLineY {
                self.triggerGameEnd(win: false, reason: "Boss passes below fail line")
            }
        }
        
        // Cleanup snowballs that fall off screen
        enumerateChildNodes(withName: "snowball") { node, _ in
            if node.position.y < -40 {
                node.removeFromParent()
            }
        }
        
        // Cleanup boss projectiles that fall off screen
        enumerateChildNodes(withName: "bossProjectile") { node, _ in
            if node.position.y < -40 {
                node.removeFromParent()
            }
        }

        // Parallax scrolling for background snow layers
        let farSpeed: CGFloat = -5.0
        let nearSpeed: CGFloat = -10.0

        if let far = farSnowLayer {
            far.position.y += farSpeed * CGFloat(dt)
            if far.position.y <= -size.height / 2 {
                far.position.y += size.height
            }
        }

        if let near = nearSnowLayer {
            near.position.y += nearSpeed * CGFloat(dt)
            if near.position.y <= -size.height / 2 {
                near.position.y += size.height
            }
        }
    }
}
