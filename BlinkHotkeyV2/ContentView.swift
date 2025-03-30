//
//  ContentView.swift
//  BlinkHotkeyV2
//
//  Created by Kaushik Manian on 30/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var cameraManager = CameraManager()
    @State private var isCalibrationMode = false

    var body: some View {
        VStack(spacing: 20) {
            CameraPreviewView(session: cameraManager.captureSession)
                .frame(width: 640, height: 480)
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding()

            if isCalibrationMode {
                VStack(spacing: 10) {
                    Text("Calibration Mode")
                        .font(.headline)
                    
                    HStack {
                        Button("Calibrate Open Eyes") {
                            cameraManager.calibratedOpenValue = cameraManager.currentEyeOpenness
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        
                        Button("Calibrate Blink") {
                            cameraManager.calibratedBlinkValue = cameraManager.currentEyeOpenness
                        }
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    if let openValue = cameraManager.calibratedOpenValue,
                       let blinkValue = cameraManager.calibratedBlinkValue {
                        let threshold = (openValue + blinkValue) / 2.0
                        Text("Calibration Threshold: \(threshold, specifier: "%.3f")")
                    }
                    
                    Button("Reset Calibration") {
                        cameraManager.calibratedOpenValue = nil
                        cameraManager.calibratedBlinkValue = nil
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                }
            } else {
                VStack(spacing: 10) {
                    if let threshold = cameraManager.calibrationThreshold {
                        Text(cameraManager.blinkDetected ? "Blink Detected" : "No Blink")
                            .font(.largeTitle)
                            .foregroundColor(cameraManager.blinkDetected ? .green : .red)
                        Text("Current Eye Openness: \(cameraManager.currentEyeOpenness, specifier: "%.3f")")
                        Text("Threshold: \(threshold, specifier: "%.3f")")
                    } else {
                        Text("Please calibrate first.")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Toggle("Calibration Mode", isOn: $isCalibrationMode)
                .padding()
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
}

#Preview {
    ContentView()
}
