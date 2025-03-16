// Fixed duplicate function declaration - AR Labels Fix
//  Ultralytics YOLO 🚀 - AGPL-3.0 License
//
//  Main View Controller for Ultralytics YOLO App
//  This file is part of the Ultralytics YOLO app, enabling real-time object detection using YOLO11 models on iOS devices.
//  Licensed under AGPL-3.0. For commercial use, refer to Ultralytics licensing: https://ultralytics.com/license
//  Access the source code: https://github.com/ultralytics/yolo-ios-app
//
//  This ViewController manages the app's main screen, handling video capture, model selection, detection visualization,
//  and user interactions. It sets up and controls the video preview layer, handles model switching via a segmented control,
//  manages UI elements like sliders for confidence and IoU thresholds, and displays detection results on the video feed.
//  It leverages CoreML, Vision, and AVFoundation frameworks to perform real-time object detection and to interface with
//  the device's camera.

import AVFoundation
import CoreML
import CoreMedia
import UIKit
import Vision
import SwiftUI
import CoreData
import SceneKit
import ARKit  // Add this import for ARWorldTrackingConfiguration

var mlModel = try! yolo11n(configuration: mlmodelConfig).model
var mlmodelConfig: MLModelConfiguration = {
  let config = MLModelConfiguration()

  if #available(iOS 17.0, *) {
    config.setValue(1, forKey: "experimentalMLE5EngineUsage")
  }

  return config
}()

/// The main view controller for the YOLO app, responsible for camera setup, model selection, and detection visualization.
class ViewController: UIViewController {
  @IBOutlet var videoPreview: UIView!
  @IBOutlet var View0: UIView!
  @IBOutlet var segmentedControl: UISegmentedControl!
  @IBOutlet var playButtonOutlet: UIBarButtonItem!
  @IBOutlet var pauseButtonOutlet: UIBarButtonItem!
  @IBOutlet var slider: UISlider!
  @IBOutlet var sliderConf: UISlider!
  @IBOutlet weak var sliderConfLandScape: UISlider!
  @IBOutlet var sliderIoU: UISlider!
  @IBOutlet weak var sliderIoULandScape: UISlider!
  @IBOutlet weak var labelName: UILabel!
  @IBOutlet weak var labelFPS: UILabel!
  @IBOutlet weak var labelZoom: UILabel!
  @IBOutlet weak var labelVersion: UILabel!
  @IBOutlet weak var labelSlider: UILabel!
  @IBOutlet weak var labelSliderConf: UILabel!
  @IBOutlet weak var labelSliderConfLandScape: UILabel!
  @IBOutlet weak var labelSliderIoU: UILabel!
  @IBOutlet weak var labelSliderIoULandScape: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var focus: UIImageView!
  @IBOutlet weak var toolBar: UIToolbar!
  // Debug label - created programmatically
  var debugLabel: UILabel?
  
  // Translation-related properties
  private var translationManager = TranslationManager.shared
  private var speechManager = SpeechManager()
  internal var currentDetection: (english: String, chinese: String, pinyin: String)?
  private var detectionPopupHostingController: UIHostingController<DetectionPopupView>?
  private var persistenceController = PersistenceController.shared
  
  // Core Data context
  private var managedObjectContext: NSManagedObjectContext {
    return persistenceController.container.viewContext
  }

  let selection = UISelectionFeedbackGenerator()
  var detector = try! VNCoreMLModel(for: mlModel)
  var session: AVCaptureSession!
  var videoCapture: VideoCapture!
  var currentBuffer: CVPixelBuffer?
  var framesDone = 0
  var t0 = 0.0  // inference start
  var t1 = 0.0  // inference dt
  var t2 = 0.0  // inference dt smoothed
  var t3 = CACurrentMediaTime()  // FPS start
  var t4 = 0.0  // FPS dt smoothed
  // var cameraOutput: AVCapturePhotoOutput!
  var longSide: CGFloat = 3
  var shortSide: CGFloat = 4
  var frameSizeCaptured = false

  // Developer mode
  let developerMode = UserDefaults.standard.bool(forKey: "developer_mode")  // developer mode selected in settings
  let save_detections = false  // write every detection to detections.txt
  let save_frames = false  // write every frame to frames.txt

  lazy var visionRequest: VNCoreMLRequest = {
    let request = VNCoreMLRequest(
      model: detector,
      completionHandler: {
        [weak self] request, error in
        self?.processObservations(for: request, error: error)
      })
    // NOTE: BoundingBoxView object scaling depends on request.imageCropAndScaleOption https://developer.apple.com/documentation/vision/vnimagecropandscaleoption
    request.imageCropAndScaleOption = VNImageCropAndScaleOption.scaleFill  // .scaleFit, .scaleFill, .centerCrop
    return request
  }()

  // MARK: - Properties
  
  // AR Scene Manager for 3D text tags
  var arSceneManager: ARSceneManager!
  
  // UI elements
  private var clearARButton: UIButton?
  
  // Track the last detected class to avoid duplicate logging
  private var lastDetectedClass: String?
  
  // Track the last time we synchronized AR labels with bounding boxes
  private var lastARSyncTime: CFTimeInterval = 0

  // Add property to store tagged detections
  private var taggedDetections: [(english: String, chinese: String, pinyin: String, worldPosition: simd_float4x4)] = []
  
  // Track hidden bounding boxes by class name
  private var hiddenBoxes: Set<String> = []

  // Add isPaused property
  var isPaused: Bool = false
  
  // Add captureSession property
  var captureSession: AVCaptureSession {
    return videoCapture.captureSession
  }

  // Add this property to the class
  // Set to store class names of objects with AR labels
  var hiddenObjectLabels = Set<String>()

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    
    print("🚀 viewDidLoad called")
    
    // Set initial UI state
    slider.value = 30
    setLabels()
    setUpBoundingBoxViews()
    setUpOrientationChangeNotification()
    
    // Create debug label programmatically
    let label = UILabel(frame: CGRect(x: 10, y: 50, width: view.bounds.width - 20, height: 150))
    label.numberOfLines = 0
    label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    label.textColor = UIColor.white
    label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    label.textAlignment = .left
    label.layer.cornerRadius = 8
    label.layer.masksToBounds = true
    label.isHidden = false
    label.text = "Debug Info Loading..."
    self.debugLabel = label
    
    // Initialize AR Scene Manager
    arSceneManager = ARSceneManager(viewController: self)
    print("✅ ARSceneManager initialized")
    
    // Set up AR view with priority - CRITICAL CHANGE: Make it a direct subview of the main view
    arSceneManager.sceneView.frame = view.bounds
    arSceneManager.sceneView.backgroundColor = UIColor.clear
    arSceneManager.sceneView.isOpaque = false
    arSceneManager.sceneView.autoenablesDefaultLighting = true
    
    // Disable debug options to remove any ghost frames
    arSceneManager.sceneView.debugOptions = []
    
    // IMPORTANT: Video view setup
    // Make video preview transparent except for content
    videoPreview.backgroundColor = UIColor.clear
    
    // Setup touch handling
    setupTransparentInteraction()
    
    // Set the toolbar reference if videoPreview is a PassThroughView
    if let passThroughView = videoPreview as? PassThroughView {
        passThroughView.toolbar = toolBar
    }
    
    // Add clear AR labels button
    addClearARButton()
    
    // Add test label button
    addTestLabelButton()
    
    // CRITICAL CHANGE: View hierarchy and initialization order
    // First add AR view to view hierarchy
    view.addSubview(arSceneManager.sceneView)
    print("✅ AR SceneView added to view hierarchy")
    
    // Then add video preview above AR view
    view.addSubview(videoPreview)
    print("✅ Video preview added above AR view")
    
    // Make sure debug label is above everything
    if let debugLabel = self.debugLabel {
        view.addSubview(debugLabel)
        debugLabel.layer.zPosition = 1000
    }
    
    // Then make sure toolbar is at the top
    view.bringSubviewToFront(toolBar)
    
    // Start AR session first to ensure it's ready
    arSceneManager.setupARSession()
    print("✅ AR session started")
    
    // Then start video capture
    startVideo()
    print("✅ Video capture started")
    
