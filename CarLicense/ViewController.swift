//
//  ViewController.swift
//  MeterNumbers
//
//  Created by Maxim Skorynin on 07.04.2021.
//

import AVKit
import UIKit

import Vision

final class ViewController: UIViewController {
    
    private var captureSession: AVCaptureSession?
    private var request: VNCoreMLRequest?
    
    private var drawingBoxesView: DrawingBoxesView?
    
    // MARK: Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupRequest()
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupBoxesView()
        captureSession?.startRunning()
    }
    
    // MARK: Functions
    
    private func setupRequest() {
        let configuration = MLModelConfiguration()
        
        guard let model = try? CarLicensePlateExperimentFullNetwork(configuration: configuration).model, let visionModel = try? VNCoreMLModel(for: model) else {
            return
        }
        
        request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        request?.imageCropAndScaleOption = .centerCrop
    }
    
    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let prediction = (request.results as? [VNRecognizedObjectObservation])?.first {
            DispatchQueue.main.async {
                self.drawingBoxesView?.drawBox(with: [prediction])
            }
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device) else {
            print("Couldn't create video input")
            return
        }
        
        session.addInput(input)
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.frame
        
        view.layer.addSublayer(preview)
        
        let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            output.connection(with: .video)?.videoOrientation = .portrait
            session.commitConfiguration()
            
            captureSession = session
        } else {
            print("Couldn't add video output")
        }
    }
    
    private func setupBoxesView() {
        let drawingBoxesView = DrawingBoxesView()
        drawingBoxesView.frame = view.frame
        
        view.addSubview(drawingBoxesView)
        self.drawingBoxesView = drawingBoxesView
    }

}

// MARK: - Video Delegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let request = request else {
            return
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
}
