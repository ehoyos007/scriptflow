//
//  ScriptFlowApp.swift
//  ScriptFlow
//
//  Teleprompter for First Health Enrollment sales agents.
//  Adapted from Textream by Fatih Kadir Akin (https://github.com/f/textream)
//

import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No services or URL scheme needed for ScriptFlow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                return false
            }
        }
        return true
    }
}

@main
struct ScriptFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About ScriptFlow") {
                    // TODO: About view
                }
            }
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