    // Add a tap gesture recognizer to the video preview view
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoPreviewTapped(_:)))
    tapGesture.cancelsTouchesInView = false // Allow touches to pass through to views underneath
    videoPreview.addGestureRecognizer(tapGesture)
    videoPreview.isUserInteractionEnabled = true
    print("✅ Tap gesture added to video preview")
    
    // Update debug information
    updateARDebugInfo()
    
    // Force video preview to be semi-transparent to see AR content
    videoPreview.alpha = 0.7
    
    // Schedule a regular update of AR debug info
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        self?.updateARDebugInfo()
        self?.ensureBoundingBoxesAreTappable()
    }
    
    // Add test label after a short delay to ensure AR session is ready
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.arSceneManager.addTestLabel()
        self.arSceneManager.configureARViewForTextOnly()
        self.updateARDebugInfo()
    }
    
    print("✅ viewDidLoad complete")
  }
  
  // Add a simple 2D test label overlay that will be visible regardless of AR rendering
  func addTestLabelOverlay() {
      // Create a container view with a semi-transparent background
      let containerView = UIView(frame: CGRect(x: 20, y: 100, width: 200, height: 120))
      containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
      containerView.layer.cornerRadius = 10
      containerView.tag = 12345 // Tag for easy reference
      
      // Create Chinese label
      let chineseLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 40))
      chineseLabel.text = "测试标签"
      chineseLabel.textColor = UIColor.white
      chineseLabel.font = UIFont.boldSystemFont(ofSize: 24)
      chineseLabel.textAlignment = .center
      
      // Create Pinyin label
      let pinyinLabel = UILabel(frame: CGRect(x: 10, y: 50, width: 180, height: 30))
      pinyinLabel.text = "cèshì biāoqiān"
      pinyinLabel.textColor = UIColor.yellow
      pinyinLabel.font = UIFont.systemFont(ofSize: 18)
      pinyinLabel.textAlignment = .center
      
      // Create English label
      let englishLabel = UILabel(frame: CGRect(x: 10, y: 80, width: 180, height: 30))
      englishLabel.text = "TEST LABEL"
      englishLabel.textColor = UIColor.cyan
      englishLabel.font = UIFont.systemFont(ofSize: 16)
      englishLabel.textAlignment = .center
      
      // Add labels to container
      containerView.addSubview(chineseLabel)
      containerView.addSubview(pinyinLabel)
      containerView.addSubview(englishLabel)
      
      // Add container to main view
      view.addSubview(containerView)
      
      // Make sure it's in front of other views
      view.bringSubviewToFront(containerView)
      
      // Add a tap gesture to play pronunciation
      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(testLabelTapped))
      containerView.addGestureRecognizer(tapGesture)
      containerView.isUserInteractionEnabled = true
      
      // Add a subtle animation to make it more noticeable
      UIView.animate(withDuration: 0.5, delay: 0, options: [.autoreverse, .repeat], animations: {
          containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
      }, completion: nil)
      
      print("2D test label overlay added")
  }
  
  // Handle tap on the test label
  @objc func testLabelTapped() {
      print("Test label tapped")
      
      // Play pronunciation
      arSceneManager.playPronunciation(for: "测试标签", pinyin: "cèshì biāoqiān")
      
      // Provide haptic feedback
      selection.selectionChanged()
      
      // Show a toast message
      showToast(message: "Test label tapped - playing pronunciation")
  }
  
  // Add a method to start a timer that periodically checks and refreshes the test label
  func startTestLabelRefreshTimer() {
      // Create a timer that fires every 3 seconds
      Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
          guard let self = self else { return }
          
          // Check if there's a test label in the scene
          let hasTestLabel = self.arSceneManager.placedNodes.contains { node in
              return node.name?.contains("TEST_LABEL") ?? false
          }
          
          // If no test label is found, add one
          if !hasTestLabel {
              print("Test label not found, adding a new one")
              self.arSceneManager.addTestLabel()
          } else {
              // If a test label exists, ensure it's visible
              for node in self.arSceneManager.placedNodes where node.name?.contains("TEST_LABEL") ?? false {
                  // Make sure the node is fully opaque
                  node.opacity = 1.0
                  node.renderingOrder = 3000 // Even higher priority
                  
                  // Apply to all children
                  for childNode in node.childNodes {
                      childNode.opacity = 1.0
                      childNode.renderingOrder = 3000
                      
                      // Make materials extra bright
                      if let geometry = childNode.geometry {
                          for material in geometry.materials {
                              material.transparency = 0.0 // Fully opaque
                              material.lightingModel = .constant // No lighting effects
                              
                              // Increase emission intensity for better visibility
                              if let _ = material.emission.contents {
                                  material.emission.intensity = 5.0 // Extremely bright emission
                              }
                          }
                      }
                  }
                  
                  // Reposition the test label in front of the camera if possible
                  if let frame = self.arSceneManager.sceneView.session.currentFrame {
                      // Get the camera position and orientation
                      let cameraTransform = frame.camera.transform
                      let positionColumn = cameraTransform.columns.3
                      let cameraPosition = SCNVector3(positionColumn.x, positionColumn.y, positionColumn.z)
                      let cameraDirection = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
                      
                      // Position the test label 0.5 meters in front of the camera
                      let position = SCNVector3(
                          cameraPosition.x + cameraDirection.x * 0.5,
                          cameraPosition.y + cameraDirection.y * 0.5,
                          cameraPosition.z + cameraDirection.z * 0.5
                      )
                      
                      // Animate the position change
                      SCNTransaction.begin()
                      SCNTransaction.animationDuration = 0.5
                      node.position = position
                      SCNTransaction.commit()
                      
                      print("Refreshed test label position to: \(position)")
                  }
              }
          }
          
          // Make sure video preview is semi-transparent
          if let previewLayer = self.videoCapture.previewLayer {
              previewLayer.opacity = 0.7
          }
          
          // Ensure AR view is properly positioned
          self.arSceneManager.sceneView.frame = self.view.bounds
          
          // Log the current state
          print("Test label refresh check completed")
      }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Start AR session
    arSceneManager.setupARSession()
    
    // Make sure bounding box views are above AR content
    for boxView in boundingBoxViews {
      videoPreview.bringSubviewToFront(boxView)
    }
    
    // Resume video capture if it was running before
    if !pauseButtonOutlet.isEnabled {
      videoCapture.start()
      playButtonOutlet.isEnabled = false
      pauseButtonOutlet.isEnabled = true
    }
    
    // Show a toast message to indicate the integrated mode is active
    showToast(message: "Tap on objects to see translations")
    
    // Force the test label to be visible after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.forceTestLabelVisible()
        
        // Make video preview semi-transparent to ensure AR content is visible
        if let previewLayer = self.videoCapture.previewLayer {
            previewLayer.opacity = 0.7
        }
        
        // Log view hierarchy for debugging
        print("View hierarchy after viewWillAppear:")
        print("Main view has \(self.view.subviews.count) subviews")
        print("AR view is at index: \(self.view.subviews.firstIndex(of: self.arSceneManager.sceneView) ?? -1)")
        print("Video preview is at index: \(self.view.subviews.firstIndex(of: self.videoPreview) ?? -1)")
    }
    
    // Ensure 2D test label is visible
    if let existingLabel = view.viewWithTag(12345) {
        // If label exists, bring it to front
        view.bringSubviewToFront(existingLabel)
    } else {
        // If label doesn't exist, add it
        addTestLabelOverlay()
    }
    
    // Ensure simple SCNView is visible
    if let existingScnView = view.viewWithTag(54321) {
        // If SCNView exists, bring it to front
        view.bringSubviewToFront(existingScnView)
    } else {
        // If SCNView doesn't exist, add it
        addSimpleSceneView()
    }
    
    // Make sure toolbar is in front of all views
    view.bringSubviewToFront(toolBar)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause AR session
    arSceneManager.pauseARSession()
    
    // Pause video capture
    videoCapture?.stop()
  }

  override func viewWillTransition(
    to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)

    if size.width > size.height {
      labelSliderConf.isHidden = true
      sliderConf.isHidden = true
      labelSliderIoU.isHidden = true
      sliderIoU.isHidden = true
      toolBar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
      toolBar.setShadowImage(UIImage(), forToolbarPosition: .any)

      labelSliderConfLandScape.isHidden = false
      sliderConfLandScape.isHidden = false
      labelSliderIoULandScape.isHidden = false
      sliderIoULandScape.isHidden = false

    } else {
      labelSliderConf.isHidden = false
      sliderConf.isHidden = false
      labelSliderIoU.isHidden = false
      sliderIoU.isHidden = false
      toolBar.setBackgroundImage(nil, forToolbarPosition: .any, barMetrics: .default)
      toolBar.setShadowImage(nil, forToolbarPosition: .any)

      labelSliderConfLandScape.isHidden = true
      sliderConfLandScape.isHidden = true
      labelSliderIoULandScape.isHidden = true
      sliderIoULandScape.isHidden = true
    }
    self.videoCapture.previewLayer?.frame = CGRect(
      x: 0, y: 0, width: size.width, height: size.height)

  }

  private func setUpOrientationChangeNotification() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(orientationDidChange),
      name: UIDevice.orientationDidChangeNotification, object: nil)
  }

  @objc func orientationDidChange() {
    videoCapture.updateVideoOrientation()
    //      frameSizeCaptured = false
  }

  @IBAction func vibrate(_ sender: Any) {
    selection.selectionChanged()
  }

  @IBAction func indexChanged(_ sender: Any) {
    selection.selectionChanged()
    activityIndicator.startAnimating()

    /// Switch model
    switch segmentedControl.selectedSegmentIndex {
    case 0:
      self.labelName.text = "YOLO11n"
      mlModel = try! yolo11n(configuration: .init()).model
    case 1:
      self.labelName.text = "YOLO11s"
      mlModel = try! yolo11s(configuration: .init()).model
    case 2:
      self.labelName.text = "YOLO11m"
      mlModel = try! yolo11m(configuration: .init()).model
    case 3:
      self.labelName.text = "YOLO11l"
      mlModel = try! yolo11l(configuration: .init()).model
    case 4:
      self.labelName.text = "YOLO11x"
      mlModel = try! yolo11x(configuration: .init()).model
    default:
      break
    }
    setModel()
    setUpBoundingBoxViews()
    activityIndicator.stopAnimating()
  }

  func setModel() {

    /// VNCoreMLModel
    detector = try! VNCoreMLModel(for: mlModel)
    detector.featureProvider = ThresholdProvider()

    /// VNCoreMLRequest
    let request = VNCoreMLRequest(
      model: detector,
      completionHandler: { [weak self] request, error in
        self?.processObservations(for: request, error: error)
      })
    request.imageCropAndScaleOption = .scaleFill  // .scaleFit, .scaleFill, .centerCrop
    visionRequest = request
    t2 = 0.0  // inference dt smoothed
    t3 = CACurrentMediaTime()  // FPS start
    t4 = 0.0  // FPS dt smoothed
  }

  /// Update thresholds from slider values
  @IBAction func sliderChanged(_ sender: Any) {
    let conf = Double(round(100 * sliderConf.value)) / 100
    let iou = Double(round(100 * sliderIoU.value)) / 100
    self.labelSliderConf.text = String(conf) + " Confidence Threshold"
    self.labelSliderIoU.text = String(iou) + " IoU Threshold"
    detector.featureProvider = ThresholdProvider(iouThreshold: iou, confidenceThreshold: conf)
  }

  @IBAction func takePhoto(_ sender: Any?) {
    let t0 = DispatchTime.now().uptimeNanoseconds

    // 1. captureSession and cameraOutput
    // session = videoCapture.captureSession  // session = AVCaptureSession()
    // session.sessionPreset = AVCaptureSession.Preset.photo
    // cameraOutput = AVCapturePhotoOutput()
    // cameraOutput.isHighResolutionCaptureEnabled = true
    // cameraOutput.isDualCameraDualPhotoDeliveryEnabled = true
    // print("1 Done: ", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1E9)

    // 2. Settings
    let settings = AVCapturePhotoSettings()
    // settings.flashMode = .off
    // settings.isHighResolutionPhotoEnabled = cameraOutput.isHighResolutionCaptureEnabled
    // settings.isDualCameraDualPhotoDeliveryEnabled = self.videoCapture.cameraOutput.isDualCameraDualPhotoDeliveryEnabled

    // 3. Capture Photo
    usleep(20_000)  // short 10 ms delay to allow camera to focus
    self.videoCapture.cameraOutput.capturePhoto(
      with: settings, delegate: self as AVCapturePhotoCaptureDelegate)
    print("3 Done: ", Double(DispatchTime.now().uptimeNanoseconds - t0) / 1E9)
  }

  @IBAction func logoButton(_ sender: Any) {
    selection.selectionChanged()
    if let link = URL(string: "https://www.ultralytics.com") {
      UIApplication.shared.open(link)
    }
  }

  func setLabels() {
    self.labelName.text = "YOLO11m"
    self.labelVersion.text = "Version " + UserDefaults.standard.string(forKey: "app_version")!
  }

  @IBAction func playButton(_ sender: UIBarButtonItem) {
    // User pressed play button - start video
    if playButtonOutlet.isEnabled {
        print("Play button pressed - starting video")
        
        // Configure video capture first
        if videoCapture == nil {
            // If video capture is nil, initialize it
            startVideo()
        } else {
            // If video capture exists, just start it
            videoCapture.start()
        }
        
        // Update button states
    playButtonOutlet.isEnabled = false
    pauseButtonOutlet.isEnabled = true
        
        // Update button title
        sender.title = "Pause"
        
        // CRITICAL CHANGE: Keep AR session running and ensure labels are visible
        // First verify AR session is running
        if arSceneManager.sceneView.session.configuration == nil {
            print("AR session not running, restarting...")
            arSceneManager.resumeARSession()
        }
        
        // Force all AR nodes to be visible with enhanced properties
        for node in arSceneManager.placedNodes {
            node.opacity = 1.0
            node.renderingOrder = 3000 // Very high rendering priority
            
            // Apply to all children
            for childNode in node.childNodes {
                childNode.opacity = 1.0
                childNode.renderingOrder = 3000
                
                // Make materials extremely bright for visibility
                if let geometry = childNode.geometry {
                    for material in geometry.materials {
                        material.transparency = 0.0 // Fully opaque
                        material.lightingModel = .constant // No lighting effects
                        
                        // Increase emission intensity for better visibility
                        if let emission = material.emission.contents as? UIColor {
                            material.emission.intensity = 5.0 // Very bright emission
                        }
                    }
                }
            }
        }
        
        // Ensure AR view is properly configured for text visibility
        arSceneManager.configureARViewForTextOnly()
        
        // Add test labels again to ensure they are visible during playback
        arSceneManager.addTestLabel()
        arSceneManager.addFixedTextNode()
        
        // Make sure 2D test label overlay is in front
        if let existingLabel = view.viewWithTag(12345) {
            view.bringSubviewToFront(existingLabel)
        }
        
        // Make sure simple SCNView is in front
        if let existingScnView = view.viewWithTag(54321) {
            view.bringSubviewToFront(existingScnView)
        }
        
        // Make video preview semi-transparent to ensure AR content is visible
        if let previewLayer = videoCapture.previewLayer {
            previewLayer.opacity = 0.7 // 70% opacity allows AR text to show through
        }
        
        // Make sure toolbar is in front of all views
        view.bringSubviewToFront(toolBar)
        
        // Force a layout update
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Schedule an additional refresh of labels after a short delay to ensure they appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Refresh the test labels
            self.forceTestLabelVisible()
            
            // Log that we've refreshed the labels
            print("Refreshed AR labels after play button pressed")
        }
    }
    // User pressed pause button - pause video
    else {
        print("Pause button pressed - pausing video")
        
        // Pause video capture
        videoCapture.stop()
        
        // Update button states
        playButtonOutlet.isEnabled = true
        pauseButtonOutlet.isEnabled = false
        
        // Update button title
        sender.title = "Play"
        
        // Keep AR session running but refresh labels
        arSceneManager.addTestLabel()
        arSceneManager.addFixedTextNode()
        
        // Make sure 2D test label overlay is visible
        if let existingLabel = view.viewWithTag(12345) {
            view.bringSubviewToFront(existingLabel)
        }
        
        // Make sure simple SCNView is visible
        if let existingScnView = view.viewWithTag(54321) {
            view.bringSubviewToFront(existingScnView)
        }
        
        // Make sure toolbar is in front of all views
        view.bringSubviewToFront(toolBar)
    }
  }

  @IBAction func pauseButton(_ sender: Any?) {
    selection.selectionChanged()
    self.videoCapture.stop()
    playButtonOutlet.isEnabled = true
    pauseButtonOutlet.isEnabled = false
    
    // Keep the AR session running even when paused to allow bounding boxes to work
    // This is a key change - we don't pause the AR session anymore
    // Instead, just ensure the bounding boxes are visible and interactive
    
    // Make sure bounding box views are above AR content
    for boxView in boundingBoxViews {
        if !boxView.isHidden {
            videoPreview.bringSubviewToFront(boxView)
        }
    }
  }

  @IBAction func switchCameraTapped(_ sender: Any) {
    self.videoCapture.captureSession.beginConfiguration()
    let currentInput = self.videoCapture.captureSession.inputs.first as? AVCaptureDeviceInput
    self.videoCapture.captureSession.removeInput(currentInput!)
    guard let currentPosition = currentInput?.device.position else { return }

    let nextCameraPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

    let newCameraDevice = bestCaptureDevice(for: nextCameraPosition)

    guard let videoInput1 = try? AVCaptureDeviceInput(device: newCameraDevice) else {
      return
    }

    self.videoCapture.captureSession.addInput(videoInput1)
    self.videoCapture.updateVideoOrientation()

    self.videoCapture.captureSession.commitConfiguration()

  }

  // share image
  @IBAction func shareButton(_ sender: Any) {
    selection.selectionChanged()
    let settings = AVCapturePhotoSettings()
    self.videoCapture.cameraOutput.capturePhoto(
      with: settings, delegate: self as AVCapturePhotoCaptureDelegate)
  }

  // share screenshot
  @IBAction func saveScreenshotButton(_ shouldSave: Bool = true) {
    // let layer = UIApplication.shared.keyWindow!.layer
    // let scale = UIScreen.main.scale
    // UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, scale);
    // layer.render(in: UIGraphicsGetCurrentContext()!)
    // let screenshot = UIGraphicsGetImageFromCurrentImageContext()
    // UIGraphicsEndImageContext()

    // let screenshot = UIApplication.shared.screenShot
    // UIImageWriteToSavedPhotosAlbum(screenshot!, nil, nil, nil)
  }

  let maxBoundingBoxViews = 100
  var boundingBoxViews = [BoundingBoxView]()
  var colors: [String: UIColor] = [:]
  let ultralyticsColorsolors: [UIColor] = [
    UIColor(red: 4 / 255, green: 42 / 255, blue: 255 / 255, alpha: 0.6),  // #042AFF
    UIColor(red: 11 / 255, green: 219 / 255, blue: 235 / 255, alpha: 0.6),  // #0BDBEB
    UIColor(red: 243 / 255, green: 243 / 255, blue: 243 / 255, alpha: 0.6),  // #F3F3F3
    UIColor(red: 0 / 255, green: 223 / 255, blue: 183 / 255, alpha: 0.6),  // #00DFB7
    UIColor(red: 17 / 255, green: 31 / 255, blue: 104 / 255, alpha: 0.6),  // #111F68
    UIColor(red: 255 / 255, green: 111 / 255, blue: 221 / 255, alpha: 0.6),  // #FF6FDD
    UIColor(red: 255 / 255, green: 68 / 255, blue: 79 / 255, alpha: 0.6),  // #FF444F
    UIColor(red: 204 / 255, green: 237 / 255, blue: 0 / 255, alpha: 0.6),  // #CCED00
    UIColor(red: 0 / 255, green: 243 / 255, blue: 68 / 255, alpha: 0.6),  // #00F344
    UIColor(red: 189 / 255, green: 0 / 255, blue: 255 / 255, alpha: 0.6),  // #BD00FF
    UIColor(red: 0 / 255, green: 180 / 255, blue: 255 / 255, alpha: 0.6),  // #00B4FF
    UIColor(red: 221 / 255, green: 0 / 255, blue: 186 / 255, alpha: 0.6),  // #DD00BA
    UIColor(red: 0 / 255, green: 255 / 255, blue: 255 / 255, alpha: 0.6),  // #00FFFF
    UIColor(red: 38 / 255, green: 192 / 255, blue: 0 / 255, alpha: 0.6),  // #26C000
    UIColor(red: 1 / 255, green: 255 / 255, blue: 179 / 255, alpha: 0.6),  // #01FFB3
    UIColor(red: 125 / 255, green: 36 / 255, blue: 255 / 255, alpha: 0.6),  // #7D24FF
    UIColor(red: 123 / 255, green: 0 / 255, blue: 104 / 255, alpha: 0.6),  // #7B0068
    UIColor(red: 255 / 255, green: 27 / 255, blue: 108 / 255, alpha: 0.6),  // #FF1B6C
    UIColor(red: 252 / 255, green: 109 / 255, blue: 47 / 255, alpha: 0.6),  // #FC6D2F
    UIColor(red: 162 / 255, green: 255 / 255, blue: 11 / 255, alpha: 0.6),  // #A2FF0B
  ]

  func setUpBoundingBoxViews() {
    // Ensure all bounding box views are initialized up to the maximum allowed.
    while boundingBoxViews.count < maxBoundingBoxViews {
      let boxView = BoundingBoxView(frame: .zero)
      boundingBoxViews.append(boxView)
      videoPreview.addSubview(boxView)
      
      // Add a tap gesture recognizer to each bounding box view
      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(boundingBoxTapped(_:)))
      boxView.addGestureRecognizer(tapGesture)
      boxView.isUserInteractionEnabled = true
        
        // Ensure bounding boxes are visible above AR content
        boxView.layer.zPosition = 100
        
        // Make sure the box view can receive touches
        boxView.isOpaque = false
        boxView.backgroundColor = .clear
        
        print("Created bounding box view with tap gesture")
    }

    // Retrieve class labels directly from the CoreML model's class labels, if available.
    guard let classLabels = mlModel.modelDescription.classLabels as? [String] else {
      fatalError("Class labels are missing from the model description")
    }

    // Assign random colors to the classes.
    var count = 0
    for label in classLabels {
      let color = ultralyticsColorsolors[count]
      count += 1
      if count > 19 {
        count = 0
      }
      colors[label] = color
    }
    
    print("Initialized \(boundingBoxViews.count) bounding box views")
  }

  func startVideo() {
    print("Starting video capture")
    
    // Initialize video capture
    videoCapture = VideoCapture()
    videoCapture.delegate = self

    // Set up video capture with photo preset
    videoCapture.setUp(sessionPreset: .photo) { success in
      if success {
            print("Video capture setup successful")
            
            // Add the video preview into the UI
        if let previewLayer = self.videoCapture.previewLayer {
                previewLayer.frame = self.videoPreview.bounds
                previewLayer.videoGravity = .resizeAspectFill
          self.videoPreview.layer.addSublayer(previewLayer)
                
                // Make video preview semi-transparent to ensure AR content is visible
                previewLayer.opacity = 0.7
                
                // Start the video capture session
        self.videoCapture.start()
      } else {
                print("ERROR: Failed to get preview layer from video capture")
            }
        } else {
            print("ERROR: Failed to set up video capture")
      }
    }
  }

  func predict(sampleBuffer: CMSampleBuffer) {
    if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      currentBuffer = pixelBuffer
      if !frameSizeCaptured {
        let frameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let frameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        longSide = max(frameWidth, frameHeight)
        shortSide = min(frameWidth, frameHeight)
        frameSizeCaptured = true
      }
        
      // The frame is always oriented based on the camera sensor,
      // so in most cases Vision needs to rotate it for the model to work as expected.
      let imageOrientation: CGImagePropertyOrientation
      switch UIDevice.current.orientation {
      case .portrait:
        imageOrientation = .up
      case .portraitUpsideDown:
        imageOrientation = .down
      case .landscapeLeft:
        imageOrientation = .up
      case .landscapeRight:
        imageOrientation = .up
      case .unknown:
        imageOrientation = .up
      default:
        imageOrientation = .up
      }

      // Invoke a VNRequestHandler with that image
      let handler = VNImageRequestHandler(
        cvPixelBuffer: pixelBuffer, orientation: imageOrientation, options: [:])
        
        // Always process frames, regardless of orientation or pause state
        // This ensures bounding boxes work even when the app is paused
        t0 = CACurrentMediaTime()  // inference start
        do {
          try handler.perform([visionRequest])
        } catch {
          print(error)
        }
        t1 = CACurrentMediaTime() - t0  // inference dt

      currentBuffer = nil
    }
  }

  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNRecognizedObjectObservation] {
        self.show(predictions: results)
      } else {
        self.show(predictions: [])
      }

      // Measure FPS
      if self.t1 < 10.0 {  // valid dt
        self.t2 = self.t1 * 0.05 + self.t2 * 0.95  // smoothed inference time
      }
      self.t4 = (CACurrentMediaTime() - self.t3) * 0.05 + self.t4 * 0.95  // smoothed delivered FPS
      self.labelFPS.text = String(format: "%.1f FPS - %.1f ms", 1 / self.t4, self.t2 * 1000)  // t2 seconds to ms
      self.t3 = CACurrentMediaTime()
        
        // Make sure AR view is properly updated regardless of play/pause state
        if self.arSceneManager.sceneView.session.currentFrame == nil {
            // If AR session is not running properly, restart it
            self.arSceneManager.resumeARSession()
        }
        
        // Always make bounding boxes visible above AR content
        for boxView in self.boundingBoxViews {
            if !boxView.isHidden {
                self.videoPreview.bringSubviewToFront(boxView)
            }
        }
    }
  }

  // Save text file
  func saveText(text: String, file: String = "saved.txt") {
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
      let fileURL = dir.appendingPathComponent(file)

      // Writing
      do {  // Append to file if it exists
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        fileHandle.seekToEndOfFile()
        fileHandle.write(text.data(using: .utf8)!)
        fileHandle.closeFile()
      } catch {  // Create new file and write
        do {
          try text.write(to: fileURL, atomically: false, encoding: .utf8)
        } catch {
          print("no file written")
        }
      }

      // Reading
      // do {let text2 = try String(contentsOf: fileURL, encoding: .utf8)} catch {/* error handling here */}
    }
  }

  // Save image file
  func saveImage() {
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    let fileURL = dir!.appendingPathComponent("saved.jpg")
    let image = UIImage(named: "ultralytics_yolo_logotype.png")
    FileManager.default.createFile(
      atPath: fileURL.path, contents: image!.jpegData(compressionQuality: 0.5), attributes: nil)
  }

  // Return hard drive space (GB)
  func freeSpace() -> Double {
    let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
    do {
      let values = try fileURL.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey
      ])
      return Double(values.volumeAvailableCapacityForImportantUsage!) / 1E9  // Bytes to GB
    } catch {
      print("Error retrieving storage capacity: \(error.localizedDescription)")
    }
    return 0
  }

  // Return RAM usage (GB)
  func memoryUsage() -> Double {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    if kerr == KERN_SUCCESS {
      return Double(taskInfo.resident_size) / 1E9  // Bytes to GB
    } else {
      return 0
    }
  }

  func show(predictions: [VNRecognizedObjectObservation]) {
    var str = ""
    // date
    let date = Date()
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minutes = calendar.component(.minute, from: date)
    let seconds = calendar.component(.second, from: date)
    let nanoseconds = calendar.component(.nanosecond, from: date)
    let sec_day =
      Double(hour) * 3600.0 + Double(minutes) * 60.0 + Double(seconds) + Double(nanoseconds) / 1E9  // seconds in the day

    self.labelSlider.text =
      String(predictions.count) + " items (max " + String(Int(slider.value)) + ")"
    let width = videoPreview.bounds.width  // 375 pix
    let height = videoPreview.bounds.height  // 812 pix

    // Store the best prediction for AR placement
    if !predictions.isEmpty && predictions.count > 0 {
      let bestPrediction = predictions[0]
      let bestClass = bestPrediction.labels[0].identifier
      
      // Check if we have a translation for this class
      if let translation = translationManager.getTranslation(for: bestClass) {
        // Store the current detection for use in AR
        self.currentDetection = (english: bestClass, chinese: translation.chinese, pinyin: translation.pinyin)
        
        // Only log if the detection has changed
        if self.lastDetectedClass != bestClass {
          print("Set currentDetection to: \(bestClass) - \(translation.chinese) (\(translation.pinyin))")
          self.lastDetectedClass = bestClass
          
            // Update AR scene with the new detection
            arSceneManager.updateCurrentDetection(english: bestClass, chinese: translation.chinese, pinyin: translation.pinyin)
        }
      }
    }
    
    // Make sure bounding box views are above AR content
    for boxView in boundingBoxViews {
      if !boxView.isHidden {
      videoPreview.bringSubviewToFront(boxView)
        
        // Make sure each visible bounding box has a tap gesture
        if boxView.gestureRecognizers?.isEmpty ?? true {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(boundingBoxTapped(_:)))
            boxView.addGestureRecognizer(tapGesture)
            boxView.isUserInteractionEnabled = true
            print("👆 Added tap gesture to box for \(boxView.className)")
        }
        
        // Make bounding box extremely clickable
        boxView.backgroundColor = UIColor.clear
        boxView.isUserInteractionEnabled = true
        boxView.layer.zPosition = 500
      }
    }

    // Process predictions and update bounding boxes
    if UIDevice.current.orientation == .portrait {
      // ratio = videoPreview AR divided by sessionPreset AR
      var ratio: CGFloat = 1.0
      if videoCapture.captureSession.sessionPreset == .photo {
        ratio = (height / width) / (4.0 / 3.0)  // .photo
      } else {
        ratio = (height / width) / (16.0 / 9.0)  // .hd4K3840x2160, .hd1920x1080, .hd1280x720 etc.
      }

      // Sort predictions by confidence to ensure higher confidence boxes are drawn on top
      let sortedPredictions = predictions.sorted { $0.labels[0].confidence > $1.labels[0].confidence }
      
      // Debug: Print the number of predictions
      print("Processing \(sortedPredictions.count) predictions, max \(Int(slider.value))")
      
      for i in 0..<boundingBoxViews.count {
        if i < sortedPredictions.count && i < Int(slider.value) {
          let prediction = sortedPredictions[i]

          var rect = prediction.boundingBox  // normalized xywh, origin lower left
          switch UIDevice.current.orientation {
          case .portraitUpsideDown:
            rect = CGRect(
              x: 1.0 - rect.origin.x - rect.width,
              y: 1.0 - rect.origin.y - rect.height,
              width: rect.width,
              height: rect.height)
          case .landscapeLeft:
            rect = CGRect(
              x: rect.origin.x,
              y: rect.origin.y,
              width: rect.width,
              height: rect.height)
          case .landscapeRight:
            rect = CGRect(
              x: rect.origin.x,
              y: rect.origin.y,
              width: rect.width,
              height: rect.height)
          case .unknown:
            print("The device orientation is unknown, the predictions may be affected")
            fallthrough
          default: break
          }

          if ratio >= 1 {  // iPhone ratio = 1.218
            let offset = (1 - ratio) * (0.5 - rect.minX)
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: offset, y: -1)
            rect = rect.applying(transform)
            rect.size.width *= ratio
          } else {  // iPad ratio = 0.75
            let offset = (ratio - 1) * (0.5 - rect.maxY)
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: offset - 1)
            rect = rect.applying(transform)
            ratio = (height / width) / (3.0 / 4.0)
            rect.size.height /= ratio
          }

          // Scale normalized to pixels [375, 812] [width, height]
          rect = VNImageRectForNormalizedRect(rect, Int(width), Int(height))

          // Get the best prediction for this observation
          let bestClass = prediction.labels[0].identifier
          let confidence = prediction.labels[0].confidence
          
          // Check if this class is in our hidden set
          if hiddenBoxes.contains(bestClass) {
            // This class should be hidden
            boundingBoxViews[i].hide()
            continue
          }
          
          // Check if we have a translation for this class
          if let translation = translationManager.getTranslation(for: bestClass) {
              // Store the current detection for use when tapped - no need to log again
              self.currentDetection = (english: bestClass, chinese: translation.chinese, pinyin: translation.pinyin)
              
              // Create a label with translation
              let label = String(format: "%@ - %@ %.1f%%", bestClass, translation.chinese, confidence * 100)
              let alpha = CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9)
              
              // Store the class name and translation in the bounding box view
              boundingBoxViews[i].className = bestClass
              boundingBoxViews[i].confidence = confidence
              boundingBoxViews[i].translation = translation
              
              // Set the tag to a value based on confidence and position
              // Higher confidence boxes should be in front (higher tag value)
              // We'll use confidence * 1000 to create a range of values
              let zIndex = Int(confidence * 1000)
              boundingBoxViews[i].tag = zIndex
              
              // Debug: Print bounding box info
              print("📦 Showing box for \(bestClass) at \(rect) with confidence \(confidence)")
              
              boundingBoxViews[i].show(
                frame: rect,
                label: label,
                color: colors[bestClass] ?? UIColor.white,
                alpha: alpha)
              
              // Add tap gesture to the bounding box view if not already added
              if boundingBoxViews[i].gestureRecognizers?.isEmpty ?? true {
                  let tapGesture = UITapGestureRecognizer(target: self, action: #selector(boundingBoxTapped(_:)))
                  boundingBoxViews[i].addGestureRecognizer(tapGesture)
                  boundingBoxViews[i].isUserInteractionEnabled = true
                  print("👆 Added tap gesture to box \(i) for \(bestClass)")
              }
              
              // Make sure the box view can receive touches
              boundingBoxViews[i].backgroundColor = UIColor.clear
              boundingBoxViews[i].isUserInteractionEnabled = true
              boundingBoxViews[i].layer.zPosition = 500
          } else {
              // No translation available, use original label
              let label = String(format: "%@ %.1f", bestClass, confidence * 100)
              let alpha = CGFloat((confidence - 0.2) / (1.0 - 0.2) * 0.9)
              
              // Store the class name in the bounding box view
              boundingBoxViews[i].className = bestClass
              boundingBoxViews[i].confidence = confidence
              boundingBoxViews[i].translation = nil
              
              boundingBoxViews[i].show(
                frame: rect,
                label: label,
                color: colors[bestClass] ?? UIColor.white,
                alpha: alpha)
          }
        } else {
          boundingBoxViews[i].hide()
        }
      }
    }

    // After updating all bounding boxes, synchronize with AR labels
    // We'll use a timer to avoid doing this on every frame
      if CACurrentMediaTime() - lastARSyncTime > 2.0 { // Sync every 2 seconds
        lastARSyncTime = CACurrentMediaTime()
        // Synchronize AR labels with bounding boxes
        synchronizeARLabelsWithBoundingBoxes()
    }

    // Write
    if developerMode {
      if save_detections {
        // Get the best prediction for the first observation
        if !predictions.isEmpty {
          let bestPrediction = predictions[0]
          let bestClass = bestPrediction.labels[0].identifier
          let confidence = bestPrediction.labels[0].confidence
          let rect = bestPrediction.boundingBox
          
          str += String(
            format: "%.3f %.3f %.3f %@ %.2f %.1f %.1f %.1f %.1f\n",
            sec_day, freeSpace(), UIDevice.current.batteryLevel, bestClass, confidence,
            rect.origin.x, rect.origin.y, rect.width, rect.height)
        }
      }
      if save_frames {
        str = String(
          format: "%.3f %.3f %.3f %.3f %.1f %.1f %.1f\n",
          sec_day, freeSpace(), memoryUsage(), UIDevice.current.batteryLevel,
          self.t1 * 1000, self.t2 * 1000, 1 / self.t4)
        saveText(text: str, file: "frames.txt")  // Write stats for each image
      }
    }
  }

  // Pinch to Zoom Start ---------------------------------------------------------------------------------------------
  let minimumZoom: CGFloat = 1.0
  let maximumZoom: CGFloat = 10.0
  var lastZoomFactor: CGFloat = 1.0

  @IBAction func pinch(_ pinch: UIPinchGestureRecognizer) {
    let device = videoCapture.captureDevice

    // Return zoom value between the minimum and maximum zoom values
    func minMaxZoom(_ factor: CGFloat) -> CGFloat {
      return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
    }

    func update(scale factor: CGFloat) {
      do {
        try device.lockForConfiguration()
        defer {
          device.unlockForConfiguration()
        }
        device.videoZoomFactor = factor
      } catch {
        print("\(error.localizedDescription)")
      }
    }

    let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
    switch pinch.state {
    case .began, .changed:
      update(scale: newScaleFactor)
      self.labelZoom.text = String(format: "%.2fx", newScaleFactor)
      self.labelZoom.font = UIFont.preferredFont(forTextStyle: .title2)
    case .ended:
      lastZoomFactor = minMaxZoom(newScaleFactor)
      update(scale: lastZoomFactor)
      self.labelZoom.font = UIFont.preferredFont(forTextStyle: .body)
    default: break
    }
  }  // Pinch to Zoom End --------------------------------------------------------------------------------------------

  // MARK: - Translation and Learning Features
  
  /// Handle tap on a bounding box
  @objc func boundingBoxTapped(_ gesture: UITapGestureRecognizer) {
    // Get the tapped bounding box
    guard let boxView = gesture.view as? BoundingBoxView else {
        print("❌ Tapped view is not a BoundingBoxView")
        return
    }
    
    print("🔍 Bounding box tapped: \(boxView.className), frame: \(boxView.frame)")
    
    // Directly use our createARLabelForBox method
    createARLabelForBox(boxView)
  }
  
  /// Handle tap on a bounding box - method that takes a BoundingBoxView directly
  func handleBoundingBoxTap(_ boxView: BoundingBoxView) {
    // Get the class name and translation directly from the bounding box
    let className = boxView.className
    let confidence = boxView.confidence
    
    // Check if we have a translation for this class
    guard let translation = boxView.translation ?? translationManager.getTranslation(for: className) else {
        print("No translation found for \(className)")
        return
    }
    
    print("Handling tap on bounding box for: \(className)")
    
    // Create detection info from the bounding box data
    let detection = (english: className, chinese: translation.chinese, pinyin: translation.pinyin)
    
    // Immediately hide the bounding box
    boxView.hide()
    
    // Add class name to hidden set
    hiddenBoxes.insert(className)
    
    // Make sure AR session is running
    if arSceneManager.sceneView.session.currentFrame == nil {
        print("AR session not running, restarting before placing label")
        arSceneManager.resumeARSession()
        arSceneManager.configureARViewForTextOnly()
        
        // Wait a moment for AR session to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.placeARLabel(for: detection, at: boxView.frame)
        }
        return
    }
    
    // Place AR label immediately
    placeARLabel(for: detection, at: boxView.frame)
  }
  
  // Helper method to place AR label
  private func placeARLabel(for detection: (english: String, chinese: String, pinyin: String), at boxFrame: CGRect) {
    // Get the center of the bounding box in screen coordinates
    let boxCenter = CGPoint(x: boxFrame.midX, y: boxFrame.midY)
    
    // Ensure AR session is running
    if arSceneManager.sceneView.session.currentFrame == nil {
        print("AR session not running, restarting before placing label")
        arSceneManager.resumeARSession()
        
        // Wait a moment for AR session to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.attemptPlaceARLabel(for: detection, at: boxCenter)
        }
        return
    }
    
    // Place AR label immediately
    attemptPlaceARLabel(for: detection, at: boxCenter)
  }
  
  // Helper method to attempt placing an AR label at a specific point
  private func attemptPlaceARLabel(for detection: (english: String, chinese: String, pinyin: String), at boxCenter: CGPoint) {
    // Perform hit test to find 3D position
    let arHitTestResults = arSceneManager.sceneView.hitTest(boxCenter, types: [.featurePoint])
    
    if let closestResult = arHitTestResults.first {
        // Get coordinates of hit test
        let transform = closestResult.worldTransform
        let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        print("Placing 3D text at world coordinates: \(worldCoord) for detection: \(detection.english)")
        
        // Create 3D text node with enhanced visibility
        let node = arSceneManager.createNewBubbleParentNode(
            english: detection.english,
            chinese: detection.chinese,
            pinyin: detection.pinyin
        )
        
        // Add node to scene
        arSceneManager.sceneView.scene.rootNode.addChildNode(node)
        node.position = worldCoord
        
        // Ensure the node is fully opaque - force it here
        node.opacity = 1.0
        
        // Apply enhanced non-ghosting rendering options to this node and its children
        applyEnhancedVisibilityOptions(to: node)
        
        // Store the node to prevent duplicates
        arSceneManager.placedNodes.append(node)
        
        // Play pronunciation
        arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
        
        // Store the detection for future reference with the actual transform
        taggedDetections.append((
                english: detection.english,
                chinese: detection.chinese,
                pinyin: detection.pinyin,
                worldPosition: transform
            ))
        } else {
        // Fallback: Use a ray from the camera through the box center
        guard let cameraNode = arSceneManager.sceneView.pointOfView else {
            print("Could not access camera node, using fixed position")
            
            // Create a fixed position in front of the camera
            if let currentFrame = arSceneManager.sceneView.session.currentFrame {
                let cameraTransform = currentFrame.camera.transform
                let position = SCNVector3(
                    cameraTransform.columns.3.x,
                    cameraTransform.columns.3.y,
                    cameraTransform.columns.3.z - 0.5 // 0.5 meters in front of camera
                )
                
                // Create and place the 3D text node
                let node = arSceneManager.createNewBubbleParentNode(
                    english: detection.english,
                    chinese: detection.chinese,
                    pinyin: detection.pinyin
                )
                
                arSceneManager.sceneView.scene.rootNode.addChildNode(node)
                node.position = position
                node.opacity = 1.0
                
                // Apply non-ghosting rendering options to this node and its children
                applyNonGhostingOptions(to: node)
                
                arSceneManager.placedNodes.append(node)
                
                // Play pronunciation
                arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
                
                // Store the detection
                taggedDetections.append((
                    english: detection.english,
                    chinese: detection.chinese,
                    pinyin: detection.pinyin,
                    worldPosition: cameraTransform
                ))
            }
                return
            }
            
        // Get camera position
        let cameraPosition = cameraNode.position
        
        // Convert box center to normalized device coordinates (-1 to 1)
        let screenSize = arSceneManager.sceneView.bounds.size
        let normalizedX = (2 * boxCenter.x / screenSize.width) - 1
        let normalizedY = 1 - (2 * boxCenter.y / screenSize.height) // Flip Y
        
        // Create a direction vector from the camera through this point
        let direction = SCNVector3(normalizedX, normalizedY, -1) // -1 for "forward" from camera
        
        // Place the node at a fixed distance from the camera (e.g., 1 meter)
        let distance: Float = 1.0
        let position = SCNVector3(
            cameraPosition.x + direction.x * distance,
            cameraPosition.y + direction.y * distance,
            cameraPosition.z + direction.z * distance
        )
        
        // Create and place the 3D text node
        let node = arSceneManager.createNewBubbleParentNode(
            english: detection.english,
            chinese: detection.chinese,
            pinyin: detection.pinyin
        )
        
        arSceneManager.sceneView.scene.rootNode.addChildNode(node)
        node.position = position
        
        // Ensure the node is fully opaque - force it here
        node.opacity = 1.0
        
        // Apply non-ghosting rendering options to this node and its children
        applyNonGhostingOptions(to: node)
        
        // Store the node
        arSceneManager.placedNodes.append(node)
        
        // Play pronunciation
        arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
        
        // Create a transform matrix from the camera's current transform
        var worldPosition = matrix_identity_float4x4
        if let currentFrame = arSceneManager.sceneView.session.currentFrame {
            // Use the camera transform as a base
            worldPosition = currentFrame.camera.transform
            // Adjust the position to be in front of the camera
            worldPosition.columns.3.z -= 1.0 // 1 meter in front
        }
        
        // Store the detection for future reference
        taggedDetections.append((
                english: detection.english,
                chinese: detection.chinese,
                pinyin: detection.pinyin,
            worldPosition: worldPosition
        ))
    }
    
    // Provide haptic feedback
    selection.selectionChanged()
  }
  
  // Helper method to apply non-ghosting rendering options to a node and its children
  private func applyNonGhostingOptions(to node: SCNNode) {
    // Set node to be fully opaque
    node.opacity = 1.0
    
    // Set high rendering priority
    node.renderingOrder = 100
    
    // Apply the same to all children
    for childNode in node.childNodes {
        childNode.opacity = 1.0
        childNode.renderingOrder = 100
        
        // If this child has material, ensure it's fully opaque
        if let geometry = childNode.geometry {
            for material in geometry.materials {
                material.transparency = 1.0
            }
        }
    }
  }
  
  // Add a new method for enhanced visibility options
  private func applyEnhancedVisibilityOptions(to node: SCNNode) {
    // Set node to be fully opaque
    node.opacity = 1.0
    
    // Set very high rendering priority
    node.renderingOrder = 1000
    
    // Make node billboard to always face the camera
    let billboardConstraint = SCNBillboardConstraint()
    billboardConstraint.freeAxes = .all
    node.constraints = [billboardConstraint]
    
    // Apply the same to all children
    for childNode in node.childNodes {
        childNode.opacity = 1.0
        childNode.renderingOrder = 1000
        
        // If this child has material, ensure it's fully opaque and bright
        if let geometry = childNode.geometry {
            for material in geometry.materials {
                material.transparency = 0.0  // 0.0 means fully opaque
                material.lightingModel = .constant  // No lighting effects
                
                // Make emission brighter for better visibility
                if let emissionContent = material.emission.contents {
                    if let color = emissionContent as? UIColor {
                        // Increase emission brightness
                        material.emission.contents = color.withAlphaComponent(1.0)
                        material.emission.intensity = 1.5  // Boost emission intensity
                    }
                }
            }
        }
    }
    
    // Make node visible even when video is running
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // Re-apply opacity after a short delay to ensure it takes effect
        node.opacity = 1.0
        for childNode in node.childNodes {
            childNode.opacity = 1.0
        }
    }
  }
  
  @objc func videoPreviewTapped(_ gesture: UITapGestureRecognizer) {
    // Get the tap location
    let location = gesture.location(in: videoPreview)
    
    // First check if the tap is on any bounding boxes, regardless of AR mode
    var tappedBoxes: [(boxView: BoundingBoxView, zIndex: Int)] = []
    
    for (i, boxView) in boundingBoxViews.enumerated() {
        if !boxView.isHidden && boxView.frame.contains(location) {
            // Store the box and its z-index (tag is used as a proxy for z-order)
            // Higher tag values are added later, so they're "in front"
            tappedBoxes.append((boxView: boxView, zIndex: boxView.tag))
        }
    }
    
    // If we found any tapped boxes, handle the one in front (highest z-index)
    if !tappedBoxes.isEmpty {
        // Sort by z-index in descending order (highest first)
        tappedBoxes.sort { $0.zIndex > $1.zIndex }
        
        // Handle the frontmost box
        let frontmostBox = tappedBoxes[0].boxView
        print("Tapped on frontmost bounding box: \(frontmostBox.className)")
        handleBoundingBoxTap(frontmostBox)
        return
    }
    
    // If no bounding box was tapped, forward the tap to the AR scene manager
    print("Forwarding tap to ARSceneManager")
        
        // Forward tap to AR scene manager
        let locationInARView = gesture.location(in: arSceneManager.sceneView)
        let customTapGesture = UITapGestureRecognizer(target: arSceneManager, action: #selector(ARSceneManager.handleTap(gestureRecognize:)))
        customTapGesture.state = .ended
        
        // Create a temporary view for the tap gesture
        let tempView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        tempView.center = locationInARView
        tempView.isUserInteractionEnabled = true
        arSceneManager.sceneView.addSubview(tempView)
        
        // Add the gesture to this view and trigger it
        tempView.addGestureRecognizer(customTapGesture)
        customTapGesture.view?.center = locationInARView
        
        // Simulate the tap
        arSceneManager.handleTap(gestureRecognize: customTapGesture)
        
        // Remove the temporary view
        tempView.removeFromSuperview()
    }

  // MARK: - AR Integration
  
  // Synchronize AR labels with bounding boxes
  func synchronizeARLabelsWithBoundingBoxes() {
    // Check if it's time to sync (don't do this every frame)
    let currentTime = CACurrentMediaTime()
    if currentTime - lastARSyncTime > 2.0 {
        lastARSyncTime = currentTime
        print("Synchronizing AR labels with bounding boxes")
        
        // First check if AR session is running
        if arSceneManager.sceneView.session.configuration == nil {
            print("AR session not running during sync, restarting...")
            arSceneManager.resumeARSession()
            
            // Wait a moment before attempting to place labels
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.attemptSynchronizeARLabels()
            }
            return
          }
          
        // Attempt to synchronize labels
        attemptSynchronizeARLabels()
    }
  }

  // Attempt to synchronize AR labels with bounding boxes
  func attemptSynchronizeARLabels() {
    print("Attempting to synchronize AR labels")
    
    // Make sure all existing AR nodes are fully visible
    for node in arSceneManager.placedNodes {
        // Make sure the node is fully opaque
        node.opacity = 1.0
        node.renderingOrder = 3000 // Very high rendering priority
        
        // Apply to all children
        for childNode in node.childNodes {
            childNode.opacity = 1.0
            childNode.renderingOrder = 3000
            
            // Make materials extra bright
            if let geometry = childNode.geometry {
                for material in geometry.materials {
                    material.transparency = 0.0 // Fully opaque
                    material.lightingModel = .constant // No lighting effects
                    
                    // Increase emission intensity for better visibility
                    if let _ = material.emission.contents {
                        material.emission.intensity = 5.0 // Extremely bright emission
                    }
                }
            }
        }
    }
    
    // Ensure all bounding boxes are visible and interactive
    for boxView in boundingBoxViews {
        if !boxView.isHidden {
            // Make sure the bounding box is in front
            videoPreview.bringSubviewToFront(boxView)
            
            // Make sure it's interactive
            boxView.isUserInteractionEnabled = true
            
            // If this class name is in our hidden set, we've already placed an AR label for it
      let className = boxView.className
            if !className.isEmpty && hiddenObjectLabels.contains(className) {
                print("Found AR label for: \(className)")
                
                // Try to find the AR node for this object and ensure it's visible
                for node in arSceneManager.placedNodes {
                    if let nodeName = node.name, nodeName.contains(className) {
                        // Force the node to be fully visible
                        node.opacity = 1.0
                        node.renderingOrder = 3000
                        
                        print("Made AR node for \(className) fully visible")
                    }
                }
            }
        }
    }
    
    // Check if there are any tagged detections that need to be displayed in AR
    for className in hiddenObjectLabels {
        // Check if we already have an AR node for this object
        var hasNode = false
        for node in arSceneManager.placedNodes {
            if let nodeName = node.name, nodeName.contains(className) {
                hasNode = true
                break
            }
        }
        
        // If we don't have a node for this object, create one
        if !hasNode {
            print("Creating new AR node for: \(className)")
            
            // Get the translation for this object
            if let translation = translationManager.getTranslation(for: className) {
                // Create a detection info tuple
                let detectionInfo = (english: className, chinese: translation.chinese, pinyin: translation.pinyin)
                
                // Create a temporary currentDetection
                currentDetection = detectionInfo
                
                // Place the AR label for this object
                placeARLabel(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
                
                print("Created new AR node for: \(className)")
            }
        }
    }
    
    // Create or refresh the test labels to ensure they're visible
    arSceneManager.addTestLabel()
    arSceneManager.addFixedTextNode()
    
    // Configure AR view for maximum text visibility
    arSceneManager.configureARViewForTextOnly()
    
    // Log that we've completed synchronization
    print("AR labels synchronized with bounding boxes")
  }
  
  // Replace the AR toggle button with just a clear button
  func addClearARButton() {
    // Add clear AR labels button
    let clearButton = UIButton(type: .system)
    clearButton.setImage(UIImage(systemName: "arrow.counterclockwise.circle.fill"), for: .normal)
    clearButton.tintColor = .white
    clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
    clearButton.layer.cornerRadius = 25
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    clearButton.addTarget(self, action: #selector(clearARButtonTapped), for: .touchUpInside)
    
    view.addSubview(clearButton)
    
    // Position button to not overlap with toolbar
    NSLayoutConstraint.activate([
      clearButton.widthAnchor.constraint(equalToConstant: 50),
      clearButton.heightAnchor.constraint(equalToConstant: 50),
      clearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      clearButton.bottomAnchor.constraint(equalTo: toolBar.topAnchor, constant: -20) // Position above toolbar
    ])
    
    // Store reference to clear button
    self.clearARButton = clearButton
    
    // Make sure button is above AR view but doesn't interfere with toolbar
    view.bringSubviewToFront(clearButton)
  }
  
  @objc func clearARButtonTapped() {
    // Clear all AR labels
    clearARLabels()
    
    // Also unhide all hidden boxes
    hiddenBoxes.removeAll()
    
    // Reset the AR session to clear any stale AR content
    arSceneManager.setupARSession()
    
    // Ensure AR view is configured for text-only display
    arSceneManager.configureARViewForTextOnly()
  }

  // Clear all AR labels
  func clearARLabels() {
    arSceneManager.clearLabels()
    // Also clear tagged detections when clearing AR labels
    taggedDetections.removeAll()
    print("Cleared all AR labels and tagged detections")
    showToast(message: "Cleared all AR labels and tagged detections")
  }
  
  // Helper method to show toast messages
  func showToast(message: String) {
    let toastLabel = UILabel(frame: CGRect(x: view.frame.width/2 - 150, y: 100, width: 300, height: 35))
    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    toastLabel.textColor = UIColor.white
    toastLabel.textAlignment = .center
    toastLabel.text = message
    toastLabel.alpha = 1.0
    toastLabel.layer.cornerRadius = 10
    toastLabel.clipsToBounds = true
    view.addSubview(toastLabel)
    
    UIView.animate(withDuration: 0.5, delay: 1.5, options: .curveEaseOut, animations: {
      toastLabel.alpha = 0.0
    }, completion: { _ in
      toastLabel.removeFromSuperview()
    })
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // Ensure the toolbar is visible and interactive
    view.bringSubviewToFront(toolBar)
    
    // Set explicit z-position to be highest
    toolBar.layer.zPosition = 1000
    
    // Make toolbar explicitly user-interactive
    toolBar.isUserInteractionEnabled = true
    
    // Ensure all toolbar items are enabled correctly
    for item in toolBar.items ?? [] {
        if item === playButtonOutlet {
            item.isEnabled = !pauseButtonOutlet.isEnabled
        } else if item === pauseButtonOutlet {
            item.isEnabled = !playButtonOutlet.isEnabled
        }
    }
    
    // Force layout update
    view.setNeedsLayout()
    view.layoutIfNeeded()
    
    print("Toolbar brought to front and made interactive")
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    // Make sure toolbar is always on top during layout
    view.bringSubviewToFront(toolBar)
    
    // Update AR view frame to fill the screen
    arSceneManager.sceneView.frame = view.bounds
    
    // Keep video preview full size
    videoPreview.frame = view.bounds
    
    // Update video preview layer
    videoCapture?.previewLayer?.frame = videoPreview.bounds
  }

  // Add a new method to force the test label to be visible
  func forceTestLabelVisible() {
    print("Forcing test label to be visible")
    
    // First ensure AR view is properly positioned
    arSceneManager.sceneView.frame = view.bounds
    
    // Make sure AR view is a direct subview of the main view
    if arSceneManager.sceneView.superview != view {
        arSceneManager.sceneView.removeFromSuperview()
        view.addSubview(arSceneManager.sceneView)
        
        // Position AR view below video preview but above other views
        view.insertSubview(arSceneManager.sceneView, belowSubview: videoPreview)
    }
    
    // Make sure video preview is transparent
    videoPreview.backgroundColor = UIColor.clear
    if let previewLayer = videoCapture.previewLayer {
        previewLayer.opacity = 0.7 // Make video feed semi-transparent
    }
    
    // Force AR session to be running
    if arSceneManager.sceneView.session.currentFrame == nil {
        print("AR session not running, restarting...")
        arSceneManager.resumeARSession()
    }
    
    // Add a new test label
    arSceneManager.addTestLabel()
    
    // Configure AR view for maximum text visibility
    arSceneManager.configureARViewForTextOnly()
    
    // Ensure toolbar is in front
    view.bringSubviewToFront(toolBar)
    
    // Log that we've forced the test label to be visible
    print("Test label should now be visible")
    
    // Show a toast message
    showToast(message: "Test label added - should be visible now")
  }

  // Add a simple SCNView with text that doesn't rely on AR
  func addSimpleSceneView() {
      print("Adding simple SCNView with text")
      
      // Create a simple SCNView
      let scnView = SCNView(frame: CGRect(x: 20, y: 250, width: 200, height: 150))
      scnView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
      scnView.layer.cornerRadius = 10
      scnView.tag = 54321 // Tag for easy reference
      
      // Create a new scene
      let scene = SCNScene()
      
      // Create a camera node
      let cameraNode = SCNNode()
      cameraNode.camera = SCNCamera()
      cameraNode.position = SCNVector3(0, 0, 5)
      scene.rootNode.addChildNode(cameraNode)
      
      // Create a light node
      let lightNode = SCNNode()
      lightNode.light = SCNLight()
      lightNode.light?.type = .omni
      lightNode.position = SCNVector3(0, 10, 10)
      scene.rootNode.addChildNode(lightNode)
      
      // Create an ambient light node
      let ambientLightNode = SCNNode()
      ambientLightNode.light = SCNLight()
      ambientLightNode.light?.type = .ambient
      ambientLightNode.light?.color = UIColor.white
      scene.rootNode.addChildNode(ambientLightNode)
      
      // Create Chinese text
      let chineseText = SCNText(string: "简单3D文本", extrusionDepth: 1.0)
      chineseText.firstMaterial?.diffuse.contents = UIColor.white
      chineseText.firstMaterial?.emission.contents = UIColor.white
      chineseText.firstMaterial?.emission.intensity = 2.0
      
      // Create Chinese text node
      let chineseTextNode = SCNNode(geometry: chineseText)
      chineseTextNode.scale = SCNVector3(0.1, 0.1, 0.1)
      chineseTextNode.position = SCNVector3(0, 0.5, 0)
      
      // Center the text
      let (min, max) = chineseText.boundingBox
      let width = max.x - min.x
      chineseTextNode.pivot = SCNMatrix4MakeTranslation(width/2, 0, 0)
      
      // Add the text node to the scene
      scene.rootNode.addChildNode(chineseTextNode)
      
      // Create English text
      let englishText = SCNText(string: "SIMPLE 3D TEXT", extrusionDepth: 1.0)
      englishText.firstMaterial?.diffuse.contents = UIColor.cyan
      englishText.firstMaterial?.emission.contents = UIColor.cyan
      englishText.firstMaterial?.emission.intensity = 2.0
      
      // Create English text node
      let englishTextNode = SCNNode(geometry: englishText)
      englishTextNode.scale = SCNVector3(0.1, 0.1, 0.1)
      englishTextNode.position = SCNVector3(0, -0.5, 0)
      
      // Center the text
      let (minE, maxE) = englishText.boundingBox
      let widthE = maxE.x - minE.x
      englishTextNode.pivot = SCNMatrix4MakeTranslation(widthE/2, 0, 0)
      
      // Add the text node to the scene
      scene.rootNode.addChildNode(englishTextNode)
      
      // Add a rotation animation to make the text more visible
      let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(Float.pi * 2), z: 0, duration: 10.0)
      let repeatRotate = SCNAction.repeatForever(rotateAction)
      chineseTextNode.runAction(repeatRotate)
      englishTextNode.runAction(repeatRotate)
      
      // Set the scene to the view
      scnView.scene = scene
      scnView.allowsCameraControl = true
      scnView.autoenablesDefaultLighting = true
      scnView.backgroundColor = UIColor.black
      
      // Add the view to the main view
      view.addSubview(scnView)
      
      // Make sure it's in front of other views
      view.bringSubviewToFront(scnView)
      
      // Add a tap gesture to play pronunciation
      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(simpleSceneViewTapped))
      scnView.addGestureRecognizer(tapGesture)
      scnView.isUserInteractionEnabled = true
      
      print("Simple SCNView with text added")
  }

  // Handle tap on the simple scene view
  @objc func simpleSceneViewTapped() {
      print("Simple scene view tapped")
          
          // Play pronunciation
      arSceneManager.playPronunciation(for: "简单3D文本", pinyin: "jiǎndān 3D wénběn")
      
      // Provide haptic feedback
      selection.selectionChanged()
      
      // Show a toast message
      showToast(message: "Simple 3D text tapped - playing pronunciation")
  }

  // Place an AR label at a specific screen point
  func placeARLabel(at point: CGPoint) {
      print("🔍 placeARLabel called at point: \(point)")
      
      // Check if we have a current detection
      guard let detection = currentDetection else {
          print("❌ No current detection available")
            return
          }
          
      print("✅ Current detection: \(detection.english) - \(detection.chinese) (\(detection.pinyin))")
      
      // Update debug information
      updateARDebugInfo()
      
      // Check if AR session is running
      if arSceneManager.sceneView.session.configuration == nil {
          print("⚠️ AR session not running, restarting...")
          arSceneManager.resumeARSession()
          arSceneManager.configureARViewForTextOnly()
          
          // Wait a moment before attempting to place label
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              print("🔄 Retrying placeARLabel after AR session restart")
              self.updateARDebugInfo()
              self.attemptPlaceARLabel(at: point, for: detection)
          }
          return
      }
      
      print("🚀 AR session is running, attempting to place the label")
      
      // Attempt to place the AR label
      attemptPlaceARLabel(at: point, for: detection)
  }

  // Attempt to place an AR label at a specific point for a detection
  func attemptPlaceARLabel(at point: CGPoint, for detection: (english: String, chinese: String, pinyin: String)) {
      print("🎯 Attempting to place AR label for: \(detection.english) at point: \(point)")
      
      // Update debug info
      updateARDebugInfo()
      
      // Make sure AR view is fully opaque
      arSceneManager.sceneView.alpha = 1.0
      arSceneManager.sceneView.isHidden = false
      
      // Make sure video preview is semitransparent to allow seeing AR content
      videoPreview.alpha = 0.7
      
      // Ensure AR view is in view hierarchy and visible
      if arSceneManager.sceneView.superview == nil {
          print("⚠️ AR view not in hierarchy, adding it")
          view.insertSubview(arSceneManager.sceneView, belowSubview: videoPreview)
      }
      
      // Ensure view is setup correctly
      arSceneManager.configureARViewForTextOnly()
      
      // Perform hit test to find 3D position
      let hitTestResults = arSceneManager.sceneView.hitTest(point, types: [.featurePoint, .estimatedHorizontalPlane])
      print("📊 Hit test results count: \(hitTestResults.count)")
      
      if let result = hitTestResults.first {
          // Get world coordinates from hit test
          let transform = result.worldTransform
          let position = SCNVector3(
              transform.columns.3.x,
              transform.columns.3.y,
              transform.columns.3.z
          )
          
          print("📍 Hit test found position: \(position)")
          
          // Create and place the AR label node
          let node = arSceneManager.createNewBubbleParentNode(
              english: detection.english,
              chinese: detection.chinese,
              pinyin: detection.pinyin
          )
          
          // Make sure node is fully visible with high priority
          node.opacity = 1.0
          node.renderingOrder = 3000
          
          for childNode in node.childNodes {
              childNode.opacity = 1.0
              childNode.renderingOrder = 3000
          }
          
          // Add the node to the scene
          arSceneManager.sceneView.scene.rootNode.addChildNode(node)
          node.position = position
          
          // Add to placed nodes array
          arSceneManager.placedNodes.append(node)
          
          // Add to hidden set
          hiddenObjectLabels.insert(detection.english)
          
          // Provide feedback
          selection.selectionChanged()
          
          // Play pronunciation
          arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          
          print("✅ AR label placed at position: \(position)")
          print("📊 Total placed nodes: \(arSceneManager.placedNodes.count)")
          
          // Update debug info after placing node
          updateARDebugInfo()
      } else {
          // If hit test fails, place at a fixed position in front of camera
          print("⚠️ Hit test failed, using fallback position in front of camera")
          
          // FALLBACK: Always use a fixed position in front of camera since hit tests might be failing
          let cameraPosition: SCNVector3
          let cameraDirection: SCNVector3
          
          if let frame = arSceneManager.sceneView.session.currentFrame {
              // Get camera position and direction
              let cameraTransform = frame.camera.transform
              let positionColumn = cameraTransform.columns.3
              cameraPosition = SCNVector3(positionColumn.x, positionColumn.y, positionColumn.z)
              cameraDirection = SCNVector3(
                  -cameraTransform.columns.2.x,
                  -cameraTransform.columns.2.y,
                  -cameraTransform.columns.2.z
              )
              
              print("📍 Using camera transform from AR session")
          } else {
              // Use default position and direction
              cameraPosition = SCNVector3(0, 0, 0)
              cameraDirection = SCNVector3(0, 0, -1)
              print("⚠️ No camera transform available, using default values")
          }
          
          // Position the label 0.5 meters in front of the camera
          let position = SCNVector3(
              cameraPosition.x + cameraDirection.x * 0.5,
              cameraPosition.y + cameraDirection.y * 0.5,
              cameraPosition.z + cameraDirection.z * 0.5
          )
          
          print("📍 Using camera-relative position: \(position)")
          
          // Create and place the AR label node
          let node = arSceneManager.createNewBubbleParentNode(
            english: detection.english,
            chinese: detection.chinese,
            pinyin: detection.pinyin
          )
          
          // Make sure node is fully visible
          node.opacity = 1.0
          node.renderingOrder = 3000
          
          // Add the node to the scene
          arSceneManager.sceneView.scene.rootNode.addChildNode(node)
          node.position = position
          
          // Add to placed nodes array
          arSceneManager.placedNodes.append(node)
          
          // Add to hidden set
          hiddenObjectLabels.insert(detection.english)
          
          // Provide feedback
          selection.selectionChanged()
          
          // Play pronunciation
          arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          
          print("✅ AR label placed at fixed position in front of camera: \(position)")
          print("📊 Total placed nodes: \(arSceneManager.placedNodes.count)")
          
          // Update debug info after placing node
          updateARDebugInfo()
      }
      
      // Force UI updates
      DispatchQueue.main.async {
          // Force update the view hierarchy
          self.view.bringSubviewToFront(self.videoPreview)
          if let debugLabel = self.debugLabel {
              self.view.bringSubviewToFront(debugLabel)
              // Make the debug label more visible
              debugLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
              debugLabel.textColor = UIColor.white
              debugLabel.layer.zPosition = 1000
          }
          self.view.bringSubviewToFront(self.toolBar)
          
          // Make AR view visible
          self.arSceneManager.sceneView.isHidden = false
          self.arSceneManager.sceneView.alpha = 1.0
          
          // Update AR debug info again after UI changes
          self.updateARDebugInfo()
      }
  }

  // Update debug label with AR information
  func updateARDebugInfo() {
      // Get current AR session state
      let sessionConfig = arSceneManager.sceneView.session.configuration != nil ? "Active" : "Not configured"
      let currentFrame = arSceneManager.sceneView.session.currentFrame != nil ? "Available" : "Not available"
      let nodesCount = arSceneManager.placedNodes.count
      
      // Get AR view info
      let arViewInHierarchy = arSceneManager.sceneView.superview != nil ? "In hierarchy" : "Not in hierarchy"
      let arViewHidden = arSceneManager.sceneView.isHidden ? "Hidden" : "Visible"
      let arViewAlpha = String(format: "%.2f", arSceneManager.sceneView.alpha)
      
      // Create debug text
      let debugText = """
      AR Session: \(sessionConfig)
      Current Frame: \(currentFrame)
      AR Nodes: \(nodesCount)
      AR View: \(arViewInHierarchy), \(arViewHidden), Alpha: \(arViewAlpha)
      Current Detection: \(currentDetection?.english ?? "None")
      """
      
      // Update debug label
      debugLabel?.text = debugText
  }

  // Ensure bounding boxes are properly configured for tapping
  func ensureBoundingBoxesAreTappable() {
      print("🔍 Checking bounding box tap configuration")
      
      var tappableCount = 0
      var untappableCount = 0
      
      for (index, boxView) in boundingBoxViews.enumerated() {
          if !boxView.isHidden {
              // Make sure the box is visible and interactive
              boxView.isUserInteractionEnabled = true
              boxView.alpha = 1.0
              
              // Make sure it has a tap gesture recognizer
              var hasTapGesture = false
              if let gestures = boxView.gestureRecognizers {
                  for gesture in gestures {
                      if gesture is UITapGestureRecognizer {
                          hasTapGesture = true
                          break
                      }
                  }
              }
              
              // If no tap gesture, add one
              if !hasTapGesture {
                  print("⚠️ Adding missing tap gesture to box \(index)")
                  let tapGesture = UITapGestureRecognizer(target: self, action: #selector(boundingBoxTapped(_:)))
                  boxView.addGestureRecognizer(tapGesture)
              }
              
              // Ensure it's in front of other views
              videoPreview.bringSubviewToFront(boxView)
              
              // Print debug info about this box
              print("📦 Box \(index): \(boxView.className), frame: \(boxView.frame), interactive: \(boxView.isUserInteractionEnabled)")
              
              tappableCount += 1
          } else {
              untappableCount += 1
          }
      }
      
      print("📊 Bounding box status: \(tappableCount) tappable, \(untappableCount) hidden")
  }

  // Direct placement of AR label with guaranteed visibility
  func placeARLabelGuaranteed(for detection: (english: String, chinese: String, pinyin: String)) {
      print("🚀 GUARANTEED AR LABEL PLACEMENT for \(detection.english)")
      
      // Make sure AR view is fully visible
      arSceneManager.sceneView.isHidden = false
      arSceneManager.sceneView.alpha = 1.0
      
      // Make sure video preview is semi-transparent
      videoPreview.alpha = 0.7
      
      // Ensure AR view is in hierarchy
      if arSceneManager.sceneView.superview == nil {
          view.insertSubview(arSceneManager.sceneView, belowSubview: videoPreview)
          print("⚠️ Had to add AR view to hierarchy")
      }
      
      // Force configurating AR view for text visibility
      arSceneManager.configureARViewForTextOnly()
      
      // Create the node for the AR label
      let node = arSceneManager.createNewBubbleParentNode(
                        english: detection.english,
                        chinese: detection.chinese,
                        pinyin: detection.pinyin
                    )
                    
      // Make the node extremely visible
      node.opacity = 1.0
      node.renderingOrder = 3000
      node.scale = SCNVector3(1.2, 1.2, 1.2)
      
      // Apply visibility settings to all children
      for childNode in node.childNodes {
          childNode.opacity = 1.0
          childNode.renderingOrder = 3000
      }
      
      // Determine position directly in front of camera
      var position = SCNVector3(0, 0, -0.5) // Default fallback
      
      if let frame = arSceneManager.sceneView.session.currentFrame {
          // Use camera position and direction
          let cameraTransform = frame.camera.transform
          let cameraPos = SCNVector3(
              cameraTransform.columns.3.x,
              cameraTransform.columns.3.y,
              cameraTransform.columns.3.z
          )
          
          let cameraDir = SCNVector3(
              -cameraTransform.columns.2.x,
              -cameraTransform.columns.2.y,
              -cameraTransform.columns.2.z
          )
          
          // Position 0.5 meters in front of camera
          position = SCNVector3(
              cameraPos.x + cameraDir.x * 0.5,
              cameraPos.y + cameraDir.y * 0.5,
              cameraPos.z + cameraDir.z * 0.5
          )
          print("📍 Positioning at camera-relative position: \(position)")
      } else {
          print("⚠️ No camera frame available, using default position")
      }
      
      // Add node to scene
      arSceneManager.sceneView.scene.rootNode.addChildNode(node)
      node.position = position
      
      // Add to placed nodes array
      arSceneManager.placedNodes.append(node)
      
      // Force UI updates
      view.bringSubviewToFront(videoPreview)
      if let debugLabel = debugLabel {
          view.bringSubviewToFront(debugLabel)
      }
      view.bringSubviewToFront(toolBar)
      
      // Play pronunciation 
      arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
      
      print("✅ AR label placed at: \(position), total placed nodes: \(arSceneManager.placedNodes.count)")
      
      // Update debug info
      updateARDebugInfo()
  }

  // Add a test label button to the toolbar
  func addTestLabelButton() {
    // Create a button with a clear icon
    let testButton = UIBarButtonItem(
        title: "Test Label",
        style: .plain,
        target: self,
        action: #selector(testLabelButtonPressed)
    )
    
    // Add to toolbar items
    var items = toolBar.items ?? []
    items.append(testButton)
    toolBar.items = items
    
    print("✅ Test label button added to toolbar")
  }

  // Handle test label button press
  @objc func testLabelButtonPressed() {
    print("🔍 Test label button pressed")
    
    // Create a test detection
    let testDetection = (english: "TEST OBJECT", chinese: "测试物体", pinyin: "cèshì wùtǐ")
    
    // Place AR label using direct placement method
    placeARLabelInFrontOfCamera(for: testDetection)
    
    // Also add a test label using ARSceneManager's method
    arSceneManager.addTestLabel()
    
    // Provide feedback
    selection.selectionChanged()
    showToast(message: "Test label added")
    
    // Update debug info
    updateARDebugInfo()
  }


// Place an AR label directly in front of the camera without hit testing
func placeARLabelInFrontOfCamera(for detection: (english: String, chinese: String, pinyin: String)) {
    print("🎯 Placing AR label directly in front of camera for: \(detection.english)")
    
    // Make sure the AR view is visible and in the hierarchy
    if arSceneManager.sceneView.superview == nil {
        view.insertSubview(arSceneManager.sceneView, at: 0)
        print("⚠️ Had to add AR view to hierarchy")
    }
    
    // Make sure AR view is fully visible
    arSceneManager.sceneView.isHidden = false
    arSceneManager.sceneView.alpha = 1.0
    
    // Make video preview semi-transparent
    videoPreview.alpha = 0.7
    
    // Force configurating AR view for text visibility
    arSceneManager.configureARViewForTextOnly()
    
    // Create the AR text node
    let node = arSceneManager.createNewBubbleParentNode(
        english: detection.english,
        chinese: detection.chinese,
        pinyin: detection.pinyin
    )
    
    // Position directly in front of the camera
    var position = SCNVector3(0, 0, -0.5) // Default fallback position
    
    if let frame = arSceneManager.sceneView.session.currentFrame {
        // Get camera position and orientation
        let cameraTransform = frame.camera.transform
        let cameraPosition = SCNVector3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        let cameraDirection = SCNVector3(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        )
        
        // Position 0.5 meters in front of camera
        position = SCNVector3(
            cameraPosition.x + cameraDirection.x * 0.5,
            cameraPosition.y + cameraDirection.y * 0.5,
            cameraPosition.z + cameraDirection.z * 0.5
        )
    } else {
        print("⚠️ No camera frame available, using default position")
        
        // Try to set the AR session config if missing
        if arSceneManager.sceneView.session.configuration == nil {
            arSceneManager.resumeARSession()
        }
    }
    
    // Add the node to the scene
    arSceneManager.sceneView.scene.rootNode.addChildNode(node)
    node.position = position
    
    // Add to placed nodes array
    arSceneManager.placedNodes.append(node)
    
    // Add to hidden object labels set
    hiddenObjectLabels.insert(detection.english)
    
    // Play pronunciation audio
    arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
    
    print("✅ AR label placed at position: \(position)")
    
    // Update debug info
    updateARDebugInfo()
}

// Update createARLabelForBox to use the direct method
func createARLabelForBox(_ boxView: BoundingBoxView) {
    let className = boxView.className
    print("🏷️ Creating AR label for box: \(className)")
    
    if className.isEmpty {
        print("❌ No class name available for this box")
        return
    }
    
    // Get translation for the class name
    if let translation = translationManager.getTranslation(for: className) {
        print("✅ Found translation for: \(className) - \(translation.chinese) (\(translation.pinyin))")
        
        // Create a detection info tuple
        let detectionInfo = (english: className, chinese: translation.chinese, pinyin: translation.pinyin)
        
        // Update current detection
        currentDetection = detectionInfo
        print("✅ Current detection updated: \(detectionInfo.english)")
        
        // Hide the bounding box
        boxView.hide()
        print("✅ Bounding box hidden")
        
        // Add to hidden sets
        hiddenObjectLabels.insert(className)
        hiddenBoxes.insert(className)
        print("✅ Added \(className) to hidden sets")
        
        // Place AR label directly in front of camera - no hit testing
        placeARLabelInFrontOfCamera(for: detectionInfo)
        
        // Make sure video preview is semi-transparent to see AR content
        videoPreview.alpha = 0.7
        
        // Provide haptic feedback
        selection.selectionChanged()
        
        // Show a toast message
        showToast(message: "Added AR label for: \(className)")
    } else {
        print("❌ No translation found for: \(className)")
        showToast(message: "No translation available for: \(className)")
    }
  }
}

