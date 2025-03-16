//
//  PersistentLabelView.swift
//  YOLO
//
//  Created as part of the Tono integration
//

import UIKit
import SceneKit

/// A view that displays a persistent 3D label in AR space
class PersistentLabelView: UIView {
    // The 3D node that contains the label
    var node: SCNNode?
    
    // The text to display
    var text: String? {
        didSet {
            updateLabel()
        }
    }
    
    // The position of the label in 3D space
    var position: SCNVector3? {
        didSet {
            updatePosition()
        }
    }
    
    // Initialize with frame
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    // Initialize with coder
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // Set up the view
    private func setupView() {
        // Make the view transparent
        backgroundColor = .clear
        
        // Create a node for the label
        node = SCNNode()
    }
    
    // Update the label text
    private func updateLabel() {
        guard let text = text else { return }
        
        // Create a text geometry
        let textGeometry = SCNText(string: text, extrusionDepth: 0.01)
        textGeometry.font = UIFont.systemFont(ofSize: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        // Create a node for the text
        let textNode = SCNNode(geometry: textGeometry)
        
        // Add the text node to the main node
        node?.addChildNode(textNode)
    }
    
    // Update the position of the label
    private func updatePosition() {
        guard let position = position else { return }
        
        // Set the position of the node
        node?.position = position
    }
    
    // Add the label to an AR scene
    func addToScene(_ scene: SCNScene) {
        guard let node = node else { return }
        
        // Add the node to the scene
        scene.rootNode.addChildNode(node)
    }
    
    // Remove the label from the scene
    func removeFromScene() {
        // Remove the node from its parent
        node?.removeFromParentNode()
    }
} 