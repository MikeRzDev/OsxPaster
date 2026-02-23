//
//  PasteManager.swift
//  OsxPaster
//
//  Created by Mike Ruiz on 23/02/26.
//

import AppKit

enum PasteMethod: String, CaseIterable {
    case keyEvents = "keyEvents"
    case clipboard = "clipboard"

    var label: String {
        switch self {
        case .keyEvents: return "Key Events"
        case .clipboard: return "Clipboard (⌘V)"
        }
    }

    var description: String {
        switch self {
        case .keyEvents: return "Simulates a keypress per character. Works in most native apps."
        case .clipboard: return "Writes to clipboard and sends ⌘V. Best for web KVMs and remote desktops."
        }
    }
}

enum PasteManager {
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Types `text` immediately using the method selected in Settings.
    static func pasteImmediately(text: String) {
        guard isAccessibilityGranted() else {
            requestAccessibility()
            return
        }
        let raw = UserDefaults.standard.string(forKey: "pasteMethod") ?? ""
        let method = PasteMethod(rawValue: raw) ?? .keyEvents
        switch method {
        case .keyEvents: typeString(text)
        case .clipboard: pasteViaClipboard(text)
        }
    }

    // MARK: - Key Events method

    static func typeString(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        // Walk UTF-16 code units; handle surrogate pairs for supplementary Unicode (emoji, etc.)
        let utf16 = Array(text.utf16)
        var i = 0
        while i < utf16.count {
            var chars: [UniChar]
            if utf16[i] >= 0xD800 && utf16[i] <= 0xDBFF && i + 1 < utf16.count {
                chars = [utf16[i], utf16[i + 1]] // surrogate pair
                i += 2
            } else {
                chars = [utf16[i]]
                i += 1
            }
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            down?.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            up?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Clipboard (⌘V) method

    private static func pasteViaClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 9 // 'v' on US QWERTY
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
