import Foundation

/// Fixed hotkey slots addressing favorites by position.
///
/// KeyboardShortcuts binds to `Name` constants fixed at compile time, while the
/// favorites list is whatever the user has starred. Slots bridge the two: a
/// shortcut keeps working when favorites change, it just points at the new
/// occupant of that position.
public enum FavoriteSlot {

    /// How many favorites can have a shortcut.
    public static let count = 5

    /// Zero-based slot indices.
    public static var indices: Range<Int> { 0..<count }

    /// User-facing name, e.g. "Favorite 1".
    public static func title(for slot: Int) -> String { "Favorite \(slot + 1)" }

    /// Stable identifier used as the shortcut's registered name.
    public static func identifier(for slot: Int) -> String { "favorite\(slot + 1)" }
}
