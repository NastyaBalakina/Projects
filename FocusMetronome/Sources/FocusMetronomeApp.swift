import SwiftUI

@main
struct FocusMetronomeApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var controller: MetronomeController

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: MetronomeController(settings: settings))
        // Подстраховка к LSUIElement в Info.plist: ни Dock, ни Cmd+Tab.
        NSApplication.shared.setActivationPolicy(.accessory)
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
