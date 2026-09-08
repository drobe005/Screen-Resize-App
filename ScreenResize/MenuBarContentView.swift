import AppKit
import SwiftUI
import ScreenResizeCore

/// The menu body.
///
/// Every view in this file is a pure function of `MenuBarModel`. Nothing here
/// computes fit, converts units, or formats a resolution — the model hands over
/// finished strings. That is what keeps resolution literals out of the UI layer,
/// per CLAUDE.md.
struct MenuBarContentView: View {

    // Shared with the onboarding window, so trust changes reach both at once.
    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch model.state {
            case .permissionRequired:
                // The entire body is replaced: no header, no picker, no size
                // lists anywhere in the tree.
                PermissionCallToActionView { model.requestPermission() }

            case .noTargetWindow(let reason):
                MenuHeaderView(title: "ScreenResize", detail: reason, scale: nil)
                Divider()
                footer

            case .ready(let snapshot):
                MenuHeaderView(
                    title: snapshot.applicationName,
                    detail: snapshot.currentSizeDescription,
                    scale: snapshot.scaleDescription
                )
                if let failure = model.failureMessage {
                    FailureBannerView(message: failure)
                }
                // Deliberately NOT wrapped in a ScrollView. A ScrollView reports
                // an ideal height of 0 along its scroll axis, and a MenuBarExtra
                // popover sizes itself to fit its content — so it collapses to
                // nothing and the entire list disappears. A maxHeight only caps
                // it, it never gives it a height. The list is bounded (14 presets
                // plus a handful of favorites and custom sizes), so natural
                // height is both correct and simpler.
                let favorites = model.favoriteOptions()
                if !favorites.isEmpty {
                    SizeSection(
                        heading: "Favorites",
                        options: favorites,
                        symbol: "star.fill",
                        apply: model.apply
                    )
                }

                let custom = model.customOptions()
                if !custom.isEmpty {
                    SizeSection(
                        heading: "Custom Sizes",
                        options: custom,
                        symbol: nil,
                        apply: model.apply
                    )
                }

                SizeSection(
                    heading: "Preset Sizes",
                    options: model.presetOptions(),
                    symbol: nil,
                    apply: model.apply
                )

                Divider()
                footer
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        // Recompute when the menu opens, and only then. Two independent triggers
        // because a MenuBarExtra panel's onAppear is not contractually
        // guaranteed to fire on every presentation; whichever arrives is enough,
        // and refresh is idempotent.
        .onAppear { model.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            model.refresh()
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsLink { Text("Settings…") }
            Button("Quit ScreenResize") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

/// Non-interactive summary of the window being targeted.
private struct MenuHeaderView: View {
    let title: String
    let detail: String
    let scale: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            HStack(spacing: 6) {
                Text(detail)
                if let scale {
                    Text("·")
                    Text(scale)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

/// A titled, flat run of sizes. No submenus: the dimensions already tell you the
/// shape of a window, so grouping by aspect ratio only added a hover between the
/// user and the thing they came to click.
private struct SizeSection: View {
    let heading: String
    let options: [ResolutionOption]
    /// Optional leading glyph, used to mark favorites.
    let symbol: String?
    let apply: (ResolutionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(options) { option in
                Button {
                    apply(option)
                } label: {
                    if let symbol {
                        Label(option.menuLabel, systemImage: symbol)
                    } else {
                        Text(option.menuLabel)
                    }
                }
                .disabled(!option.isEnabled)
            }
        }
    }
}

private struct FailureBannerView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PermissionCallToActionView: View {
    let requestPermission: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility access needed", systemImage: "lock.fill")
                .font(.headline)
            Text("ScreenResize resizes other apps' windows, which macOS requires "
                 + "your permission for.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Accessibility Settings…", action: requestPermission)
            Divider()
            Button("Quit ScreenResize") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
