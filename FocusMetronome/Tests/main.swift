// Проверки логики планировщика (без аудио). Запуск: ./scripts/test.sh
import Foundation

var failures = 0
func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("✗ line \(line): \(message)")
    }
}

let sr = TempoScheduler.sampleRate
func plan(auto: Bool = true, step: Int = 10, interval: Int = 30, ceiling: Int = 180, accent: Int? = nil) -> TempoPlan {
    TempoPlan(autoRamp: auto, stepBPM: step, intervalSamples: TempoScheduler.samples(minutes: interval),
              ceilingBPM: ceiling, accentEvery: accent)
}

/// Генерирует удары до позиции `end` и возвращает их.
func run(_ s: inout TempoScheduler, _ p: TempoPlan, until end: Int64) -> [ScheduledBeat] {
    var beats: [ScheduledBeat] = []
    while s.nextPosition < end { beats.append(s.next(p)) }
    return beats
}

// 1. Час авто-режима: повышения ровно на 30-й и 60-й минуте.
do {
    var s = TempoScheduler(bpm: 90)
    let p = plan()
    let beats = run(&s, p, until: TempoScheduler.samples(minutes: 61))
    var changes: [(Int64, Int)] = []
    for (a, b) in zip(beats, beats.dropFirst()) where a.bpm != b.bpm { changes.append((b.position, b.bpm)) }
    check(changes.count == 2, "ожидалось 2 повышения, получено \(changes.count)")
    if changes.count == 2 {
        let first = Double(changes[0].0) / sr, second = Double(changes[1].0) / sr
        check(changes[0].1 == 100 && changes[1].1 == 110, "темпы \(changes.map(\.1))")
        // Повышение — на первой доле не раньше дедлайна, т. е. в пределах одного интервала удара.
        check(first >= 1800 && first - 1800 < 60.0 / 90, "первое повышение на \(first) с")
        check(second >= 3600 && second - 3600 < 60.0 / 100, "второе повышение на \(second) с")
        print("повышения: \(first) с → 100 BPM, \(second) с → 110 BPM")
    }
    // Дрейф: каждый удар в пределах 0,5 семпла от идеальной позиции своего сегмента.
    var segStart = beats[0].position, k: Int64 = 0, bpm = beats[0].bpm, maxErr = 0.0
    for beat in beats {
        if beat.bpm != bpm { segStart = beat.position; k = 0; bpm = beat.bpm }
        let ideal = Double(segStart) + Double(k) * sr * 60 / Double(bpm)
        maxErr = max(maxErr, abs(Double(beat.position) - ideal))
        k += 1
    }
    check(maxErr <= 0.5, "ошибка позиции \(maxErr) семпла")
    print("макс. отклонение удара от эталона: \(maxErr / sr * 1000) мс")
}

// 2. Ручной режим: час без единого изменения темпа.
do {
    var s = TempoScheduler(bpm: 97)
    let beats = run(&s, plan(auto: false), until: TempoScheduler.samples(minutes: 60))
    check(beats.allSatisfy { $0.bpm == 97 }, "в ручном режиме темп изменился")
    check(s.rampDeadline(plan(auto: false)) == nil, "в ручном режиме есть дедлайн разгона")
}

// 3. Потолок: рост прекращается и темп держится.
do {
    var s = TempoScheduler(bpm: 170)
    let beats = run(&s, plan(interval: 1), until: TempoScheduler.samples(minutes: 5))
    check(beats.last?.bpm == 180, "потолок \(beats.last?.bpm ?? 0)")
    check(s.rampDeadline(plan(interval: 1)) == nil, "на потолке остался дедлайн")
}

// 4. Ручная правка: следующий удар на месте, таймер интервала с нуля.
do {
    var s = TempoScheduler(bpm: 90)
    let p = plan()
    _ = run(&s, p, until: TempoScheduler.samples(minutes: 20))
    let boundary = s.nextPosition
    s.retime(bpm: 120)
    check(s.nextPosition == boundary, "граница доли сдвинулась")
    check(s.rampDeadline(p) == boundary + TempoScheduler.samples(minutes: 30), "таймер интервала не перезапущен")
    let b1 = s.next(p), b2 = s.next(p)
    check(b1.position == boundary && b1.bpm == 120, "первый удар после правки")
    check(b2.position - b1.position == Int64((sr * 60 / 120).rounded()), "интервал после правки")
}

// 5. Акцент каждый 4-й удар, начиная с первого.
do {
    var s = TempoScheduler(bpm: 90)
    let beats = (0..<9).map { _ in s.next(plan(accent: 4)) }
    check(beats.map(\.isAccent) == [true, false, false, false, true, false, false, false, true], "акценты")
}

// 6. Пропуск ударов в прошлом.
do {
    var s = TempoScheduler(bpm: 60)
    s.skip(before: Int64(sr * 10) + 1, plan: plan())
    check(s.nextPosition == Int64(sr * 11), "skip: \(s.nextPosition)")
}

if failures == 0 {
    print("✓ все проверки пройдены")
} else {
    print("✗ провалено: \(failures)")
    exit(1)
}
