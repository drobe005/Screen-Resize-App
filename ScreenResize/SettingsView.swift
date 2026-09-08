import KeyboardShortcuts
import SwiftUI
import ScreenResizeCore

/// The Settings window. Tabs arrive alongside the features they configure.
struct SettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            FavoritesSettingsView()
                .tabItem { Label("Favorites", systemImage: "star") }
            CustomSizesSettingsView()
                .tabItem { Label("Custom Sizes", systemImage: "plus.rectangle") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "command") }
        }
        .frame(width: 460)
        .scenePadding()
        .onAppear { ActivationPolicyCoordinator.shared.windowDidAppear() }
        .onDisappear { ActivationPolicyCoordinator.shared.windowDidDisappear() }
    }
}

private struct GeneralSettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchesAtLogin($0) }
                ))
                .disabled(!model.launchAtLoginAvailability.isAvailable)

                if case .unavailable(let reason) = model.launchAtLoginAvailability {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = model.launchAtLoginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Starring lives here rather than in the menu: a MenuBarExtra submenu row is a
/// Button, and giving it a second tap target for the star is both awkward to
/// build and undiscoverable to use.
private struct FavoritesSettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Starred sizes are pinned to the top of the menu.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(model.allResolutions) { resolution in
                    Toggle(isOn: Binding(
                        get: { model.isFavorite(resolution) },
                        set: { _ in model.toggleFavorite(resolution) }
                    )) {
                        Text(resolution.label.map { "\(resolution.name) — \($0)" }
                             ?? resolution.name)
                    }
                }
            }
            .frame(height: 320)
        }
        .scenePadding()
    }
}

private struct CustomSizesSettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    @State private var widthText = ""
    @State private var heightText = ""
    @State private var errorMessage: String?

    /// Parsed only when both fields are valid numbers, so the ratio label stays
    /// blank rather than flickering nonsense while typing.
    private var pendingPointSize: PointSize? {
        guard let width = Int(widthText), let height = Int(heightText),
              width > 0, height > 0
        else { return nil }
        return PointSize(widthInPoints: CGFloat(width), heightInPoints: CGFloat(height))
    }

    private var ratioDescription: String {
        pendingPointSize.flatMap(WindowGeometry.aspectRatioDescription(of:)) ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Width", text: $widthText)
                    .frame(width: 90)
                Text("×")
                TextField("Height", text: $heightText)
                    .frame(width: 90)
                Text("pixels")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add", action: add)
                    .disabled(pendingPointSize == nil)
            }
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Text("Aspect ratio")
                    .foregroundStyle(.secondary)
                Text(ratioDescription)
                    .monospacedDigit()
            }
            .font(.callout)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            if model.customSizes.isEmpty {
                Text("No custom sizes yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(model.customSizes) { size in
                        HStack {
                            Text(size.resolution.label.map { "\(size.id) — \($0)" } ?? size.id)
                            Spacer()
                            Button("Remove") { model.removeCustomSize(size) }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .scenePadding()
    }

    private func add() {
        guard let width = Int(widthText), let height = Int(heightText) else { return }
        do {
            try model.addCustomSize(widthInPoints: width, heightInPoints: height)
            widthText = ""
            heightText = ""
            errorMessage = nil
        } catch let error as CustomSizeError {
            errorMessage = error.description
        } catch {
            errorMessage = "\(error)"
        }
    }
}

private struct ShortcutsSettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Each shortcut resizes to whatever is in that favorites position, "
                 + "so restarring keeps your shortcuts working.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Deliberately NOT a Form/List. KeyboardShortcuts.Recorder is an
            // AppKit-hosted field, and Form's own key handling intercepts the
            // keystroke before the Recorder sees it: the field focuses but
            // never records anything. A plain VStack has no such interception.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(KeyboardShortcuts.Name.favoriteSlots.enumerated()), id: \.offset) {
                    slot, name in
                    // Every row must be structurally identical. A `if slot > 0`
                    // around this divider made rows 2-5 conditional content while
                    // row 1 was not, and the recorders in the conditional rows
                    // fell back to plain text-field behaviour: RecorderCocoa
                    // refuses to become first responder when its view is not
                    // properly in a window, and silently behaves like the
                    // NSSearchField it subclasses. Hide the divider by value,
                    // never by structure.
                    Divider()
                        .opacity(slot == 0 ? 0 : 1)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FavoriteSlot.title(for: slot))
                            Text(assignment(for: slot))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: name)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
        }
        .scenePadding()
    }

    /// What this slot currently points at, so a shortcut is never a mystery.
    private func assignment(for slot: Int) -> String {
        let favorites = model.favoriteResolutionIDs
        guard favorites.indices.contains(slot) else { return "No favorite in this position" }
        return favorites[slot]
    }
}
