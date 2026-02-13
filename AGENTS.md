# AGENTS.md - Unstoppable Project Guidelines

This file defines how coding agents should operate in this repository.

## Quick Start Checklist

1. Confirm location and branch:
   - `cd /Users/luisgalvez/Projects/unstoppable`
   - `git branch --show-current`
2. Start a new local action log:
   - `source /Users/luisgalvez/.codex/skills/actions-log-local/scripts/actions_log.sh`
3. Log the first baseline checks:
   - `action_step QS-01 git status --short`
   - `action_step QS-02 git branch --show-current`
4. For each meaningful command, use:
   - `action_step <STEP-ID> <command with args>`
5. For each manual/UI action or decision, use:
   - `action_note "[STEP-ID] message"`
6. Validate iOS app before handoff:
   - `xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
   - `./scripts/run_ios_sim.sh "iPhone 17 Pro"`
7. Update project memory docs:
   - Add or update session file under the correct `codex_logs` folder.
   - Update matching `__CODEX_INDEX.md` entry.

## Scope

- Repository root: `/Users/luisgalvez/Projects/unstoppable`
- App project: `/Users/luisgalvez/Projects/unstoppable/Unstoppable`
- Backend project: `/Users/luisgalvez/Projects/unstoppable/backend`

## Core Rules

- Preserve existing app look-and-feel unless explicitly asked to redesign.
- Prefer small, targeted changes and validate with real build/launch checks.
- Keep all implementation and troubleshooting steps documented.
- Do not remove or rewrite prior user changes unless explicitly requested.

## Required Session Logging

For implementation sessions, keep a command/action log in:
- `/Users/luisgalvez/Projects/unstoppable/_actions_log`

Use the local helper:

```bash
source /Users/luisgalvez/.codex/skills/actions-log-local/scripts/actions_log.sh
```

Then log each step:

```bash
action_step STEP-ID <command with args>
action_note "[STEP-ID] manual action / decision / result"
```

Rules:
- Log commands with args and full output.
- Log manual console/UI actions with `action_note`.
- Create a new log file per session.
- Keep `_actions_log` local-only; do not commit it.

## Codex Session Notes (Repository Memory)

Maintain codex session notes and index files:

- App-level notes: `/Users/luisgalvez/Projects/unstoppable/Unstoppable/codex_logs`
- Backend notes: `/Users/luisgalvez/Projects/unstoppable/backend/codex_logs`
- Repo-level notes (if cross-cutting): `/Users/luisgalvez/Projects/unstoppable/codex_logs`

When adding a new session note:
- Create a dated markdown session file.
- Update the corresponding `__CODEX_INDEX.md`.
- Include:
  - WHAT was done
  - KEY FILES modified
  - STATUS
  - KEY DECISIONS made
  - EXECUTED COMMANDS (with CLI args)

## iOS Build and Launch Workflow

Preferred simulator:
- `iPhone 17 Pro`

Preferred launch path:

```bash
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

Fallback/validation build command:

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

## Google Auth Workflow

Primary plan doc:
- `/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_PLAN.md`

Execution standard:
- Use GA step IDs.
- Record each command/action and output.
- Record troubleshooting history and final resolutions.
- Keep plan document updated with completed steps and pending items.

Manual Firebase Console actions (example: provider enablement) must be logged as explicit `ACTION` entries.

## Auth + Navigation Expectations

- `Continue with Google` must authenticate via Firebase and configure API bearer token mode.
- Session restore should happen on app launch when valid Firebase session exists.
- Settings must provide functional sign-out.
- Sign-out must return user to `WelcomeView` (not onboarding/paywall).

## README Maintenance

When auth, flow, or runbook behavior changes:
- Update `/Users/luisgalvez/Projects/unstoppable/README.md`.
- Keep backend URL, auth behavior, and testing commands current.
- Keep local logging instructions accurate.