// MARK: - SwiftUI Views for Detection Popup

/// SwiftUI view for displaying detected object information
struct DetectionPopupView: View {
    let english: String
    let chinese: String
    let pinyin: String
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onSpeak: () -> Void
    
    @State private var isRecording = false
    @State private var hasPronounced = false
    @State private var showFeedback = false
    @State private var feedbackMessage = ""
    @State private var feedbackColor = Color.gray
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 10) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 20)
                }
                
                // Object information
                Text(chinese)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.red)
                
                HStack(spacing: 8) {
                    Text(pinyin)
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                Text(english)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                // Pronunciation recording button
                Button(action: {
                    isRecording.toggle()
                    if !isRecording {
                        // Simulate pronunciation assessment
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isProcessing = false
                            hasPronounced = true
                            showFeedback = true
                            feedbackMessage = "Good pronunciation! Score: 85/100"
                            feedbackColor = .green
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.blue)
                            .frame(width: 60, height: 60)
                        
                        if isRecording {
                            Circle()
                                .stroke(Color.red, lineWidth: 4)
                                .frame(width: 70, height: 70)
                        }
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isProcessing)
                .padding(.vertical, 5)
                
                // Loading indicator during API processing
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .padding(.vertical, 5)
                }
                
                // Feedback message
                if showFeedback {
                    Text(feedbackMessage)
                        .font(.headline)
                        .foregroundColor(feedbackColor)
                        .padding()
                        .background(feedbackColor.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    // Close button
                    Button(action: onDismiss) {
                        Text("Close")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 100)
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
                    
                    // Save button - only enabled after pronunciation
                    Button(action: onSave) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 100)
                            .background(hasPronounced ? Color.green : Color.gray.opacity(0.5))
                            .cornerRadius(10)
                    }
                    .disabled(!hasPronounced)
                }
                .padding(.top, 10)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            Spacer()
        }
    }
}

