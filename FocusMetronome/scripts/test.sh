#!/bin/bash
# Проверки логики планировщика: темп, разгон, дрейф. Не требует аудио.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
SWIFTC="swiftc"
command -v xcrun >/dev/null && SWIFTC="xcrun swiftc"
$SWIFTC -O Sources/TempoScheduler.swift Tests/main.swift -o build/scheduler-tests
./build/scheduler-tests
