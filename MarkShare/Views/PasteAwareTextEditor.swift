import SwiftUI
import UIKit

/// A text editor that converts pasted rich text to Markdown format
struct PasteAwareTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
    var backgroundColor: UIColor = .clear

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MarkdownPasteTextView {
        let textView = MarkdownPasteTextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.backgroundColor = backgroundColor
        textView.text = text
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 5
        textView.adjustsFontForContentSizeCategory = true
        return textView
    }

    func updateUIView(_ uiView: MarkdownPasteTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font
        uiView.backgroundColor = backgroundColor
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: PasteAwareTextEditor

        init(_ parent: PasteAwareTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

/// Custom UITextView that converts pasted content to Markdown-friendly format
class MarkdownPasteTextView: UITextView {

    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general

        // Try RTF first - has bold/italic info
        if let rtfData = pasteboard.data(forPasteboardType: "public.rtf"),
           let attributedString = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            let markdown = convertAttributedStringToMarkdown(attributedString)
            insertTextAtCursor(markdown)
            return
        }

        // Try HTML as attributed string
        if let htmlData = pasteboard.data(forPasteboardType: "public.html"),
           let attributedString = try? NSAttributedString(
               data: htmlData,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            let markdown = convertAttributedStringToMarkdown(attributedString)
            insertTextAtCursor(markdown)
            return
        }

        // Fallback to plain text
        if let plainText = pasteboard.string {
            let markdown = convertPlainTextToMarkdown(plainText)
            insertTextAtCursor(markdown)
            return
        }

        super.paste(sender)
    }

    /// Converts NSAttributedString to Markdown by examining font traits
    private func convertAttributedStringToMarkdown(_ attributedString: NSAttributedString) -> String {
        var result = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let substring = attributedString.attributedSubstring(from: range).string
            var text = substring

            // Check for bold/italic via font traits
            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                let isBold = traits.contains(.traitBold)
                let isItalic = traits.contains(.traitItalic)

                // Only wrap if there's actual content (not just whitespace)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && (isBold || isItalic) {
                    // Preserve leading/trailing whitespace
                    let leadingWS = String(text.prefix(while: { $0.isWhitespace }))
                    let trailingWS = String(text.reversed().prefix(while: { $0.isWhitespace }).reversed())

                    if isBold && isItalic {
                        text = "\(leadingWS)***\(trimmed)***\(trailingWS)"
                    } else if isBold {
                        text = "\(leadingWS)**\(trimmed)**\(trailingWS)"
                    } else if isItalic {
                        text = "\(leadingWS)*\(trimmed)*\(trailingWS)"
                    }
                }
            }

            result += text
        }

        // Insert newline before inline numbered list items (RTF/HTML path only - heuristic)
        // Matches: non-newline char, optional space, number with period, required space after
        result = result.replacingOccurrences(
            of: "([^\\n\\d])[ \\t]*((\\*\\*)?\\d+\\.(\\*\\*)?)[ \\t]+",
            with: "$1\n$2 ",
            options: .regularExpression
        )

        // Apply bullet conversion
        return convertPlainTextToMarkdown(result)
    }

    /// Minimal text cleanup - converts bullet chars at line start, removes junk
    private func convertPlainTextToMarkdown(_ text: String) -> String {
        var result = text

        // Remove object replacement characters
        result = result.replacingOccurrences(of: "\u{FFFC}", with: "")

        // Normalize special dash characters to regular hyphens (for table delimiters, etc.)
        // Using regex to catch all dash-like unicode characters
        result = result.replacingOccurrences(
            of: "[\u{2010}-\u{2015}\u{2212}\u{2E3A}\u{2E3B}\u{FE58}\u{FE63}\u{FF0D}]",
            with: "-",
            options: .regularExpression
        )

        // Convert bullet characters to dash (only when at line start)
        result = result.replacingOccurrences(
            of: "(^|\\n)([ \\t]*)[•◦‣▪▸►∙][ \\t]*",
            with: "$1$2- ",
            options: .regularExpression
        )

        // Clean up excessive blank lines
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func insertTextAtCursor(_ text: String) {
        if let selectedRange = selectedTextRange {
            replace(selectedRange, withText: text)
            delegate?.textViewDidChange?(self)
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    VStack {
        PasteAwareTextEditor(text: $text)
            .frame(height: 200)
            .border(Color.gray)
            .padding()

        Text("Current text: \(text)")
            .padding()
    }
}
