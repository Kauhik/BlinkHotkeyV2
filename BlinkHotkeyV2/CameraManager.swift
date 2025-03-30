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
import Carbon.HIToolbox  // for key code definitions

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    @Published var currentEyeOpenness: Double = 1.0
    @Published var blinkDetected: Bool = false
    @Published var calibratedOpenValue: Double?
    @Published var calibratedBlinkValue: Double?

    // Blink counting properties
    @Published var blinkCount: Int = 0
    var lastBlinkTime: Date?
    var isBlinking: Bool = false  // to track state transitions

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
                let isCurrentlyBlink = averageRatio < threshold
                self.blinkDetected = isCurrentlyBlink
                
                // Only count a blink on a transition from non-blink to blink.
                if isCurrentlyBlink && !self.isBlinking {
                    self.isBlinking = true
                    let now = Date()
                    // If the previous blink was within 1 second, count it; otherwise, start over.
                    if let last = self.lastBlinkTime, now.timeIntervalSince(last) < 1.0 {
                        self.blinkCount += 1
                    } else {
                        self.blinkCount = 1
                    }
                    self.lastBlinkTime = now
                    
                    // When two consecutive blinks are detected, simulate CMD+V.
                    if self.blinkCount >= 2 {
                        self.sendCmdVHotkey()
                        self.blinkCount = 0
                    }
                } else if !isCurrentlyBlink {
                    self.isBlinking = false
                }
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

    // Simulate CMD+V keystroke using Quartz events.
    // Note: Your app must have Accessibility permissions enabled.
    func sendCmdVHotkey() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Key code for 'v' is typically 9 on Mac keyboards.
        let keyCodeV: CGKeyCode = 9
        
        // Create a key down event with the Command modifier.
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Create a key up event with the Command modifier.
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("CMD+V hotkey sent")
    }
}
