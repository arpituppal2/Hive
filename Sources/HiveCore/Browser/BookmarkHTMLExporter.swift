import Foundation

/// Export Bookmarks to HTML (Netscape bookmark format) — Chrome/Safari/Arc
/// parity. Produces a `<!DOCTYPE NETSCAPE-Bookmark-file-1>` document that
/// every major browser can import back. Pure and deterministic (no date or
/// locale leakage) so the contract is testable from HiveCore without a UI.
public enum BookmarkHTMLExporter: Sendable {

    public struct Item: Sendable, Equatable {
        public let title: String
        public let urlString: String
        /// Unix seconds; 0 means unknown — Hive does not persist bookmark
        /// creation dates, and 0 is the standard value for unknown in the
        /// Netscape format.
        public let dateAdded: Int

        public init(title: String, urlString: String, dateAdded: Int = 0) {
            self.title = title
            self.urlString = urlString
            self.dateAdded = dateAdded
        }
    }

    /// HTML-escapes text and attribute content the way bookmark exporters do:
    /// `&` first, then `<`, `>`, `"`, `'`, and control characters as numeric
    /// entities — a hostile title or URL can never break out of the document.
    public static func htmlEscape(_ s: String) -> String {
        var out = ""
        for ch in s.unicodeScalars {
            switch ch.value {
            case 0x26: out += "&amp;"
            case 0x3C: out += "&lt;"
            case 0x3E: out += "&gt;"
            case 0x22: out += "&quot;"
            case 0x27: out += "&#39;"
            case 0x00...0x1F, 0x7F: out += String(format: "&#%u;", ch.value)
            default: out.unicodeScalars.append(ch)
            }
        }
        return out
    }

    /// Renders the complete Netscape bookmark document. Input order is
    /// preserved — the file mirrors the bookmarks manager exactly.
    public static func export(
        items: [Item],
        title: String = "Hive Bookmarks"
    ) -> String {
        var lines: [String] = []
        lines.append("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
        lines.append("<!-- This is an automatically generated file.")
        lines.append("     It will be read and overwritten.")
        lines.append("     DO NOT EDIT! -->")
        lines.append("<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">")
        lines.append("<TITLE>\(htmlEscape(title))</TITLE>")
        lines.append("<H1>\(htmlEscape(title))</H1>")
        lines.append("<DL><p>")
        for item in items {
            lines.append("    <DT><A HREF=\"\(htmlEscape(item.urlString))\" ADD_DATE=\"\(item.dateAdded)\">\(htmlEscape(item.title))</A>")
        }
        lines.append("</DL><p>")
        return lines.joined(separator: "\n") + "\n"
    }
}
