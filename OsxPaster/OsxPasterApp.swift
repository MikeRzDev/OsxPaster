//
//  OsxPasterApp.swift
//  OsxPaster
//
//  Created by Mike Ruiz on 23/02/26.
//

import SwiftUI

@main
struct OsxPasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = ClipboardMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
        } label: {
            if monitor.justPasted {
                Image(systemName: "checkmark.circle.fill")
                    .symbolEffect(.bounce, value: monitor.justPasted)
                    .contentTransition(.symbolEffect(.replace))
            } else if let remaining = monitor.pasteCountdown {
                Text("\(remaining)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: remaining)
            } else {
                Image(systemName: monitor.justCopied ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                    .symbolEffect(.bounce, value: monitor.justCopied)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hides dock icon
    }
}
