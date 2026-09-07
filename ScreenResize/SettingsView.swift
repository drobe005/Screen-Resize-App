import SwiftUI
import ScreenResizeCore

/// The Settings window. Tabs arrive alongside the features they configure.
struct SettingsView: View {

    @EnvironmentObject private var model: MenuBarModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
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
