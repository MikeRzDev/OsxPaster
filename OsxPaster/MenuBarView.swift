//
//  MenuBarView.swift
//  OsxPaster
//
//  Created by Mike Ruiz on 23/02/26.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    @AppStorage("pasteDelay") private var pasteDelay: Double = 3.0
    @Environment(\.openWindow) private var openWindow

    private var displayText: String {
        let t = monitor.lastItem
        if t.isEmpty { return "Nothing copied yet" }
        return t.count > 20 ? String(t.prefix(20)) + "..." : t
    }

    var body: some View {
        // Show what's on clipboard
        Text(displayText)
            .foregroundStyle(monitor.lastItem.isEmpty ? .secondary : .primary)

        Divider()

        // Paste button
        Button(monitor.pasteCountdown != nil ? "Pasting in \(monitor.pasteCountdown!) sec…" : "Paste in \(Int(pasteDelay)) sec") {
            let text = monitor.lastItem
            guard !text.isEmpty else { return }
            monitor.startPasteCountdown(text: text, delay: pasteDelay)
        }
        .disabled(monitor.lastItem.isEmpty || monitor.pasteCountdown != nil)

        Divider()

        // Settings
        Button("Settings...") { openWindow(id: "settings") }

        Divider()

        Button("Quit OsxPaster") { NSApp.terminate(nil) }
    }
}
