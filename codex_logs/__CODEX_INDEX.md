# Codex Logs Index

This folder tracks Codex session notes for this repository.

## Entries

### Session: `SIMULATOR_LAUNCH_20260212.md` (2026-02-12)

WHAT was done:
- Implemented and verified a terminal workflow to build, install, and launch the iOS app on a named simulator.
- Updated launch behavior to explicitly open `Simulator.app` UI.
- Added session logging files in `codex_logs/`.

KEY FILES modified:
- `/Users/luisgalvez/Projects/unstoppable/scripts/run_ios_sim.sh`
- `/Users/luisgalvez/.codex/skills/ios-simulator-launch/SKILL.md`
- `/Users/luisgalvez/.codex/skills/ios-simulator-launch/agents/openai.yaml`
- `/Users/luisgalvez/.codex/skills/ios-simulator-launch/references/commands.md`

STATUS:
- Completed and verified on simulator `iPhone 17 Pro`.
- Build, install, and launch flow succeeded.

KEY DECISIONS made:
- Resolve simulator by `SIM_NAME` to UDID dynamically instead of hardcoding UDID.
- Parse `simctl` output with whitespace-tolerant matching for reliability.
- Open simulator UI explicitly (`open -a Simulator --args -CurrentDeviceUDID`) and keep it on by default.
- Add `OPEN_SIMULATOR_APP=1` env toggle for optional headless behavior.

EXECUTED COMMANDS (with CLI args):
- `xcodebuild -list -project Unstoppable.xcodeproj`
- `xcrun simctl list devices available`
- `./scripts/run_ios_sim.sh "iPhone 17 Pro"`
- `xcodebuild -project Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "id=3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" -derivedDataPath /Users/luisgalvez/Projects/unstoppable/.build build`
- `xcrun simctl install "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" /Users/luisgalvez/Projects/unstoppable/.build/Build/Products/Debug-iphonesimulator/Unstoppable.app`
- `xcrun simctl launch "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB" com.unstoppable.app`
- `open -a Simulator --args -CurrentDeviceUDID "3E11D472-4B5E-4C94-B6B0-09CDFB44EFAB"`
