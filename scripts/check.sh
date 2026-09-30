#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/checks
clang -c Sources/PTYBridge/PTYBridge.c -I Sources/PTYBridge/include -o .build/checks/pty.o
sources=()
for source in Sources/Lilim/*.swift; do
    [[ "$source" == "Sources/Lilim/LilimApp.swift" ]] || sources+=("$source")
done
checks=()
for check in Tests/*.swift; do
    [[ "$check" == "Tests/SandboxProbe.swift" ]] || checks+=("$check")
done
swiftc -swift-version 6 -parse-as-library -I Sources/PTYBridge/include \
    "${sources[@]}" "${checks[@]}" .build/checks/pty.o -o .build/checks/LilimChecks
.build/checks/LilimChecks
