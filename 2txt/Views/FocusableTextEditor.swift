// ===== File: ./2txt/Views/FocusableTextEditor.swift =====

import SwiftUI

struct FocusableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onCommand: (Command) -> Bool // Return true if command was handled

    enum Command {
        case up, down, enter, tab
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FocusableTextEditor

        init(_ parent: FocusableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            self.parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                return parent.onCommand(.up)
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                return parent.onCommand(.down)
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return parent.onCommand(.enter)
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return parent.onCommand(.tab)
            }
            // If we don't handle it, let the text view do its default action
            return false
        }
    }
}
