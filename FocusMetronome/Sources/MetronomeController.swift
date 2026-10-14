import AppKit
import Combine
import IOKit.pwr_mgt

/// Машина состояний сессии: Остановлен → Идёт ⇄ Пауза → Остановлен.
@MainActor
final class MetronomeController: ObservableObject {
    enum State {
        case stopped, playing, paused
    }

    @Published private(set) var state: State = .stopped
    /// Темп, который сейчас звучит (или зазвучит после старта).
    @Published private(set) var displayBPM: Int

    let settings: AppSettings
    private let audio = MetronomeAudio()

    /// Сколько ударов держать в очереди плеера (ТЗ: 2–4).
    private let queueDepth = 3
    private var scheduler: TempoScheduler?
    /// Запланированные, но ещё не доигранные удары + состояние планировщика перед каждым:
    /// при перезапуске очереди откатываемся к первому неотыгранному удару.
    private var queue: [(beat: ScheduledBeat, before: TempoScheduler)] = []
    /// Темп авто-режима, выбранный ползунком до старта (только на эту сессию).
    private var pendingAutoStartBPM: Int?

    private var pausedAt: Int64 = 0
    private var pausedSince: Date?
    private var autoStopTimer: Timer?
    private var retimeWork: DispatchWorkItem?
    private var pendingRetimeBPM: Int?
    private var sleepAssertion: IOPMAssertionID = 0
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        displayBPM = settings.mode == .auto ? settings.autoStartBPM : settings.manualBPM
        audio.volume = Float(settings.volume)

