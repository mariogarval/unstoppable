## Feature Session

Use this for a contained feature or enhancement.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent.

Goal:
Implement a cleaner paywall purchase flow for local debug testing in Simulator.

Problem statement:
When the app is running in `DEBUG` and using the RevenueCat test public SDK key (`test_...`), continuing from the paywall shows an extra floating purchase-status menu / debug-style overlay during purchase or subscription attempts. That flow feels noisy and unlike the Apple subscription flow we expect in real-world testing.

We already have separate RevenueCat keys by environment:
- `DEBUG` / Simulator uses the RevenueCat test public SDK key.
- Release / TestFlight / real-device distribution uses the live Apple public SDK key.

The goal is to improve the Simulator + debug paywall flow so it feels closer to the real Apple purchase experience, while preserving the correct production/TestFlight behavior.

Expected outcome:
- Investigate exactly what is causing the floating purchase-status UI in the current debug/simulator flow.
- Reduce or remove that extra debug-style surface if possible.
- Keep purchase, restore, entitlement refresh, and onboarding completion behavior working.
- Do not break the live RevenueCat + Apple purchase flow used in TestFlight or release builds.

Scope:
- `Unstoppable/onboarding/PaywallView.swift`
- `Unstoppable/Payments/RevenueCatManager.swift`
- RevenueCat config wiring under `Unstoppable/Config/`
- Any StoreKit / RevenueCat environment setup needed for Simulator-only behavior
- `README.md` if local paywall testing steps or environment behavior change

Constraints:
- Capture baseline repo state first.
- Make a short implementation plan before editing.
- Split work into independent tasks where possible.
- Preserve existing product feel unless a redesign is explicitly requested.
- Keep code changes targeted and consistent with existing patterns.
- Prefer environment-aware behavior instead of hardcoding simulator-only hacks into the main purchase flow.
- Keep TestFlight / release purchase behavior unchanged unless a fix clearly applies there too.
- Update README if app behavior, payments behavior, or local test workflow changes.
- Run simulator validation for app-facing changes.

Investigation requirements:
- Identify whether the floating UI is coming from RevenueCat debug behavior, StoreKit test-session behavior, Apple system purchase UI, or another in-app overlay.
- Verify which code path is used in Simulator versus TestFlight.
- Document the chosen approach in the implementation summary.

Acceptance criteria:
- In local Simulator debug testing, the paywall purchase flow is cleaner and closer to the production Apple purchase experience.
- The app still handles successful purchase, cancelled purchase, failed purchase, and restore paths cleanly.
- `Continue with Free Version` still works.
- Successful purchase or restore still unlocks premium and completes paywall selection correctly.
- No regression in onboarding navigation after purchase/restore.

Deliver:
- implementation summary
- root cause of the floating purchase-status UI
- files touched
- verification results
- known follow-ups or limitations, especially if Apple/StoreKit imposes an unavoidable Simulator-only behavior
```
