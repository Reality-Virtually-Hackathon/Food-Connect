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
	var lastTime = getCurrentMillis()
    
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
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y + 0.15, transform.columns.3.z)
            
            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode("Toona")
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        }
    }
    
    // MARK: ARKit Set Up
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
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
	    let ciImage = CIImage(cvPixelBuffer: pixbuff!)
		
		let image = UIImage(ciImage: ciImage)
		print("printing image \(image)")
		if ((getCurrentMillis() - lastTime) > 3000){
			lastTime = getCurrentMillis()
			imageUpload(image : image)
		}
//		text_image
        guard let googleModel = try? VNCoreMLModel (for : Resnet50().model) else { return }
        let videorequest = VNCoreMLRequest(model: googleModel) {(finishedReq, err) in
            guard let foodArray  = finishedReq.results as? [VNClassificationObservation] else { return }
            guard let food = foodArray.first else { return }
            print(food.identifier, food.confidence)
            if ( food.identifier == "water bottle" && self.tuna == false )
            {
                let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
                
                let arHitTestResults : [ARHitTestResult] = self.sceneView.hitTest(screenCentre, types: [.featurePoint])
                
                if let closestResult = arHitTestResults.first {
                    // Get Coordinates of HitTest
                    let transform : matrix_float4x4 = closestResult.worldTransform
                    let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y + 0.05, transform.columns.3.z)
                    
                    // Create 3D Text
                    let node : SCNNode = self.createNewBubbleParentNode("Toona")
                    self.sceneView.scene.rootNode.addChildNode(node)
                    node.position = worldCoord
                }
                self.tuna = true
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
	

	func imageUpload(image : UIImage){
		let requestUrlString = "https://westcentralus.api.cognitive.microsoft.com/vision/v1.0/ocr/" + "?language=unk"  + "&detectOrientation%20=true"
//		var url = URLRequest(url: URL(string: requestUrlString))!
		let urlString = URL(string: requestUrlString)
		
		
		var url = URLRequest(url: urlString!)
		print("printing image inside \(image)")
		var lastRequestTime = getCurrentMillis()
		guard let ciImage = image.ciImage, let cgImage = CIContext(options: nil).createCGImage(ciImage, from: ciImage.extent) else { return }
		url.setValue("aa5a0477fe304d84b81b46ace10c8c56", forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
		var finalImage = UIImage(cgImage: cgImage)
		print("Uploading Image")
		url.httpMethod = "POST"
		url.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
		print(UIImageJPEGRepresentation(finalImage, 0.7))
		url.httpBody = createBody(data: UIImageJPEGRepresentation(finalImage, 0.7)!,
		                        mimeType: "image/jpg",
		                        filename: "textimage.jpg")

		let task = URLSession.shared.dataTask(with: url){ data, response, error in
			if error != nil{
				print("Error -> \(error)")
				return
			}else{
				let results = try! JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]
				
				// Hand dict over
				DispatchQueue.main.async {
					print(results)
					var data = parseJson(results!)
					if(data.count > 0){
						for text in data{
							print(text + " ")
						}
					}
				}
			}
			
		}
		task.resume()
		
	}
	func createBody(data: Data,
	                mimeType: String,
	                filename: String) -> Data {
		let body = NSMutableData()
		
		//		let boundaryPrefix = "--\(boundary)\r\n"
		
//		for (key, value) in parameters {
//			//			body.appendString(boundaryPrefix)
//			body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
//			body.appendString("\(value)\r\n")
//		}
		
		//		body.appendString(boundaryPrefix)
//		body.appendString("Content- Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
//		body.appendString("Content-Type: \(mimeType)\r\n\r\n")
		body.append(data)
//		body.appendString("\r\n")
		//		body.appendString("--".appending(boundary.appending("--")))
		
		return body as Data
	}
}
func parseJson(_ dictionary: [String : AnyObject]) -> [String] {
	print("parsing Data")
	if dictionary["regions"] != nil {
			print("Not nill")
		
		var extractedText : String = ""
		
		if let regionsz = dictionary["regions"] as? [AnyObject]{
			for reigons1 in regionsz
			{
				if let reigons = reigons1 as? [String:AnyObject]
				{
					let lines = reigons["lines"] as! NSArray
					print (lines)
					for words in lines{
						if let wordsArr = words as? [String:AnyObject]{
							if let dictionaryValue = wordsArr["words"] as? [AnyObject]{
								for a in dictionaryValue {
									if let z = a as? [String : String]{
										print (z["text"]!)
										extractedText += z["text"]! + " "
									}
								}
							}
						}
					}
				}
			}
			
		}
		// Get text from words
		return [extractedText]
	}
	else
	{
		return [""];
	}
}
func getCurrentMillis()->Int64 {
	return Int64(Date().timeIntervalSince1970 * 1000)
}

	
extension NSMutableData {
	func appendString(_ string: String) {
		let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false)
		append(data!)
	}
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
	
}

