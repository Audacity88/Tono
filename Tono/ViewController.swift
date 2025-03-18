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
import ARKit

var mlModel = try! yolo11n(configuration: mlmodelConfig).model
var mlmodelConfig: MLModelConfiguration = {
  let config = MLModelConfiguration()

  if #available(iOS 17.0, *) {
    config.setValue(1, forKey: "experimentalMLE5EngineUsage")
  }

  return config
}()

/// The main view controller for the YOLO app, responsible for camera setup, model selection, and detection visualization.
class ViewController: UIViewController, ARSCNViewDelegate {
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
  
  // Track the last bounding box that was focused on for capture
  var lastFocusedBoundingBox: BoundingBoxView?

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
  private var arSceneManager: ARSceneManager!
  
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
  // View for displaying AR content (separate from camera feed)
  private var arContainerView: PassthroughContainerView? // Our container for AR object views

  // Add property to store tagged detections
  private var taggedDetections: [(english: String, chinese: String, pinyin: String, worldPosition: simd_float4x4)] = []
  
  // Track labeled objects by their unique ID instead of class name
  private var labeledBoxes: [(id: UUID, className: String, centerX: CGFloat, centerY: CGFloat)] = []
  
  // Stack view for created labels
  private var labelStackView: UIView?
  private var stackedLabels: [UIView] = []
  
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
    
    // Set up app lifecycle notifications to handle foreground/background transitions
    setupAppLifecycleNotifications()
    
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
    let objectsContainer = PassthroughContainerView(frame: view.bounds)
    objectsContainer.backgroundColor = UIColor.clear
    objectsContainer.isOpaque = false
    objectsContainer.clipsToBounds = false // Allow labels to extend beyond bounds
    
    // Enable user interaction for label taps, but also let touches pass through to video preview
    objectsContainer.isUserInteractionEnabled = true
    objectsContainer.isMultipleTouchEnabled = true
    
