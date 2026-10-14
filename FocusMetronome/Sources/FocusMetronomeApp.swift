import SwiftUI

@main
struct FocusMetronomeApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var controller: MetronomeController

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        let controller = MetronomeController(settings: settings)
        _controller = StateObject(wrappedValue: controller)
        // Подстраховка к LSUIElement в Info.plist: ни Dock, ни Cmd+Tab.
        NSApplication.shared.setActivationPolicy(.accessory)
        // Для проверки в CI: открыть окно настроек сразу после запуска.
        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated {
                    SettingsWindowController.shared.show(settings: settings, controller: controller)
                    SettingsWindowController.shared.logFrame()
                }
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopupView(controller: controller, settings: settings)
        } label: {
            // Темп виден, пока сессия идёт или на паузе; в остановленном состоянии — только иконка.
            let showBPM = settings.showTempo && controller.state != .stopped
            Image(nsImage: StatusImage.make(
                bpm: showBPM ? controller.displayBPM : nil,
                active: controller.state == .playing,
                dimmed: controller.state == .paused
            ))
        }
        .menuBarExtraStyle(.window)
    }
}
