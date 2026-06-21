import XCTest
import Foundation
@testable import OsxPaster

/// Tests for the fix that keeps long pastes from freezing the UI.
///
/// The bug: `pasteImmediately` ran the typing loop on the main thread, and the
/// Key Codes method sleeps 5 ms per character (`usleep(5000)`). A 2,000-char
/// paste therefore blocked the main thread for ~10 s — a frozen menu and
/// beachball. The fix routes the typing through `runTypingOffMainThread`, which
/// posts the events on a detached background task. These tests pin that down.
@MainActor
final class PasteThreadingTests: XCTestCase {

    /// A small thread-safe box so a `@Sendable` closure can report back.
    private final class Locked<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Value
        init(_ value: Value) { stored = value }
        var value: Value {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); stored = newValue; lock.unlock() }
        }
        func mutate(_ body: (inout Value) -> Void) {
            lock.lock(); body(&stored); lock.unlock()
        }
    }

    // MARK: - The core guarantee: typing does NOT run on the main thread

    /// This is the regression guard for the freeze. If the typing work ever runs
    /// on the main thread again, `Thread.isMainThread` flips and this fails.
    func testTypingRunsOffTheMainThread() async {
        XCTAssertTrue(Thread.isMainThread, "test body should start on the main thread")

        let ranOnMainThread = Locked(true)
        await PasteManager.runTypingOffMainThread {
            ranOnMainThread.value = Thread.isMainThread
        }

        XCTAssertFalse(ranOnMainThread.value,
            "Typing must run off the main thread, otherwise a long paste freezes the UI")
    }

    // MARK: - Awaiting the work runs it fully to completion (not fire-and-forget)

    func testOffMainThreadWorkRunsToCompletion() async {
        let counter = Locked(0)
        await PasteManager.runTypingOffMainThread {
            // Mimic typing 100 characters.
            for _ in 0..<100 { counter.mutate { $0 += 1 } }
        }
        XCTAssertEqual(counter.value, 100,
            "Awaiting runTypingOffMainThread must run the whole sequence before returning")
    }

    // MARK: - The main actor stays responsive during a long paste

    /// While a long (~500 ms) paste runs off-thread, the main actor must remain
    /// free to do its own work. If the typing were back on the main thread, the
    /// quick main-actor loop below could not finish until the paste did.
    func testMainActorStaysResponsiveDuringLongPaste() async {
        // ~500 ms of blocking sleeps, the shape of a long Key Codes paste.
        let longPaste: @Sendable () -> Void = {
            for _ in 0..<100 { usleep(5000) }
        }
        let paste = Task { await PasteManager.runTypingOffMainThread(longPaste) }

        // Time a quick burst of main-actor work kicked off while the paste runs.
        let clock = ContinuousClock()
        let start = clock.now
        var sum = 0
        for i in 0..<2000 {
            sum += i
            await Task.yield()
        }
        let mainWorkDuration = clock.now - start

        XCTAssertGreaterThan(sum, 0)
        XCTAssertLessThan(mainWorkDuration, .milliseconds(300),
            "Main-actor work should finish promptly while the ~500 ms paste runs off-thread; " +
            "taking ~500 ms would mean the paste was freezing the main thread")

        await paste.value
    }
}
