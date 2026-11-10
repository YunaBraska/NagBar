import SwiftUI

@main
struct NagBarModernApp: App {
    @StateObject private var model = SourceSetupModel()

    var body: some Scene {
        WindowGroup("NagBar", id: "sources") {
            SourceSetupView(model: model)
        }
        .defaultSize(width: 620, height: 620)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            StatusMenuView(model: model)
        } label: {
            Label("NagBar", systemImage: model.hasConfiguredSource ? "waveform.path.ecg.rectangle" : "exclamationmark.triangle")
        }
        .menuBarExtraStyle(.menu)
    }
}
