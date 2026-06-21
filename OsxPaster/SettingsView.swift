//
//  SettingsView.swift
//  OsxPaster
//
//  Created by Mike Ruiz on 23/02/26.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("pasteDelay") private var pasteDelay: Double = 3.0
    @AppStorage("scanInterval") private var scanInterval: Double = 2.0
    @AppStorage("pasteMethod") private var pasteMethod: String = PasteMethod.unicode.rawValue
    @State private var accessibilityGranted = PasteManager.isAccessibilityGranted()

    var body: some View {
        Form {
            Section("Clipboard Scan Interval") {
                HStack {
                    Text("Every")
                    SpinnerField(value: $scanInterval, range: 0...10, defaultValue: 2.0)
                    Text("second\(scanInterval == 1 ? "" : "s")")
                    Spacer()
                }
                Text("How often the app checks for new clipboard content.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Paste Delay") {
                HStack {
                    SpinnerField(value: $pasteDelay, range: 0...30, defaultValue: 3.0)
                    Text("second\(pasteDelay == 1 ? "" : "s")")
                    Spacer()
                }
                Text("After clicking Paste, switch to your target app before the delay expires.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Paste Method") {
                Picker("", selection: $pasteMethod) {
                    ForEach(PasteMethod.allCases, id: \.rawValue) { method in
                        Text(method.label).tag(method.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                Text((PasteMethod(rawValue: pasteMethod) ?? .unicode).description)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Accessibility Permission") {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .red)
                    Text(accessibilityGranted ? "Granted" : "Not Granted")
                }
                if !accessibilityGranted {
                    Button("Open System Settings…") {
                        PasteManager.openAccessibilitySettings()
                    }
                    Text("OsxPaster needs Accessibility permission to type into other apps.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380)
        .onAppear { accessibilityGranted = PasteManager.isAccessibilityGranted() }
    }
}

// MARK: - SpinnerField

private struct SpinnerField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    var body: some View {
        HStack(spacing: 0) {
            NumericField(value: $value, range: range, defaultValue: defaultValue)
                .frame(width: 48, height: 21)
            Stepper("", value: $value, in: range, step: 1)
                .labelsHidden()
        }
    }
}

// MARK: - NumericField (NSViewRepresentable)

/// An NSTextField wrapper that:
/// - Accepts digits only (no spaces, no letters)
/// - Intercepts ↑/↓ arrow keys to increment/decrement while focused
/// - Reverts to `defaultValue` when the field is cleared
/// - Pushes arrow-key changes into the live editor so the display updates immediately
private struct NumericField: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.delegate = context.coordinator
        tf.alignment = .center
        tf.bezelStyle = .roundedBezel
        tf.stringValue = "\(Int(value))"
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        let str = "\(Int(value))"
        // Push the new value into the live editor (active while field is focused)
        // so arrow-key increments are reflected immediately.
        if let editor = tf.currentEditor() {
            if editor.string != str { editor.string = str }
        } else if tf.stringValue != str {
            tf.stringValue = str
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NumericField

        init(_ parent: NumericField) { self.parent = parent }

        /// Strip any non-digit character (spaces, letters, symbols) as the user types.
        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let filtered = tf.stringValue.filter(\.isNumber)
            if filtered != tf.stringValue { tf.stringValue = filtered }
        }

        /// On focus loss: empty field → default, otherwise clamp to range.
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            let raw = tf.stringValue
            if raw.isEmpty {
                parent.value = parent.defaultValue
                tf.stringValue = "\(Int(parent.defaultValue))"
            } else if let v = Double(raw) {
                let clamped = min(parent.range.upperBound, max(parent.range.lowerBound, v))
                parent.value = clamped
                tf.stringValue = "\(Int(clamped))"
            }
        }

        /// Intercept ↑/↓ arrow commands from the field's editor.
        /// Returning true tells AppKit we handled the command.
        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.moveUp(_:)) {
                parent.value = min(parent.range.upperBound, parent.value + 1)
                return true
            }
            if sel == #selector(NSResponder.moveDown(_:)) {
                parent.value = max(parent.range.lowerBound, parent.value - 1)
                return true
            }
            return false
        }
    }
}
