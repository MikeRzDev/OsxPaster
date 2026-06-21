import XCTest
@testable import OsxPaster

/// Tests for the Unicode paste method (`buildUnicodeStrokes`).
///
/// The Unicode method is OsxPaster's default. Unlike the Key Codes method it
/// never maps characters to physical US-QWERTY key codes and never emits Shift
/// events — every character (or surrogate pair) travels entirely in the event's
/// Unicode payload on virtual key 0. These tests pin that contract down so the
/// default paste path has the same coverage the Key Codes path already enjoys.
final class UnicodeStrokeTests: XCTestCase {

    private let shiftKey = PasteManager.shiftKeyCode // 56

    // MARK: - Empty / basic shape

    func testEmptyStringProducesNoStrokes() {
        XCTAssertTrue(PasteManager.buildUnicodeStrokes(for: "").isEmpty)
    }

    func testSingleCharProducesDownThenUp() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "a")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertTrue(strokes[0].keyDown)
        XCTAssertFalse(strokes[1].keyDown)
    }

    // MARK: - The Unicode-method contract: always key 0, no flags, no Shift

    func testEveryStrokeUsesVirtualKeyZero() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "Aa1!@ \t\n")
        for s in strokes {
            XCTAssertEqual(s.keyCode, 0, "Unicode method must always use virtual key 0")
        }
    }

    func testNoStrokeEverSetsFlags() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "Aa1!@${}|\"<>?~")
        for s in strokes {
            XCTAssertEqual(s.flags, [], "Unicode method must never set modifier flags")
        }
    }

    func testNoShiftEventsEverEmitted() {
        // The whole point of the Unicode method: no physical Shift key is needed,
        // even for uppercase letters and shifted symbols.
        let strokes = PasteManager.buildUnicodeStrokes(for: "ABC!@#")
        XCTAssertTrue(strokes.allSatisfy { $0.keyCode != shiftKey },
            "Unicode method must not emit Shift key events")
    }

    // MARK: - Case handling differs from the Key Codes method

    func testUppercaseCarriedInPayloadNotViaShift() {
        // Key Codes would emit shift-down/key/shift-up (4 strokes). Unicode just
        // sends 'A' as the payload on a single down/up pair.
        let strokes = PasteManager.buildUnicodeStrokes(for: "A")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].unicodeChars, Array("A".utf16))
        XCTAssertEqual(strokes[1].unicodeChars, Array("A".utf16))
    }

    func testLowercaseAndUppercaseShareShapeButDifferentPayload() {
        let lower = PasteManager.buildUnicodeStrokes(for: "a")
        let upper = PasteManager.buildUnicodeStrokes(for: "A")
        XCTAssertEqual(lower.count, upper.count)
        XCTAssertEqual(lower[0].unicodeChars, Array("a".utf16))
        XCTAssertEqual(upper[0].unicodeChars, Array("A".utf16))
        XCTAssertNotEqual(lower[0].unicodeChars, upper[0].unicodeChars)
    }

    // MARK: - Newline is a literal line feed, NOT the Return key code (≠ Key Codes)

    func testNewlineCarriesLineFeedNotReturnKeyCode() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "\n")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 0, "Unicode method does not use the Return key code")
        XCTAssertEqual(strokes[0].unicodeChars, [0x0A])
    }

    // MARK: - Full printable-ASCII payload fidelity

    func testEveryPrintableASCIICarriesItsOwnCodepoint() {
        for scalar in UInt8(0x20)...UInt8(0x7E) {
            let ch = Character(UnicodeScalar(scalar))
            let strokes = PasteManager.buildUnicodeStrokes(for: String(ch))
            XCTAssertEqual(strokes.count, 2, "'\(ch)' should be one down/up pair")
            XCTAssertEqual(strokes[0].unicodeChars, [UniChar(scalar)],
                "'\(ch)' should carry codepoint 0x\(String(scalar, radix: 16))")
            XCTAssertEqual(strokes[0].unicodeChars, strokes[1].unicodeChars,
                "key-up must carry the same payload as key-down")
        }
    }

    // MARK: - Surrogate pairs (emoji / astral plane) stay together

    func testEmojiDeliveredAsSingleSurrogatePairEvent() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "\u{1F600}") // 😀
        XCTAssertEqual(strokes.count, 2, "One scalar => one down/up pair, even as a surrogate pair")
        XCTAssertEqual(strokes[0].unicodeChars?.count, 2, "Surrogate pair must ride a single event")
        XCTAssertEqual(strokes[0].unicodeChars, Array("\u{1F600}".utf16))
    }

    func testMixedBMPAndAstralString() {
        // "a😀b": 3 scalars => 3 down/up pairs (6 strokes); the middle one is a pair.
        let strokes = PasteManager.buildUnicodeStrokes(for: "a\u{1F600}b")
        XCTAssertEqual(strokes.count, 6)
        XCTAssertEqual(strokes[0].unicodeChars, Array("a".utf16))
        XCTAssertEqual(strokes[2].unicodeChars?.count, 2)            // emoji key-down
        XCTAssertEqual(strokes[2].unicodeChars, Array("\u{1F600}".utf16))
        XCTAssertEqual(strokes[4].unicodeChars, Array("b".utf16))
    }

    // MARK: - Combining marks are sent per-scalar (documents current behavior)

    func testDecomposedAccentSentAsTwoScalars() {
        // "e" + combining acute (U+0301) => 2 scalars => 4 strokes.
        let strokes = PasteManager.buildUnicodeStrokes(for: "e\u{0301}")
        XCTAssertEqual(strokes.count, 4)
        XCTAssertEqual(strokes[0].unicodeChars, Array("e".utf16))
        XCTAssertEqual(strokes[2].unicodeChars, [0x0301])
    }

    // MARK: - Down/up pairing invariant over a realistic string

    func testStrokesAlternateDownUpAndPairOnPayload() {
        let strokes = PasteManager.buildUnicodeStrokes(for: "Hello, World! 123")
        XCTAssertEqual(strokes.count % 2, 0)
        var i = 0
        while i < strokes.count {
            XCTAssertTrue(strokes[i].keyDown,      "stroke \(i) should be key-down")
            XCTAssertFalse(strokes[i + 1].keyDown, "stroke \(i + 1) should be key-up")
            XCTAssertEqual(strokes[i].unicodeChars, strokes[i + 1].unicodeChars,
                "key-down and key-up must carry identical payload")
            i += 2
        }
    }
}
