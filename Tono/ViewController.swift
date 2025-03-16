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
  private var arToggleButton: UIButton?
  private var resetARButton: UIButton?
  
  // Track the last detected class to avoid duplicate logging
  private var lastDetectedClass: String?
  
  // Track the last time we synchronized AR labels with bounding boxes
  private var lastARSyncTime: CFTimeInterval = 0
  private var lastARRefreshTime: CFTimeInterval = 0
  private var arTrackingStateTimer: Timer?
  private var arStatusLabel: UILabel?
  private var refreshARButton: UIButton?
  private var arContainerView: UIView? // Our container for AR object views

  // Add property to store tagged detections
  private var taggedDetections: [(english: String, chinese: String, pinyin: String, worldPosition: simd_float4x4)] = []
  
  // Track hidden bounding boxes by class name
  private var hiddenBoxes: Set<String> = []
  
  // For backwards compatibility with existing code
  private var isARActive: Bool {
    // With our container approach, AR is always considered active
    return true
  }

  // MARK: - View Lifecycle

  // Helper method to check camera permissions
  private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        print("Camera access already authorized")
        completion(true)
    case .notDetermined:
        print("Camera access not determined, requesting...")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("Camera access \(granted ? "granted" : "denied")")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    case .denied, .restricted:
        print("Camera access denied or restricted")
        // Show alert to the user
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please enable camera access in Settings to use this app.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
        completion(false)
    @unknown default:
        print("Unknown camera authorization status")
        completion(false)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    print("ViewController - viewDidLoad")
    
    slider.value = 30
    setLabels()
    setUpBoundingBoxViews()
    setUpOrientationChangeNotification()
    
    // Initialize AR Scene Manager
    arSceneManager = ARSceneManager(viewController: self)
    
    // =====  COMPLETELY NEW APPROACH =====
    // Try a drastically different approach - separate the AR view 
    // and video preview into two completely different layers
    
    // 1. First, ensure the video preview is visible and correctly configured
    // Important: Don't remove from superview - this might be causing issues with camera feed
    videoPreview.frame = view.bounds
    videoPreview.alpha = 1.0
    videoPreview.isHidden = false
    videoPreview.backgroundColor = .black // Ensure black background for video
    
    // Ensure the videoPreview is in the view hierarchy
    if videoPreview.superview == nil {
        view.addSubview(videoPreview)
    }
    
    // 2. Setup view hierarchy first - from bottom to top:
    // 1. Camera feed (videoPreview)
    // 2. AR object labels (objectsContainer)
    // 3. Bounding boxes (added to videoPreview)
    // 4. Toolbar stays at the top
    
    // First, make sure the video preview is at the bottom
    view.bringSubviewToFront(videoPreview)
    
    // Next, create the AR container which will go above the camera feed
    let objectsContainer = UIView(frame: view.bounds)
    objectsContainer.backgroundColor = UIColor.clear
    objectsContainer.isOpaque = false
    objectsContainer.clipsToBounds = false // Allow labels to extend beyond bounds
    
    // Enable user interaction for label taps
    objectsContainer.isUserInteractionEnabled = true
    
    // Add the container above the video preview
    view.addSubview(objectsContainer)
    view.bringSubviewToFront(objectsContainer)
    
    // No test labels anymore - we'll only add labels when user taps on objects
    
    print("AR container view ready for user interaction")
    
    // 3. Now add the AR view, but completely hidden
    arSceneManager.sceneView.removeFromSuperview()
    arSceneManager.sceneView.frame = CGRect(x: -1000, y: -1000, width: 100, height: 100) // Off-screen
    arSceneManager.sceneView.alpha = 0.01 // Nearly invisible but still tracking
    view.addSubview(arSceneManager.sceneView)
    arSceneManager.sceneView.isUserInteractionEnabled = false // Don't interact with it directly
    
    // 4. We'll use the AR tracking but render objects in our own container
    // This is a brute-force approach but should avoid any rendering conflicts
    
    // We'll handle this in setupARSession
    
    // Store a reference to our objects container view
    self.arContainerView = objectsContainer
    
    // Make sure the toolbar is on top of all other views so it can receive touch events
    if let toolBar = self.toolBar {
        self.view.bringSubviewToFront(toolBar)
    }
    
    // Set up AR session immediately for continuous use - but off screen
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.arSceneManager.setupARSession()
        
        // Since we're now using a different approach, don't show the tracking state
        // but still monitor it in the background
        self.startARTrackingStateMonitoring()
        
        // Load saved objects but render them in our container view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadSavedARObjectsInContainer()
        }
    }
    
    // Add AR toggle button
    addARToggleButton()
    
    // Add a tap gesture recognizer to the video preview view
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoPreviewTapped(_:)))
    videoPreview.addGestureRecognizer(tapGesture)
    videoPreview.isUserInteractionEnabled = true
    
    // Keep the video preview fully opaque
    videoPreview.alpha = 1.0
    
    // Add AR status indicator
    setupARStatusLabel()
    
    // Start AR tracking monitoring
    startARTrackingStateMonitoring()
    
    // Make sure toolbar is interactive before starting video
    ensureToolbarIsInFront()
    
    // Check camera permission before starting video
    checkCameraPermission { [weak self] granted in
        guard let self = self else { return }
        
        if granted {
            print("Permission granted, starting video capture")
            self.startVideo()
        } else {
            print("Camera permission denied")
            // Show a placeholder or message indicating camera is not available
            let cameraErrorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 80))
            cameraErrorLabel.center = self.view.center
            cameraErrorLabel.textAlignment = .center
            cameraErrorLabel.numberOfLines = 0
            cameraErrorLabel.text = "Camera access required.\nPlease enable in Settings."
            cameraErrorLabel.textColor = .white
            cameraErrorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            self.videoPreview.addSubview(cameraErrorLabel)
        }
    }
    
    // Fix issue with toolbar not being clickable by bringing it to front again
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.ensureToolbarIsInFront()
        self.playButtonOutlet.isEnabled = true
        self.pauseButtonOutlet.isEnabled = false
    }
    
    // Initialize play/pause state correctly
    self.pauseButtonOutlet.isEnabled = false
    self.playButtonOutlet.isEnabled = true
    
    // setModel()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Start AR session
    arSceneManager.setupARSession()
    
    // Clear all Core Data objects on app startup - start fresh each time
    // This prevents the old labels from reappearing
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.clearCoreDataObjects()
    }
  }
  
  // Helper method to ensure toolbar is always at the front of the view hierarchy
  private func ensureToolbarIsInFront() {
    if let toolBar = self.toolBar {
        self.view.bringSubviewToFront(toolBar)
    }
  }
  
  // COMPLETELY NEW APPROACH: Render AR objects as UIViews in a separate container
  private func loadSavedARObjectsInContainer() {
    // Clear our container view
    self.arContainerView?.subviews.forEach { $0.removeFromSuperview() }
    
    print("Loading objects into container view")
    
    // Remove static test objects since we don't need them anymore
    // We'll only show objects that the user has explicitly tagged
    
    // Fetch saved objects from Core Data
    let savedObjects = self.persistenceController.fetchTaggedObjects(context: self.managedObjectContext)
    
    // If we have saved objects in Core Data, add those as well
    if !savedObjects.isEmpty {
        print("Loading \(savedObjects.count) additional objects from Core Data into container view")
        
        // Display all saved objects
        for (index, object) in savedObjects.enumerated() {
            print("Processing saved object \(index): \(object.english ?? "unknown")")
            
            // Create a simple UILabel for the object
            let objectLabel = createObjectLabel(
                english: object.english ?? "unknown",
                chinese: object.chinese ?? "",
                pinyin: object.pinyin ?? ""
            )
            
            // Position it approximately based on stored 3D coordinates
            let position = object.position
            let screenPoint = convertWorldPositionToScreenPoint(position)
            objectLabel.center = screenPoint
            
            // Add to our container
            self.arContainerView?.addSubview(objectLabel)
        }
    } else {
        print("No saved objects found in Core Data, using only test objects")
    }
    
    // Make sure the toolbar remains on top after adding AR objects
    ensureToolbarIsInFront()
  }
  
  // Helper method to create an object label
  private func createObjectLabel(english: String, chinese: String, pinyin: String) -> UIView {
    // Create a container view for the label
    let containerView = UIView()
    containerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
    containerView.layer.cornerRadius = 10
    
    // Add a border for better visibility
    containerView.layer.borderWidth = 2
    containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
    
    // Add drop shadow
    containerView.layer.shadowColor = UIColor.black.cgColor
    containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
    containerView.layer.shadowOpacity = 0.8
    containerView.layer.shadowRadius = 4
    
    // Create the Chinese label
    let chineseLabel = UILabel()
    chineseLabel.text = chinese
    chineseLabel.textColor = UIColor.red
    chineseLabel.font = UIFont.boldSystemFont(ofSize: 20)
    chineseLabel.textAlignment = .center
    
    // Create the pinyin label
    let pinyinLabel = UILabel()
    pinyinLabel.text = pinyin
    pinyinLabel.textColor = UIColor.yellow
    pinyinLabel.font = UIFont.systemFont(ofSize: 16)
    pinyinLabel.textAlignment = .center
    
    // Create the English label
    let englishLabel = UILabel()
    englishLabel.text = english
    englishLabel.textColor = UIColor.white
    englishLabel.font = UIFont.systemFont(ofSize: 14)
    englishLabel.textAlignment = .center
    
    // Add labels to container
    containerView.addSubview(chineseLabel)
    containerView.addSubview(pinyinLabel)
    containerView.addSubview(englishLabel)
    
    // Size the container and position labels - make it bigger
    containerView.frame = CGRect(x: 0, y: 0, width: 180, height: 100)
    chineseLabel.frame = CGRect(x: 0, y: 10, width: 180, height: 30)
    pinyinLabel.frame = CGRect(x: 0, y: 45, width: 180, height: 25)
    englishLabel.frame = CGRect(x: 0, y: 70, width: 180, height: 25)
    
    // Add a subtle animation to make it more noticeable
    UIView.animate(withDuration: 0.5, animations: {
        containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    }) { _ in
        UIView.animate(withDuration: 0.3) {
            containerView.transform = .identity
        }
    }
    
    // Make the label tappable
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(objectLabelTapped(_:)))
    containerView.addGestureRecognizer(tapGesture)
    containerView.isUserInteractionEnabled = true
    
    // Store data in the view's tag
    containerView.accessibilityLabel = "\(english)|\(chinese)|\(pinyin)"
    
    return containerView
  }
  
  // Helper to convert 3D position to screen coordinates
  private func convertWorldPositionToScreenPoint(_ worldPosition: SCNVector3) -> CGPoint {
    // For now, just use a very simple mapping to screen coordinates
    // This is a placeholder - ideally we'd use proper AR projection
    let screenWidth = self.view.bounds.width
    let screenHeight = self.view.bounds.height
    
    // Map from [-1, 1] range to screen coordinates
    let x = screenWidth/2 + CGFloat(worldPosition.x) * screenWidth/2
    let y = screenHeight/2 - CGFloat(worldPosition.z) * screenHeight/2
    
    return CGPoint(x: x, y: y)
  }
  
  // Handle taps on object labels
  @objc func objectLabelTapped(_ gesture: UITapGestureRecognizer) {
    guard let containerView = gesture.view,
          let labelData = containerView.accessibilityLabel?.components(separatedBy: "|"),
          labelData.count >= 3 else {
        return
    }
    
    let english = labelData[0]
    let chinese = labelData[1]
    let pinyin = labelData[2]
    
    // Play pronunciation
    arSceneManager.playPronunciation(for: chinese, pinyin: pinyin)
    
    // Animate the label to give feedback
    UIView.animate(withDuration: 0.1, animations: {
        containerView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
    }) { _ in
        UIView.animate(withDuration: 0.1) {
            containerView.transform = .identity
        }
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Stop AR tracking monitoring
    stopARTrackingStateMonitoring()
    
    // Pause AR session
    arSceneManager.pauseARSession()
  }
  
  // Setup AR status label
  private func setupARStatusLabel() {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    label.textColor = .white
    label.textAlignment = .center
    label.layer.cornerRadius = 10
    label.clipsToBounds = true
    label.isHidden = true // Initially hidden
    label.font = UIFont.systemFont(ofSize: 12)
    label.text = "AR: Normal"
    label.alpha = 0.0
    
    view.addSubview(label)
    
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.widthAnchor.constraint(equalToConstant: 150),
      label.heightAnchor.constraint(equalToConstant: 30)
    ])
    
    arStatusLabel = label
  }
  
  // Start monitoring AR tracking state
  private func startARTrackingStateMonitoring() {
    // Cancel any existing timer
    stopARTrackingStateMonitoring()
    
    // Start a new timer that checks tracking state every 1 second
    arTrackingStateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.updateARTrackingState()
    }
  }
  
  // Stop monitoring AR tracking state
  private func stopARTrackingStateMonitoring() {
    arTrackingStateTimer?.invalidate()
    arTrackingStateTimer = nil
  }
  
  // Update AR tracking state and UI
  private func updateARTrackingState() {
    // AR view is always visible now
    
    // Get current tracking state
    if let frame = arSceneManager.sceneView.session.currentFrame {
      let trackingState = frame.camera.trackingState
      
      // Update status label based on tracking state
      switch trackingState {
      case .normal:
        arStatusLabel?.text = "AR: Normal"
        arStatusLabel?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6)
        // Hide reset button if tracking is normal
        resetARButton?.isHidden = true
      case .limited(let reason):
        // Show different message based on reason
        switch reason {
        case .excessiveMotion:
          arStatusLabel?.text = "AR: Move Slower"
        case .initializing:
          arStatusLabel?.text = "AR: Initializing..."
        case .insufficientFeatures:
          arStatusLabel?.text = "AR: Scan Area"
        case .relocalizing:
          arStatusLabel?.text = "AR: Relocalizing..."
        @unknown default:
          arStatusLabel?.text = "AR: Limited"
        }
        arStatusLabel?.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.6)
        // Show the reset button when tracking is limited
        resetARButton?.isHidden = false
      case .notAvailable:
        arStatusLabel?.text = "AR: Not Available"
        arStatusLabel?.backgroundColor = UIColor.systemRed.withAlphaComponent(0.6)
        // Show reset button if tracking is not available
        resetARButton?.isHidden = false
      @unknown default:
        arStatusLabel?.text = "AR: Unknown"
        arStatusLabel?.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
      }
      
      // Make status label visible with animation
      UIView.animate(withDuration: 0.3) {
        self.arStatusLabel?.alpha = 1.0
      }
    }
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

  @IBAction func playButton(_ sender: Any) {
    selection.selectionChanged()
    
    // Don't try to start if video capture is already running
    if videoCapture?.captureSession.isRunning == false {
        self.videoCapture.start()
    } else {
        print("Video capture is already running")
    }
    
    playButtonOutlet.isEnabled = false
    pauseButtonOutlet.isEnabled = true
    
    // Also resume AR session to keep them in sync
    // Always resume AR session when video starts
    arSceneManager.resumeARSession()
    
    // Make sure the toolbar stays in front
    ensureToolbarIsInFront()
  }

  @IBAction func pauseButton(_ sender: Any?) {
    selection.selectionChanged()
    
    // Don't try to stop if video capture is already stopped
    if videoCapture?.captureSession.isRunning == true {
        self.videoCapture.stop()
    } else {
        print("Video capture is already stopped")
    }
    
    playButtonOutlet.isEnabled = true
    pauseButtonOutlet.isEnabled = false
    
    // Also pause AR session to keep them in sync
    // Always pause AR session when video stops
    arSceneManager.pauseARSession()
    
    // Make sure the toolbar stays in front
    ensureToolbarIsInFront()
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
      boxView.tag = boundingBoxViews.count - 1
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
  }

  func startVideo() {
    // Only initialize VideoCapture if it doesn't exist yet
    if videoCapture == nil {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        
        // Print debug info
        print("Setting up video capture")
        
        videoCapture.setUp(sessionPreset: .photo) { success in
          // .hd4K3840x2160 or .photo (4032x3024)  Warning: 4k may not work on all devices i.e. 2019 iPod
          if success {
            print("Video capture setup successful")
            
            // Add the video preview into the UI.
            if let previewLayer = self.videoCapture.previewLayer {
              // First ensure the videoPreview is visible and properly sized
              self.videoPreview.isHidden = false
              self.videoPreview.alpha = 1.0
              self.videoPreview.frame = self.view.bounds
              
              // Remove any existing preview layers to avoid duplication
              for layer in self.videoPreview.layer.sublayers ?? [] {
                if layer is AVCaptureVideoPreviewLayer {
                  layer.removeFromSuperlayer()
                }
              }
              
              // Add and configure the preview layer
              self.videoPreview.layer.addSublayer(previewLayer)
              previewLayer.frame = self.videoPreview.bounds
              previewLayer.videoGravity = .resizeAspectFill
              
              print("Preview layer added with frame: \(previewLayer.frame)")
            } else {
              print("Failed to get preview layer from video capture")
            }
    
            // Bring bounding box views to front
            for boxView in self.boundingBoxViews {
              self.videoPreview.bringSubviewToFront(boxView)
            }
            
            // Ensure video preview is in the right place in view hierarchy
            self.view.bringSubviewToFront(self.videoPreview)
            
            // At initialization, we'll start the camera to ensure it's working
            if !self.videoCapture.captureSession.isRunning {
                print("Starting video capture")
                self.videoCapture.start()
                self.playButtonOutlet.isEnabled = false
                self.pauseButtonOutlet.isEnabled = true
            } else {
                print("Video capture already running")
                self.playButtonOutlet.isEnabled = false
                self.pauseButtonOutlet.isEnabled = true
            }
            
            // Make sure toolbar remains accessible after starting video
            self.ensureToolbarIsInFront()
            
            // Update camera position if needed
            self.videoCapture.updateVideoOrientation()
          } else {
            print("Video capture setup failed")
          }
        }
    } else {
        print("Using existing video capture")
        
        // VideoCapture already exists, make sure preview layer is still properly configured
        if let previewLayer = self.videoCapture.previewLayer {
            // Make sure frame is correct
            previewLayer.frame = self.videoPreview.bounds
            
            // Ensure preview layer is attached
            if previewLayer.superlayer == nil {
                self.videoPreview.layer.addSublayer(previewLayer)
                print("Re-attached preview layer")
            }
        }
        
        // Update button state based on camera running status
        if self.videoCapture.captureSession.isRunning {
            self.playButtonOutlet.isEnabled = false
            self.pauseButtonOutlet.isEnabled = true
        } else {
            self.playButtonOutlet.isEnabled = true
            self.pauseButtonOutlet.isEnabled = false
        }
        
        self.ensureToolbarIsInFront()
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
      /// - Tag: MappingOrientation
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
      if UIDevice.current.orientation != .faceUp {  // stop if placed down on a table
        t0 = CACurrentMediaTime()  // inference start
        do {
          try handler.perform([visionRequest])
        } catch {
          print(error)
        }
        t1 = CACurrentMediaTime() - t0  // inference dt
      }

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
          
          // If AR mode is active, update current detection
          if arSceneManager.sceneView.alpha > 0.5 {
            // Store the detection for later AR use
            self.currentDetection = (english: bestClass, chinese: translation.chinese, pinyin: translation.pinyin)
          }
        }
      }
    }
    
    // Make sure bounding box views are above AR content
    for boxView in boundingBoxViews {
      videoPreview.bringSubviewToFront(boxView)
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
              }
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

    // Update positions of existing AR labels to follow their objects,
    // but only occasionally to improve performance
    if arContainerView != nil && !arContainerView!.subviews.isEmpty {
      // Use a timer to avoid doing this on every frame
      let currentTime = CACurrentMediaTime()
      if currentTime - lastARSyncTime > 0.2 { // Update at ~5fps, not every frame
        lastARSyncTime = currentTime
        // If we have labels in the container, synchronize their positions with bounding boxes
        synchronizeARLabelsWithBoundingBoxes()
      }
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
    guard let boxView = gesture.view as? BoundingBoxView else {
        return
    }
    
    // Call the method that takes a BoundingBoxView directly
    handleBoundingBoxTap(boxView)
  }
  
  /// Handle tap on a bounding box - method that takes a BoundingBoxView directly
  /// UPDATED VERSION: Uses the place3DTextAtBoundingBox method directly
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
    
    // COMPLETELY CHANGED APPROACH: Use our container-based approach
    // This will handle all the animations, AR positioning, Core Data, etc.
    place3DTextAtBoundingBox(boxView, detection: detection)
    
    // Add class name to hidden set so we don't show boxes for this class anymore
    hiddenBoxes.insert(className)
    
    // Add haptic feedback for better user experience
    let selection = UISelectionFeedbackGenerator()
    selection.selectionChanged()
  }
  
  @objc func videoPreviewTapped(_ gesture: UITapGestureRecognizer) {
    // Get the tap location
    let location = gesture.location(in: videoPreview)
    
    // Check if AR mode is active
    let isARActive = arSceneManager.sceneView.alpha > 0.5
    
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
    
    // Only handle AR interactions if AR mode is active
    if isARActive {
        print("AR mode is active, forwarding tap to ARSceneManager")
        
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
  }

  /// Place text label at the position of a bounding box 
  /// Using the new container-based approach - ENHANCED VERSION FOR BETTER VISIBILITY
  private func place3DTextAtBoundingBox(_ boxView: BoundingBoxView, detection: (english: String, chinese: String, pinyin: String)) {
    // Create a visual transition effect
    let boxFrame = boxView.frame
    
    // Create a temporary view that matches the bounding box for animation
    let transitionView = UIView(frame: boxFrame)
    transitionView.layer.borderWidth = 4
    transitionView.layer.borderColor = UIColor.red.cgColor
    transitionView.layer.cornerRadius = 6
    transitionView.backgroundColor = UIColor.clear
    videoPreview.addSubview(transitionView)
    
    // Show flashy animation to make it clear something happened
    UIView.animate(withDuration: 0.2, animations: {
      transitionView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
      transitionView.backgroundColor = UIColor.yellow.withAlphaComponent(0.3)
      transitionView.alpha = 0.9
    }) { _ in
      // Hide the bounding box after animation completes
      boxView.hide()
      
      // Get the center of the bounding box in screen coordinates
      let boxCenter = CGPoint(
          x: boxView.frame.midX,
          y: boxView.frame.midY
      )
      
      print("Placing text label at screen coordinates: \(boxCenter) for detection: \(detection.english)")
      
      // MAKE SURE THE CONTAINER EXISTS
      if self.arContainerView == nil {
        print("ERROR: Container view does not exist, creating one now")
        let container = UIView(frame: self.view.bounds)
        container.backgroundColor = UIColor.clear
        container.isOpaque = false
        container.isUserInteractionEnabled = true
        self.view.addSubview(container)
        self.view.bringSubviewToFront(container)
        self.arContainerView = container
      }
      
      // Make sure the container is visible and in front
      self.arContainerView?.isHidden = false
      self.view.bringSubviewToFront(self.arContainerView!)
      
      // Create a label view in our container - with enhanced visibility
      let objectLabel = self.createObjectLabel(
          english: detection.english, 
          chinese: detection.chinese,
          pinyin: detection.pinyin
      )
      
      // Position it ABOVE the box center for better visibility
      objectLabel.center = CGPoint(
        x: boxCenter.x,
        y: boxCenter.y - 80 // Position above the box
      )
      
      // Store the class name in the accessibility label for tracking
      // Make sure we never have empty class names
      let safeEnglish = detection.english.isEmpty ? "unknown" : detection.english
      objectLabel.accessibilityLabel = "\(safeEnglish)|\(detection.chinese)|\(detection.pinyin)"
      
      // Add to our container
      self.arContainerView?.addSubview(objectLabel)
      
      // Make sure the container is in the view hierarchy
      print("Container view has \(self.arContainerView?.subviews.count ?? 0) subviews")
      
      // Make it spring into view with animation
      objectLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
      UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.3, options: [], animations: {
          objectLabel.transform = CGAffineTransform.identity
          objectLabel.layer.borderColor = UIColor.green.cgColor // Flash green border
      }, completion: { _ in
          // No permanent pulsing animation - just a brief pulse then stop
          UIView.animate(withDuration: 0.5, delay: 0, options: [.autoreverse, .allowUserInteraction], animations: {
              objectLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
          }, completion: { _ in
              objectLabel.transform = .identity
          })
      })
      
      // Play pronunciation
      self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
      
      // Remove the transition view with fade out
      UIView.animate(withDuration: 0.3, animations: {
        transitionView.alpha = 0
      }) { _ in
        transitionView.removeFromSuperview()
      }
      
      // Still save to Core Data with approximate position mapping
      // This is a simplified approach that doesn't rely on AR positioning
      let position = SCNVector3(
          x: Float((boxCenter.x / self.view.bounds.width) * 2 - 1),
          y: Float((boxCenter.y / self.view.bounds.height) * -2 + 1), 
          z: -0.5
      )
      
      // Save to Core Data for persistence
      self.persistenceController.saveTaggedObject(
          english: detection.english,
          chinese: detection.chinese,
          pinyin: detection.pinyin,
          image: nil,
          position: position,
          context: self.managedObjectContext
      )
      
      // Show toast confirmation
      self.showToast(message: "Added \(detection.english) - \(detection.chinese)")
      
      // Make sure toolbar stays in front
      self.ensureToolbarIsInFront()
    }
  }

  // MARK: - Container Labels
  
  // Clear all container labels and optionally CoreData
  private func clearContainerLabels(andCoreData: Bool = false) {
    guard let container = arContainerView else { return }
    
    // Remove all subviews with animation
    UIView.animate(withDuration: 0.3, animations: {
      for subview in container.subviews {
        subview.alpha = 0
      }
    }, completion: { _ in
      for subview in container.subviews {
        subview.removeFromSuperview()
      }
      
      // Optionally clear CoreData objects too
      if andCoreData {
        self.clearCoreDataObjects()
      }
    })
  }
  
  // Clear all stored objects from CoreData
  private func clearCoreDataObjects() {
    persistenceController.deleteAllTaggedObjects(context: managedObjectContext)
    taggedDetections.removeAll()
    print("Cleared all tagged objects from CoreData")
    
    // Show a confirmation toast
    showToast(message: "Cleared all saved object labels")
  }
  
  // MARK: - AR Integration
  
  // Update container labels to follow bounding boxes
  func synchronizeARLabelsWithBoundingBoxes() {
    // This function is now used to update the position of existing labels
    // to track the objects they're attached to
    
    guard let container = arContainerView else { return }
    
    // Filter visible bounding boxes with non-empty class names
    let visibleBoxes = boundingBoxViews.filter { !$0.isHidden && !$0.className.isEmpty }
    
    // Create a dictionary but handle potential duplicates
    var visibleBoxDict = [String: BoundingBoxView]()
    for box in visibleBoxes {
        // Use highest confidence boxes when there are duplicates
        if let existingBox = visibleBoxDict[box.className] {
            if box.confidence > existingBox.confidence {
                visibleBoxDict[box.className] = box
            }
        } else {
            visibleBoxDict[box.className] = box
        }
    }
    
    // For each label in the container, try to find a matching bounding box
    for subview in container.subviews {
        // Use the accessibilityLabel to find the matching class
        if let accessibilityLabel = subview.accessibilityLabel, !accessibilityLabel.isEmpty {
            let components = accessibilityLabel.split(separator: "|")
            if components.count >= 1 {
                let className = String(components[0])
                
                // If we have a visible box for this class, update the label position
                if let boxView = visibleBoxDict[className] {
                    // Calculate the label position above the box
                    let newPosition = CGPoint(
                        x: boxView.frame.midX,
                        y: boxView.frame.minY - 60 // Position above the box
                    )
                    
                    // Animate the position update
                    UIView.animate(withDuration: 0.2) {
                        subview.center = newPosition
                    }
                }
            }
        }
    }
    
  }
  
  // Fallback hit test for creating AR labels - now only used via direct user taps
  private func fallbackHitTestForBox(detection: (english: String, chinese: String, pinyin: String), boxCenter: CGPoint) {
    // Perform hit test to find 3D position
    if let hitResult = arSceneManager.sceneView.hitTest(boxCenter, types: [.featurePoint]).first {
      // Get coordinates of hit test
      let transform = hitResult.worldTransform
      let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
      
      createARLabelForBox(detection: detection, position: worldCoord)
    }
  }
  
  // Create AR label at the specified position
  private func createARLabelForBox(detection: (english: String, chinese: String, pinyin: String), position: SCNVector3) {
    // Create 3D text node
    let node = arSceneManager.createNewBubbleParentNode(
      english: detection.english,
      chinese: detection.chinese,
      pinyin: detection.pinyin
    )
    
    // Add node to scene
    arSceneManager.sceneView.scene.rootNode.addChildNode(node)
    node.position = position
    
    // Store the node
    arSceneManager.placedNodes.append(node)
  }
  
  // Toggle AR view visibility
  func toggleARView(visible: Bool) {
    if visible {
        print("Activating AR mode with \(taggedDetections.count) tagged detections")
        
        // We don't set up the AR session here because it's already running in the background
        // Resume the session if it was paused
        arSceneManager.resumeARSession()
        
        // Start tracking state monitoring
        startARTrackingStateMonitoring()
        
        // Make AR view fully visible with animation
        UIView.animate(withDuration: 0.5, animations: {
            self.arSceneManager.sceneView.alpha = 1.0
            // Make status label visible
            self.arStatusLabel?.isHidden = false
        }, completion: { _ in
            // Ensure the AR session is active and tracking
            self.arSceneManager.refreshARSession(reloadAnchors: false)
            
            // Update tracking state immediately
            self.updateARTrackingState()
            
            // Add AR content immediately after resuming tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Show toast messages with positioning tips
                self.showToast(message: "AR Mode Active - Showing \(self.taggedDetections.count) tagged objects")
                
                // After a delay, show positioning tips
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let frame = self.arSceneManager.sceneView.session.currentFrame {
                        if case .limited = frame.camera.trackingState {
                            self.showToast(message: "Move device slowly to improve tracking")
                        }
                    }
                }
                
                // Clear existing nodes before displaying new ones
                self.arSceneManager.clearLabels()
                
                // If we have no tagged detections, show a helpful message
                if self.taggedDetections.isEmpty {
                    self.showToast(message: "No tagged objects yet. Tap on objects to tag them.")
                    return
                }
                
                // Fetch saved objects from Core Data
                let savedObjects = self.persistenceController.fetchTaggedObjects(context: self.managedObjectContext)
                
                // If we have saved objects in Core Data, use those instead of in-memory tagged detections
                if !savedObjects.isEmpty {
                    print("Using \(savedObjects.count) objects from Core Data for AR view")
                    
                    // Display all saved objects
                    for (index, object) in savedObjects.enumerated() {
                        print("Processing saved object \(index): \(object.english ?? "unknown")")
                        
                        // Get position from the object
                        let worldCoord = object.position
                        
                        print("Creating node at position: \(worldCoord)")
                        
                        // Create 3D text node
                        let node = self.arSceneManager.createNewBubbleParentNode(
                            english: object.english ?? "unknown",
                            chinese: object.chinese ?? "",
                            pinyin: object.pinyin ?? ""
                        )
                        
                        // Add node to scene
                        self.arSceneManager.sceneView.scene.rootNode.addChildNode(node)
                        node.position = worldCoord
                        
                        // Store the node
                        self.arSceneManager.placedNodes.append(node)
                    }
                } else {
                    // Fall back to in-memory tagged detections if no saved objects
                    print("No saved objects found, using \(self.taggedDetections.count) tagged detections")
                    
                    // Display all tagged detections
                    for (index, detection) in self.taggedDetections.enumerated() {
                        print("Processing tagged detection \(index): \(detection.english)")
                        
                        // Create world coordinates from stored transform
                        let worldCoord = SCNVector3Make(
                            detection.worldPosition.columns.3.x,
                            detection.worldPosition.columns.3.y,
                            detection.worldPosition.columns.3.z
                        )
                        
                        print("Creating node at position: \(worldCoord)")
                        
                        // Create 3D text node
                        let node = self.arSceneManager.createNewBubbleParentNode(
                            english: detection.english,
                            chinese: detection.chinese,
                            pinyin: detection.pinyin
                        )
                        
                        // Add node to scene
                        self.arSceneManager.sceneView.scene.rootNode.addChildNode(node)
                        node.position = worldCoord
                        
                        // Store the node
                        self.arSceneManager.placedNodes.append(node)
                    }
                }
                
                // Show the buttons since AR is active
                self.clearARButton?.isHidden = false
                
                // Show refresh button based on tracking state
                if let frame = self.arSceneManager.sceneView.session.currentFrame {
                    if case .limited = frame.camera.trackingState {
                        self.refreshARButton?.isHidden = false
                    } else {
                        self.refreshARButton?.isHidden = true
                    }
                } else {
                    self.refreshARButton?.isHidden = false
                }
            }
        })
    } else {
        // Stop tracking state monitoring
        stopARTrackingStateMonitoring()
        
        // Hide the status label
        UIView.animate(withDuration: 0.3) {
            self.arStatusLabel?.alpha = 0.0
        }
        
        // Pause AR session first to save resources
        arSceneManager.pauseARSession()
        
        // Then fade out the AR view with animation
        UIView.animate(withDuration: 0.5, animations: {
            self.arSceneManager.sceneView.alpha = 0.0
        }, completion: { _ in
            // Show a toast message to indicate AR mode is inactive
            self.showToast(message: "AR Mode Inactive")
            
            // Clear AR labels when deactivating AR mode
            self.arSceneManager.clearLabels()
            
            // Hide the buttons
            self.clearARButton?.isHidden = true
            self.refreshARButton?.isHidden = true
        })
    }
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
  
  // Clear all AR labels - now using container approach
  func clearARLabels() {
    // Clear container labels
    clearContainerLabels()
    
    // Also clear all AR labels as a backup
    arSceneManager.clearLabels()
    
    // Also clear tagged detections
    taggedDetections.removeAll()
    
    print("Cleared all labels and tagged detections")
    showToast(message: "Cleared all object labels and tagged detections")
  }

  // Add control buttons for AR view (since AR view is always visible)
  func addARToggleButton() {
    // First button - Refresh AR (was toggle button)
    let refreshButton = UIButton(type: .system)
    refreshButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
    refreshButton.tintColor = .white
    refreshButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
    refreshButton.layer.cornerRadius = 25
    refreshButton.translatesAutoresizingMaskIntoConstraints = false
    refreshButton.addTarget(self, action: #selector(refreshARButtonTapped), for: .touchUpInside) // Now uses refresh
    
    view.addSubview(refreshButton)
    
    NSLayoutConstraint.activate([
      refreshButton.widthAnchor.constraint(equalToConstant: 50),
      refreshButton.heightAnchor.constraint(equalToConstant: 50),
      refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      // Position the button above the toolbar to prevent overlap
      refreshButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
    ])
    
    // Store reference to refresh button (using arToggleButton reference)
    self.refreshARButton = refreshButton
    
    // Add clear AR labels button
    let clearButton = UIButton(type: .system)
    clearButton.setImage(UIImage(systemName: "trash"), for: .normal)
    clearButton.tintColor = .white
    clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
    clearButton.layer.cornerRadius = 25
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    clearButton.addTarget(self, action: #selector(clearARButtonTapped), for: .touchUpInside)
    clearButton.isHidden = false // Now visible by default since AR is always on
    
    view.addSubview(clearButton)
    
    NSLayoutConstraint.activate([
      clearButton.widthAnchor.constraint(equalToConstant: 50),
      clearButton.heightAnchor.constraint(equalToConstant: 50),
      clearButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -10),
      // Match the bottom constraint of the refresh button
      clearButton.bottomAnchor.constraint(equalTo: refreshButton.bottomAnchor)
    ])
    
    // Store reference to clear button
    self.clearARButton = clearButton
    
    // Add reset tracking button for when tracking is lost
    let resetButton = UIButton(type: .system)
    resetButton.setImage(UIImage(systemName: "repeat.circle.fill"), for: .normal)
    resetButton.tintColor = .white
    resetButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.7)
    resetButton.layer.cornerRadius = 25
    resetButton.translatesAutoresizingMaskIntoConstraints = false
    resetButton.addTarget(self, action: #selector(resetARButtonTapped), for: .touchUpInside)
    resetButton.isHidden = true // Initially hidden, shows when tracking is lost
    
    view.addSubview(resetButton)
    
    NSLayoutConstraint.activate([
      resetButton.widthAnchor.constraint(equalToConstant: 50),
      resetButton.heightAnchor.constraint(equalToConstant: 50),
      resetButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -10),
      // Match the bottom constraint of the clear button
      resetButton.bottomAnchor.constraint(equalTo: clearButton.bottomAnchor)
    ])
    
    // Store reference to reset button
    self.resetARButton = resetButton
    
    // Make sure the toolbar is in front of these buttons
    ensureToolbarIsInFront()
  }
  
  // Add a new method to handle reset button taps
  @objc func resetARButtonTapped() {
    // Show a loading indicator
    let loadingIndicator = UIActivityIndicatorView(style: .large)
    loadingIndicator.color = .white
    loadingIndicator.center = view.center
    view.addSubview(loadingIndicator)
    loadingIndicator.startAnimating()
    
    // Show toast with instructions
    showToast(message: "Resetting AR tracking...")
    
    // Pause AR session
    arSceneManager.pauseARSession()
    
    // Short delay to let the system reset
    DispatchQueue.global(qos: .userInitiated).async {
      Thread.sleep(forTimeInterval: 0.5)
      
      // Resume with fresh session - uses resetTracking option
      DispatchQueue.main.async {
        self.arSceneManager.setupARSession() // This will reset tracking
        
        // Reload saved objects after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          loadingIndicator.stopAnimating()
          loadingIndicator.removeFromSuperview()
          
          self.showToast(message: "AR tracking reset - reloading objects...")
          self.loadSavedARObjectsInContainer()
        }
      }
    }
  }
  
  @objc func clearARButtonTapped() {
    // Clear all AR labels and Core Data objects
    clearARLabels(andCoreData: true)
  }
  
  // Clear all AR labels - now using container approach
  func clearARLabels(andCoreData: Bool = false) {
    // Clear container labels
    clearContainerLabels(andCoreData: andCoreData)
    
    // Also clear all AR labels as a backup
    arSceneManager.clearLabels()
    
    // Also clear tagged detections
    taggedDetections.removeAll()
    
    print("Cleared all labels and tagged detections")
    showToast(message: "Cleared all object labels" + (andCoreData ? " and saved data" : ""))
  }
  
  @objc func refreshARButtonTapped() {
    // Show a loading indicator
    let loadingIndicator = UIActivityIndicatorView(style: .large)
    loadingIndicator.color = .white
    loadingIndicator.center = view.center
    view.addSubview(loadingIndicator)
    loadingIndicator.startAnimating()
    
    // Keep track of timing for performance monitoring
    let refreshStartTime = CACurrentMediaTime()
    lastARRefreshTime = refreshStartTime
    
    // Update the status label
    arStatusLabel?.text = "AR: Refreshing..."
    arStatusLabel?.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.6)
    
    // Show toast with instructions
    showToast(message: "Hold device steady during refresh...")
    
    // Run the refresh on a background thread
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      
      // Decide whether to remove anchors based on tracking state
      var removeAnchors = false
      var resetTracking = false
      
      if let frame = self.arSceneManager.sceneView.session.currentFrame {
        if case .limited(let reason) = frame.camera.trackingState {
          // Check how long we've been in limited state
          let currentTime = CACurrentMediaTime()
          let timeSinceLastRefresh = currentTime - self.lastARRefreshTime
          
          // If tracking has been limited for a while, try more aggressive recovery
          if timeSinceLastRefresh > 10.0 {
            // Remove anchors if we have severe tracking issues
            if reason == .excessiveMotion || reason == .initializing {
              removeAnchors = true
              print("Tracking limited for >10s, removing anchors for recovery")
            }
            
            // Only reset tracking as a last resort after multiple limited tracking states
            if UserDefaults.standard.integer(forKey: "ar_consecutive_limited_states") > 3 {
              resetTracking = true
              print("Multiple consecutive tracking failures, resetting tracking")
              
              // Reset the counter after a reset
              UserDefaults.standard.set(0, forKey: "ar_consecutive_limited_states")
            } else {
              // Increment the counter
              let currentCount = UserDefaults.standard.integer(forKey: "ar_consecutive_limited_states")
              UserDefaults.standard.set(currentCount + 1, forKey: "ar_consecutive_limited_states")
            }
          }
        } else {
          // Reset the counter if we have good tracking
          UserDefaults.standard.set(0, forKey: "ar_consecutive_limited_states")
        }
      }
      
      // Try a two-step refresh for better results
      if resetTracking {
        // First pause briefly
        self.arSceneManager.pauseARSession()
        
        // Short delay to let the system reset
        Thread.sleep(forTimeInterval: 0.5)
        
        // Then resume with a fresh session
        self.arSceneManager.resumeARSession()
        
        // Notify the user
        DispatchQueue.main.async {
          self.showToast(message: "AR tracking reset - establishing new positioning")
        }
      } else {
        // Standard refresh
        self.arSceneManager.refreshARSession(reloadAnchors: removeAnchors)
      }
      
      // Record the positions before refresh
      let previousPositions = self.arSceneManager.placedNodes.map { ($0.name ?? "", $0.position) }
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        // Remove loading indicator
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
        
        // Update status label
        self.updateARTrackingState()
        
        // Show toast message
        let refreshTime = String(format: "%.1f", (CACurrentMediaTime() - refreshStartTime))
        self.showToast(message: "AR view refreshed in \(refreshTime)s")
        
        // Reset consecutive failures if tracking is now good
        if let frame = self.arSceneManager.sceneView.session.currentFrame,
           case .normal = frame.camera.trackingState {
          UserDefaults.standard.set(0, forKey: "ar_consecutive_limited_states")
          
          // Hide the refresh button if tracking is now good
          self.refreshARButton?.isHidden = true
        }
        
        // If we still have tracking issues, suggest movement
        if let frame = self.arSceneManager.sceneView.session.currentFrame,
           case .limited(let reason) = frame.camera.trackingState {
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            switch reason {
            case .excessiveMotion:
              self.showToast(message: "Hold device more steady")
            case .insufficientFeatures:
              self.showToast(message: "Move to area with more visual details")
            case .initializing:
              self.showToast(message: "Move device slowly to map environment")
            case .relocalizing:
              self.showToast(message: "Look around slowly to help relocalize")
            @unknown default:
              self.showToast(message: "Try toggling AR mode off and on if issues persist")
            }
          }
        }
      }
    }
  }
  
  @objc func toggleARButtonTapped() {
    // This function is no longer used since AR view is always visible
    // We keep it to avoid breaking existing connections but we'll call refreshARButtonTapped instead
    refreshARButtonTapped()
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
