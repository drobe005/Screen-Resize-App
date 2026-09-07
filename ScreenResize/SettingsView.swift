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
            Picker("Sizing mode", selection: $model.sizingMode) {
                ForEach(SizingMode.allCases, id: \.self) { mode in
                    Text(mode.menuTitle).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Text(model.sizingMode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                ForEach(ResolutionCatalog.groups) { group in
                    Section(group.heading) {
                        ForEach(group.resolutions) { resolution in
                            Toggle(isOn: Binding(
                                get: { model.isFavorite(resolution) },
                                set: { _ in model.toggleFavorite(resolution) }
                            )) {
                                Text(resolution.label.map { "\(resolution.name) — \($0)" }
                                     ?? resolution.name)
                            }
                        }
                    }
                }
            }
            .frame(height: 320)
        }
        .scenePadding()
    }
}
