import KeyboardShortcuts
import ScreenResizeCore
import SwiftUI

/// The five bindable shortcut names.
///
/// These are fixed at compile time because that is what `KeyboardShortcuts`
/// requires, while the favorites list is whatever the user has starred. The
/// bridge is position: a shortcut fires whatever currently occupies that slot.
/// The identifiers must match `FavoriteSlot.identifier(for:)`, which is covered
/// by a test in Core.
extension KeyboardShortcuts.Name {
    static let favorite1 = Self("favorite1")
    static let favorite2 = Self("favorite2")
    static let favorite3 = Self("favorite3")
    static let favorite4 = Self("favorite4")
    static let favorite5 = Self("favorite5")

    static let favoriteSlots: [Self] = [.favorite1, .favorite2, .favorite3, .favorite4, .favorite5]
}

/// Routes global hotkeys to favorite slots.
@MainActor
final class HotkeyBinder {

    private let model: MenuBarModel
    private var isBound = false

    init(model: MenuBarModel) {
        self.model = model
    }

    /// Registers every slot. Safe to call more than once.
    func bind() {
        guard !isBound else { return }
        isBound = true

        for (slot, name) in KeyboardShortcuts.Name.favoriteSlots.enumerated() {
            KeyboardShortcuts.onKeyUp(for: name) { [weak model] in
                // A hotkey fires with no menu open, so applyFavoriteSlot
                // refreshes before doing anything.
                model?.applyFavoriteSlot(slot)
            }
        }
    }
}
