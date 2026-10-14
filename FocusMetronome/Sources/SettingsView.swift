import AppKit
import Combine
import SwiftUI

/// Окно настроек: две вкладки — «Разгон» и «Звук».
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var controller: MetronomeController

    private var t: Strings { settings.strings }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                rampTab.tabItem { Text(t.tabRamp) }
                soundTab.tabItem { Text(t.tabSound) }
            }
            .padding([.horizontal, .top], 12)

            HStack {
                Spacer()
                Button(t.reset) { settings.resetToDefaults() }
            }
            .padding(16)
        }
        // Grouped Form прокручивается и сам высоты не просит — без явного размера вкладки схлопываются.
        .frame(width: 480, height: 600)
        .onAppear { settings.refreshLaunchAtLogin() }
    }

    private var rampTab: some View {
        Form {
            Section {
                bpmStepper(t.startTempo, value: $settings.autoStartBPM, range: TempoLimits.bpm, prefix: "")
                bpmStepper(t.step, value: $settings.stepBPM, range: TempoLimits.step, prefix: "+")
                LabeledContent(t.interval) {
                    Stepper(value: $settings.intervalMinutes, in: TempoLimits.intervalMinutes) {
                        Text(t.minutes(settings.intervalMinutes)).monospacedDigit()
                    }
                }
                Text(t.intervalNote).font(.caption).foregroundStyle(.secondary)
                bpmStepper(t.ceiling, value: $settings.ceilingBPM, range: settings.autoStartBPM...TempoLimits.bpm.upperBound, prefix: "")
                Text(t.ceilingNote).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker(t.autoStop, selection: $settings.autoStopMinutes) {
                    ForEach(TempoLimits.autoStopOptions, id: \.self) { minutes in
                        Text(minutes == 0 ? t.off : t.duration(minutes: minutes)).tag(minutes)
                    }
                }
                Text(t.autoStopNote).font(.caption).foregroundStyle(.secondary)
                Toggle(t.preventSleep, isOn: $settings.preventSleep)
            }
        }
        .formStyle(.grouped)
    }

    private var soundTab: some View {
        Form {
            Section {
                Picker(t.timbre, selection: Binding(
                    get: { settings.timbre },
                    set: { value in
                        settings.timbre = value
                        controller.previewTimbre()
                    }
                )) {
                    ForEach(Timbre.allCases) { timbre in
                        Text(t.timbreName(timbre)).tag(timbre)
                    }
                }
                Toggle(t.accent, isOn: $settings.accentEnabled)
                if settings.accentEnabled {
                    Picker("", selection: $settings.accentEvery) {
                        ForEach(Array(TempoLimits.accentEvery), id: \.self) { n in
                            Text(t.accentEvery(n)).tag(n)
                        }
                    }
                }
                Text(t.accentNote).font(.caption).foregroundStyle(.secondary)
            }
            Section(t.general) {
                Toggle(t.showTempo, isOn: $settings.showTempo)
                Picker(t.languageLabel, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(t.languageName(language)).tag(language)
                    }
                }
                Toggle(t.launchAtLogin, isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
            }
        }
        .formStyle(.grouped)
    }

    private func bpmStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, prefix: String) -> some View {
        LabeledContent(title) {
            Stepper(value: value, in: range) {
                Text("\(prefix)\(value.wrappedValue) BPM").monospacedDigit()
            }
        }
    }
}

/// Обычное окно AppKit с SwiftUI внутри: у приложения без Dock (LSUIElement)
/// так надёжнее, чем сцена Settings, и окно можно вывести на передний план.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    private var titleSubscription: AnyCancellable?

    func show(settings: AppSettings, controller: MetronomeController) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings, controller: controller))
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.title = settings.strings.settingsTitle
            window.center()
            self.window = window
            titleSubscription = settings.$language.sink { [weak window] language in
                MainActor.assumeIsolated { window?.title = Strings(language).settingsTitle }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
