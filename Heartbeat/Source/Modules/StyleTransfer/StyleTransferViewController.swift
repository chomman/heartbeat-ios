//
//  StyleTransferViewController.swift
//  Heartbeat
//
//  Created by Jameson Toole on 6/8/18.
//  Copyright © 2018 Fritz Labs, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import AlamofireImage
import Fritz
import Photos
import CoreML


class StyleTransferViewController: UIViewController
{

    var captureController = CameraSessionController()
    
    var previewView = VideoPreviewView()
    
    var models: [MLModel] = [starryNightSmall().model]
    var activeModel: MLModel?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.white
        view.addSubview(previewView)
        
        // Tap anywhere on the screen to change the current model (hack for now)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    
    @objc func tapped()
    {
        activateNextRenderer()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        checkAuthorization(for: .camera) { (success) in
            if success {
                self.configureCaptureController()
            } else {
                showAuthorizationRequiredAlert(for: .camera, from: self)
            }
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .portrait }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // TODO use Auto Layout :(
        let maxDimension = max(view.bounds.size.width, view.bounds.size.height)
        previewView.frame = CGRect(x: (view.bounds.size.width - maxDimension) / 2, y: (view.bounds.size.height - maxDimension) / 2, width: maxDimension, height: maxDimension)
    }
    
    
    // Session handling
    func configureCaptureController()
    {
        captureController.configure()
        captureController.rendererCallback = displaySampleCallback
        captureController.pixelRenderer = rendererForModel(model: activeModel)
        captureController.startRunning()
    }
    
    func displaySampleCallback(samples: CVPixelBuffer)
    {
        previewView.display(buffer: samples)
    }
    
    func rendererForModel(model: MLModel?) -> (CVPixelBuffer) -> CVPixelBuffer
    {
        func applier(input: CVPixelBuffer) -> CVPixelBuffer
        {
            if let model = model {
                if let outFeatures = try? model.prediction(from: StyleTransferInput(input: input)),
                    let output = outFeatures.featureValue(for: "output1")?.imageBufferValue {
                    return output
                }
            }
            return input
        }
        return applier
    }
    
    func activateNextRenderer()
    {
        if let activeModel = activeModel {
            let currentModelIndex = models.index(of: activeModel)!
            if currentModelIndex == models.count - 1 {
                self.activeModel = nil
            } else {
                self.activeModel = models[currentModelIndex + 1]
            }
        } else {
            activeModel = models.first
        }
        captureController.pixelRenderer = rendererForModel(model: activeModel)
    }
}

/*
 Camera and video capture session controller
 
 
 pixelRenderer - Function that transforms pixels, typically this will be done by our ML model.
 rendererCallback - Function that handles rendered pixels, typically by displaying them.
 
 These are protected variables, and may be changed at any time.
 
 
 callbackQueue - The main queue for displaying rendered pixels.
 sessionQueue - A serial queue to lock access to the AVCaptureSession.
 videoOutputQueue - A high priority queue to process samples.
 callbackLockingQueue - A serial queue used to protect access to the callback and renderer functions.
 
 These are the locking queues currently used. We could make this more sophisticated by adopting a true
 producer/consumer dispatch model, but since we don't care about dropped frames we can simplify our architecture.
 */
class CameraSessionController : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate
{
    var session: AVCaptureSession!
    var device: AVCaptureDevice!
    
    var captureVideoInput: AVCaptureInput!
    var captureVideoOutput: AVCaptureVideoDataOutput!
    
    var running: Bool = false
    
    // Internal storage for atomic lamdas
    private var _rendererCallback: ((CVPixelBuffer) -> Void)?
    private var _pixelRenderer: ((CVPixelBuffer) -> CVPixelBuffer)?
    
    // Computed properties for atomic lamda access
    var pixelRenderer: ((CVPixelBuffer) -> CVPixelBuffer)? {
        set {
            callbackLockingQueue.sync {
                _pixelRenderer = newValue
            }
        }
        get {
            var renderer: ((CVPixelBuffer) -> CVPixelBuffer)?
            callbackLockingQueue.sync {
                renderer = _pixelRenderer
            }
            return renderer
        }
    }
    
    var rendererCallback: ((CVPixelBuffer) -> Void)? {
        set {
            callbackLockingQueue.sync {
                _rendererCallback = newValue
            }
        }
        get {
            var callback: ((CVPixelBuffer) -> Void)?
            callbackLockingQueue.sync {
                callback = _rendererCallback
            }
            return callback
        }
    }
    
