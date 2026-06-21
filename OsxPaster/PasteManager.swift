//
//  PasteManager.swift
//  OsxPaster
//
//  Created by Mike Ruiz on 23/02/26.
//

import AppKit

enum PasteMethod: String, CaseIterable {
    case unicode  = "unicode"   // keyboardSetUnicodeString — works in native apps
    case keyCodes = "keyCodes"  // real US QWERTY key codes — works in web KVMs
    case clipboard = "clipboard" // writes to pasteboard + sends ⌘V

    var label: String {
        switch self {
        case .unicode:   return "Unicode (default)"
        case .keyCodes:  return "Key Codes (US QWERTY)"
        case .clipboard: return "Clipboard (⌘V)"
        }
    }

    var description: String {
        switch self {
        case .unicode:   return "Sends each character as a Unicode key event. Works in most native apps."
        case .keyCodes:  return "Sends real US QWERTY key codes. Use this for web KVMs and remote desktops."
        case .clipboard: return "Writes to the clipboard and sends ⌘V. Requires the target app to accept ⌘V."
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

    /// Types `text` using the method selected in Settings.
    ///
    /// The event posting runs on a detached background task: the Key Codes
    /// method sleeps 5 ms per character, so on the main thread a long paste
    /// would freeze the menu and UI for seconds. Returns once the whole
    /// string has been posted.
    static func pasteImmediately(text: String) async {
        guard isAccessibilityGranted() else {
            requestAccessibility()
            return
        }
        let raw = UserDefaults.standard.string(forKey: "pasteMethod") ?? ""
        let method = PasteMethod(rawValue: raw) ?? .unicode
        await runTypingOffMainThread {
            switch method {
            case .unicode:   typeUnicode(text)
            case .keyCodes:  typeKeyCodes(text)
            case .clipboard: pasteViaClipboard(text)
            }
        }
    }

    /// Runs event-posting `work` on a detached background task at user-initiated
    /// priority, returning once it finishes. The Key Codes method sleeps 5 ms per
    /// character, so on the main thread a long paste would freeze the menu and UI
    /// for the length of the paste. Posting CGEvents is thread-safe, so the work
    /// is safe to run off the main thread. Exposed (not private) so the
    /// off-main-thread guarantee can be unit-tested.
    static func runTypingOffMainThread(_ work: @escaping @Sendable () -> Void) async {
        await Task.detached(priority: .userInitiated) { work() }.value
    }

    // MARK: - Unicode method (virtual key 0 + Unicode payload)

    /// Builds the keystroke sequence for `text` using the Unicode method:
    /// every UTF-16 unit (or surrogate pair) rides a virtual-key-0 event with
    /// no modifier flags — no physical key codes, no Shift events. Pure and
    /// side-effect free, so it can be unit-tested the same way `buildKeyStrokes`
    /// is. `typeUnicode` posts exactly what this returns.
    static func buildUnicodeStrokes(for text: String) -> [KeyStroke] {
        var strokes: [KeyStroke] = []
        let utf16 = Array(text.utf16)
        var i = 0
        while i < utf16.count {
            let chars: [UniChar]
            if utf16[i] >= 0xD800 && utf16[i] <= 0xDBFF && i + 1 < utf16.count {
                // High surrogate — keep it with its trailing low surrogate so an
                // astral-plane scalar (e.g. an emoji) is delivered as one event.
                chars = [utf16[i], utf16[i + 1]]
                i += 2
            } else {
                chars = [utf16[i]]
                i += 1
            }
            strokes.append(KeyStroke(keyCode: 0, keyDown: true,  flags: [], unicodeChars: chars))
            strokes.append(KeyStroke(keyCode: 0, keyDown: false, flags: [], unicodeChars: chars))
        }
        return strokes
    }

    static func typeUnicode(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        for stroke in buildUnicodeStrokes(for: text) {
            post(stroke, source: source)
        }
    }

    /// Posts a single `KeyStroke` as a CGEvent. The one place every paste method
    /// turns a built stroke into a real event, so all three share identical flag
    /// and Unicode handling and the `build*Strokes` functions stay the source of
    /// truth for what gets posted.
    private static func post(_ stroke: KeyStroke, source: CGEventSource?) {
        let event = CGEvent(keyboardEventSource: source,
                            virtualKey: stroke.keyCode, keyDown: stroke.keyDown)
        event?.flags = stroke.flags
        if var chars = stroke.unicodeChars {
            event?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        }
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Key Codes method (real US QWERTY mapping)

    static let shiftKeyCode: CGKeyCode = 56 // kVK_Shift

    /// A single event in the keystroke sequence (testable without posting).
    struct KeyStroke: Equatable {
        let keyCode: CGKeyCode
        let keyDown: Bool
        let flags: CGEventFlags
        let unicodeChars: [UniChar]?

        static func == (lhs: KeyStroke, rhs: KeyStroke) -> Bool {
            lhs.keyCode == rhs.keyCode
            && lhs.keyDown == rhs.keyDown
            && lhs.flags == rhs.flags
            && lhs.unicodeChars == rhs.unicodeChars
        }
    }

    /// Builds the sequence of keystrokes for `text` without posting any events.
    static func buildKeyStrokes(for text: String) -> [KeyStroke] {
        var strokes: [KeyStroke] = []
        for char in text {
            if let (keyCode, shift) = keyCodeMap[char] {
                if shift {
                    strokes.append(KeyStroke(keyCode: shiftKeyCode, keyDown: true,
                                             flags: .maskShift, unicodeChars: nil))
                }
                let flags: CGEventFlags = shift ? .maskShift : []
                let chars = Array(char.utf16)
                strokes.append(KeyStroke(keyCode: keyCode, keyDown: true,
                                         flags: flags, unicodeChars: chars))
                strokes.append(KeyStroke(keyCode: keyCode, keyDown: false,
                                         flags: flags, unicodeChars: chars))
                if shift {
                    strokes.append(KeyStroke(keyCode: shiftKeyCode, keyDown: false,
                                             flags: [], unicodeChars: nil))
                }
            } else {
                let chars = Array(char.utf16)
                strokes.append(KeyStroke(keyCode: 0, keyDown: true,
                                         flags: [], unicodeChars: chars))
                strokes.append(KeyStroke(keyCode: 0, keyDown: false,
                                         flags: [], unicodeChars: chars))
            }
        }
        return strokes
    }

    // Maps printable characters to (virtualKeyCode, needsShift) for US QWERTY.
    static let keyCodeMap: [Character: (CGKeyCode, Bool)] = [
        // Lowercase letters
        "a": (0,  false), "s": (1,  false), "d": (2,  false), "f": (3,  false),
        "h": (4,  false), "g": (5,  false), "z": (6,  false), "x": (7,  false),
        "c": (8,  false), "v": (9,  false), "b": (11, false), "q": (12, false),
        "w": (13, false), "e": (14, false), "r": (15, false), "y": (16, false),
        "t": (17, false), "o": (31, false), "u": (32, false), "i": (34, false),
        "p": (35, false), "l": (37, false), "j": (38, false), "k": (40, false),
        "n": (45, false), "m": (46, false),
        // Uppercase letters
        "A": (0,  true), "S": (1,  true), "D": (2,  true), "F": (3,  true),
        "H": (4,  true), "G": (5,  true), "Z": (6,  true), "X": (7,  true),
        "C": (8,  true), "V": (9,  true), "B": (11, true), "Q": (12, true),
        "W": (13, true), "E": (14, true), "R": (15, true), "Y": (16, true),
        "T": (17, true), "O": (31, true), "U": (32, true), "I": (34, true),
        "P": (35, true), "L": (37, true), "J": (38, true), "K": (40, true),
        "N": (45, true), "M": (46, true),
        // Numbers
        "1": (18, false), "2": (19, false), "3": (20, false), "4": (21, false),
        "5": (23, false), "6": (22, false), "7": (26, false), "8": (28, false),
        "9": (25, false), "0": (29, false),
        // Shift+number symbols
        "!": (18, true), "@": (19, true), "#": (20, true), "$": (21, true),
        "%": (23, true), "^": (22, true), "&": (26, true), "*": (28, true),
        "(": (25, true), ")": (29, true),
        // Punctuation
        "-": (27, false), "=": (24, false), "[": (33, false), "]": (30, false),
        "\\": (42, false), ";": (41, false), "'": (39, false), ",": (43, false),
        ".": (47, false), "/": (44, false), "`": (50, false),
        // Shift+punctuation
        "_": (27, true), "+": (24, true), "{": (33, true), "}": (30, true),
        "|": (42, true), ":": (41, true), "\"": (39, true), "<": (43, true),
        ">": (47, true), "?": (44, true), "~": (50, true),
        // Whitespace
        " ": (49, false), "\t": (48, false), "\n": (36, false), "\r": (36, false),
    ]

    static func typeKeyCodes(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        // Post exactly what `buildKeyStrokes` produces so the heavily-tested
        // logic and the live path can never drift. The 5 ms gap is per character
        // (a character is 2 or 4 strokes), matching the original KVM pacing.
        for char in text {
            for stroke in buildKeyStrokes(for: String(char)) {
                post(stroke, source: source)
            }
            usleep(5000) // 5 ms between characters for KVM compatibility
        }
    }

    // MARK: - Clipboard (⌘V) method

    static let vKeyCode: CGKeyCode = 9 // 'v' on US QWERTY

    /// The ⌘V keystroke sequence (Command held via the event flag). Pure/testable.
    static func buildClipboardPasteStrokes() -> [KeyStroke] {
        [
            KeyStroke(keyCode: vKeyCode, keyDown: true,  flags: .maskCommand, unicodeChars: nil),
            KeyStroke(keyCode: vKeyCode, keyDown: false, flags: .maskCommand, unicodeChars: nil),
        ]
    }

    private static func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        for stroke in buildClipboardPasteStrokes() {
            post(stroke, source: source)
        }

        // Let the target app read the clipboard before we put the user's
        // previous contents back. This runs off the main thread (see
        // runTypingOffMainThread), so the blocking wait never freezes the UI.
        usleep(150_000) // 150 ms
        restore(saved, to: pasteboard)
    }

    /// Captures a detached copy of everything on `pasteboard` so it can be
    /// restored after a ⌘V paste. Each item is rebuilt as a fresh
    /// `NSPasteboardItem` because originals can't be re-added to a pasteboard.
    static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    /// Restores a snapshot produced by `snapshot(of:)` onto `pasteboard`.
    static func restore(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
