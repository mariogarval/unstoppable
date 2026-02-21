# iOS Simulator Launch Workflow

**Date**: 2026-02-12
**Status**: Complete
**Branch**: `main`
**Author**: Codex (GPT-5)

---

## Summary

This session implemented a terminal-based build/install/launch workflow for iOS simulator execution by simulator name and validated it on `iPhone 17 Pro`. The launcher was updated to explicitly open `Simulator.app` UI so app launch is visible, and the flow became reusable through `scripts/run_ios_sim.sh`.

---

## Problem Statement

The project needed a repeatable local command flow to launch the app on a target simulator without manual Xcode UI steps. The workflow also needed to ensure simulator UI visibility for active debugging and demos.

---

## Changes Made

### 1. Added reusable simulator launcher script

Implemented script-driven simulator workflow: resolve UDID by name, boot/wait device readiness, build app, install app, and launch app.

**Files Created/Modified**:
- `scripts/run_ios_sim.sh` - simulator name to UDID resolution, build/install/launch pipeline.

### 2. Hardened simulator device parsing

Improved parsing of `simctl` device output to tolerate spacing variations and avoid brittle matching.

**Files Created/Modified**:
- `scripts/run_ios_sim.sh` - resilient device-line parsing logic.

### 3. Forced Simulator.app UI visibility by default

Added explicit simulator app open command and a runtime toggle for optional headless behavior.

**Files Created/Modified**:
- `scripts/run_ios_sim.sh` - `open -a Simulator --args -CurrentDeviceUDID ...`.
- `scripts/run_ios_sim.sh` - `OPEN_SIMULATOR_APP` toggle (default enabled).

### 4. Verified end-to-end launch path

Executed full build/install/launch flow successfully on the `iPhone 17 Pro` simulator.

**Files Created/Modified**:
- `scripts/run_ios_sim.sh` - validation against current project scheme and simulator target.

---

## Key Results

- One command now handles simulator boot, build, install, and launch.
- Simulator UI opens automatically during launch path, reducing manual steps.
- Validation succeeded on `iPhone 17 Pro` with app bundle `com.unstoppable.app` at the time of this session.

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Resolve UDID from simulator name at runtime | Avoids brittle hardcoded simulator IDs. |
| Keep `open -a Simulator` enabled by default | Ensures visible app launch/debug experience. |
| Provide `OPEN_SIMULATOR_APP` override | Preserves optional headless/automation use cases. |

---

## Verification

```bash
xcodebuild -list -project Unstoppable.xcodeproj
xcrun simctl list devices available
./scripts/run_ios_sim.sh "iPhone 17 Pro"
xcodebuild -project Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "id=3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" -derivedDataPath /Users/luisgalvez/Projects/unstoppable/.build build
xcrun simctl install "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" /Users/luisgalvez/Projects/unstoppable/.build/Build/Products/Debug-iphonesimulator/Unstoppable.app
xcrun simctl launch "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" com.unstoppable.app
open -a Simulator --args -CurrentDeviceUDID "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB"
```

- [x] Launcher script resolves target simulator from provided name.
- [x] Build/install/launch workflow executed successfully.
- [x] Simulator UI explicitly opened to selected device.

---

## Next Steps

- Continue using `./scripts/run_ios_sim.sh "iPhone 17 Pro"` as default launch path.
- Keep script aligned with current bundle ID and scheme changes as project evolves.

---

## Related Documents

- `README.md` - local run and verification commands.
