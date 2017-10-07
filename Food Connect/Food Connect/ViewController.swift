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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{

    
    override func viewDidLoad() {
        super.viewDidLoad()
		
		let captureSession = AVCaptureSession()
		guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
		guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
	
		captureSession.addInput(input)
		captureSession.startRunning()
		
		let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		view.layer.addSublayer(previewLayer)
		previewLayer.frame = view.frame
		
		let feed = AVCaptureVideoDataOutput()
		feed.setSampleBufferDelegate(self, queue: DispatchQueue(label:"video"))
		captureSession.addOutput(feed)
		print("before capture")
	}
		func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
			print("after capture")
			guard let buffer : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
			
			guard let googleModel = try? VNCoreMLModel (for : Resnet50().model) else {return}
			let videorequest = VNCoreMLRequest(model: googleModel) {(finishedReq, err) in
//				print( finishedReq.results )
				guard let foodArray  = finishedReq.results as? [VNClassificationObservation] else { return }
				guard let food = foodArray.first else { return }
				print(food.identifier, food.confidence)
				
			}
			
			try? VNImageRequestHandler(cvPixelBuffer: buffer, options: [:]).perform([videorequest])
			
		}
		
		
        // Set the view's delegate

        
        // Show statistics such as fps and timing information
        
        // Create a new scene
//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
		
        // Set the scene to the view
//        sceneView.scene = scene
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        // Create a session configuration
//        let configuration = ARWorldTrackingConfiguration()
//
//        // Run the view's session
//        sceneView.session.run(configuration)
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//
//        // Pause the view's session
//        sceneView.session.pause()
//    }
//
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Release any cached data, images, etc that aren't in use.
//    }
//
//    // MARK: - ARSCNViewDelegate
//
//
//
///*
//    // Override to create and configure nodes for anchors added to the view's session.
//    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//        let node = SCNNode()
//
//        return node
//    }
//*/
//
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        // Present an error message to the user
//
//    }
//
//    func sessionWasInterrupted(_ session: ARSession) {
//        // Inform the user that the session has been interrupted, for example, by presenting an overlay
//
//    }
//
//    func sessionInterruptionEnded(_ session: ARSession) {
//        // Reset tracking and/or remove existing anchors if consistent tracking is required
//
//    }

