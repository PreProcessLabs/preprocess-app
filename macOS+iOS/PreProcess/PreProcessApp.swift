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
        // Send the POST request here
        self.sendPostRequest()
#endif
    }
    // Function to send the POST request
    func sendPostRequest() {
        guard let url = URL(string: "http://13.52.112.56:8000/api/v1/account/device/sign-in/") else {
            print("Invalid URL")
            return
        }

        let deviceID = getMacSerialNumber() // Get the Mac's serial number

        let payload: [String: Any] = [
            "device_id": deviceID,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error: \(error)")
                    // Handle the error (e.g., show an alert to the user)
                    return
                } else if let data = data {
                    do {
                        if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if let dataDict = jsonResponse["data"] as? [String: Any],
                               let accessToken = dataDict["access_token"] as? String {
                                // Save the access token to UserDefaults or your preferred storage
                                UserDefaults.standard.set(accessToken, forKey: "AccessTokenKey")
                                print("Access Token: \(accessToken)")
                                // Update the AccessTokenStore with the access token
                            } else {
                                print("Failed to extract access token from JSON response")
                                // Handle the error (e.g., show an alert to the user)
                            }
                        } else {
                            print("Failed to parse JSON response")
                            // Handle the error (e.g., show an alert to the user)
                        }
                    } catch {
                        print("Error parsing JSON response: \(error)")
                        // Handle the error (e.g., show an alert to the user)
                    }
                }
            }.resume()
        } catch {
            print("Error serializing JSON: \(error)")
            // Handle the error (e.g., show an alert to the user)
        }
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
        
        .windowToolbarStyle(.expanded)
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

