//
//  ClipboardMonitor.swift
//  OsxPaster
//

import AppKit
import Combine

@MainActor
class ClipboardMonitor: ObservableObject {
    @Published var lastItem: String = ""
    @Published var justCopied: Bool = false
    @Published var pasteCountdown: Int? = nil
    @Published var justPasted: Bool = false

    private var changeCount: Int
    private var timer: Timer?
    private var pasteTask: Task<Void, Never>?

    init() {
        changeCount = NSPasteboard.general.changeCount
        startTimer()

        // Restart timer whenever any UserDefaults key changes (covers scanInterval)
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in self.startTimer() }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let raw = UserDefaults.standard.double(forKey: "scanInterval")
        let interval = raw > 0 ? raw : 0.25 // 0 = fastest practical rate
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in self.check() }
        }
        RunLoop.main.add(timer!, forMode: .common) // fires even while menu is open
    }

    private func check() {
        let current = NSPasteboard.general.changeCount
        guard current != changeCount else { return }
        changeCount = current
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            lastItem = text
            flashCopied()
        }
    }

    private func flashCopied() {
        justCopied = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            justCopied = false
        }
    }

    func startPasteCountdown(text: String, delay: Double) {
        pasteTask?.cancel()
        let totalSeconds = Int(delay)

        // Delay of 0 — paste immediately, no countdown
        guard totalSeconds > 0 else {
            PasteManager.pasteImmediately(text: text)
            justPasted = true
            pasteTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                justPasted = false
            }
            return
        }

        pasteCountdown = totalSeconds
        pasteTask = Task {
            for secondsLeft in (1...totalSeconds).reversed() {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { pasteCountdown = nil; return }
                pasteCountdown = secondsLeft > 1 ? secondsLeft - 1 : nil
            }
            if Task.isCancelled { return }
            PasteManager.pasteImmediately(text: text)
            justPasted = true
            try? await Task.sleep(for: .seconds(1.5))
            justPasted = false
        }
    }
}
