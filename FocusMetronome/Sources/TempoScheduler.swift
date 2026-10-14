import Foundation

/// Параметры разгона, читаются из настроек при расчёте каждого удара.
struct TempoPlan: Equatable {
    var autoRamp: Bool
    var stepBPM: Int
    var intervalSamples: Int64
    var ceilingBPM: Int
    /// nil — акцент выключен, иначе акцентируется каждый N-й удар.
    var accentEvery: Int?
}

struct ScheduledBeat: Equatable {
    /// Позиция удара от начала сессии, в семплах (44,1 кГц). Время паузы не входит.
    let position: Int64
    let bpm: Int
    let isAccent: Bool
}

/// Чистая логика расчёта ударов, без аудио и таймеров.
///
/// Каждый удар считается от начала текущего сегмента постоянного темпа:
/// `segmentStart + round(k * samplesPerBeat)`. Интервалы не складываются,
/// поэтому ошибка округления не накапливается (≤ 0,5 семпла на удар).
struct TempoScheduler: Equatable {
    static let sampleRate: Double = 44_100

    private(set) var bpm: Int
    /// Позиция нулевого удара текущего сегмента.
    private(set) var segmentStart: Int64
    /// Номер следующего удара внутри сегмента.
    private(set) var beatInSegment: Int64 = 0
    /// Точка отсчёта таймера интервала повышения.
    private(set) var rampAnchor: Int64
    /// Сколько ударов уже выдано с начала сессии (для акцента).
    private(set) var beatCount: Int64 = 0

    init(bpm: Int, start: Int64 = 0) {
        self.bpm = bpm
        self.segmentStart = start
        self.rampAnchor = start
    }

    static func samplesPerBeat(_ bpm: Int) -> Double {
        sampleRate * 60 / Double(bpm)
    }

    static func samples(minutes: Int) -> Int64 {
        Int64(minutes) * 60 * Int64(sampleRate)
    }

    var nextPosition: Int64 {
        segmentStart + Int64((Double(beatInSegment) * Self.samplesPerBeat(bpm)).rounded())
    }

    /// Момент следующего повышения или nil, если разгона нет (ручной режим или потолок).
    func rampDeadline(_ plan: TempoPlan) -> Int64? {
        guard plan.autoRamp, plan.stepBPM > 0, bpm < plan.ceilingBPM else { return nil }
        return rampAnchor + plan.intervalSamples
    }

    /// Выдаёт следующий удар. Повышение темпа срабатывает на первой границе доли,
    /// попавшей на дедлайн или позже: этот удар — начало нового сегмента.
    mutating func next(_ plan: TempoPlan) -> ScheduledBeat {
        let position = nextPosition
        if let deadline = rampDeadline(plan), position >= deadline {
            bpm = min(bpm + plan.stepBPM, plan.ceilingBPM)
            segmentStart = position
            beatInSegment = 0
            // Следующий дедлайн отсчитывается от предыдущего, а не от удара:
            // повышения ложатся ровно на 30-ю, 60-ю… минуту.
            // Если интервал в настройках сократили и дедлайн давно прошёл — отсчёт от текущего удара.
            rampAnchor = position - deadline < plan.intervalSamples ? deadline : position
        }
        let accent: Bool
        if let n = plan.accentEvery, n > 1 {
            accent = beatCount % Int64(n) == 0
        } else {
            accent = false
        }
        beatInSegment += 1
        beatCount += 1
        return ScheduledBeat(position: position, bpm: bpm, isAccent: accent)
    }

    /// Ручная правка темпа: следующий удар остаётся на месте, интервалы после него — новые,
    /// таймер интервала запускается заново от этой границы доли.
    mutating func retime(bpm newBPM: Int) {
        let boundary = nextPosition
        bpm = newBPM
        segmentStart = boundary
        beatInSegment = 0
        rampAnchor = boundary
    }

    /// Пропускает удары, которые уже в прошлом (например, после долгой задержки главного потока).
    mutating func skip(before position: Int64, plan: TempoPlan) {
        while nextPosition < position {
            _ = next(plan)
        }
    }
}
