import Foundation

/// Строки интерфейса на русском, английском и испанском.
/// Таблица в коде, а не в .lproj: язык переключается в настройках на лету, без перезапуска.
struct Strings {
    let language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language.resolved
    }

    private func pick(_ ru: String, _ en: String, _ es: String) -> String {
        switch language {
        case .en: return en
        case .es: return es
        default: return ru
        }
    }

    // Попап
    var modeAuto: String { pick("Авто", "Auto", "Auto") }
    var modeManual: String { pick("Ручной", "Manual", "Manual") }
    var tempo: String { pick("Темп", "Tempo", "Tempo") }
    var volume: String { pick("Громкость", "Volume", "Volumen") }
    var start: String { pick("Старт", "Start", "Iniciar") }
    var pause: String { pick("Пауза", "Pause", "Pausa") }
    var resume: String { pick("Продолжить", "Resume", "Reanudar") }
    var stop: String { pick("Стоп", "Stop", "Detener") }
    var settingsMenu: String { pick("Настройки…", "Settings…", "Ajustes…") }
    var quit: String { pick("Выйти", "Quit", "Salir") }

    var subAuto: String { pick("авто", "auto", "auto") }
    var subManual: String { pick("ручной", "manual", "manual") }
    var subFixed: String { pick("темп фиксирован", "fixed tempo", "tempo fijo") }
    var subPaused: String { pick("пауза", "paused", "en pausa") }
    var subAtCeiling: String { pick("максимум", "at maximum", "en el máximo") }
    func subRampIn(_ step: Int, _ time: String) -> String {
        pick("+\(step) BPM через \(time)", "+\(step) BPM in \(time)", "+\(step) BPM en \(time)")
    }
    func subStartsAt(_ bpm: Int) -> String {
        pick("старт с \(bpm) BPM", "starts at \(bpm) BPM", "empieza en \(bpm) BPM")
    }

    // Окно настроек
    var settingsTitle: String { pick("Настройки", "Settings", "Ajustes") }
    var tabRamp: String { pick("Разгон", "Ramp-up", "Aceleración") }
    var tabSound: String { pick("Звук", "Sound", "Sonido") }
    var startTempo: String { pick("Стартовый темп", "Starting tempo", "Tempo inicial") }
    var step: String { pick("Шаг повышения", "Increase step", "Incremento") }
    var interval: String { pick("Интервал повышения", "Increase every", "Intervalo de aumento") }
    var intervalNote: String {
        pick("Считается только время воспроизведения.",
             "Only playing time counts.",
             "Solo cuenta el tiempo de reproducción.")
    }
    var ceiling: String { pick("Потолок темпа", "Maximum tempo", "Tempo máximo") }
    var ceilingNote: String {
        pick("На потолке темп держится до остановки. Не ниже стартового.",
             "At the maximum the tempo holds until you stop. Never below the starting tempo.",
             "En el máximo el tempo se mantiene hasta detener. Nunca por debajo del inicial.")
    }
    var autoStop: String { pick("Автоостановка на паузе", "Auto-stop when paused", "Detener tras pausa de") }
    var autoStopNote: String {
        pick("Пауза дольше этого времени полностью останавливает сессию.",
             "A longer pause stops the session completely.",
             "Una pausa más larga detiene la sesión por completo.")
    }
    var off: String { pick("Выключено", "Off", "Desactivado") }
    var preventSleep: String {
        pick("Не давать Mac уснуть во время сессии",
             "Keep Mac awake during a session",
             "Mantener el Mac activo durante la sesión")
    }
    var launchAtLogin: String { pick("Запускать при входе в систему", "Open at login", "Abrir al iniciar sesión") }
    var general: String { pick("Общие", "General", "General") }
    var timbre: String { pick("Тембр", "Sound", "Timbre") }
    func timbreName(_ timbre: Timbre) -> String {
        switch timbre {
        case .click: return pick("Щелчок", "Click", "Clic")
        case .woodblock: return pick("Вуд-блок", "Wood block", "Bloque de madera")
        case .softTick: return pick("Тихий тик", "Soft tick", "Tic suave")
        case .softBeep: return pick("Мягкий бип", "Soft beep", "Pitido suave")
        }
    }
    var accent: String { pick("Акцент", "Accent", "Acento") }
    var accentNote: String {
        pick("Каждый N-й удар громче и выше.",
             "Every Nth beat is louder and higher.",
             "Cada N tiempos, uno más fuerte y agudo.")
    }
    func accentEvery(_ n: Int) -> String {
        pick("Каждый \(n)-й удар", "Every \(n) beats", "Cada \(n) tiempos")
    }
    var showTempo: String {
        pick("Показывать темп рядом с иконкой", "Show tempo next to the icon", "Mostrar el tempo junto al icono")
    }
    var languageLabel: String { pick("Язык интерфейса", "Language", "Idioma") }
    func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: return pick("Как в системе", "System", "Como el sistema")
        case .ru: return "Русский"
        case .en: return "English"
        case .es: return "Español"
        }
    }
    var reset: String { pick("Сбросить к заводским", "Restore defaults", "Restablecer valores") }

    func minutes(_ value: Int) -> String {
        pick("\(value) мин", "\(value) min", "\(value) min")
    }

    func duration(minutes total: Int) -> String {
        let h = total / 60, m = total % 60
        if h == 0 { return minutes(m) }
        let hours = pick("\(h) ч", "\(h) h", "\(h) h")
        return m == 0 ? hours : "\(hours) \(minutes(m))"
    }
}