    // ...
    var callbackQueue: DispatchQueue!
    // ...
    let sessionQueue = DispatchQueue(label: "queue.session", qos: DispatchQoS.default, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.workItem, target: nil)
    // ...
    let videoOutputQueue = DispatchQueue(label: "queue.video.output", qos: DispatchQoS.userInitiated, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.workItem, target: nil)
    // ...
    let callbackLockingQueue = DispatchQueue(label: "queue.session.callback.lock", qos: DispatchQoS.default, attributes: [], autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.workItem, target: nil)
    
    
    func configure()
    {
        let callerQueue = DispatchQueue.main
        
        sessionQueue.sync {
            guard session == nil else { return }
            
            callbackQueue = callerQueue
            
            // TODO: register for AVCaptureSessionRuntimeError, AVCaptureSessionDidStartRunning, AVCaptureSessionDidStopRunning, AVCaptureSessionWasInterrupted, AVCaptureSessionInterruptionEndedNotification
            // TODO: register for UIApplicationWillEnterForegroundNotification in case runtime error reason was AVErrorDeviceIsNotAvailableInBackground
            
            session = AVCaptureSession()
            
            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                device = backCamera
            } else {
                fatalError("Unable to acess the back camera. Please make sure the device supports a front-facing camera.")
            }
            
            try! device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 5)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            device.unlockForConfiguration()
            
            guard let videoInput = try? AVCaptureDeviceInput(device: device) else {
                fatalError("Unable to obtain video input for default camera.")
            }
            captureVideoInput = videoInput
            
            captureVideoOutput = AVCaptureVideoDataOutput()
            captureVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as UInt32]
            captureVideoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            captureVideoOutput.alwaysDiscardsLateVideoFrames = true
            
            guard session.canAddInput(captureVideoInput) else { fatalError("Cannot add input") }
            guard session.canAddOutput(captureVideoOutput) else { fatalError("Cannot add output") }
            
            session.beginConfiguration()
            session.sessionPreset = .vga640x480
            session.addInput(captureVideoInput)
            session.addOutput(captureVideoOutput)
            session.commitConfiguration()
            
            captureVideoOutput.connection(with: .video)?.videoOrientation = .portrait
        }
    }
    
    func tearDown()
    {
        sessionQueue.sync {
            guard session != nil else { return }
            
            // TODO: unregister notifications
            
            session = nil
            device = nil
            captureVideoOutput = nil
            captureVideoInput = nil
        }
    }
    
    func startRunning()
    {
        sessionQueue.sync {
            guard !running else { return }
            
            running = true
            session.startRunning()
        }
    }
    
    func stopRunning()
    {
        sessionQueue.sync {
            guard running else { return }
            
            session.stopRunning()
            running = false
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        // Obtain callback and renderer functions behind lock
        var callback: ((CVPixelBuffer) -> Void)?
        var renderer: ((CVPixelBuffer) -> CVPixelBuffer)?
        callbackLockingQueue.sync {
            callback = _rendererCallback
            renderer = _pixelRenderer
        }
        
        if let callback = callback,
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            let renderedImageBuffer: CVPixelBuffer
            
            if let renderer = renderer {
                renderedImageBuffer = renderer(imageBuffer)
            } else {
                renderedImageBuffer = imageBuffer
            }
            
            callbackQueue.async {
                callback(renderedImageBuffer)
            }
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        print("dropped samples")
    }
}

// Camera and Photo Library authorization handling
enum AuthorizationType {
    case camera
    case photoLibrary
}

private func checkAuthorization(for type: AuthorizationType, _ completion: @escaping ((_ autorized: Bool) -> Void))
{
    switch type {
    case .camera:
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
            
        case .denied:
            fallthrough
        case .restricted:
            completion(false)
        }
    case .photoLibrary:
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                completion(status == .authorized)
            })
            
        case .denied:
            fallthrough
        case .restricted:
            completion(false)
        }
    }
}

private func showAuthorizationRequiredAlert(for type: AuthorizationType, from controller: UIViewController)
{
    let alertController: UIAlertController
    if type == .camera {
        alertController = UIAlertController(title: "Camera Access", message: "Camera Access is requied to run this demo and can be changed in Settings | Privacy | Camera.", preferredStyle: .alert)
    } else {
        alertController = UIAlertController(title: "Photo Library Access", message: "Photo Library Access is requied to run this demo and can be changed in Settings | Privacy | Photos.", preferredStyle: .alert)
    }
    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
        alertController.dismiss(animated: true, completion: nil)
    }))
    controller.present(alertController, animated: true, completion: nil)
}
