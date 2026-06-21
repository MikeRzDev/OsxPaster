import XCTest
import AppKit
@testable import OsxPaster

/// Tests for the Clipboard (⌘V) paste method.
///
/// Two things are verified without posting real events or disturbing the user's
/// real clipboard:
///   1. The ⌘V keystroke sequence (`buildClipboardPasteStrokes`).
///   2. snapshot / restore — the fix for the method previously clobbering the
///      user's clipboard and never putting it back. Tests use a private, named
///      NSPasteboard so the real general pasteboard is never touched.
final class ClipboardPasteTests: XCTestCase {

    private func makePasteboard(_ name: String) -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("OsxPasterTest-\(name)"))
        pb.clearContents()
        return pb
    }

    // MARK: - ⌘V keystrokes

    func testClipboardPasteStrokesAreCommandV() {
        let strokes = PasteManager.buildClipboardPasteStrokes()
        XCTAssertEqual(strokes.count, 2)
        XCTAssertEqual(strokes[0].keyCode, 9, "'v' on US QWERTY is keycode 9")
        XCTAssertEqual(strokes[0].keyCode, PasteManager.vKeyCode)
        XCTAssertTrue(strokes[0].keyDown)
        XCTAssertEqual(strokes[0].flags, .maskCommand)
        XCTAssertNil(strokes[0].unicodeChars, "⌘V carries no Unicode payload")
        XCTAssertFalse(strokes[1].keyDown)
        XCTAssertEqual(strokes[1].flags, .maskCommand)
    }

    // MARK: - snapshot / restore (the clobber fix)

    func testRestoreBringsBackPreviousString() {
        let pb = makePasteboard("roundtrip")
        pb.setString("the user's important clipboard", forType: .string)

        let saved = PasteManager.snapshot(of: pb)

        // Simulate the paste overwriting the clipboard.
        pb.clearContents()
        pb.setString("text being pasted", forType: .string)
        XCTAssertEqual(pb.string(forType: .string), "text being pasted")

        PasteManager.restore(saved, to: pb)
        XCTAssertEqual(pb.string(forType: .string), "the user's important clipboard",
            "the clipboard method must restore the user's previous contents")
    }

    func testSnapshotOfEmptyPasteboardIsEmpty() {
        let pb = makePasteboard("empty")
        XCTAssertTrue(PasteManager.snapshot(of: pb).isEmpty)
    }

    func testRestorePreservesMultipleTypes() {
        let pb = makePasteboard("multitype")
        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        item.setString("<b>rich</b>", forType: .html)
        pb.writeObjects([item])

        let saved = PasteManager.snapshot(of: pb)
        pb.clearContents()
        pb.setString("clobbered", forType: .string)

        PasteManager.restore(saved, to: pb)
        XCTAssertEqual(pb.string(forType: .string), "plain")
        XCTAssertEqual(pb.string(forType: .html), "<b>rich</b>")
    }

    func testRestoringEmptySnapshotLeavesClipboardEmpty() {
        let pb = makePasteboard("restore-empty")
        pb.setString("something", forType: .string)
        PasteManager.restore([], to: pb)
        XCTAssertNil(pb.string(forType: .string),
            "restoring an empty snapshot should not leave stale content behind")
    }
}
