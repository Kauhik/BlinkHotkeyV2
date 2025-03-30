//
//  CameraManager.swift
//  BlinkHotkeyV2
//
//  Created by Kaushik Manian on [current date].
//

import Foundation
import AVFoundation
import Vision
import SwiftUI

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    @Published var currentEyeOpenness: Double = 1.0
    @Published var blinkDetected: Bool = false
    @Published var calibratedOpenValue: Double?
    @Published var calibratedBlinkValue: Double?

    var calibrationThreshold: Double? {
        if let openValue = calibratedOpenValue, let blinkValue = calibratedBlinkValue {
            return (openValue + blinkValue) / 2.0
        }
        return nil
    }

    private let videoOutput = AVCaptureVideoDataOutput()

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device found")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }

    func startSession() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    // Delegate method to process each frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNFaceObservation], let face = results.first {
                self.processFaceObservation(face)
            } else {
                DispatchQueue.main.async {
                    self.currentEyeOpenness = 1.0
                    self.blinkDetected = false
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform face landmarks request: \(error)")
        }
    }

    private func processFaceObservation(_ face: VNFaceObservation) {
        guard let landmarks = face.landmarks else { return }
        guard let leftEyePoints = landmarks.leftEye?.normalizedPoints,
              let rightEyePoints = landmarks.rightEye?.normalizedPoints else { return }

        let leftRatio = eyeOpennessRatio(from: leftEyePoints)
        let rightRatio = eyeOpennessRatio(from: rightEyePoints)
        let averageRatio = (leftRatio + rightRatio) / 2.0

        DispatchQueue.main.async {
            self.currentEyeOpenness = averageRatio
            if let threshold = self.calibrationThreshold {
                self.blinkDetected = averageRatio < threshold
            } else {
                self.blinkDetected = false
            }
        }
    }

    // Calculate eye openness ratio as (height / width) for the given eye landmarks
    private func eyeOpennessRatio(from points: [CGPoint]) -> Double {
        guard let minX = points.map({ $0.x }).min(),
              let maxX = points.map({ $0.x }).max(),
              let minY = points.map({ $0.y }).min(),
              let maxY = points.map({ $0.y }).max() else {
            return 1.0
        }
        let width = Double(maxX - minX)
        let height = Double(maxY - minY)
        return width == 0 ? 1.0 : height / width
    }
}
