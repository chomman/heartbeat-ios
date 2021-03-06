//
//  ViewController.swift
//  yolo-object-tracking
//
//  Created by Mikael Von Holst on 2017-12-19.
//  Copyright © 2017 Mikael Von Holst. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVFoundation
import Accelerate
import Fritz

class SSDViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var frameLabel: UILabel!
    var lastExecution = Date()
    var screenHeight: Double?
    var screenWidth: Double?

    let visionModel = FritzVisionObjectModel()

    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()

        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
            else { return session }
        session.addInput(input)
        return session
    }()

    let numBoxes = 100
    var boundingBoxes: [BoundingBox] = []
    let multiClass = true

    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        self.cameraView?.bringSubview(toFront: self.frameLabel)
        self.frameLabel.textAlignment = .left
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        setupBoxes()
        screenWidth = Double(view.frame.width)
        screenHeight = Double(view.frame.height)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraLayer.frame = cameraView.layer.bounds
    }

    func setupBoxes() {
        // Create shape layers for the bounding boxes.
        for _ in 0..<numBoxes {
            let box = BoundingBox()
            box.addToLayer(cameraView)
            self.boundingBoxes.append(box)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func drawBoxes(predictions: [FritzVisionObject], framesPerSecond: Double) {
        self.frameLabel.text = "FPS: \(framesPerSecond.format(f: ".3"))"

        let filteredPredictions = predictions.filter { $0.label.label == "person" }
        for (index, prediction) in filteredPredictions.enumerated() {
            let textLabel = String(format: "%.2f - %@", prediction.label.confidence, prediction.label.label)

            let height = Double(cameraView.frame.height)
            let width = Double(cameraView.frame.width)
            let yOffset = (height - width) / 2

            let box = prediction.boundingBox
            let rect = box.toCGRect(imgHeight: width, imgWidth: width, xOffset: 0.0, yOffset: yOffset)
            self.boundingBoxes[index].show(frame: rect,
                                           label: textLabel,
                                           color: UIColor.red, textColor: UIColor.black)
        }

        for index in filteredPredictions.count..<self.numBoxes {
            self.boundingBoxes[index].hide()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let options = FritzVisionObjectModelOptions(threshold: 0.5)
        let image = FritzVisionImage(buffer: sampleBuffer)
        image.metadata = FritzVisionImageMetadata()

        visionModel.predict(image, options: options) { objects, error in
            if let objects = objects, objects.count > 0 {
                let thisExecution = Date()
                let executionTime = thisExecution.timeIntervalSince(self.lastExecution)
                let framesPerSecond:Double = 1/executionTime
                self.lastExecution = thisExecution

                DispatchQueue.main.async {
                    self.drawBoxes(predictions: objects, framesPerSecond: framesPerSecond)

                }
            }
        }


    }

}
