//
//  GameViewController.swift
//  Final Season Defense
//
//  Created by Yuliang Liu on 11/18/25.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as? SKView {
            // Create scene with logical resolution 180×320
            let sceneSize = CGSize(width: 180, height: 320)
            // Start with MenuScene
            let scene = MenuScene(size: sceneSize)

            // Portrait orientation, logical size is 180 width × 320 height
            scene.scaleMode = .aspectFit
            
            view.presentScene(scene)

            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