        audio.onBeatPlayed = { [weak self] beat in
            MainActor.assumeIsolated { self?.beatPlayed(beat) }
        }
        audio.onConfigurationChange = { [weak self] in
            MainActor.assumeIsolated { self?.outputDeviceChanged() }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            // Засыпание Mac — пауза. Блокировка экрана воспроизведение не прерывает.
            MainActor.assumeIsolated { self?.pause() }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAutoStop() }
        }

        // @Published шлёт значения синхронно из сеттера, а настройки меняются только на главном потоке.
        settings.$volume
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.audio.volume = Float(value) }
            }
            .store(in: &cancellables)
        settings.$preventSleep
            .dropFirst()
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.updateSleepAssertion(preventSleep: value) }
            }
            .store(in: &cancellables)
        settings.$autoStopMinutes
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.checkAutoStop() } }
            }
            .store(in: &cancellables)
        // Стартовый темп поменяли в настройках, пока метроном стоит.
        settings.$autoStartBPM
            .dropFirst()
            .sink { [weak self] value in
                MainActor.assumeIsolated {
                    guard let self, self.state == .stopped, self.settings.mode == .auto,
                          self.pendingAutoStartBPM == nil else { return }
                    self.displayBPM = value
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Команды

    /// Главная кнопка попапа: Старт / Пауза / Продолжить.
    func togglePrimary() {
        switch state {
        case .stopped: start()
        case .playing: pause()
        case .paused: resume()
        }
    }

    func start() {
        guard state == .stopped else { return }
        let bpm = settings.mode == .auto
            ? (pendingAutoStartBPM ?? settings.autoStartBPM)
            : settings.manualBPM
        pendingAutoStartBPM = nil
        scheduler = TempoScheduler(bpm: bpm)
        queue = []
        setDisplay(bpm)
        audio.begin(atLogical: 0)
        fillQueue()
        audio.play()
        state = .playing
        updateSleepAssertion()
    }

    func pause() {
        guard state == .playing else { return }
        retimeWork?.cancel()
        let now = audio.currentLogical()
        rewindScheduler(to: now)
        if let bpm = pendingRetimeBPM {
            scheduler?.retime(bpm: bpm)
            pendingRetimeBPM = nil
        }
        audio.halt()
        pausedAt = now
        pausedSince = Date()
        state = .paused
        scheduleAutoStop()
    }

    func resume() {
        guard state == .paused else { return }
        autoStopTimer?.invalidate()
        pausedSince = nil
        audio.begin(atLogical: pausedAt)
        fillQueue()
        audio.play()
        state = .playing
    }

    /// Стоп сбрасывает сессию: следующий старт снова со стартового темпа.
    func stop() {
        guard state != .stopped else { return }
        retimeWork?.cancel()
        pendingRetimeBPM = nil
        autoStopTimer?.invalidate()
        pausedSince = nil
        audio.halt()
        scheduler = nil
        queue = []
        pendingAutoStartBPM = nil
        state = .stopped
        setDisplay(idleBPM)
        updateSleepAssertion()
    }

    /// Переключение режима во время игры = Стоп + новый Старт.
    func setMode(_ mode: MetronomeMode) {
        guard mode != settings.mode else { return }
        let wasPlaying = state == .playing
        stop()
        settings.mode = mode
        pendingAutoStartBPM = nil
        setDisplay(idleBPM)
        if wasPlaying { start() }
    }

    /// Правка темпа ползунком.
    func setTempo(_ value: Int) {
        let bpm = min(max(value, TempoLimits.bpm.lowerBound), TempoLimits.bpm.upperBound)
        if settings.mode == .manual {
            settings.manualBPM = bpm
        }
        switch state {
        case .stopped:
            if settings.mode == .auto { pendingAutoStartBPM = bpm }
            setDisplay(bpm)
        case .paused:
            // Очередь уже пуста, планировщик стоит на следующем ударе.
            scheduler?.retime(bpm: bpm)
            setDisplay(bpm)
        case .playing:
            setDisplay(bpm)
            pendingRetimeBPM = bpm
            // Ползунок шлёт много значений подряд — перестраиваем очередь раз в 120 мс.
            retimeWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.flushRetime() }
            }
            retimeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }
    }

    func previewTimbre() {
        guard state != .playing else { return }
        audio.preview(settings.timbre)
    }

    // MARK: Для интерфейса

    var tempoForSlider: Int { displayBPM }

    /// Секунд до следующего повышения; nil — повышений нет (ручной режим, потолок, стоп).
    func secondsUntilRamp() -> Int? {
        guard settings.mode == .auto, state != .stopped, let scheduler,
              let deadline = scheduler.rampDeadline(plan) else { return nil }
        let now = state == .paused ? pausedAt : audio.currentLogical()
        let remaining = Double(max(0, deadline - now)) / TempoScheduler.sampleRate
        return Int(remaining.rounded(.up))
    }

    var isAtCeiling: Bool {
        settings.mode == .auto && state != .stopped && displayBPM >= settings.ceilingBPM
    }

    // MARK: Внутреннее

    private var idleBPM: Int {
        settings.mode == .auto ? (pendingAutoStartBPM ?? settings.autoStartBPM) : settings.manualBPM
    }

    private var plan: TempoPlan {
        TempoPlan(
            autoRamp: settings.mode == .auto,
            stepBPM: settings.stepBPM,
            intervalSamples: TempoScheduler.samples(minutes: settings.intervalMinutes),
            ceilingBPM: settings.ceilingBPM,
            accentEvery: settings.accentEnabled ? settings.accentEvery : nil
        )
    }

    private func setDisplay(_ bpm: Int) {
        if displayBPM != bpm { displayBPM = bpm }
    }

    private func fillQueue() {
        guard var scheduler else { return }
        let plan = plan
        while queue.count < queueDepth {
            let before = scheduler
            let beat = scheduler.next(plan)
            queue.append((beat, before))
            audio.schedule(beat, timbre: settings.timbre)
        }
        self.scheduler = scheduler
    }

    private func beatPlayed(_ beat: ScheduledBeat) {
        guard state == .playing else { return }
        queue.removeAll { $0.beat.position <= beat.position }
        setDisplay(beat.bpm)
        fillQueue()
    }

    /// Откатывает планировщик к первому удару, который ещё не начал звучать к моменту `now`,
    /// и очищает очередь. Уже прозвучавшие удары не повторяются.
    private func rewindScheduler(to now: Int64) {
        if let entry = queue.first(where: { $0.beat.position >= now }) {
            scheduler = entry.before
        }
        queue = []
        scheduler?.skip(before: now, plan: plan)
    }

    /// Перестраивает очередь с текущего момента, не меняя ритм:
    /// следующий удар остаётся на месте, новый темп — с интервала после него.
    private func flushRetime() {
        retimeWork?.cancel()
        retimeWork = nil
        guard let bpm = pendingRetimeBPM else { return }
        guard state == .playing else { pendingRetimeBPM = nil; return }
        let now = audio.currentLogical()
        // Не обрываем удар, который звучит прямо сейчас: ждём его конца.
        if let sounding = queue.first(where: { $0.beat.position <= now }),
           now - sounding.beat.position < MetronomeAudio.maxSampleLength {
            let wait = Double(MetronomeAudio.maxSampleLength - (now - sounding.beat.position)) / TempoScheduler.sampleRate
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated { self?.flushRetime() }
            }
            retimeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + wait + 0.005, execute: work)
            return
        }
        pendingRetimeBPM = nil
        rewindScheduler(to: now)
        scheduler?.retime(bpm: bpm)
        audio.begin(atLogical: now)
        fillQueue()
        audio.play()
    }

    /// Смена устройства вывода: движок перезапускается, сессия и таймер разгона сохраняются.
    private func outputDeviceChanged() {
        guard state == .playing else { return }
        let now = audio.currentLogical()
        rewindScheduler(to: now)
        audio.begin(atLogical: now)
        fillQueue()
        audio.play()
    }

    // MARK: Автоостановка на паузе

    private func scheduleAutoStop() {
        autoStopTimer?.invalidate()
        guard state == .paused, let since = pausedSince, settings.autoStopMinutes > 0 else { return }
        let fireAt = since.addingTimeInterval(TimeInterval(settings.autoStopMinutes * 60))
        let timer = Timer(fire: fireAt, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAutoStop() }
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        autoStopTimer = timer
    }

    /// Таймер не идёт во сне Mac, поэтому сверяемся с настенными часами и после пробуждения.
    private func checkAutoStop() {
        guard state == .paused, let since = pausedSince else { return }
        let limit = settings.autoStopMinutes
        if limit > 0, Date().timeIntervalSince(since) >= TimeInterval(limit * 60) {
            stop()
        } else {
            scheduleAutoStop()
        }
    }

    // MARK: Сон системы

    private func updateSleepAssertion(preventSleep: Bool? = nil) {
        let wanted = (preventSleep ?? settings.preventSleep) && state != .stopped
        if wanted, sleepAssertion == 0 {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Focus Metronome session" as CFString,
                &id
            )
            if result == kIOReturnSuccess { sleepAssertion = id }
        } else if !wanted, sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
    }
}
