import XCTest
@testable import OsxPaster

/// Tests for the explicit-Shift keystroke sequence produced by `buildKeyStrokes`.
///
/// The bug: web KVMs ignored `.maskShift` on CGEvent flags because they never
/// saw an actual Shift key-down event. Characters like `|`, `&`, `$`, `"`, `>`
/// were typed as their unshifted counterparts (`\`, `7`, `4`, `'`, `.`).
///
/// The fix: `buildKeyStrokes` now wraps shifted characters with explicit Shift
/// key-down / key-up events (keycode 56).
final class KeyCodeStrokeTests: XCTestCase {

    private let shiftKey = PasteManager.shiftKeyCode // 56

    // MARK: - KeyCodeMap coverage

    func testAllPrintableASCIIAreMapped() {
        // Every printable ASCII char (0x20–0x7E) plus \t, \n, \r should be mapped.
        let mapped = PasteManager.keyCodeMap
        for scalar in UInt8(0x20)...UInt8(0x7E) {
            let ch = Character(UnicodeScalar(scalar))
            XCTAssertNotNil(mapped[ch], "ASCII \(scalar) ('\(ch)') should be in keyCodeMap")
        }
        XCTAssertNotNil(mapped["\t"], "Tab should be mapped")
        XCTAssertNotNil(mapped["\n"], "Newline should be mapped")
        XCTAssertNotNil(mapped["\r"], "Carriage return should be mapped")
    }

    // MARK: - Shift pairing consistency

    /// Every shifted symbol must share its keycode with the unshifted base on the same physical key.
    func testShiftedSymbolsShareKeycodeWithBase() {
        let pairs: [(shifted: Character, base: Character)] = [
            ("!", "1"), ("@", "2"), ("#", "3"), ("$", "4"), ("%", "5"),
            ("^", "6"), ("&", "7"), ("*", "8"), ("(", "9"), (")", "0"),
            ("_", "-"), ("+", "="), ("{", "["), ("}", "]"), ("|", "\\"),
            (":", ";"), ("\"", "'"), ("<", ","), (">", "."), ("?", "/"),
            ("~", "`"),
        ]
        let map = PasteManager.keyCodeMap
        for (shifted, base) in pairs {
            let (shiftedCode, shiftedNeedsShift) = map[shifted]!
            let (baseCode, baseNeedsShift) = map[base]!
            XCTAssertEqual(shiftedCode, baseCode,
                "'\(shifted)' and '\(base)' must share the same keycode (\(shiftedCode) vs \(baseCode))")
            XCTAssertTrue(shiftedNeedsShift,  "'\(shifted)' must require shift")
            XCTAssertFalse(baseNeedsShift,    "'\(base)' must NOT require shift")
        }
    }

    func testUppercaseLettersShareKeycodeWithLowercase() {
        let map = PasteManager.keyCodeMap
        for lower in "abcdefghijklmnopqrstuvwxyz" {
            let upper = Character(lower.uppercased())
            let (lowerCode, lowerShift) = map[lower]!
            let (upperCode, upperShift) = map[upper]!
            XCTAssertEqual(lowerCode, upperCode,
                "'\(upper)' and '\(lower)' must share keycode")
            XCTAssertFalse(lowerShift, "'\(lower)' must not need shift")
            XCTAssertTrue(upperShift,  "'\(upper)' must need shift")
        }
    }

    // MARK: - Exhaustive per-character keycode verification (Carbon kVK_ANSI_*)

