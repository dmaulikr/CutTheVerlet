//
//  GameScene.swift
//  CutTheVerlet
//
//  Created by Nick Lockwood on 07/09/2014.
//  Copyright (c) 2014 Nick Lockwood. All rights reserved.
//

import SpriteKit
import AVFoundation



class GameScene: SKScene, SKPhysicsContactDelegate {
    
    private var crocodile: SKSpriteNode!
    private var prize: SKSpriteNode!
    private var backgroundMusicPlayer: AVAudioPlayer!
    private var sliceSoundAction: SKAction!
    private var splashSoundAction: SKAction!
    private var nomNomSoundAction: SKAction!
    private var levelOver = false
    

    override func didMoveToView(view: SKView) {
        
        setUpPhysics()
        setUpScenery()
        setUpPrize()
        setUpRopes()
        setUpCrocodile()
        
        setUpAudio()
    }
    
    //MARK: Level setup
    
    private func setUpPhysics() {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVectorMake(0.0,-9.8)
        physicsWorld.speed = 1.0

    }
    
    private func setUpScenery() {
        let background = SKSpriteNode(imageNamed: BackgroundImage)
        background.anchorPoint = CGPointMake(0, 1)
        background.position = CGPointMake(0, size.height)
        background.zPosition = Layer.Background
        background.size = CGSize(width: self.view!.bounds.size.width, height:self.view!.bounds.size.height)
        addChild(background)
        
        let water = SKSpriteNode(imageNamed: WaterImage)
        water.anchorPoint = CGPointMake(0, 0)
        water.position = CGPointMake(0, size.height - background.size.height)
        water.zPosition = Layer.Foreground
        water.size = CGSize(width: self.view!.bounds.size.width, height: self.view!.bounds.size.height * 0.2139)
        
        addChild(water)

    }
    
    private func setUpPrize() {
        prize = SKSpriteNode(imageNamed: PrizeImage)
        prize.position = CGPointMake(size.width * 0.50, size.height * 0.7)
        prize.zPosition = Layer.Prize
        
        prize.physicsBody = SKPhysicsBody(texture: SKTexture(imageNamed: PrizeImage), size: prize.size)
        prize.physicsBody?.categoryBitMask = Category.Prize
        prize.physicsBody?.collisionBitMask = 0
        prize.physicsBody?.contactTestBitMask = Category.Rope
        prize.physicsBody?.dynamic = PrizeIsDynamicsOnStart
        
        addChild(prize)

    }
    
    //MARK: Rope methods
    
    private func setUpRopes() {
        // load rope data
        let dataFile = NSBundle.mainBundle().pathForResource(RopeDataFile, ofType: nil)
        let ropes = NSArray(contentsOfFile: dataFile!) as! [NSDictionary]
        
        // add ropes
        for i in 0..<ropes.count {
            
            // create rope
            let ropeData = ropes[i]
            let length = Int(ropeData["length"] as! NSNumber) * Int(UIScreen.mainScreen().scale)
            let relAnchorPoint = CGPointFromString(ropeData["relAnchorPoint"] as! String)
            let anchorPoint = CGPoint(x: relAnchorPoint.x * self.view!.bounds.size.width,
                y: relAnchorPoint.y * self.view!.bounds.size.height)
            let rope = RopeNode(length: length, anchorPoint: anchorPoint, name: "\(i)")
            
            // add to scene
            rope.addToScene(self)
            
            // connect the other end of the rope to the prize
            rope.attachToPrize(prize)
        }

    }
    
    //MARK: Croc methods
    
    private func setUpCrocodile() {
        
        crocodile = SKSpriteNode(imageNamed: CrocMouthClosedImage)
        crocodile.position = CGPointMake(size.width * 0.75, size.height * 0.312)
        crocodile.zPosition = Layer.Crocodile
        
        crocodile.physicsBody = SKPhysicsBody(texture: SKTexture(imageNamed: CrocMaskImage), size: crocodile.size)
        crocodile.physicsBody?.categoryBitMask = Category.Crocodile
        crocodile.physicsBody?.collisionBitMask = 0
        crocodile.physicsBody?.contactTestBitMask = Category.Prize
        crocodile.physicsBody?.dynamic = false
        
        addChild(crocodile)
        
        animateCrocodile()
    }
    
    private func animateCrocodile() {
        let frames = [
            SKTexture(imageNamed: CrocMouthClosedImage),
            SKTexture(imageNamed: CrocMouthOpenImage),
        ]
        
        let duration = 2.0 + drand48() * 2.0
        
        let move = SKAction.animateWithTextures(frames, timePerFrame:1.0)
        let wait = SKAction.waitForDuration(duration)
        let rest = SKAction.setTexture(frames[0])
        let sequence = SKAction.sequence([wait, move, wait, rest])
        
        crocodile.runAction(SKAction.repeatActionForever(sequence))


    }
    
