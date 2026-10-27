import SwiftUI

/// Alpha ramp that trails the newest word. Whatever you are writing right now
/// stays fully dark; everything behind it dims gradually the further the cursor
/// gets from it, so the fade chases the text instead of dropping all at once.
enum TrailingFade {
    /// How faint the oldest text gets — never fully invisible.
    static let floor = 0.13
    /// Characters immediately behind the cursor that stay fully dark.
    static let clearWindow = 40
    /// Characters over which the dimming completes.
    static let span = 900.0

    static func alpha(distanceFromEnd distance: Int) -> Double {
        guard distance > clearWindow else { return 1 }
        let t = min(Double(distance - clearWindow) / span, 1)
        let eased = t * t * (3 - 2 * t)
        return 1 - (1 - floor) * eased
    }

    static func isAtFloor(_ alpha: Double) -> Bool {
        alpha <= floor + 0.001
    }
}

#if os(iOS)
import UIKit

struct InlineFadingTextEditor: UIViewRepresentable {
    @Binding var draft: String
    let releasedText: String
    let shouldFocus: Bool
    /// Fired when the session rules reject an edit, so the UI can say why.
    var onBlockedEdit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        // Autocorrect rewrites words you already typed, which the no-editing
        // rule forbids — it would fight the delegate on every correction.
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.undoManager?.removeAllActions()
        textView.accessibilityLabel = "Private brain dump"
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.protectedLength = releasedText.utf16.count
        context.coordinator.isUpdating = true

        let fullText = releasedText + draft
        if textView.text != fullText {
            textView.text = fullText
            textView.selectedRange = NSRange(location: fullText.utf16.count, length: 0)
        }

        applyAttributes(to: textView)
        context.coordinator.isUpdating = false

        if shouldFocus && !textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
                textView.selectedRange = NSRange(location: textView.text.utf16.count, length: 0)
            }
        }
    }

    private func applyAttributes(to textView: UITextView) {
        let text = textView.text ?? ""
        let ns = text as NSString
        let fullLength = ns.length
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4

        let clearColor = UIColor(red: 0.090, green: 0.247, blue: 0.227, alpha: 1)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: roundedFont,
            .foregroundColor: clearColor,
            .paragraphStyle: paragraph
        ]

        guard let storage = textView.textStorage as NSTextStorage? else { return }
        storage.beginEditing()
        if fullLength > 0 {
            storage.setAttributes(baseAttributes, range: NSRange(location: 0, length: fullLength))

            // Walk words backwards from the cursor, dimming as we go, then
            // flood-fill everything past the ramp in one pass.
            var flooredPrefixEnd = 0
            ns.enumerateSubstrings(
                in: NSRange(location: 0, length: fullLength),
                options: [.byWords, .reverse]
            ) { _, range, _, stop in
                let alpha = TrailingFade.alpha(distanceFromEnd: fullLength - range.location)
                if TrailingFade.isAtFloor(alpha) {
                    flooredPrefixEnd = range.location + range.length
                    stop.pointee = true
                    return
                }
                if alpha < 1 {
                    storage.addAttributes(Self.faded(alpha: alpha, color: clearColor), range: range)
                }
            }

            if flooredPrefixEnd > 0 {
                storage.addAttributes(
                    Self.faded(alpha: TrailingFade.floor, color: clearColor),
                    range: NSRange(location: 0, length: flooredPrefixEnd)
                )
            }
        }
        storage.endEditing()
        textView.typingAttributes = baseAttributes
    }

    private static func faded(alpha: Double, color: UIColor) -> [NSAttributedString.Key: Any] {
        let softness = 1 - alpha
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.18 * softness)
        shadow.shadowBlurRadius = 1.35 * softness
        return [
            .foregroundColor: color.withAlphaComponent(alpha),
            .shadow: shadow
        ]
    }

    private var roundedFont: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .title2)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: 0)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: InlineFadingTextEditor
        var protectedLength = 0
        var isUpdating = false

        init(parent: InlineFadingTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            let fullText = textView.text ?? ""
            guard fullText.hasPrefix(parent.releasedText) else { return }
            parent.draft = String(fullText.dropFirst(parent.releasedText.count))
        }

        /// Session rules: no deleting, no editing what you already wrote —
        /// everything is an append at the very end.
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            let end = (textView.text as NSString).length
            let isAppend = range.location >= end && range.length == 0
            let isDeletion = text.isEmpty

            guard !isDeletion, isAppend, range.location >= protectedLength else {
                let notify = parent.onBlockedEdit
                DispatchQueue.main.async { notify?() }
                return false
            }
            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdating else { return }
            // The caret lives at the end of the page. You cannot go back.
            let end = (textView.text as NSString).length
            if textView.selectedRange.location != end || textView.selectedRange.length != 0 {
                textView.selectedRange = NSRange(location: end, length: 0)
            }
        }
    }
}