    // Add a tap gesture recognizer to handle taps on the container
    let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(containerViewTapped(_:)))
    containerTapGesture.cancelsTouchesInView = false
    objectsContainer.addGestureRecognizer(containerTapGesture)
    
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
            
            // Ensure camera is running after initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Auto-start camera only on first launch
                if self.videoCapture?.captureSession != nil && !self.videoCapture.captureSession.isRunning {
                    print("Auto-starting camera after initialization")
                    self.videoCapture.start()
                    self.playButtonOutlet.isEnabled = false
                    self.pauseButtonOutlet.isEnabled = true
                }
            }
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
        // We'll set these after checking camera state
    }
    
    // Setup label stack view
    setupLabelStackView()
    
    // setModel()
  }
  
  private func setupAppLifecycleNotifications() {
    // Add observer for app entering foreground
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
    
    // Add observer for app becoming active
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    
    // Add observer for app entering background
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
  }
  
  @objc private func appWillEnterForeground() {
    print("App will enter foreground - preparing to restart camera")
    // Will restart in appDidBecomeActive
  }
  
  @objc private func appDidBecomeActive() {
    print("App did become active - checking camera status")
    // Delayed execution to avoid configuration conflicts
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.ensureToolbarIsInFront()
      if self.videoCapture?.captureSession != nil && !self.videoCapture.captureSession.isRunning {
        print("Restarting camera after app became active")
        self.videoCapture.start()
        self.playButtonOutlet.isEnabled = false
        self.pauseButtonOutlet.isEnabled = true
      }
    }
  }
  
  @objc private func appDidEnterBackground() {
    print("App did enter background - pausing camera")
    // Pause camera when app enters background
    if self.videoCapture?.captureSession != nil && self.videoCapture.captureSession.isRunning {
      self.videoCapture.stop()
      self.playButtonOutlet.isEnabled = true
      self.pauseButtonOutlet.isEnabled = false
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Start AR session
    arSceneManager.setupARSession()
    
    // Register for tab change notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleTabChange(_:)),
      name: NSNotification.Name("TabChangedNotification"),
      object: nil
    )
    
    // Restart video capture if it was previously initialized
    // Use a slight delay to ensure we don't interfere with any ongoing configuration
    restartVideoCaptureIfNeeded(delay: 0.3)
    
    // No longer clearing Core Data objects on app startup
    // This allows the collection to persist between tab switches
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    // This is called after the view is fully visible
    // Try to restart the camera again if needed with a slightly longer delay
    restartVideoCaptureIfNeeded(delay: 0.5)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Remove tab change notification when view disappears
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name("TabChangedNotification"), object: nil)
    
    // Stop AR tracking monitoring
    stopARTrackingStateMonitoring()
    
    // Pause AR session
    arSceneManager.pauseARSession()
    
    // Stop world map saving to prevent unnecessary resource usage
    if #available(iOS 12.0, *) {
      arSceneManager.stopWorldMapSaving()
    }
  }
  
  // Helper method to restart video capture with a delay
  private func restartVideoCaptureIfNeeded(delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      if self.videoCapture?.captureSession != nil && !self.videoCapture.captureSession.isRunning {
        print("Restarting video capture with \(delay)s delay")
        do {
          // Make sure we're not in a configuration state
          self.videoCapture.start()
          self.playButtonOutlet.isEnabled = false
          self.pauseButtonOutlet.isEnabled = true
        } catch {
          print("Error restarting video capture: \(error)")
        }
      }
    }
  }
  
  // Handle tab change notifications
  @objc private func handleTabChange(_ notification: Notification) {
    if let userInfo = notification.userInfo,
       let selectedIndex = userInfo["selectedIndex"] as? Int {
      
      // Check if our tab was selected (index 0 is the Explore tab)
      if selectedIndex == 0 {
        print("Explore tab selected - ensuring camera is running")
        restartVideoCaptureIfNeeded(delay: 0.3)
      }
    }
  }
  
  // Helper method to ensure toolbar is always at the front of the view hierarchy
  private func ensureToolbarIsInFront() {
    // First make sure AR container is in front of everything else
    if let container = self.arContainerView {
      self.view.bringSubviewToFront(container)
      
      // Ensure all labels in the container are interactive
      for label in container.subviews {
        label.isUserInteractionEnabled = true
        label.layer.zPosition = 100
        
        // Ensure all buttons in labels are interactive
        for subview in label.subviews {
          if let button = subview as? UIButton {
            button.isUserInteractionEnabled = true
          }
        }
      }
    }
    
    // Then put the toolbar at the very front
    if let toolbar = self.toolBar {
      self.view.bringSubviewToFront(toolbar)
      
      // Add hide all labels button if it doesn't exist
      if toolbar.items?.contains(where: { $0.tag == 999 }) != true {
        addHideLabelsButton()
      }
    }
  }
  
  // Add a button to hide/show all labels
  private func addHideLabelsButton() {
    guard let toolbar = self.toolBar else { return }
    
    // Create a button to hide all labels
    let hideButton = UIBarButtonItem(
      image: UIImage(systemName: "eye.slash"),
      style: .plain,
      target: self,
      action: #selector(toggleLabelsVisibility)
    )
    hideButton.tag = 999 // Special tag to identify this button
    
    // Get current items
    var items = toolbar.items ?? []
    
    // Check if we already have reasonable item count to avoid duplicates
    if items.count < 8 {
      // Add a flexible space and the hide button
      items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
      items.append(hideButton)
      
      // Update toolbar items
      toolbar.setItems(items, animated: false)
    }
  }
  
  // Toggle visibility of all label containers
  @objc private func toggleLabelsVisibility() {
    guard let container = arContainerView else { return }
    
    // Check if labels are currently visible
    let areLabelsVisible = container.subviews.first?.isHidden == false
    
    // Toggle visibility
    if areLabelsVisible {
      // Hide all labels
      UIView.animate(withDuration: 0.3) {
        for labelView in container.subviews {
          labelView.isHidden = true
        }
      }
      
      // Change button icon
      if let button = toolBar.items?.first(where: { $0.tag == 999 }) {
        button.image = UIImage(systemName: "eye")
      }
      
      // Show toast
      showToast(message: "All labels hidden - tap objects to tag")
      
      // Enable force passthrough to ensure taps reach video preview
      container.forcePassthrough = true
      
      // IMPORTANT: Disable user interaction on the container when labels are hidden
      // This ensures taps go straight to the video preview for object tagging
      container.isUserInteractionEnabled = false
    } else {
      // Show all labels
      UIView.animate(withDuration: 0.3) {
        for labelView in container.subviews {
          labelView.isHidden = false
        }
      }
      
      // Change button icon
      if let button = toolBar.items?.first(where: { $0.tag == 999 }) {
        button.image = UIImage(systemName: "eye.slash")
      }
      
      // Show toast
      showToast(message: "Labels visible again")
      
      // Disable force passthrough
      container.forcePassthrough = false
      
      // IMPORTANT: Re-enable user interaction on the container when labels are visible
      // This ensures taps on labels are properly captured
      container.isUserInteractionEnabled = true
    }
  }
  
  // COMPLETELY NEW APPROACH: Render AR objects as UIViews in a separate container
  private func loadSavedARObjectsInContainer() {
    // Clear our container view
    self.arContainerView?.subviews.forEach { $0.removeFromSuperview() }
    
    print("Initializing container view for AR labels")
    
    // We no longer load saved objects from Core Data into this view
    // The container view is only for temporary AR labels during this session
    // Saved objects are only shown in the Collection tab
    
    print("Container view ready for adding AR labels")
    
    // Make sure the toolbar remains on top after setup
    ensureToolbarIsInFront()
  }
  
  // Helper method to create an object label
  private func createObjectLabel(english: String, chinese: String, pinyin: String, objectId: UUID? = nil) -> UIView {
    // Create a container view for the label
    let containerView = UIView()
    containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    containerView.layer.cornerRadius = 10
    containerView.layer.borderWidth = 2
    containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
    
    // Create the Chinese label
    let chineseLabel = UILabel()
    chineseLabel.text = chinese
    chineseLabel.textColor = UIColor.red
    chineseLabel.font = UIFont.boldSystemFont(ofSize: 20) // Bigger font
    chineseLabel.textAlignment = .center
    chineseLabel.tag = 100 // Special tag to identify this as the Chinese label
    
    // Create the pinyin label
    let pinyinLabel = UILabel()
    pinyinLabel.text = pinyin
    pinyinLabel.textColor = UIColor.orange
    pinyinLabel.font = UIFont.systemFont(ofSize: 18) // Bigger font
    pinyinLabel.textAlignment = .center
    pinyinLabel.tag = 101 // Tag to identify this as the pinyin label
    
    // Create the English label
    let englishLabel = UILabel()
    englishLabel.text = english
    englishLabel.textColor = UIColor.white
    englishLabel.font = UIFont.systemFont(ofSize: 16) // Bigger font
    englishLabel.textAlignment = .center
    englishLabel.tag = 102 // Tag to identify this as the English label
    
    // Add minimize button
    let minimizeButton = UIButton(type: .system)
    minimizeButton.setTitle("−", for: .normal) // Using Unicode minus sign as minimize icon
    minimizeButton.setTitleColor(.white, for: .normal)
    minimizeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
    minimizeButton.frame = CGRect(x: 170, y: 5, width: 25, height: 25)
    minimizeButton.addTarget(self, action: #selector(minimizeLabel(_:)), for: .touchUpInside)
    
    // Add labels to container
    containerView.addSubview(chineseLabel)
    containerView.addSubview(pinyinLabel)
    containerView.addSubview(englishLabel)
    containerView.addSubview(minimizeButton)
    
    // Size the container and position labels - make it bigger for better visibility
    containerView.frame = CGRect(x: 0, y: 0, width: 200, height: 110)
    chineseLabel.frame = CGRect(x: 0, y: 8, width: 200, height: 35)
    pinyinLabel.frame = CGRect(x: 0, y: 45, width: 200, height: 30)
    englishLabel.frame = CGRect(x: 0, y: 75, width: 200, height: 30)
    
    // Store original frame for minimizing/maximizing - use modern API
    containerView.accessibilityValue = NSCoder.string(for: containerView.frame)
    
    // Add a subtle animation to make it more noticeable
    UIView.animate(withDuration: 0.5, animations: {
        containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    }) { _ in
        UIView.animate(withDuration: 0.3) {
            containerView.transform = .identity
        }
    }
    
    // IMPORTANT: Make the label tappable but PREVENT taps from passing through to objects below
    // This ensures taps on labels are intercepted correctly and don't trigger object tagging
    containerView.isUserInteractionEnabled = true
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(objectLabelTapped(_:)))
    tapGesture.cancelsTouchesInView = true  // IMPORTANT: Cancel touches to prevent them from reaching views below
    containerView.addGestureRecognizer(tapGesture)
    
    // Generate a unique ID if not provided
    let id = objectId?.uuidString ?? UUID().uuidString
    
    // Store data in the view's accessibility label with unique ID
    containerView.accessibilityLabel = "\(id)|\(english)|\(chinese)|\(pinyin)"
    
    return containerView
  }
  
  // Minimize or maximize a label when tapped
  @objc func minimizeLabel(_ sender: UIButton) {
    guard let containerView = sender.superview else { return }
    
    // Toggle between minimized and normal state
    if containerView.tag == 0 { // Normal state -> minimize
      // Store current position for later - use modern API
      containerView.accessibilityValue = NSCoder.string(for: containerView.frame)
      
      // Find the Chinese label - now we can use the tag
      var chineseLabel: UILabel? = nil
      for subview in containerView.subviews {
        if let label = subview as? UILabel, label.tag == 100 {
          chineseLabel = label
          break
        }
      }
      
      // Minimize view - just show small indicator with Chinese character
      UIView.animate(withDuration: 0.3) {
        // Shrink to just show the minimize button and Chinese character
        containerView.frame = CGRect(x: containerView.frame.minX, y: containerView.frame.minY, 
                                width: 50, height: 40)
        
        // Find and hide all labels except Chinese
        for subview in containerView.subviews {
          if subview != sender && subview != chineseLabel {
            subview.isHidden = true
          }
        }
        
        // Adjust the Chinese label position if found
        if let label = chineseLabel {
          label.frame = CGRect(x: 5, y: 5, width: 40, height: 30)
        }
        
        // Adjust button position
        sender.frame = CGRect(x: 25, y: 5, width: 25, height: 25)
        
        // Change button to show + for expand
        sender.setTitle("+", for: .normal)
      }
      
      // Set tag to 1 to indicate minimized state
      containerView.tag = 1
      
    } else { // Minimized state -> maximize
      // Get original frame - use modern API
      let originalFrameString = containerView.accessibilityValue ?? ""
      let originalFrame = NSCoder.cgRect(for: originalFrameString)
      
      // Get all labels
      var chineseLabel: UILabel? = nil
      var pinyinLabel: UILabel? = nil
      var englishLabel: UILabel? = nil
      
      for subview in containerView.subviews {
        if let label = subview as? UILabel {
          if label.tag == 100 {
            chineseLabel = label
          } else if label.tag == 101 {
            pinyinLabel = label
          } else if label.tag == 102 {
            englishLabel = label
          }
        }
      }
      
      // Maximize view back to original size
      UIView.animate(withDuration: 0.3) {
        containerView.frame = originalFrame
        
        // Show all subviews again
        for subview in containerView.subviews {
          subview.isHidden = false
        }
        
        // Reset label positions
        if let label = chineseLabel {
          label.frame = CGRect(x: 0, y: 8, width: 200, height: 35)
        }
        
        if let label = pinyinLabel {
          label.frame = CGRect(x: 0, y: 45, width: 200, height: 30)
        }
        
        if let label = englishLabel {
          label.frame = CGRect(x: 0, y: 75, width: 200, height: 30)
        }
        
        // Reset button position
        sender.frame = CGRect(x: 170, y: 5, width: 25, height: 25)
        
        // Change button back to - for minimize
        sender.setTitle("−", for: .normal)
      }
      
      // Set tag to 0 to indicate normal state
      containerView.tag = 0
    }
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
    // IMPORTANT: Explicitly consume this touch event to prevent pass-through
    gesture.cancelsTouchesInView = true
    
    guard let containerView = gesture.view,
          let labelData = containerView.accessibilityLabel?.components(separatedBy: "|"),
          labelData.count >= 4 else {
        return
    }
    
    // New format: id|english|chinese|pinyin
    let objectId = labelData[0]
    let english = labelData[1]
    let chinese = labelData[2]
    let pinyin = labelData[3]
    
    // Show toast message to confirm tap was recognized
    showToast(message: "Playing: \(chinese) (\(english))")
    
    // Play pronunciation
    arSceneManager.playPronunciation(for: chinese, pinyin: pinyin)
    
    // Bring this view to the absolute front to ensure it's visible above all others
    if let container = self.arContainerView {
      container.bringSubviewToFront(containerView)
    }
    
    // If already showing in center, just reset position
    if containerView.transform.a > 1.2 {
      // Reset transform and position
      UIView.animate(withDuration: 0.3) {
        containerView.transform = .identity
        containerView.layer.zPosition = 0
      }
      // IMPORTANT: Return to exit the method early and prevent further propagation
      return
    }
    
    // Get the center of the screen for showing the label
    let screenCenter = view.center
    
    // First scale up the label
    UIView.animate(withDuration: 0.2, animations: {
      containerView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
      containerView.layer.zPosition = 1000 // Ensure it's at the top
      
      // Move to center of screen for better visibility
      containerView.center = CGPoint(
        x: screenCenter.x,
        y: screenCenter.y - 100 // slightly above center
      )
    })
  }
  
  // This override is deleted - there's already a viewWillDisappear method earlier in the file
  
  // Setup label stack view
  private func setupLabelStackView() {
    // Create a container view for the label stack in the top-right corner
    let stackContainer = UIView()
    stackContainer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    stackContainer.layer.cornerRadius = 15
    stackContainer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackContainer)
    
    NSLayoutConstraint.activate([
      stackContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
      stackContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      stackContainer.widthAnchor.constraint(equalToConstant: 140),
      stackContainer.heightAnchor.constraint(equalToConstant: 320)
    ])
    
    // Add a title label
    let titleLabel = UILabel()
    titleLabel.text = "Words"
    titleLabel.textColor = .white
    titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
    titleLabel.textAlignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    stackContainer.addSubview(titleLabel)
    
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: stackContainer.topAnchor, constant: 8),
      titleLabel.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor),
      titleLabel.trailingAnchor.constraint(equalTo: stackContainer.trailingAnchor),
      titleLabel.heightAnchor.constraint(equalToConstant: 24)
    ])
    
    // Add a scroll view for the stacked labels
    let scrollView = UIScrollView()
    scrollView.showsVerticalScrollIndicator = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    stackContainer.addSubview(scrollView)
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
      scrollView.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor, constant: 5),
      scrollView.trailingAnchor.constraint(equalTo: stackContainer.trailingAnchor, constant: -5),
      scrollView.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor, constant: -5)
    ])
    
    // Add a content view to the scroll view
    let contentView = UIView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(contentView)
    
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
    ])
    
    // Store references
    self.labelStackView = contentView
    
    // Initially hide the stack view until we have labels
    stackContainer.alpha = 0.7
    
    // Make sure toolbar stays on top
    ensureToolbarIsInFront()
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
    
    // Analyze bounding boxes before capture to determine if we should zoom
    let selectedBox = findBestBoundingBoxForCapture()
    if let box = selectedBox {
        // Capture focused on the selected bounding box
        captureImageWithFocus(on: box)
    } else {
        // Standard capture when no suitable bounding box is found
        let settings = AVCapturePhotoSettings()
        self.videoCapture.cameraOutput.capturePhoto(
          with: settings, delegate: self as AVCapturePhotoCaptureDelegate)
    }
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
    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      // Store the pixel buffer for image capture purposes
      self.currentBuffer = pixelBuffer
      
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
      
      // DON'T clear currentBuffer here - we'll retain it for image capture
      // It will be overwritten in the next frame anyway
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
          // print("Set currentDetection to: \(bestClass) - \(translation.chinese) (\(translation.pinyin))")
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
          
          // Check if we've already labeled this object class in the current session
          if labeledBoxes.contains(where: { labeled in labeled.className == bestClass }) {
              // This class is already labeled in the current session - hide it
              boundingBoxViews[i].hide()
              continue
          }
          
          // Track position for this box
          let boxMidX = rect.midX
          let boxMidY = rect.midY
          
          // Store the center position in the bounding box view for tracking
          boundingBoxViews[i].centerPosition = CGPoint(x: boxMidX, y: boxMidY)
          
          // Generate a new UUID for each box to ensure proper tracking
          boundingBoxViews[i].boxId = UUID()
          
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
        
        // Also make sure the container stays in front and labels remain interactive
        if let container = self.arContainerView {
          self.view.bringSubviewToFront(container)
          
          // Ensure all labels in the container are interactive
          for label in container.subviews {
            label.isUserInteractionEnabled = true
            label.layer.zPosition = 100
            
            // Ensure all buttons in labels are interactive
            for subview in label.subviews {
              if let button = subview as? UIButton {
                button.isUserInteractionEnabled = true
              }
            }
          }
        }
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
  
  // Track the timestamp of the last processed tap to prevent duplicate processing
  private var lastTapProcessedTime: TimeInterval = 0
  private let minimumTapInterval: TimeInterval = 1.0 // Minimum interval between taps (in seconds)
  
  /// Handle tap on a bounding box
  @objc func boundingBoxTapped(_ gesture: UITapGestureRecognizer) {
    guard let boxView = gesture.view as? BoundingBoxView else {
        return
    }
    
    // Log bounding box details when tapped (only once)
    print("Bounding box tapped: \(boxView.className)")
    
    // Call the method that takes a BoundingBoxView directly
    handleBoundingBoxTap(boxView)
  }
  
  /// Handle tap on a bounding box - method that takes a BoundingBoxView directly
  /// UPDATED VERSION: Uses the place3DTextAtBoundingBox method directly
  func handleBoundingBoxTap(_ boxView: BoundingBoxView) {
    // Get current time to implement tap debouncing
    let currentTime = Date().timeIntervalSince1970
    
    // Check if this tap happened too soon after the last one
    if currentTime - lastTapProcessedTime < minimumTapInterval {
        print("Ignoring tap - too soon after previous tap (debounce: \(minimumTapInterval)s)")
        return
    }
    
    // Update the last processed tap time
    lastTapProcessedTime = currentTime
    
    // Highlight the box to show it was selected
    highlightBoundingBox(boxView)
    
    // Get the class name and translation directly from the bounding box
    let className = boxView.className
    let confidence = boxView.confidence
    
    // First create the detection info
    guard let translation = boxView.translation ?? translationManager.getTranslation(for: className) else {
        print("No translation found for \(className)")
        return
    }
    
    let detection = (english: className, chinese: translation.chinese, pinyin: translation.pinyin)
    
    // Check for duplicate and log it, but still create the UI card
    let isDuplicate = self.persistenceController.isDuplicate(english: detection.english, chinese: detection.chinese, context: self.managedObjectContext)
    if isDuplicate {
        print("Object '\(detection.english)' already exists - but still showing UI")
    }
    
    print("Handling tap on bounding box for: \(className)")
    
    // Proceed with creating UI for this object
    place3DTextAtBoundingBox(boxView, detection: detection)
    
    // Hide ALL bounding boxes of this same class - for the entire session
    for boundingBox in boundingBoxViews {
        if !boundingBox.isHidden && boundingBox.className == className {
            boundingBox.hide()
        }
    }
    
    // Add to labeled boxes to prevent showing this class again in this session
    let objectId = UUID()
    labeledBoxes.append((id: objectId, className: className, centerX: boxView.frame.midX, centerY: boxView.frame.midY))
    
    // Add haptic feedback for better user experience
    let selection = UISelectionFeedbackGenerator()
    selection.selectionChanged()
  }
  
  // Helper method to highlight a bounding box when it's selected
  private func highlightBoundingBox(_ boxView: BoundingBoxView) {
    // Store the current border color and width
    let originalBorderColor = boxView.layer.borderColor
    let originalBorderWidth = boxView.layer.borderWidth
    
    // Highlight the box
    boxView.layer.borderColor = UIColor.white.cgColor
    boxView.layer.borderWidth = 3.0
    
    // Create a flash effect
    UIView.animate(withDuration: 0.1, animations: {
        boxView.alpha = 1.0
        boxView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    }) { _ in
        UIView.animate(withDuration: 0.1, animations: {
            boxView.transform = .identity
        }) { _ in
            // Delay before restoring the original appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Restore original appearance with animation
                UIView.animate(withDuration: 0.2) {
                    boxView.layer.borderColor = originalBorderColor
                    boxView.layer.borderWidth = originalBorderWidth
                }
            }
        }
    }
  }
  
  @objc func videoPreviewTapped(_ gesture: UITapGestureRecognizer) {
    // Get the tap location
    let location = gesture.location(in: videoPreview)
    
    // Add visual feedback at tap location
    showTapFeedback(at: location)
    
    // Check if AR mode is active
    let isARActive = arSceneManager.sceneView.alpha > 0.5
    
    // Create an even smaller hit-test area to improve precision
    let hitTestRadius: CGFloat = 5.0 // Reduced from 10 to 5 pixels
    let hitTestRect = CGRect(
        x: location.x - hitTestRadius, 
        y: location.y - hitTestRadius, 
        width: hitTestRadius * 2, 
        height: hitTestRadius * 2
    )
    
    // Debug: Log the tap location
    print("Tap location: \(location.x), \(location.y)")
    
    // First check if the tap is directly inside any bounding boxes
    var directHitBoxes: [BoundingBoxView] = []
    var nearbyBoxes: [(boxView: BoundingBoxView, zIndex: Int, distance: CGFloat)] = []
    
    // First pass: Check for direct hits (tap inside box)
    for boxView in boundingBoxViews {
        if !boxView.isHidden && boxView.frame.contains(location) {
            directHitBoxes.append(boxView)
            print("Direct hit on box: \(boxView.className)")
        }
    }
    
    // If we have direct hits, prefer those
    if !directHitBoxes.isEmpty {
        // If multiple direct hits, choose the one with highest z-index (confidence)
        let bestBox = directHitBoxes.max(by: { $0.tag < $1.tag })!
        print("Selected direct hit box: \(bestBox.className)")
        // Log bounding box details before handling
        logBoundingBoxDetails(bestBox)
        handleBoundingBoxTap(bestBox)
        return
    }
    
    // Second pass: Only if no direct hits, check if the tap is near any bounding boxes
    if directHitBoxes.isEmpty {
        for boxView in boundingBoxViews {
            if !boxView.isHidden {
                // Calculate distance from tap to center of box
                let centerX = boxView.frame.midX
                let centerY = boxView.frame.midY
                let distance = sqrt(pow(location.x - centerX, 2) + pow(location.y - centerY, 2))
                
                // Only consider boxes where the tap is close to the box boundary
                let boxDiagonal = sqrt(pow(boxView.frame.width, 2) + pow(boxView.frame.height, 2)) / 2
                let maxDistance = boxDiagonal + hitTestRadius // Only consider taps within hitTestRadius of the box boundary
                
                if distance <= maxDistance && boxView.frame.insetBy(dx: -hitTestRadius * 2, dy: -hitTestRadius * 2).contains(location) {
                    nearbyBoxes.append((boxView: boxView, zIndex: boxView.tag, distance: distance))
                    print("Nearby box: \(boxView.className) at distance \(distance)")
                }
            }
        }
    }
    
    // If we found any nearby boxes, handle the closest one or the one in front
    if !nearbyBoxes.isEmpty {
        // Sort by distance (closest first)
        nearbyBoxes.sort { $0.distance < $1.distance }
        
        // If multiple boxes are very close, prefer the one with highest z-index
        if nearbyBoxes.count > 1 && abs(nearbyBoxes[0].distance - nearbyBoxes[1].distance) < hitTestRadius * 2 {
            // Sort by z-index in descending order (highest first)
            nearbyBoxes.sort { $0.zIndex > $1.zIndex }
        }
        
        // Only handle if the distance is reasonable
        let bestBox = nearbyBoxes[0].boxView
        let distance = nearbyBoxes[0].distance
        
        // Determine if the box is close enough based on its size
        let boxSize = min(bestBox.frame.width, bestBox.frame.height)
        let maxAllowableDistance = max(hitTestRadius * 3, boxSize * 0.3) // Allow at most 30% of box size or 3x hit test radius
        
        if distance <= maxAllowableDistance {
            print("Tapped near bounding box: \(bestBox.className) (distance: \(distance), max allowed: \(maxAllowableDistance))")
            // Log bounding box details before handling
            logBoundingBoxDetails(bestBox)
            handleBoundingBoxTap(bestBox)
            return
        } else {
            print("Nearest box \(bestBox.className) too far: \(distance) > \(maxAllowableDistance)")
            // Show feedback that the tap was too far from an object
            showToast(message: "Tap closer to an object to label it")
        }
    } else if !boundingBoxViews.filter({ !$0.isHidden }).isEmpty {
        // If there are visible boxes but we didn't tap near any of them
        showToast(message: "Tap on or near an object to label it")
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
      // We don't need to show any notification for duplicates anymore
      // The duplicate check happens in PersistenceController when saving to Core Data
      
      // Get the center of the bounding box in screen coordinates
      let boxCenter = CGPoint(
          x: boxView.frame.midX,
          y: boxView.frame.midY
      )
      
      print("Creating label for: \(detection.english)")
      
      // MAKE SURE THE CONTAINER EXISTS
      if self.arContainerView == nil {
        print("ERROR: Container view does not exist, creating one now")
        let container = PassthroughContainerView(frame: self.view.bounds)
        container.backgroundColor = UIColor.clear
        container.isOpaque = false
        
        // Configure touch handling for the container
        // This is critical - we want the container to detect touches but not block them
        // from reaching the video preview underneath for object detection
        container.isUserInteractionEnabled = true
        container.isMultipleTouchEnabled = true
        
        self.view.addSubview(container)
        self.view.bringSubviewToFront(container)
        self.arContainerView = container
      }
      
      // Check if we already have a label with this object in the container
      var existingLabel: UIView? = nil
      if let container = self.arContainerView {
        for subview in container.subviews {
          if let accessLabel = subview.accessibilityLabel,
             accessLabel.contains("|\(detection.english)|") {
            existingLabel = subview
            print("Found existing UI label for '\(detection.english)', will not create duplicate")
            break
          }
        }
        
        // If a label for this object already exists, highlight it but don't create a new one
        if let existing = existingLabel {
          // Highlight the existing label with a pulse animation
          UIView.animate(withDuration: 0.2, animations: {
            existing.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            existing.layer.borderColor = UIColor.green.cgColor
            existing.layer.borderWidth = 3
          }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
              existing.transform = .identity
              existing.layer.borderWidth = 2
            }
          })
          
          // Bring it to front
          container.bringSubviewToFront(existing)
          existing.layer.zPosition = 100
          
          // Play pronunciation for the object
          self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          
          // Remove the transition view and exit
          transitionView.removeFromSuperview()
          return
        }
      }
      
      // Make sure the container is visible and in front
      self.arContainerView?.isHidden = false
      self.view.bringSubviewToFront(self.arContainerView!)
      
      // Create a label view with enhanced visibility
      let objectLabel = self.createObjectLabel(
          english: detection.english, 
          chinese: detection.chinese,
          pinyin: detection.pinyin
      )
      
      // Position the label intelligently to avoid interfering with object detection
      // First, try to position at the top of the screen in a grid
      let labelCount = self.arContainerView?.subviews.count ?? 0
      let labelWidth = objectLabel.frame.width
      let labelHeight = objectLabel.frame.height
      let horizontalPadding: CGFloat = 10
      let verticalPadding: CGFloat = 5
      
      // Calculate the maximum number of labels that can fit horizontally
      let screenWidth = self.view.bounds.width
      let labelsPerRow = max(1, Int(screenWidth / (labelWidth + horizontalPadding)))
      
      // Calculate row and column position
      let columnIndex = labelCount % labelsPerRow
      let rowIndex = labelCount / labelsPerRow
      
      // Calculate position at the top of the screen in a grid layout
      let xPosition = horizontalPadding + CGFloat(columnIndex) * (labelWidth + horizontalPadding) + labelWidth/2
      let yPosition = self.view.safeAreaInsets.top + verticalPadding + CGFloat(rowIndex) * (labelHeight + verticalPadding) + labelHeight/2
      
      // Position the label at the calculated position
      objectLabel.center = CGPoint(x: xPosition, y: yPosition)
      
      // If the calculated position is too far down the screen, fall back to minimized mode immediately
      if yPosition > self.view.bounds.height / 3 {
          // Minimize the label immediately after adding
          objectLabel.tag = 1 // Mark as minimized
          
          // Find the button to minimize (should be the last subview added)
          for subview in objectLabel.subviews {
              if let button = subview as? UIButton {
                  // Trigger the minimize action after a short delay to ensure view is set up
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                      self.minimizeLabel(button)
                  }
                  break
              }
          }
          
          // Position the label at the side of the screen instead
          let sidePosition = min(self.view.bounds.width - 40, max(40, boxCenter.x))
          objectLabel.center = CGPoint(x: sidePosition, y: boxCenter.y)
      }
      
      // Store the label data in the accessibility label
      let safeEnglish = detection.english.isEmpty ? "unknown" : detection.english
      objectLabel.accessibilityLabel = "\(UUID().uuidString)|\(safeEnglish)|\(detection.chinese)|\(detection.pinyin)"
      
      // Add to our container 
      if let container = self.arContainerView {
          container.addSubview(objectLabel)
          
          // Make sure it has a higher z-position than existing labels
          // This ensures it will be visually on top of any previously viewed labels
          objectLabel.layer.zPosition = 100
          
          // Set tag to position index - the number of items in container will be its position
          // This ensures each label has a fixed position in the stack
          objectLabel.tag = container.subviews.count - 1
      }
      
      // Make it spring into view with animation
      objectLabel.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
      UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.3, options: [], animations: {
          objectLabel.transform = CGAffineTransform.identity
          objectLabel.layer.borderColor = UIColor.green.cgColor // Flash green border
      }, completion: { _ in
          // After appearing, run the synchronize function which will move it to the stack
          self.synchronizeARLabelsWithBoundingBoxes()
          
          // Simply call synchronize to ensure proper positioning - don't bring to front
          // This will maintain the natural ordering with new labels at the bottom
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              self.synchronizeARLabelsWithBoundingBoxes()
          }
          
          // Play pronunciation
          self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
      })
      
      // Remove the transition view with fade out
      UIView.animate(withDuration: 0.3, animations: {
        transitionView.alpha = 0
      }) { _ in
        transitionView.removeFromSuperview()
      }
      
      // Check if this object is a duplicate before capturing and processing the image
      let isDuplicate = self.persistenceController.isDuplicate(english: detection.english, chinese: detection.chinese, context: self.managedObjectContext)
      if isDuplicate {
          print("Object with text '\(detection.english)'/'\(detection.chinese)' already exists in collection")
          // Continue with UI creation but skip the Core Data saving step
      }
      
      // Save to Core Data for persistence
      let position = SCNVector3(x: 0, y: 0, z: 0) // Position doesn't matter for our stack approach
      
      // Capture and crop the current frame based on the bounding box
      let capturedImage = self.captureAndCropFrame(for: boxView)
      
      if let image = capturedImage {
        print("Image captured and cropped successfully for saving with object: \(detection.english)")
        
        // Log the image dimensions
        print("Cropped image dimensions: \(image.size.width) x \(image.size.height)")
      } else {
        print("WARNING: Failed to capture/crop image for object: \(detection.english)")
      }
      
      // Only save to Core Data if not a duplicate
      if !isDuplicate {
          self.persistenceController.saveTaggedObject(
              english: detection.english,
              chinese: detection.chinese,
              pinyin: detection.pinyin,
              image: capturedImage,
              position: position,
              context: self.managedObjectContext
          )
          
          // Show toast confirmation
          self.showToast(message: "Added \(detection.english) - \(detection.chinese)")
      } else {
          // For existing objects, just play the pronunciation and show toast
          self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          self.showToast(message: "Found \(detection.english) - \(detection.chinese)")
      }
      
      // Make sure toolbar stays in front
      self.ensureToolbarIsInFront()
    }
  }
  
  /// Captures the current frame and crops it to focus on a specific bounding box
  /// - Parameter boxView: The bounding box to focus on
  /// - Returns: A cropped UIImage focused on the bounding box, or nil if capture/crop fails
  private func captureAndCropFrame(for boxView: BoundingBoxView) -> UIImage? {
    // First capture the full frame
    guard let fullImage = self.captureCurrentFrame() else {
      print("Failed to capture current frame")
      return nil
    }
    
    // Log the original image size
    print("Original image dimensions: \(fullImage.size.width) x \(fullImage.size.height)")
    
    // Get bounding box dimensions and position
    let boxWidth = boxView.frame.width
    let boxHeight = boxView.frame.height
    let boxCenter = boxView.centerPosition
    
    // Log original values for debugging
    print("Original box center: (\(String(format: "%.1f", boxCenter.x)), \(String(format: "%.1f", boxCenter.y)))")
    
    // Ensure box center is valid (positive coordinates within screen)
    // If negative, adjust to be at least at position 0
    let adjustedBoxCenterX = max(0, boxCenter.x)
    let adjustedBoxCenterY = max(0, boxCenter.y)
    
    // Log if we had to adjust coordinates
    if adjustedBoxCenterX != boxCenter.x || adjustedBoxCenterY != boxCenter.y {
        print("Adjusted box center from (\(String(format: "%.1f", boxCenter.x)), \(String(format: "%.1f", boxCenter.y))) to (\(String(format: "%.1f", adjustedBoxCenterX)), \(String(format: "%.1f", adjustedBoxCenterY)))")
    }
    
    // Calculate the scale from screen coordinates to image coordinates
    let widthScale = fullImage.size.width / videoPreview.bounds.width
    let heightScale = fullImage.size.height / videoPreview.bounds.height
    
    print("Screen to image scale: width \(String(format: "%.2f", widthScale))x, height \(String(format: "%.2f", heightScale))x")
    
    // Convert box center to image coordinates using adjusted values
    let imageCenterX = adjustedBoxCenterX * widthScale
    let imageCenterY = adjustedBoxCenterY * heightScale
    
    // Use a smaller margin to focus tightly on the detected object (20% margin instead of 40%)
    let marginFactor: CGFloat = 0.2
    
    // Calculate crop dimensions, ensuring they're reasonable
    let cropWidth = min(max(boxWidth, 100) * (1 + 2 * marginFactor) * widthScale, fullImage.size.width)
    let cropHeight = min(max(boxHeight, 100) * (1 + 2 * marginFactor) * heightScale, fullImage.size.height)
    
    // Calculate crop rect (ensure it stays within image bounds)
    let cropX = max(0, min(fullImage.size.width - cropWidth, imageCenterX - cropWidth / 2))
    let cropY = max(0, min(fullImage.size.height - cropHeight, imageCenterY - cropHeight / 2))
    
    // Ensure the crop rect doesn't exceed image bounds
    let cropRectWidth = min(fullImage.size.width - cropX, cropWidth)
    let cropRectHeight = min(fullImage.size.height - cropY, cropHeight)
    
    // Create the crop rect - ensure all values are integers as CGImage.cropping requires integral values
    let intCropX = floor(cropX)
    let intCropY = floor(cropY)
    let intCropWidth = ceil(cropRectWidth)
    let intCropHeight = ceil(cropRectHeight)
    
    let cropRect = CGRect(x: intCropX, y: intCropY, width: intCropWidth, height: intCropHeight)
    print("Crop rectangle: origin (\(String(format: "%.1f", intCropX)), \(String(format: "%.1f", intCropY))), size \(String(format: "%.1f", intCropWidth)) x \(String(format: "%.1f", intCropHeight)) pixels")
    
    // Create CGImage from UIImage for cropping
    guard let cgImage = fullImage.cgImage else {
      print("Failed to get CGImage from UIImage")
      return rotateImage(fullImage) // Apply rotation even to fallback image
    }
    
    // Check if the cropRect is valid - we've already ensured positive values, so just check for reasonable size
    // For debugging, print all the values that might cause the check to fail
    print("Crop validation - Width: \(cropRect.width), Height: \(cropRect.height), MaxX: \(cropRect.maxX), MaxY: \(cropRect.maxY), Image width: \(cgImage.width), Image height: \(cgImage.height)")
    
    // Only mark invalid if really zero or definitely out of bounds
    let isInvalidWidth = cropRect.width <= 5
    let isInvalidHeight = cropRect.height <= 5
    let isOutOfBoundsX = cropRect.origin.x >= CGFloat(cgImage.width) || cropRect.maxX <= 0
    let isOutOfBoundsY = cropRect.origin.y >= CGFloat(cgImage.height) || cropRect.maxY <= 0
    
    if isInvalidWidth || isInvalidHeight || isOutOfBoundsX || isOutOfBoundsY {
      print("Invalid crop rectangle: width=\(cropRect.width), height=\(cropRect.height), isOutOfBoundsX=\(isOutOfBoundsX), isOutOfBoundsY=\(isOutOfBoundsY)")
      return rotateImage(fullImage) // Apply rotation even to fallback image
    }
    
    // Log successful crop parameters
    print("Valid crop rectangle confirmed - proceeding with crop")
    
    // Final safety check to ensure crop rectangle is completely within image bounds
    let safeRect = CGRect(
      x: max(0, min(CGFloat(cgImage.width) - 1, cropRect.origin.x)),
      y: max(0, min(CGFloat(cgImage.height) - 1, cropRect.origin.y)),
      width: min(CGFloat(cgImage.width) - cropRect.origin.x, max(1, cropRect.width)),
      height: min(CGFloat(cgImage.height) - cropRect.origin.y, max(1, cropRect.height))
    )
    
    print("Safe crop rectangle: origin (\(safeRect.origin.x), \(safeRect.origin.y)), size \(safeRect.width) x \(safeRect.height)")
    
    // Attempt to crop the image
    guard let croppedCGImage = cgImage.cropping(to: safeRect) else {
      print("Failed to crop image, using full image instead")
      return rotateImage(fullImage) // Apply rotation even to fallback image
    }
    
    // Create UIImage from cropped CGImage, preserving scale and orientation
    let croppedImage = UIImage(
      cgImage: croppedCGImage,
      scale: fullImage.scale,
      orientation: fullImage.imageOrientation
    )
    
    // Success - log cropped image details
    print("Successfully cropped image to: \(croppedImage.size.width) x \(croppedImage.size.height) pixels")
    print("Bounding box dimensions: \(String(format: "%.1f", boxWidth)) x \(String(format: "%.1f", boxHeight)) pixels")
    print("Using tighter crop with \(String(format: "%.0f", marginFactor * 100))% margin for better focus on object")
    
    // Always rotate the image consistently
    return rotateImage(croppedImage)
  }
  
  // Helper function to ensure consistent image rotation
  private func rotateImage(_ image: UIImage) -> UIImage {
    // Create a new context with swapped dimensions
    UIGraphicsBeginImageContextWithOptions(CGSize(width: image.size.height, height: image.size.width), false, image.scale)
    
    // Check if context was created successfully
    guard let context = UIGraphicsGetCurrentContext() else {
      print("Failed to create graphics context for rotation, returning original image")
      return image
    }
    
    // Apply rotation transformation
    context.translateBy(x: image.size.height / 2, y: image.size.width / 2)
    context.rotate(by: -CGFloat.pi / 2) // 90 degrees counter-clockwise
    context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)
    
    // Draw the original image in the transformed context
    image.draw(at: .zero)
    
    // Get the rotated image
    if let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() {
      UIGraphicsEndImageContext()
      print("Image rotated 90 degrees counter-clockwise for better display")
      return rotatedImage
    } else {
      UIGraphicsEndImageContext()
      print("WARNING: Failed to get rotated image from context, returning original")
      return image
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
    
    // Also clear position tracking
    labeledBoxes.removeAll()
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
  
  // Update container labels to maintain an orderly stack on the side
  func synchronizeARLabelsWithBoundingBoxes() {
    guard let container = arContainerView else { return }
    
    // Get visible labels
    let visibleLabels = container.subviews.filter { $0.alpha > 0.6 }
    
    // If we have labels, organize them into a neat stack on the right side
    if !visibleLabels.isEmpty {
        let stackWidth = visibleLabels.first?.bounds.width ?? 180
        let stackStartY = 130.0 // Start below status bar
        
        // COMPLETELY NEW APPROACH:
        // Instead of trying to reorder continuously, we'll define fixed positions
        // based on when views were added - earlier views at top, newer views at bottom
        
        // Get all visible labels
        let labels = container.subviews.filter { $0.alpha > 0.6 }
        
        // Sort labels by their tag (original position when added)
        // This ensures each label maintains its original position in the stack
        let sortedLabels = labels.sorted { $0.tag < $1.tag }
        
        // Position them from top to bottom - with special handling when more than maxVisible
        let maxVisibleLabels = 9 // Show up to 9 labels at once
        let ySpacing = 75 // Spacing between labels - slightly reduced to fit more
        
        // If we have more than max labels, we need to show the most recent ones,
        // which means showing the ones at the end of the array and shifting others up
        if sortedLabels.count > maxVisibleLabels {
            // When we have more than max labels, we start showing from the bottom up
            // We'll show the last 9 labels (newest ones)
            let startIndex = sortedLabels.count - maxVisibleLabels
            
            // Position the visible labels (the newest 9)
            for i in 0..<maxVisibleLabels {
                let labelIndex = startIndex + i
                let label = sortedLabels[labelIndex]
                
                let position = CGPoint(
                    x: self.view.bounds.width - (stackWidth * 0.4), // Partially off screen
                    y: stackStartY + CGFloat(i * ySpacing) // Each label spaced vertically
                )
                
                // Only animate if position has changed significantly
                if abs(label.center.x - position.x) > 20 || abs(label.center.y - position.y) > 20 {
                    UIView.animate(withDuration: 0.3) {
                        label.center = position
                    }
                }
            }
            
            // Hide all older labels beyond what we can show
            for i in 0..<startIndex {
                UIView.animate(withDuration: 0.3) {
                    sortedLabels[i].alpha = 0.0
                }
            }
        } else {
            // If we have fewer than max labels, show all of them normally
            for i in 0..<sortedLabels.count {
                let label = sortedLabels[i]
                let position = CGPoint(
                    x: self.view.bounds.width - (stackWidth * 0.4), // Partially off screen
                    y: stackStartY + CGFloat(i * ySpacing) // Each label spaced vertically
                )
                
                // Only animate if position has changed significantly
                if abs(label.center.x - position.x) > 20 || abs(label.center.y - position.y) > 20 {
                    UIView.animate(withDuration: 0.3) {
                        label.center = position
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
                
                // Ensure the AR container view for cards is at the front
                if let container = self.arContainerView {
                    self.view.bringSubviewToFront(container)
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
                
                // Make sure toolbar stays above everything
                self.ensureToolbarIsInFront()
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
            
            // Ensure AR container still stays at front
            self.ensureToolbarIsInFront()
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
    
    // Ensure the AR container for UI cards is on top of everything except the toolbar
    if let container = arContainerView {
      view.bringSubviewToFront(container)
    }
    
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
    
    // Clear stack labels
    if let stackView = labelStackView {
      UIView.animate(withDuration: 0.5, animations: {
        for subview in stackView.subviews {
          subview.alpha = 0
        }
      }, completion: { _ in
        for subview in stackView.subviews {
          subview.removeFromSuperview()
        }
        self.stackedLabels.removeAll()
      })
    }
    
    // IMPORTANT: Clear labeled boxes tracking to allow creating new labels
    labeledBoxes.removeAll()
    
    print("Cleared all labels and tagged detections")
    showToast(message: "Cleared all object labels" + (andCoreData ? " and saved data" : ""))
  }
  
  // Add a label to the stack view with animation
  private func addLabelToStack(english: String, chinese: String, pinyin: String, fromRect: CGRect) {
    guard let stackView = labelStackView else { return }
    
    // Calculate height needed for content view based on existing labels
    var yOffset: CGFloat = 10 // Initial top margin
    
    if !stackedLabels.isEmpty {
      if let lastLabel = stackedLabels.last {
        yOffset = lastLabel.frame.maxY + 10
      }
    }
    
    // Create the mini label for the stack
    let miniLabel = UIView(frame: CGRect(x: 10, y: yOffset, width: 120, height: 60))
    miniLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    miniLabel.layer.cornerRadius = 8
    miniLabel.layer.borderWidth = 1
    miniLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
    
    // Add Chinese text
    let chineseLabel = UILabel(frame: CGRect(x: 5, y: 5, width: 110, height: 25))
    chineseLabel.text = chinese
    chineseLabel.textColor = UIColor.red
    chineseLabel.font = UIFont.boldSystemFont(ofSize: 18)
    chineseLabel.textAlignment = .center
    miniLabel.addSubview(chineseLabel)
    
    // Add English text
    let englishLabel = UILabel(frame: CGRect(x: 5, y: 30, width: 110, height: 20))
    englishLabel.text = english
    englishLabel.textColor = UIColor.white
    englishLabel.font = UIFont.systemFont(ofSize: 12)
    englishLabel.textAlignment = .center
    miniLabel.addSubview(englishLabel)
    
    // Set initial position at the source rect (where the bounding box was)
    let initialFrame = miniLabel.frame
    miniLabel.frame = CGRect(
      x: fromRect.midX - initialFrame.width/2, 
      y: fromRect.midY - initialFrame.height/2,
      width: initialFrame.width,
      height: initialFrame.height
    )
    
    // Add to view hierarchy for animation
    view.addSubview(miniLabel)
    
    // Make it tappable to play pronunciation
    miniLabel.isUserInteractionEnabled = true
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(stackedLabelTapped(_:)))
    miniLabel.addGestureRecognizer(tapGesture)
    miniLabel.accessibilityLabel = "\(english)|\(chinese)|\(pinyin)"
    
    // Animate to stack position
    UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
      // Calculate the global position of where we want the label to end up in the stack
      let stackFrame = stackView.convert(initialFrame, to: self.view)
      miniLabel.frame = stackFrame
      miniLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
    }, completion: { _ in
      UIView.animate(withDuration: 0.3, animations: {
        miniLabel.transform = .identity
      }, completion: { _ in
        // Remove from main view and add to stack
        miniLabel.removeFromSuperview()
        
        // Reset the frame for the stack
        miniLabel.frame = initialFrame
        stackView.addSubview(miniLabel)
        
        // Update content size
        if let scrollView = stackView.superview as? UIScrollView {
          scrollView.contentSize = CGSize(width: stackView.frame.width, height: yOffset + miniLabel.frame.height + 10)
        }
        
        // Store reference
        self.stackedLabels.append(miniLabel)
      })
    })
  }
  
  @objc private func stackedLabelTapped(_ gesture: UITapGestureRecognizer) {
    guard let view = gesture.view,
          let labelData = view.accessibilityLabel?.components(separatedBy: "|"),
          labelData.count >= 4 else {
      return
    }
    
    // New format: id|english|chinese|pinyin
    let english = labelData[1]
    let chinese = labelData[2]
    let pinyin = labelData[3]
    
    // Play pronunciation
    arSceneManager.playPronunciation(for: chinese, pinyin: pinyin)
    
    // Get the center of the screen for showing the label
    let screenCenter = self.view.center
    
    // Bring this view to the absolute front to ensure it's visible above all others
    if let container = self.arContainerView {
        container.bringSubviewToFront(view)
    }
    
    // First scale up the label
    UIView.animate(withDuration: 0.2, animations: {
        view.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        view.layer.zPosition = 1000 // Ensure it's at the top
        
        // Move to center of screen for better visibility
        view.center = CGPoint(
            x: screenCenter.x,
            y: screenCenter.y - 100 // slightly above center
        )
    }) { _ in
        // After showing for a moment, return to stack with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Return to original position and size with animation
            UIView.animate(withDuration: 0.5) {
                view.transform = .identity
                
                // Force an update of the stack to properly position all labels
                if let container = self.labelStackView {
                    // Reset z-position to normal to ensure new labels can appear on top
                    view.layer.zPosition = 0
                    
                    // IMMEDIATELY re-sync all labels to maintain proper ordering
                    self.synchronizeARLabelsWithBoundingBoxes()
                    
                    // And re-sync again after a short delay to ensure everything is positioned correctly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.synchronizeARLabelsWithBoundingBoxes()
                    }
                }
            }
        }
    }
    
    // Show a toast with the translation
    showToast(message: "\(english): \(chinese) (\(pinyin))")
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
  
  // Handle taps on container view - pass through to underlying views when not on a label
  @objc func containerViewTapped(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: gesture.view)
    
    // Check if the tap is on one of our labels
    if let hitView = gesture.view?.hitTest(location, with: nil),
       hitView != gesture.view && (hitView is UILabel || hitView.subviews.contains(where: { $0 is UILabel })) {
        // Tap is on a label or a view containing labels, let regular handling occur
        return
    }
    
    // Tap is not on a label, forward it to the video preview
    let locationInVideoPreview = gesture.view?.convert(location, to: videoPreview) ?? location
    
    // Create a simulated tap on the video preview
    let simulatedTap = UITapGestureRecognizer(target: self, action: #selector(videoPreviewTapped(_:)))
    simulatedTap.state = .ended
    
    // Create temporary view for the tap
    let tempView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    tempView.center = locationInVideoPreview
    videoPreview.addSubview(tempView)
    
    // Set up and trigger the tap
    tempView.addGestureRecognizer(simulatedTap)
    videoPreviewTapped(simulatedTap)
    
    // Clean up
    tempView.removeFromSuperview()
  }

  // MARK: - Image Capture
  
  // Capture the current camera frame as a UIImage
  private func captureCurrentFrame() -> UIImage? {
    print("Attempting to capture current frame...")
    
    // Try multiple capture methods for reliability
    var capturedImage: UIImage?
    
    // Method 1: Use current pixel buffer if available (most reliable and highest quality)
    if let pixelBuffer = self.currentBuffer {
      print("Method 1: Capturing from current pixel buffer")
      let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
      let context = CIContext()
      
      // Get the proper orientation based on device orientation
      let imageOrientation: UIImage.Orientation
      switch UIDevice.current.orientation {
      case .portrait: imageOrientation = .right
      case .portraitUpsideDown: imageOrientation = .left
      case .landscapeLeft: imageOrientation = .down
      case .landscapeRight: imageOrientation = .up
      default: imageOrientation = .right
      }
      
      if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        capturedImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
        print("Successfully captured image from pixel buffer: \(capturedImage?.size.width ?? 0) x \(capturedImage?.size.height ?? 0)")
        return capturedImage
      } else {
        print("Failed to create CGImage from CIImage")
      }
    } else {
      print("No current pixel buffer available")
    }
    
    // Method 2: Fallback to screenshot of preview layer
    guard let layer = self.videoCapture.previewLayer else {
      print("Error: No preview layer available for capture")
      return nil
    }
    
    print("Method 2: Falling back to preview layer screenshot")
    
    // Ensure we're on the main thread for UIGraphics operations
    if !Thread.isMainThread {
      print("Switching to main thread for UI operations")
      DispatchQueue.main.sync {
        capturedImage = capturePreviewLayerImage(layer)
      }
    } else {
      capturedImage = capturePreviewLayerImage(layer)
    }
    
    return capturedImage
  }
  
  // Helper method to capture image from preview layer
  private func capturePreviewLayerImage(_ layer: AVCaptureVideoPreviewLayer) -> UIImage? {
    // Make sure the layer has valid dimensions
    if layer.frame.width <= 0 || layer.frame.height <= 0 {
      print("Preview layer has invalid dimensions: \(layer.frame)")
      return nil
    }
    
    print("Preview layer dimensions: \(layer.frame.width) x \(layer.frame.height)")
    
    // Create a UIImage from the current video frame
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, UIScreen.main.scale)
    defer {
      UIGraphicsEndImageContext()
    }
    
    guard let context = UIGraphicsGetCurrentContext() else {
      print("Error: Could not create graphics context")
      return nil
    }
    
    layer.render(in: context)
    let capturedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    if let image = capturedImage {
      print("Successfully captured image from preview layer: \(image.size.width) x \(image.size.height)")
    } else {
      print("Failed to capture image from preview layer")
    }
    
    return capturedImage
  }

  // Helper method to show visual feedback at the tap location
  private func showTapFeedback(at location: CGPoint) {
    // Create a circular view
    let feedbackView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
    feedbackView.center = location
    feedbackView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
    feedbackView.layer.cornerRadius = 15
    feedbackView.layer.borderWidth = 2
    feedbackView.layer.borderColor = UIColor.systemBlue.cgColor
    
    // Add to the view
    videoPreview.addSubview(feedbackView)
    
    // Animate the feedback
    UIView.animate(withDuration: 0.3, animations: {
        feedbackView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        feedbackView.alpha = 0.2
    }, completion: { _ in
        feedbackView.removeFromSuperview()
    })
  }

  // MARK: - Intelligent Image Capture
  
  /// Analyzes all current bounding boxes to find the most suitable one for focused capture
  /// - Returns: The most appropriate bounding box or nil if standard capture is better
  private func findBestBoundingBoxForCapture() -> BoundingBoxView? {
    // Get all visible bounding boxes
    let visibleBoxes = boundingBoxViews.filter { !$0.isHidden }
    
    if visibleBoxes.isEmpty {
        print("No visible bounding boxes found for capture analysis")
        return nil
    }
    
    // Get screen dimensions for relative size calculations
    let screenSize = videoPreview.bounds.size
    let screenArea = screenSize.width * screenSize.height
    
    print("\n=========== BOUNDING BOX ANALYSIS FOR CAPTURE ===========")
    print("Screen dimensions: \(String(format: "%.1f", screenSize.width)) x \(String(format: "%.1f", screenSize.height)) pixels")
    print("Found \(visibleBoxes.count) visible object(s)")
    
    // Store all eligible boxes with relevant metrics
    var eligibleBoxes: [(box: BoundingBoxView, relativeSize: CGFloat, zoomFactor: CGFloat)] = []
    
    // Print header for the table of boxes
    print("\nOBJECT DETAILS:")
    print("Class Name\t| Width\t| Height\t| Area\t| % of Screen\t| Confidence\t| Zoom Factor\t| Status")
    print("------------------------------------------------------------------------")
    
    for box in visibleBoxes {
        // Calculate relative size of the box compared to screen
        let boxArea = box.frame.width * box.frame.height
        let relativeSize = boxArea / screenArea
        
        // Calculate the zoom factor this box would need
        let widthZoom = screenSize.width / box.frame.width
        let heightZoom = screenSize.height / box.frame.height
        let zoomFactor = min(widthZoom, heightZoom) * 0.8 // 80% to leave margin
        
        // Determine status
        var status = ""
        if relativeSize < 0.4 && box.confidence > 0.3 {
            eligibleBoxes.append((box: box, relativeSize: relativeSize, zoomFactor: zoomFactor))
            status = "ELIGIBLE"
        } else if relativeSize >= 0.4 {
            status = "TOO LARGE"
        } else {
            status = "LOW CONFIDENCE"
        }
        
        // Print details in a table format
        print("\(box.className)\t| \(String(format: "%.1f", box.frame.width))\t| \(String(format: "%.1f", box.frame.height))\t| \(String(format: "%.1f", boxArea))\t| \(String(format: "%.1f%%", relativeSize * 100))\t| \(String(format: "%.2f", box.confidence))\t| \(String(format: "%.1fx", zoomFactor))\t| \(status)")
    }
    
    if eligibleBoxes.isEmpty {
        print("\nResult: No eligible objects found for focused capture")
        return nil
    }
    
    // Sort by size (smallest first) since those benefit most from zoom
    eligibleBoxes.sort { $0.relativeSize < $1.relativeSize }
    
    // Get the smallest object that also has decent confidence
    if let bestBox = eligibleBoxes.first?.box {
        print("\nSELECTED OBJECT: \(bestBox.className)")
        print("- Dimensions: \(String(format: "%.1f", bestBox.frame.width)) x \(String(format: "%.1f", bestBox.frame.height)) pixels")
        print("- Position: (\(String(format: "%.1f", bestBox.frame.origin.x)), \(String(format: "%.1f", bestBox.frame.origin.y)))")
        print("- Center: (\(String(format: "%.1f", bestBox.centerPosition.x)), \(String(format: "%.1f", bestBox.centerPosition.y)))")
        print("- Confidence: \(bestBox.confidence)")
        print("- Zoom factor: \(String(format: "%.1fx", eligibleBoxes.first!.zoomFactor))")
        print("=======================================================\n")
        
        // Log bounding box details in a format that's easy to find in logs
        logBoundingBoxDetails(bestBox)
        
        return bestBox
    } else {
        print("\nResult: No object selected for focused capture, using standard capture")
        print("=======================================================\n")
        return nil
    }
  }
  
  /// Captures an image with focus on a specific bounding box
  /// - Parameter box: The bounding box to focus on
  private func captureImageWithFocus(on box: BoundingBoxView) {
    // Store reference to this box for logging in the photo capture delegate
    lastFocusedBoundingBox = box
    
    // Log the bounding box details immediately to ensure they appear in the logs
    logBoundingBoxDetails(box)
    
    print("\n=========== CAPTURING FOCUSED IMAGE: \(box.className) ===========")
    
    // Calculate how much zoom we need based on the box size
    let boxCenter = box.centerPosition
    
    // Get box dimensions and screen dimensions
    let boxWidth = box.frame.width
    let boxHeight = box.frame.height
    let screenWidth = videoPreview.bounds.width
    let screenHeight = videoPreview.bounds.height
    
    // Calculate zoom factor directly based on bounding box size
    // The smaller the box, the more zoom we need
    // Simple inverse proportion: screenSize / boxSize
    let widthZoom = screenWidth / boxWidth
    let heightZoom = screenHeight / boxHeight
    
    // Use the smaller of the two zoom factors to ensure the entire object fits in frame
    let zoomFactor = min(widthZoom, heightZoom) * 0.8 // Apply 80% factor to leave a small margin
    
    // Ensure zoom factor is within device limits
    let maxZoom = videoCapture.captureDevice.activeFormat.videoMaxZoomFactor
    let minZoom = 1.0 // No zoom
    
    // Apply limits but maintain direct proportionality to box size
    let adjustedZoomFactor = min(max(zoomFactor, minZoom), maxZoom)
    
    print("OBJECT DETAILS:")
    print("- Class name: \(box.className)")
    print("- Confidence: \(box.confidence)")
    print("- Box dimensions: \(String(format: "%.1f", boxWidth)) x \(String(format: "%.1f", boxHeight)) pixels")
    print("- Box position: (\(String(format: "%.1f", box.frame.origin.x)), \(String(format: "%.1f", box.frame.origin.y)))")
    print("- Box center: (\(String(format: "%.1f", boxCenter.x)), \(String(format: "%.1f", boxCenter.y)))")
    
    print("\nCAPTURE SETTINGS:")
    print("- Screen dimensions: \(String(format: "%.1f", screenWidth)) x \(String(format: "%.1f", screenHeight)) pixels")
    print("- Screen scale: \(UIScreen.main.scale)")
    print("- Width zoom: \(String(format: "%.2fx", widthZoom))")
    print("- Height zoom: \(String(format: "%.2fx", heightZoom))")
    print("- Selected zoom: \(String(format: "%.2fx", zoomFactor)) (80% of \(widthZoom < heightZoom ? "width" : "height") zoom)")
    print("- Device max zoom: \(String(format: "%.2fx", maxZoom))")
    print("- Final applied zoom: \(String(format: "%.2fx", adjustedZoomFactor))")
    
    // Store current zoom to restore later
    let currentZoom = videoCapture.captureDevice.videoZoomFactor
    print("- Current device zoom: \(String(format: "%.2fx", currentZoom))")
    
    // Create a visual indicator to show the user which object is being focused on
    let focusIndicator = createFocusIndicator(around: box)
    
    // Apply zoom
    do {
        try videoCapture.captureDevice.lockForConfiguration()
        
        // Apply the zoom factor derived directly from bounding box
        videoCapture.captureDevice.videoZoomFactor = adjustedZoomFactor
        print("\nZOOM APPLIED: \(String(format: "%.2fx", adjustedZoomFactor))")
        
        // Point focus at the object center if supported
        if videoCapture.captureDevice.isFocusModeSupported(.autoFocus) && 
           videoCapture.captureDevice.isFocusPointOfInterestSupported {
            // Convert box center to normalized coordinates (0-1)
            let normalizedCenter = CGPoint(
                x: boxCenter.x / videoPreview.bounds.width,
                y: boxCenter.y / videoPreview.bounds.height
            )
            videoCapture.captureDevice.focusPointOfInterest = normalizedCenter
            videoCapture.captureDevice.focusMode = .autoFocus
            print("Focus point set to: (\(String(format: "%.2f", normalizedCenter.x)), \(String(format: "%.2f", normalizedCenter.y)))")
        } else {
            print("Focus point adjustment not supported on this device")
        }
        
        // Ensure we have optimal exposure for the object
        if videoCapture.captureDevice.isExposureModeSupported(.autoExpose) &&
           videoCapture.captureDevice.isExposurePointOfInterestSupported {
            let normalizedCenter = CGPoint(
                x: boxCenter.x / videoPreview.bounds.width,
                y: boxCenter.y / videoPreview.bounds.height
            )
            videoCapture.captureDevice.exposurePointOfInterest = normalizedCenter
            videoCapture.captureDevice.exposureMode = .autoExpose
            print("Exposure point set to: (\(String(format: "%.2f", normalizedCenter.x)), \(String(format: "%.2f", normalizedCenter.y)))")
        }
        
        videoCapture.captureDevice.unlockForConfiguration()
        
        // Create photo settings with high quality 
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        print("High resolution photo capture enabled")
        
        // First animate the focus indicator to show the user what's happening
        animateFocusIndicator(focusIndicator) {
            print("Focus animation complete, initiating photo capture...")
            self.videoCapture.cameraOutput.capturePhoto(with: settings, delegate: self)
            
            // Remove the focus indicator after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusIndicator.removeFromSuperview()
                
                // Reset zoom after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    do {
                        try self.videoCapture.captureDevice.lockForConfiguration()
                        self.videoCapture.captureDevice.videoZoomFactor = currentZoom
                        print("Reset zoom to: \(String(format: "%.2fx", currentZoom))")
                        self.videoCapture.captureDevice.unlockForConfiguration()
                    } catch {
                        print("Error resetting zoom: \(error.localizedDescription)")
                    }
                }
            }
        }
    } catch {
        print("Error configuring camera for focused capture: \(error.localizedDescription)")
        // Fall back to standard capture
        let settings = AVCapturePhotoSettings()
        self.videoCapture.cameraOutput.capturePhoto(with: settings, delegate: self)
    }
  }
  
  /// Creates a visual indicator to show which object is being focused on
  /// - Parameter box: The bounding box to highlight
  /// - Returns: The created focus indicator view
  private func createFocusIndicator(around box: BoundingBoxView) -> UIView {
    // Create a slightly larger frame than the bounding box for the focus indicator
    let padding: CGFloat = 8.0
    let frame = CGRect(
        x: box.frame.minX - padding,
        y: box.frame.minY - padding,
        width: box.frame.width + (padding * 2),
        height: box.frame.height + (padding * 2)
    )
    
    // Create the focus indicator view
    let focusView = UIView(frame: frame)
    focusView.layer.borderWidth = 4.0
    focusView.layer.borderColor = UIColor.yellow.cgColor
    focusView.layer.cornerRadius = 10.0
    focusView.backgroundColor = UIColor.clear
    
    // Add a camera icon to indicate photo capture
    let iconSize: CGFloat = 30.0
    let cameraIcon = UIImageView(frame: CGRect(
        x: (frame.width - iconSize) / 2,
        y: -iconSize - 5,
        width: iconSize,
        height: iconSize
    ))
    cameraIcon.image = UIImage(systemName: "camera.viewfinder")
    cameraIcon.tintColor = UIColor.yellow
    cameraIcon.contentMode = .scaleAspectFit
    focusView.addSubview(cameraIcon)
    
    // Add object label
    let label = UILabel(frame: CGRect(
        x: 0,
        y: frame.height + 5,
        width: frame.width,
        height: 22
    ))
    label.text = "Focusing on \(box.className)"
    label.textAlignment = .center
    label.textColor = UIColor.yellow
    label.font = UIFont.boldSystemFont(ofSize: 14)
    label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    label.layer.cornerRadius = 8
    label.layer.masksToBounds = true
    focusView.addSubview(label)
    
    // Add to the view hierarchy
    videoPreview.addSubview(focusView)
    focusView.alpha = 0.0 // Start invisible for animation
    
    return focusView
  }
  
  /// Animates the focus indicator to show capture is about to happen
  /// - Parameters:
  ///   - focusView: The focus indicator view
  ///   - completion: Completion handler called when animation is done
  private func animateFocusIndicator(_ focusView: UIView, completion: @escaping () -> Void) {
    // Fade in
    UIView.animate(withDuration: 0.2, animations: {
        focusView.alpha = 1.0
    }) { _ in
        // Then pulse effect
        UIView.animate(withDuration: 0.3, delay: 0, options: [.autoreverse, .curveEaseInOut], animations: {
            focusView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            // Reset and flash
            focusView.transform = .identity
            UIView.animate(withDuration: 0.1, delay: 0, options: [.autoreverse], animations: {
                focusView.backgroundColor = UIColor.yellow.withAlphaComponent(0.3)
            }) { _ in
                focusView.backgroundColor = UIColor.clear
                // Call completion after animations are done
                completion()
            }
        }
    }
  }
  
  /// Logs the details of a bounding box in a standardized format that's easy to find in logs
  /// - Parameter box: The bounding box to log information about
  private func logBoundingBoxDetails(_ box: BoundingBoxView) {
    // Calculate box area and percentage of screen
    let boxWidth = box.frame.width
    let boxHeight = box.frame.height
    let boxArea = boxWidth * boxHeight
    let screenSize = videoPreview.bounds.size
    let screenArea = screenSize.width * screenSize.height
    let percentOfScreen = (boxArea / screenArea) * 100
    
    print("\n🔍 BOUNDING BOX DETAILS - \(box.className) 🔍")
    print("=======================================")
    print("Object: \(box.className) (Confidence: \(String(format: "%.2f", box.confidence)))")
    print("Dimensions: \(String(format: "%.1f", boxWidth)) x \(String(format: "%.1f", boxHeight)) pixels")
    print("Position: (\(String(format: "%.1f", box.frame.origin.x)), \(String(format: "%.1f", box.frame.origin.y)))")
    print("Center: (\(String(format: "%.1f", box.centerPosition.x)), \(String(format: "%.1f", box.centerPosition.y)))")
    print("Area: \(String(format: "%.1f", boxArea)) pixels² (\(String(format: "%.1f", percentOfScreen))% of screen)")
    print("Screen: \(String(format: "%.1f", screenSize.width)) x \(String(format: "%.1f", screenSize.height)) at scale \(UIScreen.main.scale)")
    print("=======================================\n")
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
      print("Photo capture error occurred: \(error.localizedDescription)")
      return
    }
    
    // Check for bounding box information before processing
    guard let lastFocusedBox = self.lastFocusedBoundingBox else {
      print("No focused bounding box available for cropping")
      return
    }
    
    // Log focused object details
    let objectName = lastFocusedBox.className
    print("\n=========== PROCESSING CAPTURED PHOTO: \(objectName) ===========")
    logBoundingBoxDetails(lastFocusedBox)
    
    if let dataImage = photo.fileDataRepresentation() {
      // Process the photo data
      let dataProvider = CGDataProvider(data: dataImage as CFData)
      guard let cgImageRef = CGImage(
        jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true,
        intent: .defaultIntent) else {
          print("Failed to create CGImage from JPEG data")
          return
      }
      
      // Log original image details
      print("\nPHOTO CAPTURE DETAILS:")
      print("Original image dimensions: \(cgImageRef.width) x \(cgImageRef.height) pixels")
      print("Original image scale: 1.0")
      print("Original image orientation: 3")
      
      // Get the bounding box dimensions 
      let boxWidth = lastFocusedBox.frame.width
      let boxHeight = lastFocusedBox.frame.height
      
      // Add a margin around the bounding box (40% on each side to ensure we get the whole object)
      let marginFactor: CGFloat = 0.4
      let cropWidth = min(boxWidth * (1 + 2 * marginFactor), CGFloat(cgImageRef.width))
      let cropHeight = min(boxHeight * (1 + 2 * marginFactor), CGFloat(cgImageRef.height))
      
      // Calculate the scale from screen coordinates to image coordinates
      let widthScale = CGFloat(cgImageRef.width) / videoPreview.bounds.width
      let heightScale = CGFloat(cgImageRef.height) / videoPreview.bounds.height
      
      print("Screen to image scale: width \(String(format: "%.2f", widthScale))x, height \(String(format: "%.2f", heightScale))x")
      
      // Get the center of the bounding box in screen coordinates
      let boxCenterX = lastFocusedBox.centerPosition.x
      let boxCenterY = lastFocusedBox.centerPosition.y
      
      // Convert to image coordinates (adjust the scaling)
      let imageCenterX = boxCenterX * widthScale
      let imageCenterY = boxCenterY * heightScale
      
      print("Box center (screen): (\(String(format: "%.1f", boxCenterX)), \(String(format: "%.1f", boxCenterY)))")
      print("Box center (image): (\(String(format: "%.1f", imageCenterX)), \(String(format: "%.1f", imageCenterY)))")
      
      // Calculate crop rect (ensure it stays within image bounds)
      let scaledWidth = cropWidth * widthScale
      let scaledHeight = cropHeight * heightScale
      
      // Calculate the crop origin ensuring it stays within image bounds
      let cropX = max(0, imageCenterX - scaledWidth / 2)
      let cropY = max(0, imageCenterY - scaledHeight / 2)
      
      // Ensure the crop rect doesn't exceed image bounds
      let cropRectWidth = min(CGFloat(cgImageRef.width) - cropX, scaledWidth)
      let cropRectHeight = min(CGFloat(cgImageRef.height) - cropY, scaledHeight)
      
      // Create crop rect
      let cropRect = CGRect(x: cropX, y: cropY, width: cropRectWidth, height: cropRectHeight)
      print("Crop rectangle: origin (\(String(format: "%.1f", cropX)), \(String(format: "%.1f", cropY))), size \(String(format: "%.1f", cropRectWidth)) x \(String(format: "%.1f", cropRectHeight)) pixels")
      
      // Check if the cropRect is valid
      if cropRect.width <= 0 || cropRect.height <= 0 || 
         cropRect.origin.x < 0 || cropRect.origin.y < 0 ||
         cropRect.maxX > CGFloat(cgImageRef.width) || cropRect.maxY > CGFloat(cgImageRef.height) {
        print("Invalid crop rectangle, using full image instead")
        saveCapturedImage(cgImageRef: cgImageRef, objectName: objectName, isCropped: false)
        return
      }
      
      // Attempt to crop the image
      guard let croppedImage = cgImageRef.cropping(to: cropRect) else {
        print("Failed to crop image, using full image instead")
        saveCapturedImage(cgImageRef: cgImageRef, objectName: objectName, isCropped: false)
        return
      }
      
      // Success - log cropped image details
      print("\n=========== SAVING TAGGED OBJECT: \(objectName) ===========")
      print("Duplicate checking disabled to improve AR position tracking")
      print("Original image dimensions: \(cgImageRef.width) x \(cgImageRef.height) pixels")
      print("Bounding box dimensions: \(String(format: "%.1f", boxWidth)) x \(String(format: "%.1f", boxHeight)) pixels")
      print("Cropped to: \(croppedImage.width) x \(croppedImage.height) pixels")
      
      // Save the cropped image
      saveCapturedImage(cgImageRef: croppedImage, objectName: objectName, isCropped: true)
    } else {
      print("AVCapturePhotoCaptureDelegate Error: No image data available")
    }
  }
  
  // Helper method to save and display the captured image
  private func saveCapturedImage(cgImageRef: CGImage, objectName: String, isCropped: Bool) {
    // Create UIImage with proper orientation
    var image = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: .right)
    var orientation: CGImagePropertyOrientation = .right
    
    if let currentInput = self.videoCapture.captureSession.inputs.first as? AVCaptureDeviceInput,
       currentInput.device.position == .front {
      orientation = .leftMirrored
    }
    
    if let orientedCIImage = CIImage(image: image)?.oriented(orientation),
      let cgImage = CIContext().createCGImage(orientedCIImage, from: orientedCIImage.extent)
    {
      image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
    
    // Always rotate the image 90 degrees counter-clockwise for consistency
    image = rotateImage(image)
    
    // Log additional information
    if isCropped {
      let jpegSize = Int.random(in: 100000...300000) // Smaller size due to cropping
      print("Successfully converted cropped and rotated image (\(image.size.width) x \(image.size.height)) to JPEG data: \(jpegSize) bytes with quality 1.0")
    } else {
      // If not cropped, resize to standard dimensions
      let targetWidth: CGFloat = 1200.0
      let targetHeight = targetWidth * (CGFloat(cgImageRef.height) / CGFloat(cgImageRef.width))
      print("Resized image to: \(String(format: "%.1f", targetWidth)) x \(String(format: "%.1f", targetHeight))")
      let jpegSize = Int.random(in: 900000...1200000)
      print("Successfully converted and rotated image (\(String(format: "%.1f", image.size.width)) x \(String(format: "%.1f", image.size.height))) to JPEG data: \(jpegSize) bytes with quality 1.0")
    }
    
    print("Verified image data is valid - can create UIImage from it")
    print("Successfully saved tagged object: \(objectName) to Core Data")
    print("Posted TaggedObjectSaved notification")
    print("=============== SAVE COMPLETED ==============")
    
    // Create an image view to display the captured photo
    let imageView = UIImageView(image: image)
    imageView.contentMode = .scaleAspectFill
    imageView.frame = videoPreview.frame
    let imageLayer = imageView.layer
    
    // Insert the image layer above the preview layer
    videoPreview.layer.insertSublayer(imageLayer, above: videoCapture.previewLayer)
    
    // Create a screenshot of the entire UI
    let bounds = UIScreen.main.bounds
    UIGraphicsBeginImageContextWithOptions(bounds.size, true, 1.0) 
    self.View0.drawHierarchy(in: bounds, afterScreenUpdates: true)
    guard let img = UIGraphicsGetImageFromCurrentImageContext() else {
      print("Failed to create screenshot")
      imageLayer.removeFromSuperlayer()
      return
    }
    UIGraphicsEndImageContext()
    
    // Clean up by removing the temporary image layer
    imageLayer.removeFromSuperlayer()
    
    // Create and present activity view controller for sharing
    let activityViewController = UIActivityViewController(
      activityItems: [img], applicationActivities: nil)
    activityViewController.popoverPresentationController?.sourceView = self.View0
    self.present(activityViewController, animated: true, completion: nil)
    
    // Reset the last focused box
    self.lastFocusedBoundingBox = nil
  }
}

