# AGENTS.md - Unstoppable Project Guidelines

This file defines how coding agents should operate in this repository.

## Quick Start Checklist

1. Confirm location and branch:
   - `cd /Users/luisgalvez/Projects/unstoppable`
   - `git branch --show-current`
2. Capture baseline checks:
   - `git status --short`
   - `git branch --show-current`
3. Validate iOS app before handoff:
   - `xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build`
   - `./scripts/run_ios_sim.sh "iPhone 17 Pro"`

## Scope

- Repository root: `/Users/luisgalvez/Projects/unstoppable`
- App project: `/Users/luisgalvez/Projects/unstoppable/Unstoppable`
- Backend project: `/Users/luisgalvez/Projects/unstoppable/backend`

## Core Rules

- Preserve existing app look-and-feel unless explicitly asked to redesign.
- Prefer small, targeted changes and validate with real build/launch checks.
- Keep all implementation and troubleshooting steps documented.
- Do not remove or rewrite prior user changes unless explicitly requested.
- Do not stop at `xcodebuild` verification alone. After building, install and launch the latest app binary in Simulator.

## Planning and Clarifications

- Always make a plan first.
- Ask clarification questions to improve the result.
- Wait for the answers to clarification questions before starting work.

## Agent Session Logs

When using `agent-logs` skill

Scope routing for this repo:
- App scope: `/Users/luisgalvez/Projects/unstoppable/Unstoppable/agent_logs`
- Backend scope: `/Users/luisgalvez/Projects/unstoppable/backend/agent_logs`
- Repo scope (cross-cutting): `/Users/luisgalvez/Projects/unstoppable/agent_logs`

Rules:
- Choose the narrowest scope that contains the changes.
- If changes span app + backend, log under repo scope.
- Maintain `__AGENT_INDEX.md` in the chosen scope.
- Only create or update `agent_logs` files when explicitly requested by the user.

## iOS Build and Launch Workflow

Preferred simulator:
- `iPhone 17 Pro`

Execution requirement:
- Build validation must be followed by simulator install/launch in the same workflow (no build-only handoff).
- Prefer `./scripts/run_ios_sim.sh "iPhone 17 Pro"` for this because it handles build, install, and launch.

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