    /// Verify every mapped character against the canonical macOS virtual keycodes.
    /// Source: HIToolbox/Events.h  (kVK_ANSI_* constants).
    func testEveryCharacterKeycode() {
        let map = PasteManager.keyCodeMap

        // ── Letters ────────────────────────────────────────────
        // kVK_ANSI_A = 0x00 (0)
        XCTAssertEqual(map["a"]?.0, 0);  XCTAssertEqual(map["a"]?.1, false)
        XCTAssertEqual(map["A"]?.0, 0);  XCTAssertEqual(map["A"]?.1, true)
        // kVK_ANSI_S = 0x01 (1)
        XCTAssertEqual(map["s"]?.0, 1);  XCTAssertEqual(map["s"]?.1, false)
        XCTAssertEqual(map["S"]?.0, 1);  XCTAssertEqual(map["S"]?.1, true)
        // kVK_ANSI_D = 0x02 (2)
        XCTAssertEqual(map["d"]?.0, 2);  XCTAssertEqual(map["d"]?.1, false)
        XCTAssertEqual(map["D"]?.0, 2);  XCTAssertEqual(map["D"]?.1, true)
        // kVK_ANSI_F = 0x03 (3)
        XCTAssertEqual(map["f"]?.0, 3);  XCTAssertEqual(map["f"]?.1, false)
        XCTAssertEqual(map["F"]?.0, 3);  XCTAssertEqual(map["F"]?.1, true)
        // kVK_ANSI_H = 0x04 (4)
        XCTAssertEqual(map["h"]?.0, 4);  XCTAssertEqual(map["h"]?.1, false)
        XCTAssertEqual(map["H"]?.0, 4);  XCTAssertEqual(map["H"]?.1, true)
        // kVK_ANSI_G = 0x05 (5)
        XCTAssertEqual(map["g"]?.0, 5);  XCTAssertEqual(map["g"]?.1, false)
        XCTAssertEqual(map["G"]?.0, 5);  XCTAssertEqual(map["G"]?.1, true)
        // kVK_ANSI_Z = 0x06 (6)
        XCTAssertEqual(map["z"]?.0, 6);  XCTAssertEqual(map["z"]?.1, false)
        XCTAssertEqual(map["Z"]?.0, 6);  XCTAssertEqual(map["Z"]?.1, true)
        // kVK_ANSI_X = 0x07 (7)
        XCTAssertEqual(map["x"]?.0, 7);  XCTAssertEqual(map["x"]?.1, false)
        XCTAssertEqual(map["X"]?.0, 7);  XCTAssertEqual(map["X"]?.1, true)
        // kVK_ANSI_C = 0x08 (8)
        XCTAssertEqual(map["c"]?.0, 8);  XCTAssertEqual(map["c"]?.1, false)
        XCTAssertEqual(map["C"]?.0, 8);  XCTAssertEqual(map["C"]?.1, true)
        // kVK_ANSI_V = 0x09 (9)
        XCTAssertEqual(map["v"]?.0, 9);  XCTAssertEqual(map["v"]?.1, false)
        XCTAssertEqual(map["V"]?.0, 9);  XCTAssertEqual(map["V"]?.1, true)
        // kVK_ANSI_B = 0x0B (11)
        XCTAssertEqual(map["b"]?.0, 11); XCTAssertEqual(map["b"]?.1, false)
        XCTAssertEqual(map["B"]?.0, 11); XCTAssertEqual(map["B"]?.1, true)
        // kVK_ANSI_Q = 0x0C (12)
        XCTAssertEqual(map["q"]?.0, 12); XCTAssertEqual(map["q"]?.1, false)
        XCTAssertEqual(map["Q"]?.0, 12); XCTAssertEqual(map["Q"]?.1, true)
        // kVK_ANSI_W = 0x0D (13)
        XCTAssertEqual(map["w"]?.0, 13); XCTAssertEqual(map["w"]?.1, false)
        XCTAssertEqual(map["W"]?.0, 13); XCTAssertEqual(map["W"]?.1, true)
        // kVK_ANSI_E = 0x0E (14)
        XCTAssertEqual(map["e"]?.0, 14); XCTAssertEqual(map["e"]?.1, false)
        XCTAssertEqual(map["E"]?.0, 14); XCTAssertEqual(map["E"]?.1, true)
        // kVK_ANSI_R = 0x0F (15)
        XCTAssertEqual(map["r"]?.0, 15); XCTAssertEqual(map["r"]?.1, false)
        XCTAssertEqual(map["R"]?.0, 15); XCTAssertEqual(map["R"]?.1, true)
        // kVK_ANSI_Y = 0x10 (16)
        XCTAssertEqual(map["y"]?.0, 16); XCTAssertEqual(map["y"]?.1, false)
        XCTAssertEqual(map["Y"]?.0, 16); XCTAssertEqual(map["Y"]?.1, true)
        // kVK_ANSI_T = 0x11 (17)
        XCTAssertEqual(map["t"]?.0, 17); XCTAssertEqual(map["t"]?.1, false)
        XCTAssertEqual(map["T"]?.0, 17); XCTAssertEqual(map["T"]?.1, true)
        // kVK_ANSI_O = 0x1F (31)
        XCTAssertEqual(map["o"]?.0, 31); XCTAssertEqual(map["o"]?.1, false)
        XCTAssertEqual(map["O"]?.0, 31); XCTAssertEqual(map["O"]?.1, true)
        // kVK_ANSI_U = 0x20 (32)
        XCTAssertEqual(map["u"]?.0, 32); XCTAssertEqual(map["u"]?.1, false)
        XCTAssertEqual(map["U"]?.0, 32); XCTAssertEqual(map["U"]?.1, true)
        // kVK_ANSI_I = 0x22 (34)
        XCTAssertEqual(map["i"]?.0, 34); XCTAssertEqual(map["i"]?.1, false)
        XCTAssertEqual(map["I"]?.0, 34); XCTAssertEqual(map["I"]?.1, true)
        // kVK_ANSI_P = 0x23 (35)
        XCTAssertEqual(map["p"]?.0, 35); XCTAssertEqual(map["p"]?.1, false)
        XCTAssertEqual(map["P"]?.0, 35); XCTAssertEqual(map["P"]?.1, true)
        // kVK_ANSI_L = 0x25 (37)
        XCTAssertEqual(map["l"]?.0, 37); XCTAssertEqual(map["l"]?.1, false)
        XCTAssertEqual(map["L"]?.0, 37); XCTAssertEqual(map["L"]?.1, true)
        // kVK_ANSI_J = 0x26 (38)
        XCTAssertEqual(map["j"]?.0, 38); XCTAssertEqual(map["j"]?.1, false)
        XCTAssertEqual(map["J"]?.0, 38); XCTAssertEqual(map["J"]?.1, true)
        // kVK_ANSI_K = 0x28 (40)
        XCTAssertEqual(map["k"]?.0, 40); XCTAssertEqual(map["k"]?.1, false)
        XCTAssertEqual(map["K"]?.0, 40); XCTAssertEqual(map["K"]?.1, true)
        // kVK_ANSI_N = 0x2D (45)
        XCTAssertEqual(map["n"]?.0, 45); XCTAssertEqual(map["n"]?.1, false)
        XCTAssertEqual(map["N"]?.0, 45); XCTAssertEqual(map["N"]?.1, true)
        // kVK_ANSI_M = 0x2E (46)
        XCTAssertEqual(map["m"]?.0, 46); XCTAssertEqual(map["m"]?.1, false)
        XCTAssertEqual(map["M"]?.0, 46); XCTAssertEqual(map["M"]?.1, true)

        // ── Number row ────────────────────────────────────────
        // kVK_ANSI_1 = 0x12 (18)    Shift → !
        XCTAssertEqual(map["1"]?.0, 18); XCTAssertEqual(map["1"]?.1, false)
        XCTAssertEqual(map["!"]?.0, 18); XCTAssertEqual(map["!"]?.1, true)
        // kVK_ANSI_2 = 0x13 (19)    Shift → @
        XCTAssertEqual(map["2"]?.0, 19); XCTAssertEqual(map["2"]?.1, false)
        XCTAssertEqual(map["@"]?.0, 19); XCTAssertEqual(map["@"]?.1, true)
        // kVK_ANSI_3 = 0x14 (20)    Shift → #
        XCTAssertEqual(map["3"]?.0, 20); XCTAssertEqual(map["3"]?.1, false)
        XCTAssertEqual(map["#"]?.0, 20); XCTAssertEqual(map["#"]?.1, true)
        // kVK_ANSI_4 = 0x15 (21)    Shift → $
        XCTAssertEqual(map["4"]?.0, 21); XCTAssertEqual(map["4"]?.1, false)
        XCTAssertEqual(map["$"]?.0, 21); XCTAssertEqual(map["$"]?.1, true)
        // kVK_ANSI_5 = 0x17 (23)    Shift → %
        XCTAssertEqual(map["5"]?.0, 23); XCTAssertEqual(map["5"]?.1, false)
        XCTAssertEqual(map["%"]?.0, 23); XCTAssertEqual(map["%"]?.1, true)
        // kVK_ANSI_6 = 0x16 (22)    Shift → ^
        XCTAssertEqual(map["6"]?.0, 22); XCTAssertEqual(map["6"]?.1, false)
        XCTAssertEqual(map["^"]?.0, 22); XCTAssertEqual(map["^"]?.1, true)
        // kVK_ANSI_7 = 0x1A (26)    Shift → &
        XCTAssertEqual(map["7"]?.0, 26); XCTAssertEqual(map["7"]?.1, false)
        XCTAssertEqual(map["&"]?.0, 26); XCTAssertEqual(map["&"]?.1, true)
        // kVK_ANSI_8 = 0x1C (28)    Shift → *
        XCTAssertEqual(map["8"]?.0, 28); XCTAssertEqual(map["8"]?.1, false)
        XCTAssertEqual(map["*"]?.0, 28); XCTAssertEqual(map["*"]?.1, true)
        // kVK_ANSI_9 = 0x19 (25)    Shift → (
        XCTAssertEqual(map["9"]?.0, 25); XCTAssertEqual(map["9"]?.1, false)
        XCTAssertEqual(map["("]?.0, 25); XCTAssertEqual(map["("]?.1, true)
        // kVK_ANSI_0 = 0x1D (29)    Shift → )
        XCTAssertEqual(map["0"]?.0, 29); XCTAssertEqual(map["0"]?.1, false)
        XCTAssertEqual(map[")"]?.0, 29); XCTAssertEqual(map[")"]?.1, true)

        // ── Punctuation / symbols ─────────────────────────────
        // kVK_ANSI_Minus = 0x1B (27)         Shift → _
        XCTAssertEqual(map["-"]?.0, 27); XCTAssertEqual(map["-"]?.1, false)
        XCTAssertEqual(map["_"]?.0, 27); XCTAssertEqual(map["_"]?.1, true)
        // kVK_ANSI_Equal = 0x18 (24)         Shift → +
        XCTAssertEqual(map["="]?.0, 24); XCTAssertEqual(map["="]?.1, false)
        XCTAssertEqual(map["+"]?.0, 24); XCTAssertEqual(map["+"]?.1, true)
        // kVK_ANSI_LeftBracket = 0x21 (33)   Shift → {
        XCTAssertEqual(map["["]?.0, 33); XCTAssertEqual(map["["]?.1, false)
        XCTAssertEqual(map["{"]?.0, 33); XCTAssertEqual(map["{"]?.1, true)
        // kVK_ANSI_RightBracket = 0x1E (30)  Shift → }
        XCTAssertEqual(map["]"]?.0, 30); XCTAssertEqual(map["]"]?.1, false)
        XCTAssertEqual(map["}"]?.0, 30); XCTAssertEqual(map["}"]?.1, true)
        // kVK_ANSI_Backslash = 0x2A (42)     Shift → |
        XCTAssertEqual(map["\\"]?.0, 42); XCTAssertEqual(map["\\"]?.1, false)
        XCTAssertEqual(map["|"]?.0, 42);  XCTAssertEqual(map["|"]?.1, true)
        // kVK_ANSI_Semicolon = 0x29 (41)     Shift → :
        XCTAssertEqual(map[";"]?.0, 41); XCTAssertEqual(map[";"]?.1, false)
        XCTAssertEqual(map[":"]?.0, 41); XCTAssertEqual(map[":"]?.1, true)
        // kVK_ANSI_Quote = 0x27 (39)         Shift → "
        XCTAssertEqual(map["'"]?.0, 39);  XCTAssertEqual(map["'"]?.1, false)
        XCTAssertEqual(map["\""]?.0, 39); XCTAssertEqual(map["\""]?.1, true)
        // kVK_ANSI_Comma = 0x2B (43)         Shift → <
        XCTAssertEqual(map[","]?.0, 43); XCTAssertEqual(map[","]?.1, false)
        XCTAssertEqual(map["<"]?.0, 43); XCTAssertEqual(map["<"]?.1, true)
        // kVK_ANSI_Period = 0x2F (47)        Shift → >
        XCTAssertEqual(map["."]?.0, 47); XCTAssertEqual(map["."]?.1, false)
        XCTAssertEqual(map[">"]?.0, 47); XCTAssertEqual(map[">"]?.1, true)
        // kVK_ANSI_Slash = 0x2C (44)         Shift → ?
        XCTAssertEqual(map["/"]?.0, 44); XCTAssertEqual(map["/"]?.1, false)
        XCTAssertEqual(map["?"]?.0, 44); XCTAssertEqual(map["?"]?.1, true)
        // kVK_ANSI_Grave = 0x32 (50)         Shift → ~
        XCTAssertEqual(map["`"]?.0, 50); XCTAssertEqual(map["`"]?.1, false)
        XCTAssertEqual(map["~"]?.0, 50); XCTAssertEqual(map["~"]?.1, true)

        // ── Whitespace / control ──────────────────────────────
        // kVK_Space = 0x31 (49)
        XCTAssertEqual(map[" "]?.0, 49);  XCTAssertEqual(map[" "]?.1, false)
        // kVK_Tab = 0x30 (48)
        XCTAssertEqual(map["\t"]?.0, 48); XCTAssertEqual(map["\t"]?.1, false)
        // kVK_Return = 0x24 (36)
        XCTAssertEqual(map["\n"]?.0, 36); XCTAssertEqual(map["\n"]?.1, false)
        XCTAssertEqual(map["\r"]?.0, 36); XCTAssertEqual(map["\r"]?.1, false)
    }

