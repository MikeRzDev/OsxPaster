import XCTest
import CoreGraphics

/// Tests proving that CGEvent's internal Unicode string does NOT respect
/// .maskShift set after creation — and that keyboardSetUnicodeString fixes it.
///
/// This is the root cause of uppercase letters appearing as lowercase when
/// using the "Key Codes (US QWERTY)" paste method in Linux VMs / KVM consoles,
/// which read the event's Unicode string rather than interpreting key code + flags.
final class KeyCodeCaseTests: XCTestCase {

    private let source = CGEventSource(stateID: .hidSystemState)

    /// Reads back the Unicode string embedded in a CGEvent.
    private func unicodeString(from event: CGEvent) -> String {
        var actualLength = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &actualLength,
            unicodeString: &buffer
        )
        return String(utf16CodeUnits: Array(buffer.prefix(actualLength)), count: actualLength)
    }

    // MARK: - Prove the bug: shift flag alone does NOT update the Unicode string

    func testShiftFlagAloneDoesNotChangeUnicodeString() throws {
        // Key code 0 = 'a' on US QWERTY
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true))
        // Set shift AFTER creation — the internal Unicode string is already set to 'a'
        event.flags = .maskShift

        let str = unicodeString(from: event)
        // CGEvent ignores the shift flag for its internal Unicode string.
        // Apps that read the Unicode string (Linux VMs, KVM consoles) see lowercase.
        XCTAssertEqual(str, "a",
            "Setting .maskShift after creation should NOT change the Unicode string — this IS the bug")
    }

    func testShiftedSymbolWithoutFixCarriesBaseChar() throws {
        // Key code 18 = '1' on US QWERTY; Shift+1 should give '!' but doesn't
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 18, keyDown: true))
        event.flags = .maskShift

        let str = unicodeString(from: event)
        XCTAssertEqual(str, "1",
            "Without keyboardSetUnicodeString, Shift+1 event still carries '1' (not '!')")
    }

    func testAllUppercaseLettersWithoutFixAreLowercase() throws {
        let letterKeyCodes: [(upper: Character, lower: Character, keyCode: CGKeyCode)] = [
            ("A", "a", 0),  ("B", "b", 11), ("C", "c", 8),  ("D", "d", 2),
            ("E", "e", 14), ("F", "f", 3),  ("G", "g", 5),  ("H", "h", 4),
            ("I", "i", 34), ("J", "j", 38), ("K", "k", 40), ("L", "l", 37),
            ("M", "m", 46), ("N", "n", 45), ("O", "o", 31), ("P", "p", 35),
            ("Q", "q", 12), ("R", "r", 15), ("S", "s", 1),  ("T", "t", 17),
            ("U", "u", 32), ("V", "v", 9),  ("W", "w", 13), ("X", "x", 7),
            ("Y", "y", 16), ("Z", "z", 6),
        ]

        for (upper, lower, keyCode) in letterKeyCodes {
            let event = try XCTUnwrap(
                CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true))
            event.flags = .maskShift

            let str = unicodeString(from: event)
            XCTAssertEqual(str, String(lower),
                "Without fix, '\(upper)' (keyCode \(keyCode)) should still show lowercase '\(lower)'")
        }
    }

    // MARK: - Prove the fix: keyboardSetUnicodeString sets the correct character

    func testKeyboardSetUnicodeStringFixesUppercase() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true))
        event.flags = .maskShift
        var chars: [UniChar] = Array("A".utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

        let str = unicodeString(from: event)
        XCTAssertEqual(str, "A",
            "keyboardSetUnicodeString should make the event carry uppercase 'A'")
    }

    func testKeyboardSetUnicodeStringForLowercase() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true))
        var chars: [UniChar] = Array("a".utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

        let str = unicodeString(from: event)
        XCTAssertEqual(str, "a",
            "keyboardSetUnicodeString should preserve lowercase 'a'")
    }

    func testShiftedSymbolsCarryCorrectUnicodeString() throws {
        // '!' is Shift+1 (key code 18)
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 18, keyDown: true))
        event.flags = .maskShift
        var chars: [UniChar] = Array("!".utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

        let str = unicodeString(from: event)
        XCTAssertEqual(str, "!",
            "keyboardSetUnicodeString should make the event carry '!'")
    }

    func testAllUppercaseLettersWithFix() throws {
        let letterKeyCodes: [(Character, CGKeyCode)] = [
            ("A", 0),  ("B", 11), ("C", 8),  ("D", 2),  ("E", 14), ("F", 3),
            ("G", 5),  ("H", 4),  ("I", 34), ("J", 38), ("K", 40), ("L", 37),
            ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15),
            ("S", 1),  ("T", 17), ("U", 32), ("V", 9),  ("W", 13), ("X", 7),
            ("Y", 16), ("Z", 6),
        ]

        for (expectedChar, keyCode) in letterKeyCodes {
            let event = try XCTUnwrap(
                CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true))
            event.flags = .maskShift
            var chars: [UniChar] = Array(String(expectedChar).utf16)
            event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

            let str = unicodeString(from: event)
            XCTAssertEqual(str, String(expectedChar),
                "Letter '\(expectedChar)' (keyCode \(keyCode)) should carry correct uppercase Unicode string")
        }
    }

    // MARK: - Key-up events also need the fix

    func testKeyUpEventAlsoCarriesUnicodeString() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false))
        event.flags = .maskShift
        var chars: [UniChar] = Array("A".utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)

        let str = unicodeString(from: event)
        XCTAssertEqual(str, "A",
            "Key-up event should also carry the correct Unicode string after fix")
    }
}
