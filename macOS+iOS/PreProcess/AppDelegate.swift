//
//  AppDelegate.swift
//  PreProcess
//
//  Created by Roushil Singla on 30/08/23.
//

import XCGLogger
import AppKit
import AXSwift
import SwiftUI

let log = XCGLogger.default


class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainApp: PreProcessApp?
    var isScreenCaptureToggleOn = true
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier!
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)[0].activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
            NSApp.terminate(nil)
        }
        
        if UserDefaults(suiteName: "group.io.preprocess.ios")!.bool(forKey: "PREPROCESS_BROWSER") {
            checkIsProcessTrusted(prompt: true)
        }
        
        let logUrl: URL = homeDirectory().appendingPathComponent("Log").appendingPathComponent("PreProcess.log")
        do {
            try FileManager.default.createDirectory(at: logUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        } catch { fatalError("Failed to create log dir") }
        let fileDest = AutoRotatingFileDestination(writeToFile: logUrl.path(percentEncoded: false))
        
        log.add(destination: fileDest)
        log.info("PreProcess startup")
        NSWindow.allowsAutomaticWindowTabbing = false
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)),
                                                          name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleepListener(_:)),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        
        setupStatusMenu()
    }


    @objc private func sleepListener(_ aNotification: Notification) {
        log.info("listening to sleep")
        if aNotification.name == NSWorkspace.willSleepNotification {
            log.info("Going to sleep")
            if mainApp != nil {
                Task {
                    if await mainApp!.screenRecorder.isRunning {
                        await mainApp!.screenRecorder.stop()
                    }
                }
            }
        } else if aNotification.name == NSWorkspace.didWakeNotification {
            log.info("Woke up")
            if mainApp != nil {
                Task {
                    if isScreenCaptureToggleOn {
                        if await mainApp!.screenRecorder.canRecord {
                            await mainApp!.screenRecorder.start()
                        }
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Memory.shared.closeEpisode()
    }
}


extension AppDelegate {
    
    func setupStatusMenu() {
        let menu = NSMenu()

        var captureView = ToggleCaptureMenuView()
        captureView.onToggleChange = { [weak self] isToggle in
            guard let _self = self else { return }
            _self.isScreenCaptureToggleOn = isToggle
        }
        let view = NSHostingView(rootView: captureView)
        view.frame = NSRect(x: 0, y: 0, width: 175, height: 30)
        let captureItem = NSMenuItem()
        captureItem.view = view
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        
        let quickStartItem = NSMenuItem(title: "Quick Start", action: #selector(quickURL), keyEquivalent: "")
        menu.addItem(quickStartItem)
        
        let feedbackItem = NSMenuItem(title: "Feedback", action: #selector(toggleSampleRate), keyEquivalent: "")
        menu.addItem(feedbackItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(teardown), keyEquivalent: "")
        menu.addItem(quitItem)

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem?.menu = menu
        self.statusItem?.button?.image = NSImage(named: "LogoIcon")
    }
    
    
    @objc func toggleSampleRate() {
        openSwiftWindow(title: "User Feedback", controller: FeedbackViewController())
    }

    @objc func quickURL() {
        NSWorkspace.shared.open(URL(string: "https://planet-seaplane-93a.notion.site/How-to-use-PreProcess-bce91ac25f7d4ba9bdeb1ff453f4ee9c")!)
    }
    
    @objc func openApp() {
//        if NSApplication.shared.windows.count <= 3 {
//            openWindow(id: "preprocess-app")
//        }
//        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    /// Stops the recorder which will in turn close any open episode and flush
    /// to disk.
    @objc func teardown() {
        Task {
            if await ScreenRecorder.shared.canRecord {
                await ScreenRecorder.shared.stop()
            }
        }
        Agent.shared.teardown()
        NSApplication.shared.terminate(nil)
    }
    
}
