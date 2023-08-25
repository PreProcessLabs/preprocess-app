//
//  PreProcessApp.swift
//  PreProcess
//
//  Created by Shaun Narayan on 27/02/23.
//

import SwiftUI
import XCGLogger
import CoreData

#if os(macOS)
    import AXSwift
#endif

@main
struct PreProcessApp: App {
    let persistenceController = PersistenceController.shared
    let bundleCache = BundleCache()
    let episodeModel = EpisodeModel()
    let defaults = UserDefaults(suiteName: "group.io.preprocess.ios")!
#if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject var screenRecorder = ScreenRecorder.shared
#else
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @Environment(\.openWindow) var openWindow
    
    ///
    /// On first run, sets default prefernce values (90 day retention)
    /// On every run, starts the recorder and sets up hotkey listeners
    ///
    func setup() {
        
        appDelegate.mainApp = self
#if os(macOS)
        if defaults.bool(forKey: "PREPROCESS_HIDE_DOCK") {
            NSApp.setActivationPolicy(.accessory)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        HotkeyListener.register()
#else
        try! FileManager.default.createDirectory(at: homeDirectory(), withIntermediateDirectories: true)
#endif
        if defaults.object(forKey: "PREPROCESS_RETENTION") == nil {
            defaults.set(30, forKey: "PREPROCESS_RETENTION")
        }
        // Prefetch icons
        Task {
            // offset from other startup work
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let bundleFetch : NSFetchRequest<BundleExclusion> = BundleExclusion.fetchRequest()
            do {
                let fetched = try PersistenceController.shared.container.viewContext.fetch(bundleFetch)
                for bundle in fetched {
                    let _ = bundleCache.getIcon(bundleID: bundle.bundle!)
                    try await Task.sleep(nanoseconds: 10_000_000)
                }
            } catch { }
        }
#if os(macOS)
        Task {
            if await screenRecorder.canRecord {
                await screenRecorder.start()
            }
        }
#endif
    }
    
    ///
    /// Stops the recorder which will in turn close any open episode and flush
    /// to disk.
    ///
    func teardown() {
#if os(macOS)
        Task {
            if await screenRecorder.canRecord {
                await screenRecorder.stop()
            }
        }
#endif
        Agent.shared.teardown()
    }

    var body: some Scene {
        WindowGroup(id: "preprocess-app") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(bundleCache)
                .environmentObject(episodeModel)
                .onAppear {
                    self.setup()
                }
        }
        .commands {
            CommandGroup(replacing: .printItem) { }
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .systemServices) { }
            CommandGroup(replacing: .textFormatting) { }
            CommandGroup(replacing: .toolbar) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .sidebar) { }
        }
#if os(macOS)
        MenuBarExtra(
                    "App Menu Bar Extra", image: "LogoIcon",
                    isInserted: $showMenuBarExtra)
                {
                    VStack {
                        HStack {
                            Button(screenRecorder.isRunning ? "Pause" : "Record") {
                                
                                Task {
                                    if screenRecorder.isRunning {
                                        await screenRecorder.stop()
                                    }
                                    else if await screenRecorder.canRecord {
                                        await screenRecorder.start()
                                    }
                                }
                            }
                            .keyboardShortcut("R")
                        }
                        Button("Open") {
                            if NSApplication.shared.windows.count <= 3 {
                                openWindow(id: "preprocess-app")
                            }
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        }
                            .keyboardShortcut("O")
                        Divider()
                        Button("Quit") { self.teardown(); NSApplication.shared.terminate(nil); }
                            .keyboardShortcut("Q")
                    }
                    .frame(width: 200)
                }
#endif
    }
}
let log = XCGLogger.default
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainApp: PreProcessApp?
    
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
                    if await mainApp!.screenRecorder.canRecord {
                        await mainApp!.screenRecorder.start()
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Memory.shared.closeEpisode()
    }
}
#else

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var mainApp: PreProcessApp?
}
#endif
