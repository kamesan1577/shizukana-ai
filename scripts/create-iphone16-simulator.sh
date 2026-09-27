#!/usr/bin/env bash
set -euo pipefail
if xcrun simctl list devices available | grep -q 'Quiet-iPhone-16'; then
  exit 0
fi
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; print(next(r["identifier"] for r in json.load(sys.stdin)["runtimes"] if r["name"].startswith("iOS 27") and r["isAvailable"]))')
xcrun simctl create Quiet-iPhone-16 com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$runtime"