    private func runNomNomAnimationWithDelay(delay: NSTimeInterval) {
        crocodile.removeAllActions()
        
        let openMouth = SKAction.setTexture(SKTexture(imageNamed: CrocMouthOpenImage))
        let wait = SKAction.waitForDuration(delay)
        let closeMouth = SKAction.setTexture(SKTexture(imageNamed: CrocMouthClosedImage))
        let sequence = SKAction.sequence([openMouth, wait, closeMouth])
        
        crocodile.runAction(sequence)
        runAction(nomNomSoundAction)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        runNomNomAnimationWithDelay(1)
        runAction(sliceSoundAction)
    }
    
    //MARK: Touch handling
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            

            let startPoint = touch.locationInNode(self)
            let endPoint = touch.previousLocationInNode(self)
            
            // check if rope cut
            scene?.physicsWorld.enumerateBodiesAlongRayStart(startPoint, end: endPoint, usingBlock: { (body, point, normal, stop) -> Void in
                
                self.checkIfRopeCutWithBody(body)
            })
            
            // produce some nice particles
            let emitter = SKEmitterNode(fileNamed: "Particle.sks")
            emitter!.position = startPoint
            emitter!.zPosition = Layer.Rope
            addChild(emitter!)
        }
        
    }
    
    //MARK: Game logic
    
    override func update(currentTime: CFTimeInterval) {
        if levelOver {
            return
        }
        if prize.position.y <= 0 {
            let transitions = [
                SKTransition.doorsOpenHorizontalWithDuration(1.0),
                SKTransition.doorsOpenVerticalWithDuration(1.0),
                SKTransition.doorsCloseHorizontalWithDuration(1.0),
                SKTransition.doorsCloseVerticalWithDuration(1.0),
                SKTransition.flipHorizontalWithDuration(1.0),
                SKTransition.flipVerticalWithDuration(1.0),
                SKTransition.moveInWithDirection(.Left, duration:1.0),
                SKTransition.pushWithDirection(.Right, duration:1.0),
                SKTransition.revealWithDirection(.Down, duration:1.0),
                SKTransition.crossFadeWithDuration(1.0),
                SKTransition.fadeWithColor(UIColor.darkGrayColor(), duration:1.0),
                SKTransition.fadeWithDuration(1.0),
            ]
            
            // transition to next level
            let randomIndex = arc4random_uniform(UInt32(transitions.count))
            switchToNewGameWithTransition(transitions[Int(randomIndex)])
            runAction(splashSoundAction)
            levelOver = true
        }

    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        if levelOver {
            return
        }
        if (contact.bodyA.node == crocodile && contact.bodyB.node == prize) ||
            (contact.bodyA.node == prize && contact.bodyB.node == crocodile) {
                
                // fade the pineapple away
                let shrink = SKAction.scaleTo(0, duration: 0.08)
                let removeNode = SKAction.removeFromParent()
                let sequence = SKAction.sequence([shrink, removeNode])
                prize.runAction(sequence)
                
                runNomNomAnimationWithDelay(1)
                levelOver = true
        }

    }
    
    private func checkIfRopeCutWithBody(body: SKPhysicsBody) {
        let node = body.node!
        
        // if it has a name it must be a rope node
        if let name = node.name {
            
            //enable prize dynamics
            prize.physicsBody?.dynamic = true
            
            // cut the rope
            node.removeFromParent()
            
            // fade out all nodes matching name
            self.enumerateChildNodesWithName(name, usingBlock: { (node, stop) in
                
                let fadeAway = SKAction.fadeOutWithDuration(0.25)
                let removeNode = SKAction.removeFromParent()
                let sequence = SKAction.sequence([fadeAway, removeNode])
                
                node.runAction(sequence)
            })
        }
        
    }
    
    private func switchToNewGameWithTransition(transition: SKTransition) {
        let delay = SKAction.waitForDuration(1)
        let transition = SKAction.runBlock({
            let scene = GameScene(size: self.size)
            self.view?.presentScene(scene, transition: transition)
        })
        
        runAction(SKAction.sequence([delay, transition]))
        
    }
    
    //MARK: Audio
    
    private func setUpAudio() {
        if (backgroundMusicPlayer == nil) {
            let backgroundMusicURL = NSBundle.mainBundle().URLForResource(BackgroundMusicSound, withExtension: nil)
            do {
                try backgroundMusicPlayer = AVAudioPlayer(contentsOfURL: backgroundMusicURL!)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
                try session.overrideOutputAudioPort(AVAudioSessionPortOverride.Speaker)
            }catch {
                
            }
            backgroundMusicPlayer.numberOfLoops = -1
            if (!backgroundMusicPlayer.playing) {
                backgroundMusicPlayer.play()
            }
            sliceSoundAction = SKAction.playSoundFileNamed(SliceSound, waitForCompletion: false)
            splashSoundAction = SKAction.playSoundFileNamed(SplashSound, waitForCompletion: false)
            nomNomSoundAction = SKAction.playSoundFileNamed(NomNomSound, waitForCompletion: false)

        }

        
    }
}
