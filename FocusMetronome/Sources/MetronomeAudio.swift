import AVFoundation

/// Аудио-движок: удары планируются на часах AVAudioPlayerNode, а не системным таймером.
///
/// Вся сессия живёт в «логическом» времени — семплы 44,1 кГц от начала сессии без пауз.
/// Время плеера обнуляется при каждом перезапуске (пауза, правка темпа, смена устройства),
/// поэтому храним `baseOffset`: логическая позиция, соответствующая нулю плеера.
/// Все методы вызываются только с главного потока.
final class MetronomeAudio {
    struct Sample {
        let normal: AVAudioPCMBuffer
        let accent: AVAudioPCMBuffer
    }

    static let sampleRate = TempoScheduler.sampleRate
    /// Длительность самого длинного семпла, в семплах (60 мс).
    static let maxSampleLength: Int64 = 2_646

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let previewPlayer = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var samples: [Timbre: Sample] = [:]

    private var generation = 0
    private var baseOffset: Int64 = 0
    private var playStartHost: UInt64 = 0
    private(set) var isSessionActive = false
    private var engineStopWork: DispatchWorkItem?
    private var configObserver: NSObjectProtocol?

    /// Удар доигран (вызывается на главном потоке).
    var onBeatPlayed: ((ScheduledBeat) -> Void)?
    /// Сменилось устройство вывода, движок остановлен системой.
    var onConfigurationChange: (() -> Void)?

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        for timbre in Timbre.allCases {
            if let sample = Self.loadSample(timbre, format: format) {
                samples[timbre] = sample
            }
        }
        engine.attach(player)
        engine.attach(previewPlayer)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(previewPlayer, to: engine.mainMixerNode, format: format)

        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    var volume: Float = 0.5 {
        didSet {
            player.volume = volume
            previewPlayer.volume = volume
        }
    }

    // MARK: Сессия

    /// Начинает новую временную шкалу плеера с логической позиции `logical`.
    /// После вызова нужно запланировать удары и вызвать `play()`.
    func begin(atLogical logical: Int64) {
        engineStopWork?.cancel()
        generation += 1
        player.stop()
        baseOffset = logical
        isSessionActive = true
        startEngineIfNeeded()
    }

    func schedule(_ beat: ScheduledBeat, timbre: Timbre) {
        guard let sample = samples[timbre] ?? samples[.click] else { return }
        let buffer = beat.isAccent ? sample.accent : sample.normal
        let playerSample = max(0, beat.position - baseOffset)
        let time = AVAudioTime(sampleTime: AVAudioFramePosition(playerSample), atRate: Self.sampleRate)
        let gen = generation
        player.scheduleBuffer(buffer, at: time, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                self.onBeatPlayed?(beat)
            }
        }
    }

    func play() {
        guard engine.isRunning else { return }
        player.play()
        playStartHost = mach_absolute_time()
    }

    /// Полностью глушит сессию и останавливает движок: в покое и на паузе CPU = 0.
    func halt() {
        generation += 1
        player.stop()
        isSessionActive = false
        engine.stop()
    }

    /// Текущая логическая позиция воспроизведения в семплах.
    func currentLogical() -> Int64 {
        if engine.isRunning,
           let nodeTime = player.lastRenderTime,
           nodeTime.isSampleTimeValid,
           let playerTime = player.playerTime(forNodeTime: nodeTime),
           playerTime.isSampleTimeValid {
            return baseOffset + max(0, Int64(playerTime.sampleTime))
        }
        // Запасной путь (движок уже остановлен системой): по хост-часам от момента play().
        guard playStartHost != 0 else { return baseOffset }
        let elapsed = AVAudioTime.seconds(forHostTime: mach_absolute_time())
            - AVAudioTime.seconds(forHostTime: playStartHost)
        return baseOffset + Int64(max(0, elapsed) * Self.sampleRate)
    }

    // MARK: Предпрослушивание

    /// Один удар выбранным тембром. Вне сессии движок поднимается на полсекунды.
    func preview(_ timbre: Timbre) {
        guard let sample = samples[timbre] else { return }
        engineStopWork?.cancel()
        startEngineIfNeeded()
        guard engine.isRunning else { return }
        previewPlayer.stop()
        previewPlayer.scheduleBuffer(sample.normal, at: nil, options: [])
        previewPlayer.play()
        if !isSessionActive {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.isSessionActive else { return }
                self.previewPlayer.stop()
                self.engine.stop()
            }
            engineStopWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    // MARK: Внутреннее

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        player.volume = volume
        previewPlayer.volume = volume
        engine.prepare()
        do {
            try engine.start()
        } catch {
            NSLog("FocusMetronome: audio engine start failed: \(error.localizedDescription)")
        }
    }

    private func handleConfigurationChange() {
        // Наушники, внешний интерфейс, Bluetooth: система остановила движок.
        // Подключаем микшер к новому выходу; сессию перезапускает контроллер.
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        if isSessionActive {
            onConfigurationChange?()
        }
    }

    private static func loadSample(_ timbre: Timbre, format: AVAudioFormat) -> Sample? {
        guard let url = Bundle.main.url(forResource: timbre.fileName, withExtension: "wav"),
              let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false),
              let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: source)) != nil,
              let input = source.floatChannelData?[0]
        else {
            NSLog("FocusMetronome: missing sound \(timbre.fileName).wav")
            return nil
        }
        let count = Int(source.frameLength)
        let mono = Array(UnsafeBufferPointer(start: input, count: count))

        // Обычный удар — как в файле.
        guard let normal = makeBuffer(mono, format: format) else { return nil }

        // Акцент: на квинту выше (ускоренное чтение ×1,5) и громче.
        let ratio = 1.5
        let gain: Float = 1.8
        let accentCount = Int(Double(count) / ratio)
        var accent = [Float](repeating: 0, count: accentCount)
        for i in 0..<accentCount {
            let src = Double(i) * ratio
            let j = Int(src)
            let frac = Float(src - Double(j))
            let a = mono[min(j, count - 1)]
            let b = mono[min(j + 1, count - 1)]
            accent[i] = max(-1, min(1, (a + (b - a) * frac) * gain))
        }
        guard let accentBuffer = makeBuffer(accent, format: format) else { return nil }
        return Sample(normal: normal, accent: accentBuffer)
    }

    private static func makeBuffer(_ data: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count)),
              let out = buffer.floatChannelData?[0] else { return nil }
        data.withUnsafeBufferPointer { src in
            out.update(from: src.baseAddress!, count: data.count)
        }
        buffer.frameLength = AVAudioFrameCount(data.count)
        return buffer
    }
}
