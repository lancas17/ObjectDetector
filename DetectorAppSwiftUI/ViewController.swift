import UIKit
import SwiftUI
import AVFoundation
import Vision
import Combine

class PreviewState: ObservableObject {
    @Published var isPreviewEnabled: Bool = true
    @Published var models: [String: Bool] = [
//        "yolov7": true,
        "04172023_best": true
//        "doors_4062023": true
    ]
    @Published var confidenceThreshold: Double = 0.6
    @Published var detectedObjects: [String: Any] = [:]
    var base64ImageString: String?
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false // Flag for permission
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil // For view dimensions
    var previewState: PreviewState!
    private var isPreviewEnabledCancellable: AnyCancellable?

    
    // Detector
    private var videoOutput = AVCaptureVideoDataOutput()

    var requests: [String: [VNRequest]] = [:]
//    var yolov7Requests = [VNRequest]()
//    var doorsModelRequests = [VNRequest]()
    var bestModelRequests = [VNRequest]()
//    var yolov7DetectionLayer: CALayer! = nil
    var bestModelDetectionLayer: CALayer! = nil
//    var doorsModelDetectionLayer: CALayer! = nil

    
      
    override func viewDidLoad() {
        super.viewDidLoad()
            
        // Initialize screenRect here
        screenRect = UIScreen.main.bounds
        
        checkPermission()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            
            self.setupLayers()
            for modelName in previewState.models.keys {
                requests[modelName] = setupDetector(modelName: modelName)
            }
            
            self.captureSession.startRunning()
        }
        setupBindings()
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            self.screenRect = UIScreen.main.bounds
            self.previewLayer.frame = CGRect(x: 0, y: 0, width: self.screenRect.size.width, height: self.screenRect.size.height)
        }, completion: { _ in
            // Update the video orientation based on the new device orientation
            switch UIDevice.current.orientation {
            // Home button on top
            case .portraitUpsideDown:
                self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
             
            // Home button on right
            case .landscapeLeft:
                self.previewLayer.connection?.videoOrientation = .landscapeRight
            
            // Home button on left
            case .landscapeRight:
                self.previewLayer.connection?.videoOrientation = .landscapeLeft
             
            // Home button at bottom
            case .portrait:
                self.previewLayer.connection?.videoOrientation = .portrait
                
            default:
                break
            }

            // Detector
            self.updateLayers()
        })
    }

    
    // Add this method to the ViewController class
    func setupBindings() {
        isPreviewEnabledCancellable = previewState.$isPreviewEnabled
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] newValue in
                self?.previewLayer.isHidden = !newValue
        })
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            // Permission has been granted before
            case .authorized:
                permissionGranted = true

            // Permission has not been requested yet
            case .notDetermined:
                requestPermission()

            default:
                permissionGranted = false
            }
    }

    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    func setupCaptureSession() {
        // Camera input
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
            print("Can not get AVCaptureDevice")
            return
        }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Can not get AVCaptureDeviceInput")
            return
        }

        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
                         
        // Preview layer
        screenRect = UIScreen.main.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.backgroundColor = UIColor.black.cgColor
        
        // Detector
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        captureSession.addOutput(videoOutput)
        
        videoOutput.connection(with: .video)?.videoOrientation = .portrait
        
        // Updates to UI must be on main queue
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
        }
    }
}

struct HostedViewController: UIViewControllerRepresentable {
    @ObservedObject var previewState: PreviewState

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = ViewController()
        viewController.previewState = previewState
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}
