//
//  ToggleCaptureMenuView.swift
//  PreProcess
//
//  Created by Roushil Singla on 26/08/23.
//

import Foundation
import SwiftUI

struct ToggleCaptureMenuView: View {
 
    @State private var isCapturing = true
    @StateObject var screenRecorder = ScreenRecorder.shared
    
    var body: some View {
            let binding = Binding<Bool>(get: {
                return isCapturing
            }, set: {
                isCapturing = $0
                handleCapture()
            })
            Toggle("Capture Screens", isOn: binding)
                .toggleStyle(.switch)
    }
    
    
    func handleCapture() {
        Task {
            if isCapturing {
                if await screenRecorder.canRecord {
                    await screenRecorder.start()
                }
            } else {
                if screenRecorder.isRunning {
                    await screenRecorder.stop()
                }
            }
        }
    }
}

