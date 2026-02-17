# Codex Logs Index

This folder tracks Codex session notes for this repository.

## Entries

### Session: `PAYMENTS_PLAN_20260213.md` (2026-02-13)

WHAT was done:
- Created `/Users/luisgalvez/Projects/unstoppable/PAYMENTS_PLAN.md` as a reusable RevenueCat payments runbook.
- Defined phase-based execution steps (`RC-00` to `RC-52`) for setup, app integration, backend webhook handling, QA, rollout, and rollback.
- Added cross-project reuse guidance so the same flow can be applied to future apps with minimal edits.

KEY FILES modified:
- `/Users/luisgalvez/Projects/unstoppable/PAYMENTS_PLAN.md`
- `/Users/luisgalvez/Projects/unstoppable/codex_logs/PAYMENTS_PLAN_20260213.md`
- `/Users/luisgalvez/Projects/unstoppable/codex_logs/__CODEX_INDEX.md`

STATUS:
- Completed.
- New runbook is ready for implementation execution.
- Branch prepared for follow-up payment integration work.

KEY DECISIONS made:
- Use RevenueCat entitlement (`premium`) as the single source for app feature gating.
- Map authenticated app identity (`Firebase UID`) to RevenueCat `appUserID` for deterministic restore across devices.
- Require webhook authorization + idempotency to keep backend subscription state consistent.
- Include rollout guardrails (feature flag + staged release + rollback) in the base runbook, not as optional documentation.

EXECUTED COMMANDS (with CLI args):
- `git status --short`
- `git branch --show-current`
- `git checkout -b codex/payments-revenuecat-plan`
- `sed -n '1,260p' GOOGLE_AUTH_PLAN.md`
- `sed -n '1,260p' README.md`
- `rg -n "paywall|subscription|purchase|iap|revenuecat|StoreKit" Unstoppable README.md backend -S`
- `sed -n '1,260p' codex_logs/SIMULATOR_LAUNCH_20260212.md`

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