    /// Verify that buildKeyStrokes produces correct output for every single
    /// printable ASCII character — the right keycode, right shift state, and
    /// the correct UTF-16 unicode payload.
    func testBuildKeyStrokesForEveryPrintableASCII() {
        let map = PasteManager.keyCodeMap
        for scalar in UInt8(0x20)...UInt8(0x7E) {
            let ch = Character(UnicodeScalar(scalar))
            let strokes = PasteManager.buildKeyStrokes(for: String(ch))
            let (expectedKeyCode, expectedShift) = map[ch]!

            if expectedShift {
                // Shifted: 4 strokes — shift-down, key-down, key-up, shift-up
                XCTAssertEqual(strokes.count, 4,
                    "'\(ch)' (0x\(String(scalar, radix: 16))) should produce 4 strokes (shifted)")
                XCTAssertEqual(strokes[0].keyCode, shiftKey,
                    "'\(ch)' stroke 0 should be shift-down")
                XCTAssertTrue(strokes[0].keyDown)
                XCTAssertEqual(strokes[1].keyCode, expectedKeyCode,
                    "'\(ch)' stroke 1 keycode should be \(expectedKeyCode)")
                XCTAssertTrue(strokes[1].keyDown)
                XCTAssertEqual(strokes[1].flags, .maskShift)
                XCTAssertEqual(strokes[1].unicodeChars, Array(String(ch).utf16),
                    "'\(ch)' key-down should carry correct UTF-16")
                XCTAssertEqual(strokes[2].keyCode, expectedKeyCode)
                XCTAssertFalse(strokes[2].keyDown)
                XCTAssertEqual(strokes[3].keyCode, shiftKey,
                    "'\(ch)' stroke 3 should be shift-up")
                XCTAssertFalse(strokes[3].keyDown)
            } else {
                // Unshifted: 2 strokes — key-down, key-up
                XCTAssertEqual(strokes.count, 2,
                    "'\(ch)' (0x\(String(scalar, radix: 16))) should produce 2 strokes (unshifted)")
                XCTAssertEqual(strokes[0].keyCode, expectedKeyCode,
                    "'\(ch)' key-down keycode should be \(expectedKeyCode)")
                XCTAssertTrue(strokes[0].keyDown)
                XCTAssertEqual(strokes[0].flags, [])
                XCTAssertEqual(strokes[0].unicodeChars, Array(String(ch).utf16),
                    "'\(ch)' key-down should carry correct UTF-16")
                XCTAssertEqual(strokes[1].keyCode, expectedKeyCode)
                XCTAssertFalse(strokes[1].keyDown)
            }
        }
    }

