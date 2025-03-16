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
  
  // Track the last detected class to avoid duplicate logging
  private var lastDetectedClass: String?
  
  // Track the last time we synchronized AR labels with bounding boxes
  private var lastARSyncTime: CFTimeInterval = 0

  // Add property to store tagged detections
  private var taggedDetections: [(english: String, chinese: String, pinyin: String, worldPosition: simd_float4x4)] = []
  
  // Track hidden bounding boxes by class name
  private var hiddenBoxes: Set<String> = []

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    
    slider.value = 30
    setLabels()
    setUpBoundingBoxViews()
    setUpOrientationChangeNotification()
    
    // Initialize AR Scene Manager
    arSceneManager = ARSceneManager(viewController: self)
    
    // Add the AR view to the view hierarchy
    // Insert it above the video preview for proper layering
    view.insertSubview(arSceneManager.sceneView, aboveSubview: videoPreview)
    
    // Make sure the AR view covers the entire screen
    arSceneManager.sceneView.frame = view.bounds
    
    // Make the AR view fully transparent so we only see the AR content
    arSceneManager.sceneView.alpha = 0.0 // Start with AR mode inactive
    arSceneManager.sceneView.backgroundColor = UIColor.clear
    
    // Initially AR view is not hidden, just transparent
    // arSceneManager.sceneView.isHidden = true
    
    // Add AR toggle button
    addARToggleButton()
    
    // Add a tap gesture recognizer to the video preview view
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoPreviewTapped(_:)))
    videoPreview.addGestureRecognizer(tapGesture)
    videoPreview.isUserInteractionEnabled = true
    
    // Keep the video preview fully opaque
    videoPreview.alpha = 1.0
    
    startVideo()
    // setModel()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Start AR session
    arSceneManager.setupARSession()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause AR session
    arSceneManager.pauseARSession()
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
    self.videoCapture.start()
    playButtonOutlet.isEnabled = false
    pauseButtonOutlet.isEnabled = true
  }

  @IBAction func pauseButton(_ sender: Any?) {
    selection.selectionChanged()
    self.videoCapture.stop()
    playButtonOutlet.isEnabled = true
    pauseButtonOutlet.isEnabled = false
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
    videoCapture = VideoCapture()
    videoCapture.delegate = self

    videoCapture.setUp(sessionPreset: .photo) { success in
      // .hd4K3840x2160 or .photo (4032x3024)  Warning: 4k may not work on all devices i.e. 2019 iPod
      if success {
        // Add the video preview into the UI.
        if let previewLayer = self.videoCapture.previewLayer {
          self.videoPreview.layer.addSublayer(previewLayer)
          self.videoCapture.previewLayer?.frame = self.videoPreview.bounds  // resize preview layer
        }

        // Bring bounding box views to front
        for boxView in self.boundingBoxViews {
          self.videoPreview.bringSubviewToFront(boxView)
        }

        // Once everything is set up, we can start capturing live video.
        self.videoCapture.start()
      } else {
        print("Video capture setup failed")
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
          
          // If AR mode is active, pass the detection to the AR scene manager
          if arSceneManager.sceneView.alpha > 0.5 {
            // Update AR scene with the new detection
            arSceneManager.updateCurrentDetection(english: bestClass, chinese: translation.chinese, pinyin: translation.pinyin)
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

    // After updating all bounding boxes, synchronize with AR labels if AR mode is active
    // We'll use a timer to avoid doing this on every frame
    if arSceneManager.sceneView.alpha > 0.5 {
      // Use a static property to track when we last synchronized
      if CACurrentMediaTime() - lastARSyncTime > 2.0 { // Sync every 2 seconds
        lastARSyncTime = CACurrentMediaTime()
        // Synchronize AR labels with bounding boxes
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
    
    // Get the center of the bounding box in screen coordinates
    let boxCenter = CGPoint(x: boxView.frame.midX, y: boxView.frame.midY)
    
    // Create a visual transition effect
    let transitionView = UIView(frame: boxView.frame)
    transitionView.layer.borderWidth = 4
    transitionView.layer.borderColor = UIColor.red.cgColor
    transitionView.layer.cornerRadius = 6
    transitionView.backgroundColor = UIColor.clear
    videoPreview.addSubview(transitionView)
    
    // Add class name to hidden set
    hiddenBoxes.insert(className)
    
    // Animate the transition view expanding slightly before hiding
    UIView.animate(withDuration: 0.2, animations: {
        transitionView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        transitionView.alpha = 0.7
    }) { _ in
        // Hide the bounding box
        boxView.hide()
        
        // Play pronunciation
        self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
        
        // Try multiple hit test types to get a reliable world position
        var worldTransform: simd_float4x4?
        
        // First try feature points (most accurate for real-world positioning)
        if let hitResult = self.arSceneManager.sceneView.hitTest(boxCenter, types: [.featurePoint]).first {
            worldTransform = hitResult.worldTransform
            print("Got world position from feature point hit test")
        }
        // If that fails, try existing planes
        else if let hitResult = self.arSceneManager.sceneView.hitTest(boxCenter, types: [.existingPlaneUsingExtent]).first {
            worldTransform = hitResult.worldTransform
            print("Got world position from existing plane hit test")
        }
        // If that fails, try estimated horizontal planes
        else if let hitResult = self.arSceneManager.sceneView.hitTest(boxCenter, types: [.estimatedHorizontalPlane]).first {
            worldTransform = hitResult.worldTransform
            print("Got world position from estimated horizontal plane hit test")
        }
        
        if let transform = worldTransform {
            print("Storing tagged detection for \(className) at world position")
            self.taggedDetections.append((
                english: detection.english,
                chinese: detection.chinese,
                pinyin: detection.pinyin,
                worldPosition: transform
            ))
            print("Total tagged detections: \(self.taggedDetections.count)")
            
            // Show a toast message confirming the object was tagged
            self.showToast(message: "\(className) tagged for AR view")
        } else {
            print("Failed to get world position for \(className) - using camera-relative position")
            
            // Use a position relative to the camera
            guard let frame = self.arSceneManager.sceneView.session.currentFrame else {
                print("No current AR frame available - using default position")
                // Use a default position as last resort
                var defaultTransform = matrix_identity_float4x4
                defaultTransform.columns.3 = simd_float4(0, 0, -1, 1) // 1 meter in front of camera
                
                self.taggedDetections.append((
                    english: detection.english,
                    chinese: detection.chinese,
                    pinyin: detection.pinyin,
                    worldPosition: defaultTransform
                ))
                
                self.showToast(message: "\(className) tagged for AR view (default position)")
                return
            }
            
            // Get camera transform
            let cameraTransform = frame.camera.transform
            
            // Create a position 1 meter in front of the camera
            var transform = cameraTransform
            transform.columns.3.z -= 1.0 // 1 meter in front
            
            self.taggedDetections.append((
                english: detection.english,
                chinese: detection.chinese,
                pinyin: detection.pinyin,
                worldPosition: transform
            ))
            
            print("Stored tagged detection with camera-relative position")
            self.showToast(message: "\(className) tagged for AR view (camera-relative)")
        }
        
        // Remove the transition view with fade out
        UIView.animate(withDuration: 0.3, animations: {
            transitionView.alpha = 0
        }) { _ in
            transitionView.removeFromSuperview()
        }
        
        // Provide haptic feedback
        self.selection.selectionChanged()
    }
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

  /// Place 3D text at the position of a bounding box
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
    
    // Animate the transition view expanding slightly before placing AR content
    UIView.animate(withDuration: 0.2, animations: {
      transitionView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
      transitionView.alpha = 0.7
    }) { _ in
      // Hide the bounding box after animation completes
      boxView.hide()
      
      // Get the center of the bounding box in screen coordinates
      let boxCenter = CGPoint(
          x: boxView.frame.midX,
          y: boxView.frame.midY
      )
      
      // Perform hit test to find 3D position
      let arHitTestResults = self.arSceneManager.sceneView.hitTest(boxCenter, types: [.featurePoint])
      
      if let closestResult = arHitTestResults.first {
          // Get coordinates of hit test
          let transform = closestResult.worldTransform
          let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
          
          print("Placing 3D text at world coordinates: \(worldCoord) for detection: \(detection.english)")
          
          // Create 3D text node
          let node = self.arSceneManager.createNewBubbleParentNode(
              english: detection.english,
              chinese: detection.chinese,
              pinyin: detection.pinyin
          )
          
          // Add node to scene
          self.arSceneManager.sceneView.scene.rootNode.addChildNode(node)
          node.position = worldCoord
          
          // Store the node to prevent duplicates
          self.arSceneManager.placedNodes.append(node)
          
          // Play pronunciation
          self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          
          // Remove the transition view with fade out
          UIView.animate(withDuration: 0.3, animations: {
            transitionView.alpha = 0
          }) { _ in
            transitionView.removeFromSuperview()
          }
      } else {
          print("Could not find 3D position for bounding box. Using fallback method.")
          
          // Fallback: Use a ray from the camera through the box center
          guard let cameraNode = self.arSceneManager.sceneView.pointOfView else {
            // Remove the transition view if we can't place AR content
            transitionView.removeFromSuperview()
            return
          }
          
          // Get camera position and orientation
          let cameraPosition = cameraNode.position
          
          // Convert box center to normalized device coordinates (-1 to 1)
          let screenSize = self.arSceneManager.sceneView.bounds.size
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
          let node = self.arSceneManager.createNewBubbleParentNode(
              english: detection.english,
              chinese: detection.chinese,
              pinyin: detection.pinyin
          )
          
          self.arSceneManager.sceneView.scene.rootNode.addChildNode(node)
          node.position = position
          
          // Store the node
          self.arSceneManager.placedNodes.append(node)
          
          // Play pronunciation
          self.arSceneManager.playPronunciation(for: detection.chinese, pinyin: detection.pinyin)
          
          // Remove the transition view with fade out
          UIView.animate(withDuration: 0.3, animations: {
            transitionView.alpha = 0
          }) { _ in
            transitionView.removeFromSuperview()
          }
      }
    }
  }

  // MARK: - AR Integration
  
  // Synchronize AR labels with bounding boxes
  func synchronizeARLabelsWithBoundingBoxes() {
    // Only proceed if AR mode is active
    guard arSceneManager.sceneView.alpha > 0.5 else { return }
    
    // Get all visible bounding boxes
    let visibleBoxes = boundingBoxViews.filter { !$0.isHidden }
    
    // For each visible box, check if there's already an AR label for it
    for boxView in visibleBoxes {
      let className = boxView.className
      
      // Skip if no translation available
      guard let translation = boxView.translation else { continue }
      
      // Check if there's already an AR node for this object
      let hasARNode = arSceneManager.isNodeForObject(className)
      
      // If there's no AR node for this object and it has high confidence, create one
      if !hasARNode && boxView.confidence > 0.7 {
        // Create detection info
        let detection = (english: className, chinese: translation.chinese, pinyin: translation.pinyin)
        
        // Place AR label at the bounding box position
        // We'll use a simplified version without animation for automatic placement
        let boxCenter = CGPoint(x: boxView.frame.midX, y: boxView.frame.midY)
        
        // Perform hit test to find 3D position
        if let hitResult = arSceneManager.sceneView.hitTest(boxCenter, types: [.featurePoint]).first {
          // Get coordinates of hit test
          let transform = hitResult.worldTransform
          let worldCoord = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
          
          // Create 3D text node
          let node = arSceneManager.createNewBubbleParentNode(
            english: detection.english,
            chinese: detection.chinese,
            pinyin: detection.pinyin
          )
          
          // Add node to scene
          arSceneManager.sceneView.scene.rootNode.addChildNode(node)
          node.position = worldCoord
          
          // Store the node
          arSceneManager.placedNodes.append(node)
          
          // Don't play pronunciation for automatic placement
        }
      }
    }
  }
  
  // Toggle AR view visibility
  func toggleARView(visible: Bool) {
    if visible {
        print("Activating AR mode with \(taggedDetections.count) tagged detections")
        
        // Make sure AR session is ready before showing content
        arSceneManager.setupARSession()
        
        // Make AR view fully visible with animation
        UIView.animate(withDuration: 0.5, animations: {
            self.arSceneManager.sceneView.alpha = 1.0
        }, completion: { _ in
            // Resume AR session after animation completes
            self.arSceneManager.resumeARSession()
            
            // Wait a moment for AR session to stabilize before adding content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Show a toast message to indicate AR mode is active
                self.showToast(message: "AR Mode Active - Showing \(self.taggedDetections.count) tagged objects")
                
                // Clear existing nodes before displaying new ones
                self.arSceneManager.clearLabels()
                
                // If we have no tagged detections, show a helpful message
                if self.taggedDetections.isEmpty {
                    self.showToast(message: "No tagged objects yet. Tap on objects to tag them.")
                    return
                }
                
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
                
                // Show the clear button since we have AR content
                self.clearARButton?.isHidden = false
            }
        })
    } else {
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
            
            // Hide the clear button
            self.clearARButton?.isHidden = true
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
  
  // Clear all AR labels
  func clearARLabels() {
    arSceneManager.clearLabels()
    // Also clear tagged detections when clearing AR labels
    taggedDetections.removeAll()
    print("Cleared all AR labels and tagged detections")
    showToast(message: "Cleared all AR labels and tagged detections")
  }

  // Add a button to toggle AR view
  func addARToggleButton() {
    let button = UIButton(type: .system)
    button.setImage(UIImage(systemName: "cube.transparent"), for: .normal)
    button.tintColor = .white
    button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
    button.layer.cornerRadius = 25
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(toggleARButtonTapped), for: .touchUpInside)
    
    view.addSubview(button)
    
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: 50),
      button.heightAnchor.constraint(equalToConstant: 50),
      button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
    ])
    
    // Add clear AR labels button
    let clearButton = UIButton(type: .system)
    clearButton.setImage(UIImage(systemName: "arrow.counterclockwise.circle.fill"), for: .normal)
    clearButton.tintColor = .white
    clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
    clearButton.layer.cornerRadius = 25
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    clearButton.addTarget(self, action: #selector(clearARButtonTapped), for: .touchUpInside)
    clearButton.isHidden = true // Initially hidden
    
    view.addSubview(clearButton)
    
    NSLayoutConstraint.activate([
      clearButton.widthAnchor.constraint(equalToConstant: 50),
      clearButton.heightAnchor.constraint(equalToConstant: 50),
      clearButton.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -10),
      clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
    ])
    
    // Store reference to clear button
    self.clearARButton = clearButton
  }
  
  @objc func clearARButtonTapped() {
    // Clear all AR labels
    clearARLabels()
  }
  
  @objc func toggleARButtonTapped() {
    // Toggle AR view visibility based on alpha instead of hidden property
    let isVisible = arSceneManager.sceneView.alpha > 0.5
    print("Toggling AR mode from \(isVisible ? "active" : "inactive") to \(!isVisible ? "active" : "inactive")")
    
    // Show a loading indicator while AR is initializing
    let loadingIndicator = UIActivityIndicatorView(style: .large)
    loadingIndicator.color = .white
    loadingIndicator.center = view.center
    view.addSubview(loadingIndicator)
    loadingIndicator.startAnimating()
    
    // Run the AR session toggle on a background thread to prevent UI freezing
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      
      // Make sure the AR view is properly positioned in the view hierarchy
      if !isVisible {
        DispatchQueue.main.async {
          // Bring bounding box views to front so they appear above AR content
          for boxView in self.boundingBoxViews {
            self.videoPreview.bringSubviewToFront(boxView)
          }
        }
      }
      
      // Toggle AR view on the main thread
      DispatchQueue.main.async {
        self.toggleARView(visible: !isVisible)
        
        // Show/hide clear button
        self.clearARButton?.isHidden = isVisible
        
        // Update the AR toggle button icon to reflect the current state
        if let button = loadingIndicator.superview?.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.actions(forTarget: self, forControlEvent: .touchUpInside)?.contains("toggleARButtonTapped") == true }) as? UIButton {
          button.setImage(UIImage(systemName: !isVisible ? "cube.fill" : "cube.transparent"), for: .normal)
          button.backgroundColor = !isVisible ? UIColor.systemGreen.withAlphaComponent(0.7) : UIColor.systemBlue.withAlphaComponent(0.7)
        }
        
        // Remove loading indicator
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
      }
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