extension ViewController: VideoCaptureDelegate {
  func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame sampleBuffer: CMSampleBuffer) {
    predict(sampleBuffer: sampleBuffer)
  }
}

// Programmatically save image
extension ViewController: AVCapturePhotoCaptureDelegate {
  func photoOutput(
    _ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?
  ) {
    if let error = error {
      print("error occurred : \(error.localizedDescription)")
    }
    if let dataImage = photo.fileDataRepresentation() {
      let dataProvider = CGDataProvider(data: dataImage as CFData)
      let cgImageRef: CGImage! = CGImage(
        jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent)
      var isCameraFront = false
      if let currentInput = self.videoCapture.captureSession.inputs.first as? AVCaptureDeviceInput,
        currentInput.device.position == .front
      {
        isCameraFront = true
      }
      var orientation: CGImagePropertyOrientation = isCameraFront ? .leftMirrored : .right
      switch UIDevice.current.orientation {
      case .landscapeLeft:
        orientation = isCameraFront ? .downMirrored : .up
      case .landscapeRight:
        orientation = isCameraFront ? .upMirrored : .down
      default:
        break
      }
      var image = UIImage(cgImage: cgImageRef, scale: 0.5, orientation: .right)
      if let orientedCIImage = CIImage(image: image)?.oriented(orientation),
        let cgImage = CIContext().createCGImage(orientedCIImage, from: orientedCIImage.extent)
      {
        image = UIImage(cgImage: cgImage)
      }
      let imageView = UIImageView(image: image)
      imageView.contentMode = .scaleAspectFill
      imageView.frame = videoPreview.frame
      let imageLayer = imageView.layer
      videoPreview.layer.insertSublayer(imageLayer, above: videoCapture.previewLayer)

      let bounds = UIScreen.main.bounds
      UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0.0)
      self.View0.drawHierarchy(in: bounds, afterScreenUpdates: true)
      let img = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      imageLayer.removeFromSuperlayer()
      let activityViewController = UIActivityViewController(
        activityItems: [img!], applicationActivities: nil)
      activityViewController.popoverPresentationController?.sourceView = self.View0
      self.present(activityViewController, animated: true, completion: nil)
      //
      //            // Save to camera roll
      //            UIImageWriteToSavedPhotosAlbum(img!, nil, nil, nil);
    } else {
      print("AVCapturePhotoCaptureDelegate Error")
    }
  }
}