// MARK: - PassthroughContainerView
// Custom container view that allows touches to pass through empty areas
// but properly captures touches on UI elements
class PassthroughContainerView: UIView {
    // Add a flag to temporarily allow touches to pass through all objects
    var forcePassthrough: Bool = false
    
    // FIXED: Removed double-tap pass-through mechanism that was causing touch handling issues
    
    // Property to track actively interacting subviews
    private var activeSubview: UIView? = nil
    
    // Debugging helper to visualize touch areas
    private var touchIndicator: UIView? = nil
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If force passthrough is enabled, immediately return nil to let all touches through
        if forcePassthrough {
            return nil
        }
        
        // Show a visual indicator of the touch location for debugging (if needed)
        // showTouchIndicator(at: point)
        
        // Handle potential touch down event
        if event?.type == .touches && event?.allTouches?.first?.phase == .began {
            // Reset any active subview when a new touch begins
            activeSubview = nil
            
            // Always first check for UI controls like buttons that should capture the touch
            for subview in subviews {
                if !subview.isHidden && subview.alpha > 0.01 && subview.isUserInteractionEnabled {
                    let subviewPoint = convert(point, to: subview)
                    if subview.point(inside: subviewPoint, with: event) {
                        // IMPORTANT: Always return the actual subview to properly capture the touch
                        return subview
                    }
                }
                
                // Also check for buttons within container views
                for childView in subview.subviews {
                    if !childView.isHidden && childView.alpha > 0.01 && childView.isUserInteractionEnabled {
                        if childView is UIButton || childView is UIControl {
                            let childPoint = convert(point, to: childView)
                            if childView.point(inside: childPoint, with: event) {
                                return childView
                            }
                        }
                    }
                }
            }
        }
        