    // MARK: - buildKeyStrokes: unshifted characters

    func testUnshiftedCharProducesTwoStrokes() {
        let strokes = PasteManager.buildKeyStrokes(for: "a")
        XCTAssertEqual(strokes.count, 2, "Unshifted char should produce key-down + key-up")
        XCTAssertTrue(strokes[0].keyDown)
        XCTAssertFalse(strokes[1].keyDown)
        XCTAssertEqual(strokes[0].keyCode, 0)  // 'a' = keycode 0
        XCTAssertEqual(strokes[1].keyCode, 0)
        XCTAssertEqual(strokes[0].flags, [])
        XCTAssertEqual(strokes[1].flags, [])
    }

    func testUnshiftedCharHasNoShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "a")
        let shiftStrokes = strokes.filter { $0.keyCode == shiftKey }
        XCTAssertTrue(shiftStrokes.isEmpty,
            "Unshifted character must not produce any Shift key events")
    }

    // MARK: - buildKeyStrokes: shifted characters

    func testShiftedCharProducesFourStrokes() {
        let strokes = PasteManager.buildKeyStrokes(for: "A")
        XCTAssertEqual(strokes.count, 4,
            "Shifted char should produce: shift-down, key-down, key-up, shift-up")
    }

    func testShiftedCharSequenceOrder() {
        let strokes = PasteManager.buildKeyStrokes(for: "|")
        XCTAssertEqual(strokes.count, 4)

        // 1. Shift down
        XCTAssertEqual(strokes[0].keyCode, shiftKey)
        XCTAssertTrue(strokes[0].keyDown)
        XCTAssertEqual(strokes[0].flags, .maskShift)

        // 2. Key down (backslash key = 42, with shift flag)
        XCTAssertEqual(strokes[1].keyCode, 42)
        XCTAssertTrue(strokes[1].keyDown)
        XCTAssertEqual(strokes[1].flags, .maskShift)

        // 3. Key up
        XCTAssertEqual(strokes[2].keyCode, 42)
        XCTAssertFalse(strokes[2].keyDown)
        XCTAssertEqual(strokes[2].flags, .maskShift)

        // 4. Shift up
        XCTAssertEqual(strokes[3].keyCode, shiftKey)
        XCTAssertFalse(strokes[3].keyDown)
        XCTAssertEqual(strokes[3].flags, [])
    }

    func testShiftedCharCarriesCorrectUnicode() {
        let strokes = PasteManager.buildKeyStrokes(for: "|")
        // The key-down event (index 1) should carry the pipe unicode char
        XCTAssertEqual(strokes[1].unicodeChars, Array("|".utf16))
        // Shift key events should have no unicode chars
        XCTAssertNil(strokes[0].unicodeChars)
        XCTAssertNil(strokes[3].unicodeChars)
    }

    // MARK: - buildKeyStrokes: the exact bug scenario

    /// The characters that were garbled in the original bug report.
    func testPipeCharacterHasExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "|")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        let shiftUps = strokes.filter { $0.keyCode == shiftKey && !$0.keyDown }
        XCTAssertEqual(shiftDowns.count, 1, "Pipe must have one shift-down")
        XCTAssertEqual(shiftUps.count, 1, "Pipe must have one shift-up")
    }

    func testAmpersandHasExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "&")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        XCTAssertEqual(shiftDowns.count, 1)
        // Verify keycode is 26 (the '7' key)
        XCTAssertEqual(strokes[1].keyCode, 26)
    }

    func testDollarSignHasExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "$")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        XCTAssertEqual(shiftDowns.count, 1)
        XCTAssertEqual(strokes[1].keyCode, 21) // '4' key
    }

    func testDoubleQuoteHasExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "\"")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        XCTAssertEqual(shiftDowns.count, 1)
        XCTAssertEqual(strokes[1].keyCode, 39) // quote key
    }

    func testGreaterThanHasExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: ">")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        XCTAssertEqual(shiftDowns.count, 1)
        XCTAssertEqual(strokes[1].keyCode, 47) // period key
    }

    func testParenthesesHaveExplicitShiftEvents() {
        let strokes = PasteManager.buildKeyStrokes(for: "()")
        let shiftDowns = strokes.filter { $0.keyCode == shiftKey && $0.keyDown }
        XCTAssertEqual(shiftDowns.count, 2, "Each paren should have its own shift-down")
    }

    // MARK: - buildKeyStrokes: mixed strings

    func testCurlCommandStrokeCount() {
        // curl -fsSL https://openclaw.ai/install.sh | bash
        let text = "curl -fsSL https://openclaw.ai/install.sh | bash"
        let strokes = PasteManager.buildKeyStrokes(for: text)

        // Count shifted chars in the string: S, L, (colon :), (pipe |) = 4
        let shiftedChars = text.filter { ch in
            if let (_, shift) = PasteManager.keyCodeMap[ch] { return shift }
            return false
        }
        let unshiftedChars = text.count - shiftedChars.count

        // Each shifted char → 4 strokes, each unshifted → 2 strokes
        let expectedCount = shiftedChars.count * 4 + unshiftedChars * 2
        XCTAssertEqual(strokes.count, expectedCount)
    }

    func testDoubleAmpersandProducesCorrectSequence() {
        // "&&" was the string that produced "77" in the bug
        let strokes = PasteManager.buildKeyStrokes(for: "&&")
        XCTAssertEqual(strokes.count, 8) // 2 shifted chars × 4 strokes each

        // First &: shift-down, key(26)-down, key(26)-up, shift-up
        XCTAssertEqual(strokes[0].keyCode, shiftKey)
        XCTAssertTrue(strokes[0].keyDown)
        XCTAssertEqual(strokes[1].keyCode, 26)
        XCTAssertEqual(strokes[3].keyCode, shiftKey)
        XCTAssertFalse(strokes[3].keyDown)

        // Second &: same pattern at offset 4
        XCTAssertEqual(strokes[4].keyCode, shiftKey)
        XCTAssertTrue(strokes[4].keyDown)
        XCTAssertEqual(strokes[5].keyCode, 26)
        XCTAssertEqual(strokes[7].keyCode, shiftKey)
        XCTAssertFalse(strokes[7].keyDown)
    }

    func testRedirectOperatorProducesCorrectSequence() {
        // ">>" was producing ".." in the bug (shift dropped from period key)
        let strokes = PasteManager.buildKeyStrokes(for: ">>")
        XCTAssertEqual(strokes.count, 8)
        // Both must use keycode 47 (period) with shift
        XCTAssertEqual(strokes[1].keyCode, 47)
        XCTAssertEqual(strokes[1].flags, .maskShift)
        XCTAssertEqual(strokes[5].keyCode, 47)
        XCTAssertEqual(strokes[5].flags, .maskShift)
    }

    func testShellSubstitutionProducesCorrectSequence() {
        // "$()" was producing "490" — shift dropped from $, (, )
        let strokes = PasteManager.buildKeyStrokes(for: "$()")
        XCTAssertEqual(strokes.count, 12) // 3 shifted chars × 4

        // $ → keycode 21 (the '4' key), shift
        XCTAssertEqual(strokes[1].keyCode, 21)
        XCTAssertEqual(strokes[1].flags, .maskShift)
        XCTAssertEqual(strokes[1].unicodeChars, Array("$".utf16))

        // ( → keycode 25 (the '9' key), shift
        XCTAssertEqual(strokes[5].keyCode, 25)
        XCTAssertEqual(strokes[5].flags, .maskShift)

        // ) → keycode 29 (the '0' key), shift
        XCTAssertEqual(strokes[9].keyCode, 29)
        XCTAssertEqual(strokes[9].flags, .maskShift)
    }

    // MARK: - buildKeyStrokes: unmapped characters (Unicode fallback)

    func testUnmappedCharFallsBackToUnicode() {
        // Emoji is not in the keyCodeMap
        let strokes = PasteManager.buildKeyStrokes(for: "\u{1F600}") // 😀
        XCTAssertEqual(strokes.count, 2) // down + up
        XCTAssertEqual(strokes[0].keyCode, 0) // virtual key 0 for fallback
        XCTAssertEqual(strokes[0].flags, [])
        XCTAssertNotNil(strokes[0].unicodeChars)
        // Emoji produces a surrogate pair in UTF-16
        XCTAssertEqual(strokes[0].unicodeChars?.count, 2)
    }

    // MARK: - buildKeyStrokes: whitespace

    func testNewlineProducesReturnKey() {
        let strokes = PasteManager.buildKeyStrokes(for: "\n")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 36) // Return
        XCTAssertEqual(strokes[0].flags, [])
    }

    func testCarriageReturnProducesReturnKey() {
        let strokes = PasteManager.buildKeyStrokes(for: "\r")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 36)
    }

    func testSpaceProducesSpaceKey() {
        let strokes = PasteManager.buildKeyStrokes(for: " ")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 49) // Space
    }

    func testTabProducesTabKey() {
        let strokes = PasteManager.buildKeyStrokes(for: "\t")
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 48) // Tab
    }

    // MARK: - buildKeyStrokes: empty string

    func testEmptyStringProducesNoStrokes() {
        let strokes = PasteManager.buildKeyStrokes(for: "")
        XCTAssertTrue(strokes.isEmpty)
    }

    // MARK: - Auto-indent simulation

    /// Simulates a text editor or terminal processing keystrokes.
    /// Return key (\r / 0x0D) always creates a new line at column 0.
    /// When `autoIndent` is true, the new line is pre-filled with the
    /// previous line's leading whitespace (like NSTextView / many editors).
    private func simulateTerminal(_ strokes: [PasteManager.KeyStroke],
                                  autoIndent: Bool) -> String {
        var lines: [String] = [""]
        var col = 0

        for stroke in strokes {
            guard stroke.keyDown else { continue }

            // Modifier-only keys — skip
            if stroke.keyCode == PasteManager.shiftKeyCode { continue }

            // Return (keycode 36, carries \r)
            if stroke.keyCode == 36 {
                if autoIndent {
                    let indent = lines.last!.prefix(while: { $0 == " " || $0 == "\t" })
                    lines.append(String(indent))
                    col = indent.count
                } else {
                    lines.append("")
                    col = 0
                }
                continue
            }

            // Regular character — insert at cursor
            if let chars = stroke.unicodeChars {
                // Skip \r characters in unicode payload (already handled above)
                if chars == [0x0D] { continue }
                let str = String(utf16CodeUnits: chars, count: chars.count)
                let i = lines.count - 1
                var line = Array(lines[i])
                for (j, ch) in str.enumerated() {
                    line.insert(ch, at: col + j)
                }
                lines[i] = String(line)
                col += str.count
            }
        }

        return lines.joined(separator: "\n")
    }

    // ── Multi-line indentation (the exact bug scenario) ────────────

    func testYAMLIndentationPreserved() {
        let text = "network:\n    version: 2\n    ethernets:\n        enp2s0:\n            dhcp4: true\nEOF"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text,
            "Indentation must be preserved exactly")
    }

    func testFullNetplanCommand() {
        let text = "sudo bash -c 'cat > /etc/netplan/01-network.yaml << EOF\nnetwork:\n    version: 2\n    ethernets:\n        enp2s0:\n            dhcp4: true\nEOF\nchmod 600 /etc/netplan/01-network.yaml && netplan apply'"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text)
    }

    func testDecreasingIndentation() {
        let text = "a\n    b\n        c\nd"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text)
    }

    func testEmptyLinesPreserved() {
        let text = "a\n\n    b\n\nc"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text)
    }

    func testTabIndentation() {
        let text = "a\n\tb\n\t\tc\nd"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text)
    }

    func testSingleLineNoNewlineUnchanged() {
        let text = "    indented but no newline"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let result = simulateTerminal(strokes, autoIndent: false)
        XCTAssertEqual(result, text)
    }

    func testNewlinesUseReturnKeyCode() {
        let text = "a\nb\nc"
        let strokes = PasteManager.buildKeyStrokes(for: text)
        let returnStrokes = strokes.filter { $0.keyCode == 36 && $0.keyDown }
        XCTAssertEqual(returnStrokes.count, 2)
    }
}