// Extension to make transparent views not intercept touches
extension ViewController {
    // Override the viewDidLoad method to add a custom subclass for video preview
    func setupTransparentInteraction() {
        // Create a custom UIView subclass for videoPreview if it's not already
        if !(videoPreview is PassThroughView) && videoPreview != nil {
            let oldVideoPreview = videoPreview!
            let newVideoPreview = PassThroughView(frame: oldVideoPreview.frame)
            
            // Transfer all properties and subviews to the new view
            newVideoPreview.backgroundColor = oldVideoPreview.backgroundColor
            newVideoPreview.isUserInteractionEnabled = oldVideoPreview.isUserInteractionEnabled
            
            for subview in oldVideoPreview.subviews {
                subview.removeFromSuperview()
                newVideoPreview.addSubview(subview)
            }
            
            // Transfer gesture recognizers
            for gesture in oldVideoPreview.gestureRecognizers ?? [] {
                oldVideoPreview.removeGestureRecognizer(gesture)
                newVideoPreview.addGestureRecognizer(gesture)
            }
            
            // Replace in view hierarchy
            if let superview = oldVideoPreview.superview, let index = superview.subviews.firstIndex(of: oldVideoPreview) {
                superview.insertSubview(newVideoPreview, at: index)
                oldVideoPreview.removeFromSuperview()
            }
            
            // Set the custom view as videoPreview
            videoPreview = newVideoPreview
            
            // Add any additional layers (like preview layer)
            if let previewLayer = videoCapture?.previewLayer {
                videoPreview.layer.addSublayer(previewLayer)
                videoCapture.previewLayer?.frame = videoPreview.bounds
            }
        }
    }
}

// Custom UIView subclass that passes touches to lower views in specific areas
class PassThroughView: UIView {
    // Store a reference to the toolbar, if available
    weak var toolbar: UIToolbar?
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Check if we have a toolbar reference
        if let toolbar = toolbar {
            // Convert point to toolbar's coordinate space
            let pointInToolbar = convert(point, to: toolbar.superview)
            
            // If the point is inside the toolbar, return false to pass the touch through
            if toolbar.frame.contains(pointInToolbar) {
                return false
            }
        }
        
        // First check if the point is inside any bounding box
        for subview in subviews {
            if let boxView = subview as? BoundingBoxView,
               !boxView.isHidden && boxView.isUserInteractionEnabled && boxView.frame.contains(point) {
                print("Touch inside bounding box: \(boxView.className)")
                return true
            }
        }
        
        // If there's a visible layer at this point, handle touch
        if let previewLayer = layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            return previewLayer.frame.contains(point) && previewLayer.opacity > 0.3
        }
        
        // For all other cases, allow the touch to pass through
        return false
  }
}
