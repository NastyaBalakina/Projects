# Focus Metronome

Метроном для концентрации в строке меню macOS. Авто-режим стартует с 90 BPM и добавляет 10 BPM
каждые 30 минут игры до 180 BPM; ручной режим держит заданный темп.

## Установка на Mac

Нужен Mac на Apple Silicon с macOS 14 Sonoma или новее и установленный Xcode
(или только Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/nastyabalakina/projects.git
cd projects/FocusMetronome
./scripts/install.sh
```

Скрипт собирает `FocusMetronome.app`, подписывает его локально (ad-hoc, «Sign to Run Locally»),
кладёт в `~/Applications` и запускает. Иконка метронома появится в строке меню; в Dock и Cmd+Tab
приложения нет.

Подпись личным Apple ID вместо ad-hoc:

```bash
SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" ./scripts/install.sh
```

Удаление: выйти из приложения (⌘Q в попапе) и удалить `~/Applications/FocusMetronome.app`.

## Управление

- Клик по иконке открывает попап; Esc или клик мимо закрывает.
- Пробел в открытом попапе — Старт / Пауза / Продолжить.
- ⌘, — настройки (вкладки «Разгон» и «Звук»), ⌘Q — выход.

## Устройство

| Файл | Что внутри |
| --- | --- |
| `Sources/TempoScheduler.swift` | Расчёт ударов в семплах от начала сессии, разгон, акцент |
| `Sources/MetronomeAudio.swift` | AVAudioEngine + AVAudioPlayerNode, `scheduleBuffer(at:)`, смена устройства |
| `Sources/MetronomeController.swift` | Состояния Остановлен / Идёт / Пауза, сон Mac, автоостановка, IOPMAssertion |
| `Sources/PopupView.swift` | Попап MenuBarExtra (.window) |
| `Sources/SettingsView.swift` | Окно настроек |
| `Sources/StatusImage.swift` | Шаблонная иконка с темпом для строки меню |
| `Sources/AppSettings.swift`, `Sources/Strings.swift` | UserDefaults и строки ru / en / es |
| `Resources/Sounds/*.wav` | 4 тембра, 44,1 кГц / 16 бит, ≤ 60 мс (генерирует `scripts/gen_sounds.py`) |

Тайминг: в очереди плеера всегда 3 ближайших удара, позиция каждого считается как
`начало сегмента + round(k × семплов на удар)`, поэтому ошибка не накапливается (≤ 0,5 семпла).
Пауза останавливает аудио-движок целиком — в покое и на паузе CPU не тратится.

Проверки логики (час разгона, ручной режим, потолок, правка темпа, акцент):

```bash
./scripts/test.sh
```
