import Foundation
import ServiceManagement

enum MetronomeMode: String, CaseIterable {
    case auto, manual
}

enum Timbre: String, CaseIterable, Identifiable {
    case click, woodblock, softTick, softBeep
    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .click: return "click"
        case .woodblock: return "woodblock"
        case .softTick: return "soft_tick"
        case .softBeep: return "soft_beep"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ru, en, es
    var id: String { rawValue }

    /// «Как в системе, иначе русский».
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for identifier in Locale.preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "ru": return .ru
            case "en": return .en
            case "es": return .es
            default: continue
            }
        }
        return .ru
    }
}

enum TempoLimits {
    static let bpm = 30...240
    static let step = 1...30
    static let intervalMinutes = 1...180
    static let accentEvery = 2...8
    /// Варианты автоостановки на паузе в минутах; 0 — выключено.
    static let autoStopOptions = [30, 60, 90, 120, 180, 240, 300, 360, 420, 480, 0]
}

/// Все настройки приложения в UserDefaults. Состояние сессии здесь не хранится.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let mode = "mode"
        static let manualBPM = "manualBPM"
        static let volume = "volume"
        static let autoStartBPM = "autoStartBPM"
        static let stepBPM = "stepBPM"
        static let intervalMinutes = "intervalMinutes"
        static let ceilingBPM = "ceilingBPM"
        static let autoStopMinutes = "autoStopMinutes"
        static let timbre = "timbre"
        static let accentEnabled = "accentEnabled"
        static let accentEvery = "accentEvery"
        static let showTempo = "showTempo"
        static let language = "language"
        static let preventSleep = "preventSleep"
    }

    private enum Default {
        static let mode = MetronomeMode.auto
        static let manualBPM = 90
        static let volume = 0.5
        static let autoStartBPM = 90
        static let stepBPM = 10
        static let intervalMinutes = 30
        static let ceilingBPM = 180
        static let autoStopMinutes = 180
        static let timbre = Timbre.click
        static let accentEnabled = false
        static let accentEvery = 4
        static let showTempo = true
        static let language = AppLanguage.system
        static let preventSleep = false
    }

    private let defaults: UserDefaults

    @Published var mode: MetronomeMode { didSet { defaults.set(mode.rawValue, forKey: Key.mode) } }
    @Published var manualBPM: Int { didSet { defaults.set(manualBPM, forKey: Key.manualBPM) } }
    @Published var volume: Double { didSet { defaults.set(volume, forKey: Key.volume) } }

    @Published var autoStartBPM: Int {
        didSet {
            if ceilingBPM < autoStartBPM { ceilingBPM = autoStartBPM }
            defaults.set(autoStartBPM, forKey: Key.autoStartBPM)
        }
    }
    @Published var stepBPM: Int { didSet { defaults.set(stepBPM, forKey: Key.stepBPM) } }
    @Published var intervalMinutes: Int { didSet { defaults.set(intervalMinutes, forKey: Key.intervalMinutes) } }
    @Published var ceilingBPM: Int {
        didSet {
            // Потолок не может быть ниже стартового темпа.
            if ceilingBPM < autoStartBPM { ceilingBPM = autoStartBPM }
            defaults.set(ceilingBPM, forKey: Key.ceilingBPM)
        }
    }
    @Published var autoStopMinutes: Int { didSet { defaults.set(autoStopMinutes, forKey: Key.autoStopMinutes) } }
    @Published var timbre: Timbre { didSet { defaults.set(timbre.rawValue, forKey: Key.timbre) } }
    @Published var accentEnabled: Bool { didSet { defaults.set(accentEnabled, forKey: Key.accentEnabled) } }
    @Published var accentEvery: Int { didSet { defaults.set(accentEvery, forKey: Key.accentEvery) } }
    @Published var showTempo: Bool { didSet { defaults.set(showTempo, forKey: Key.showTempo) } }
    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Key.language) } }
    @Published var preventSleep: Bool { didSet { defaults.set(preventSleep, forKey: Key.preventSleep) } }

    /// Источник истины — SMAppService, а не UserDefaults.
    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func int(_ key: String, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
            guard defaults.object(forKey: key) != nil else { return fallback }
            return min(max(defaults.integer(forKey: key), range.lowerBound), range.upperBound)
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }

        mode = defaults.string(forKey: Key.mode).flatMap(MetronomeMode.init(rawValue:)) ?? Default.mode
        manualBPM = int(Key.manualBPM, Default.manualBPM, TempoLimits.bpm)
        volume = defaults.object(forKey: Key.volume) == nil
            ? Default.volume
            : min(max(defaults.double(forKey: Key.volume), 0), 1)
        let start = int(Key.autoStartBPM, Default.autoStartBPM, TempoLimits.bpm)
        autoStartBPM = start
        stepBPM = int(Key.stepBPM, Default.stepBPM, TempoLimits.step)
        intervalMinutes = int(Key.intervalMinutes, Default.intervalMinutes, TempoLimits.intervalMinutes)
        ceilingBPM = max(int(Key.ceilingBPM, Default.ceilingBPM, TempoLimits.bpm), start)
        let stop = int(Key.autoStopMinutes, Default.autoStopMinutes, 0...480)
        autoStopMinutes = TempoLimits.autoStopOptions.contains(stop) ? stop : Default.autoStopMinutes
        timbre = defaults.string(forKey: Key.timbre).flatMap(Timbre.init(rawValue:)) ?? Default.timbre
        accentEnabled = bool(Key.accentEnabled, Default.accentEnabled)
        accentEvery = int(Key.accentEvery, Default.accentEvery, TempoLimits.accentEvery)
        showTempo = bool(Key.showTempo, Default.showTempo)
        language = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? Default.language
        preventSleep = bool(Key.preventSleep, Default.preventSleep)
    }

    var strings: Strings { Strings(language.resolved) }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("FocusMetronome: SMAppService error: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// «Сбросить к заводским»: вся таблица настроек возвращается к значениям из ТЗ.
    func resetToDefaults() {
        mode = Default.mode
        manualBPM = Default.manualBPM
        volume = Default.volume
        autoStartBPM = Default.autoStartBPM
        ceilingBPM = Default.ceilingBPM
        stepBPM = Default.stepBPM
        intervalMinutes = Default.intervalMinutes
        autoStopMinutes = Default.autoStopMinutes
        timbre = Default.timbre
        accentEnabled = Default.accentEnabled
        accentEvery = Default.accentEvery
        showTempo = Default.showTempo
        language = Default.language
        preventSleep = Default.preventSleep
        if launchAtLogin { setLaunchAtLogin(false) }
    }
}