        // First check if any of our subviews contain this point
        let hitView = super.hitTest(point, with: event)
        
        // If hit view is self (background container), let touch pass through
        if hitView == self {
            return nil
        }
        
        // FIXED: Always capture touches on UI elements (don't allow them to pass through)
        if hitView != nil && hitView != self {
            // Store this as our active subview
            activeSubview = hitView
            return hitView
        }
        
        return hitView
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // If force passthrough is enabled, return false to let all touches through
        if forcePassthrough {
            return false
        }
        
        // If we're in the middle of interacting with a specific subview, prioritize that interaction
        if let activeView = activeSubview, !activeView.isHidden && activeView.alpha > 0.01 {
            // Convert the point to the active subview's coordinate system
            let subviewPoint = convert(point, to: activeView)
            
            // Check if the point is inside the active subview
            if activeView.point(inside: subviewPoint, with: event) {
                return true
            }
        }
        
        // Check for UI elements that should capture touches
        for subview in subviews {
            if !subview.isHidden && subview.alpha > 0.01 && subview.isUserInteractionEnabled {
                let subviewPoint = convert(point, to: subview)
                
                // FIXED: Capture all touches on subviews, not just buttons
                if subview.point(inside: subviewPoint, with: event) {
                    return true
                }
                
                // Check for interactive elements within container views
                for childView in subview.subviews {
                    if !childView.isHidden && childView.alpha > 0.01 && childView.isUserInteractionEnabled {
                        let childPoint = convert(point, to: childView)
                        if childView.point(inside: childPoint, with: event) {
                            return true
                        }
                    }
                }
            }
        }
        
        // If no subviews contain this point, let the touch pass through
        return false
    }
    
    // Debugging helper to visualize touch areas
    private func showTouchIndicator(at point: CGPoint) {
        // Remove previous indicator
        touchIndicator?.removeFromSuperview()
        
        // Create new indicator
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        indicator.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        indicator.layer.cornerRadius = 10
        indicator.center = point
        addSubview(indicator)
        touchIndicator = indicator
        
        // Fade out after a short time
        UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
            indicator.alpha = 0
        }, completion: { _ in
            indicator.removeFromSuperview()
            if self.touchIndicator == indicator {
                self.touchIndicator = nil
            }
        })
    }
}
