import Foundation

/// Pure normalization for user-typed tab names (Arc/Safari-style tab rename).
///
/// Kept in HiveCore so the trimming/cap rules are deterministic and unit-tested
/// without launching a browser. Callers decide what to do with the result:
/// an empty normalized name means the user cleared the rename (fall back to
/// the live page title); a non-empty one is the durable custom title.
public enum TabRenamePolicy {

    /// Upper bound on a custom tab name. Arc-style short labels — a rename is
    /// a nickname, not a document title, so the cap keeps the tab strip tidy.
    public static let maxLength = 60

    /// Normalizes a user-typed name: surrounding whitespace is trimmed and
    /// every interior run of whitespace (spaces, tabs, pasted newlines)
    /// collapses to a single space, so a multi-line title lands as one clean
    /// label. The result is capped at ``maxLength``. Returns the empty string
    /// when nothing meaningful remains.
    public static func normalized(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(maxLength))
    }
}
