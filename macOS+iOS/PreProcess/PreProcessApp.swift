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
    //@AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    //@Environment(\.openWindow) var openWindow
    
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
//    func teardown() {
//#if os(macOS)
//        Task {
//            if await screenRecorder.canRecord {
//                await screenRecorder.stop()
//            }
//        }
//#endif
//        Agent.shared.teardown()
//    }

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
//#if os(macOS)
//        MenuBarExtra(
//            "App Menu Bar Extra", image: "LogoIcon",
//            isInserted: $showMenuBarExtra)
//        {
//            VStack {
//                HStack {
//                    Button(screenRecorder.isRunning ? "Pause" : "Record") {
//
//                        Task {
//                            if screenRecorder.isRunning {
//                                await screenRecorder.stop()
//                            }
//                            else if await screenRecorder.canRecord {
//                                await screenRecorder.start()
//                            }
//                        }
//                    }
//                }
//
//                Button("Open") {
//                    if NSApplication.shared.windows.count <= 3 {
//                        openWindow(id: "preprocess-app")
//                    }
//                    NSApplication.shared.activate(ignoringOtherApps: true)
//                }
//
//                Divider()
//                Button("Quit") {
//                    appDelegate.teardown()
//                }
//            }
//            .frame(width: 200)
//        }
//#endif
    }
}


#if os(macOS)

func openSwiftWindow(title: String, controller: NSViewController) {
    let win = NSWindow(contentViewController: controller)
    win.contentViewController = controller
    win.title = title
    win.styleMask = [.closable, .titled]
    win.makeKeyAndOrderFront(nil)
}


public func getMacSerialNumber() -> String {
    var serialNumber: String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice") )
        
        guard platformExpert > 0 else {
            return nil
        }
        
        guard let serialNumber = (IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as CFString, kCFAllocatorDefault, 0).takeUnretainedValue() as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) else {
            return nil
        }
        
        IOObjectRelease(platformExpert)
        
        return serialNumber
    }
    
    return serialNumber ?? "Unknown"
}
#endif