#elseif os(macOS)
import AppKit

struct InlineFadingTextEditor: NSViewRepresentable {
    @Binding var draft: String
    let releasedText: String
    let shouldFocus: Bool
    /// Fired when the session rules reject an edit, so the UI can say why.
    var onBlockedEdit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        // Undo would walk back over writing the rules say is final.
        textView.allowsUndo = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 5, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.setAccessibilityLabel("Private brain dump")

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.protectedLength = releasedText.utf16.count
        context.coordinator.isUpdating = true

        let fullText = releasedText + draft
        if textView.string != fullText {
            textView.string = fullText
            textView.setSelectedRange(NSRange(location: fullText.utf16.count, length: 0))
        }

        applyAttributes(to: textView)
        context.coordinator.isUpdating = false

        if shouldFocus, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
            }
        }
    }

    private func applyAttributes(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let ns = textView.string as NSString
        let fullLength = ns.length
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4

        let clearColor = NSColor(red: 0.090, green: 0.247, blue: 0.227, alpha: 1)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: roundedFont,
            .foregroundColor: clearColor,
            .paragraphStyle: paragraph
        ]

        storage.beginEditing()
        if fullLength > 0 {
            storage.setAttributes(baseAttributes, range: NSRange(location: 0, length: fullLength))

            var flooredPrefixEnd = 0
            ns.enumerateSubstrings(
                in: NSRange(location: 0, length: fullLength),
                options: [.byWords, .reverse]
            ) { _, range, _, stop in
                let alpha = TrailingFade.alpha(distanceFromEnd: fullLength - range.location)
                if TrailingFade.isAtFloor(alpha) {
                    flooredPrefixEnd = range.location + range.length
                    stop.pointee = true
                    return
                }
                if alpha < 1 {
                    storage.addAttributes(Self.faded(alpha: alpha, color: clearColor), range: range)
                }
            }

            if flooredPrefixEnd > 0 {
                storage.addAttributes(
                    Self.faded(alpha: TrailingFade.floor, color: clearColor),
                    range: NSRange(location: 0, length: flooredPrefixEnd)
                )
            }
        }
        storage.endEditing()
        textView.typingAttributes = baseAttributes
    }

    private static func faded(alpha: Double, color: NSColor) -> [NSAttributedString.Key: Any] {
        let softness = 1 - alpha
        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.18 * softness)
        shadow.shadowBlurRadius = 1.35 * softness
        return [
            .foregroundColor: color.withAlphaComponent(alpha),
            .shadow: shadow
        ]
    }

    private var roundedFont: NSFont {
        let base = NSFont.systemFont(ofSize: 22)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: 22) ?? base
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineFadingTextEditor
        var protectedLength = 0
        var isUpdating = false

        init(parent: InlineFadingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            let fullText = textView.string
            guard fullText.hasPrefix(parent.releasedText) else { return }
            parent.draft = String(fullText.dropFirst(parent.releasedText.count))
        }

        /// Session rules: no deleting, no editing what you already wrote —
        /// everything is an append at the very end.
        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            let end = (textView.string as NSString).length
            let isAppend = affectedCharRange.location >= end && affectedCharRange.length == 0
            let isDeletion = (replacementString ?? "").isEmpty

            guard !isDeletion, isAppend, affectedCharRange.location >= protectedLength else {
                let notify = parent.onBlockedEdit
                DispatchQueue.main.async { notify?() }
                return false
            }
            return true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            let end = (textView.string as NSString).length
            if textView.selectedRange().location != end || textView.selectedRange().length != 0 {
                textView.setSelectedRange(NSRange(location: end, length: 0))
            }
        }
    }
}
#endif
