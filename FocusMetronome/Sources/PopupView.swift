import SwiftUI

/// Попап в строке меню: всё управление сессией.
struct PopupView: View {
    @ObservedObject var controller: MetronomeController
    @ObservedObject var settings: AppSettings
    @StateObject private var ticker = Ticker()
    @State private var lastVolumePreview = Date.distantPast

    private var t: Strings { settings.strings }

    var body: some View {
        VStack(spacing: 14) {
            header
            Picker("", selection: Binding(
                get: { settings.mode },
                set: { controller.setMode($0) }
            )) {
                Text(t.modeAuto).tag(MetronomeMode.auto)
                Text(t.modeManual).tag(MetronomeMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            labeledSlider(title: t.tempo, value: "\(controller.displayBPM) BPM") {
                Slider(
                    value: Binding(
                        get: { Double(controller.displayBPM) },
                        set: { controller.setTempo(Int($0.rounded())) }
                    ),
                    in: Double(TempoLimits.bpm.lowerBound)...Double(TempoLimits.bpm.upperBound),
                    step: 1
                )
            }

            labeledSlider(title: t.volume, value: "\(Int((settings.volume * 100).rounded())) %") {
                Slider(
                    value: Binding(
                        get: { settings.volume },
                        set: { newValue in
                            settings.volume = newValue
                            previewVolume()
                        }
                    ),
                    in: 0...1
                )
            }

            HStack(spacing: 10) {
                Button { controller.togglePrimary() } label: {
                    Text(primaryTitle).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])

                Button { controller.stop() } label: {
                    Text(t.stop).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(controller.state == .stopped)
            }
            .controlSize(.large)

            Divider().padding(.horizontal, -16)

            VStack(spacing: 2) {
                MenuRow(title: t.settingsMenu, shortcut: "⌘,") {
                    NSApp.keyWindow?.close()
                    SettingsWindowController.shared.show(settings: settings, controller: controller)
                }
                .keyboardShortcut(",", modifiers: .command)

                MenuRow(title: t.quit, shortcut: "⌘Q") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal, -8)
        }
        .padding(16)
        .frame(width: 290)
        .onAppear { ticker.start() }
        .onDisappear { ticker.stop() }
        .onKeyPress(.escape) {
            NSApp.keyWindow?.close()
            return .handled
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("\(controller.displayBPM)")
                .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.identity)
            Text(subtitle)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // Подписка на тикер: обратный отсчёт обновляется раз в секунду, пока попап открыт.
                .id(ticker.tick)
        }
    }

    private var primaryTitle: String {
        switch controller.state {
        case .stopped: return t.start
        case .playing: return t.pause
        case .paused: return t.resume
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if settings.mode == .auto {
            parts.append(t.subAuto)
            if controller.state == .stopped {
                parts.append(t.subStartsAt(controller.displayBPM))
            } else if let seconds = controller.secondsUntilRamp() {
                parts.append(t.subRampIn(settings.stepBPM, Self.format(seconds)))
            } else if controller.isAtCeiling {
                parts.append(t.subAtCeiling)
            }
        } else {
            parts.append(t.subManual)
            parts.append(t.subFixed)
        }
        if controller.state == .paused { parts.append(t.subPaused) }
        return parts.joined(separator: " · ")
    }

    private static func format(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds % 3600 / 60, s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Движение ползунка громкости сразу играет удар (не чаще ~7 раз в секунду).
    private func previewVolume() {
        let now = Date()
        guard now.timeIntervalSince(lastVolumePreview) > 0.15 else { return }
        lastVolumePreview = now
        controller.previewTimbre()
    }

    private func labeledSlider<S: View>(title: String, value: String, @ViewBuilder slider: () -> S) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit().foregroundStyle(.secondary)
            }
            slider()
        }
    }
}

/// Строка в стиле пункта меню: подсвечивается при наведении.
private struct MenuRow: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.primary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Секундный тикер для обратного отсчёта. Работает только пока попап открыт — в покое CPU 0 %.
@MainActor
final class Ticker: ObservableObject {
    @Published private(set) var tick = 0
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick &+= 1 }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick &+= 1
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
