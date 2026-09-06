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

    @StateObject private var model = MenuBarModel(
        windowManager: AXWindowManager(),
        screens: NSScreenProvider(),
        frontmostTracker: WorkspaceFrontmostTracker()
    )

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
                SizingModePicker(mode: $model.sizingMode)
                if let failure = model.failureMessage {
                    FailureBannerView(message: failure)
                }
                ForEach(ResolutionCatalog.groups) { group in
                    AspectRatioGroupMenu(
                        heading: group.heading,
                        options: model.options(in: group),
                        apply: model.apply
                    )
                }
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
            // Placeholder: a real Settings scene would make MenuBarExtra no
            // longer the app's only scene, which CLAUDE.md forbids for now.
            Button("Settings…") {}
                .disabled(true)
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

private struct SizingModePicker: View {
    @Binding var mode: SizingMode

    var body: some View {
        Picker("Sizing", selection: $mode) {
            ForEach(SizingMode.allCases, id: \.self) { mode in
                Text(mode.menuTitle).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

private struct AspectRatioGroupMenu: View {
    let heading: String
    let options: [ResolutionOption]
    let apply: (ResolutionOption) -> Void

    var body: some View {
        Menu(heading) {
            ForEach(options) { option in
                Button(option.menuLabel) { apply(option) }
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
