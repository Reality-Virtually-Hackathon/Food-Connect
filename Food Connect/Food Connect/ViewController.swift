//
//  ViewController.swift
//  Food Connect
//
//  Created by Arjun Madgavkar on 10/7/17.
//  Copyright © 2017 NYC Labs LLC. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreML
import Vision
import AVKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, ARSCNViewDelegate {
    // Need to use SceneView to show the AR content
    @IBOutlet var sceneView: ARSCNView!
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    
    // Check whether AR has been added
    var tuna = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
	}
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Interaction
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Get Screen Centre
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Create 3D Text
//            let node : SCNNode = createNewBubbleParentNode("Toona")
//            sceneView.scene.rootNode.addChildNode(node)
//            node.position = worldCoord
            
            // Create a new scene from .scn file
            let shipScene = SCNScene(named: "art.scnassets/ship.scn")
            // Create a node from the .scn file
            let shipNode = shipScene?.rootNode.childNode(withName: "ship", recursively: true)
            shipNode?.position = worldCoord
            sceneView.scene.rootNode.addChildNode(shipNode!)
        }
        
    }
    
    func createBall(position: SCNVector3) {
        
    }
    
    // MARK: ARKit Set Up
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        
        // Makes the text always face the camera!
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
//        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        /*
         This is doing something that I do not understand. But it is important. Makes it so the text doesn't go super high
         */
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2 )
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        
        return bubbleNodeParent
    }

    // MARK: CoreML + Vision
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
        
    }
    
    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        
        guard let googleModel = try? VNCoreMLModel (for : Resnet50().model) else { return }
        let videorequest = VNCoreMLRequest(model: googleModel) {(finishedReq, err) in
            guard let foodArray  = finishedReq.results as? [VNClassificationObservation] else { return }
            guard let food = foodArray.first else { return }
            print(food.identifier, food.confidence)
            // if identifier is a water bottle and we haven't added the AR yet
            if ( food.identifier == "water bottle" && self.tuna == false )
            {
                // get the center of the screen
                let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
                
                // use the center of the screen and see the results that come from that location in the world
                let arHitTestResults : [ARHitTestResult] = self.sceneView.hitTest(screenCentre, types: [.featurePoint])
                
                if let closestResult = arHitTestResults.first {
                    let transform : matrix_float4x4 = closestResult.worldTransform
                    let worldCoord : SCNVector3 = SCNVector3Make((transform.columns.3.x), (transform.columns.3.y), transform.columns.3.z)
                    /*
                    // Object 1
                    let transform : matrix_float4x4 = closestResult.worldTransform
                    let worldCoord1 : SCNVector3 = SCNVector3Make((transform.columns.3.x), (transform.columns.3.y), transform.columns.3.z)
                    // Object 2
                    let worldCoord2 : SCNVector3 = SCNVector3Make(transform.columns.3.x, (transform.columns.3.y), transform.columns.3.z)
                    // Object 3
                    let worldCoord3 : SCNVector3 = SCNVector3Make((transform.columns.3.x), (transform.columns.3.y), transform.columns.3.z)
                    
                    // Text 1
                    let node1 : SCNNode = self.createNewBubbleParentNode("ONE")
                    self.sceneView.scene.rootNode.addChildNode(node1)
                    node1.position = worldCoord1
                    // Text 2
                    let node2 : SCNNode = self.createNewBubbleParentNode("TWO")
                    self.sceneView.scene.rootNode.addChildNode(node2)
                    node2.position = worldCoord2
                    // Text 3
                    let node3 : SCNNode = self.createNewBubbleParentNode("THREE")
                    self.sceneView.scene.rootNode.addChildNode(node3)
                    node3.position = worldCoord3
                    */
                    
                    
                    // Create a new scene from .scn file
//                    let shipScene = SCNScene(named: "art.scnassets/ship.scn")
//                    // Create a node from the .scn file
//                    let shipNode = shipScene?.rootNode.childNode(withName: "ship", recursively: true)
//                    shipNode?.position = worldCoord
//                    self.sceneView.scene.rootNode.addChildNode(shipNode!)
 
                    
                    // Create a new scene from .scn file
                    var frameScene : SCNScene!
                    frameScene? = SCNScene(named: "SceneKit SceneX.scn")!
                    if frameScene != nil {
                        // Create a node from the .scn file
                        let frameNode = frameScene.rootNode.childNode(withName: "gt", recursively: true)
                        frameNode?.position = worldCoord
                        self.sceneView.scene.rootNode.addChildNode(frameNode!)
                    }
                    else
                    {
                        print("scene is nil")
                    }
                    
//                    var node = SCNNode()
//                    let scene = SCNScene(named: "grade_F.dae")
//                    var nodeArray = scene!.rootNode.childNodes
//
//                    for childNode in nodeArray {
//                        node.addChildNode(childNode as SCNNode)
//                    }
//                    node.position = worldCoord
//                    self.sceneView.scene.rootNode.addChildNode(node)

//                    let tableScene = SCNScene(named: "art.scnassets/gradeJoined.dae")
//                    let tableNode = tableScene?.rootNode.childNode(withName: "x", recursively: true)
//                    tableNode?.position = worldCoord
//                    self.sceneView.scene.rootNode.addChildNode(tableNode!)
 
                    self.tuna = true
                }
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixbuff!, options: [:]).perform([videorequest])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading

        // Run the view's session
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate



/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()

        return node
    }
*/

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user

    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required

    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

