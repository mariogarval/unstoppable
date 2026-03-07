# START_AGENT_SESSION.md - Copy-Paste Prompts for Agent Sessions

Use this file to start agent-driven development sessions for the Unstoppable repo.

Primary repo instructions:

- `/Users/luisgalvez/Projects/unstoppable/AGENTS.md`
- `/Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md`

Use prompts from this file at the start of a session. Replace bracketed placeholders before sending.

## General Rule

Always give the lead agent:

- one concrete goal
- the repo workflow files to follow
- permission to delegate bounded tasks
- a requirement to verify app behavior when code changes affect the iOS app

Avoid vague goals such as:

- "improve the app"
- "make onboarding better"
- "fix auth"

Prefer goals such as:

- "Fix sign-out so it always returns to WelcomeView"
- "Review Google sign-in restore and fix incomplete-profile routing"
- "Harden RevenueCat restore handling after relaunch"

## Default Lead-Agent Starter

Use this when you want the agent to decide the best small plan for one goal.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent for the Unstoppable repo.

Goal: Fix the routines and routines done stats to store and show the data for the current user, currently whicherver user sees the same stats.

Requirements:
- Capture baseline repo state first.
- Make a short plan.
- Delegate independent implementation, review, and verification tasks when useful.
- Keep changes small and targeted.
- Preserve the current app look-and-feel unless the task explicitly asks for design changes.
- Do not revert unrelated user changes.
- If auth, navigation, or runbook behavior changes, update the relevant docs.
- If the iOS app behavior changes, validate with the required simulator workflow before handoff.

Deliver:
- implemented changes
- key review findings or risks
- verification results
- any remaining follow-up work
```

## Bug Fix Session

Use this for a user-visible defect with a known symptom.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent.

Goal: Fix this bug: When resetting local profile, even if the user logged in with Google or Apple, the streaks get reset too.

Expected behavior:
Streaks should be reset just for local guest that hasn't signed in. If user is signed in, the streaks should be hydrated from the API, so when the user logs out and logs in again, it can keep it's streks.

Constraints:
- Start by capturing git status and current branch.
- Inspect the smallest relevant area first.
- Delegate review and verification tasks in parallel if that reduces risk.
- Keep the fix surgical.
- Do not redesign the UI.
- Do not stop at build-only validation if the bug affects app behavior.

Deliver:
- root cause
- fix
- files touched
- verification run
- remaining edge cases or risks
```

## Feature Session

Use this for a contained feature or enhancement.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent.

Goal: Implement this feature: [feature description]

Scope:
[modules, screens, or endpoints involved]

Constraints:
- Capture baseline repo state first.
- Make a short implementation plan before editing.
- Split work into independent tasks where possible.
- Preserve existing product feel unless a redesign is explicitly requested.
- Keep code changes targeted and consistent with existing patterns.
- Update README if app behavior, auth behavior, or runbook steps change.
- Run simulator validation for app-facing changes.

Deliver:
- implementation summary
- files touched
- verification results
- known follow-ups
```

## Auth Or Navigation Debug Session

Use this when the issue touches Firebase auth, Google sign-in, session restore, onboarding routing, or sign-out behavior.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md, /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md, /Users/luisgalvez/Projects/unstoppable/README.md, and /Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_PLAN.md and follow them for this session.

Act as the lead agent.

Goal: Investigate and fix this auth/navigation issue: [issue description]

Requirements:
- Capture baseline repo state first.
- Review the relevant auth and routing files before editing.
- Use worker agents for implementation, regression review, and verification when useful.
- Preserve these expectations:
  Continue with Google authenticates with Firebase and configures bearer token mode.
  Session restore happens on app launch when a valid Firebase session exists.
  Settings sign-out works.
  Sign-out returns the user to WelcomeView.
- Update README and GOOGLE_AUTH_PLAN.md if behavior or runbook steps change.
- Validate with the simulator workflow before handoff.

Deliver:
- root cause
- behavior before and after the fix
- files touched
- verification results
- any unresolved risk
```

## Code Review Session

Use this when you want the agent to review existing changes rather than implement new work first.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Review the current changes in this repo.

Review focus:
- bugs
- regressions
- auth/navigation edge cases
- missing tests
- risky assumptions

Instructions:
- Findings first, ordered by severity.
- Include concrete file references.
- Keep summaries brief.
- Mention residual testing gaps if no findings are found.
```

## Release Hardening Session

Use this before a TestFlight push or other release-oriented checkpoint.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent.

Goal: Harden the app for release readiness around this area: [area]

Focus:
- user-visible bugs
- auth/session restore stability
- onboarding completion flow
- sign-out behavior
- paywall and restore behavior
- build and launch reliability

Requirements:
- Capture baseline repo state first.
- Make a short prioritized plan.
- Use worker agents for targeted review and verification.
- Prefer small fixes over broad refactors.
- Run the required simulator validation before handoff.
- Update docs if runtime behavior or runbook steps changed.

Deliver:
- issues fixed
- issues found but not fixed
- verification results
- recommended next release-blocking actions
```

## Weekly Improvement Session

Use this when you want the agent to pull one high-value improvement instead of working from a single bug report.

```text
Read /Users/luisgalvez/Projects/unstoppable/AGENTS.md and /Users/luisgalvez/Projects/unstoppable/AGENTS_WORKFLOW.md and follow them for this session.

Act as the lead agent.

Goal: Pick and complete one high-value, low-risk improvement for the Unstoppable app.

Instructions:
- Start by reviewing the current repo state and the most likely high-risk areas.
- Choose one bounded improvement only.
- Explain why you picked it.
- Use worker agents if parallel review or verification will help.
- Keep the change small enough to verify thoroughly in one session.
- Validate with the simulator workflow before handoff if app behavior changes.

Deliver:
- chosen improvement
- rationale
- changes made
- verification results
- next best candidate after this one
```

## How To Use These Prompts

1. Pick the closest session type.
2. Replace bracketed placeholders with the actual goal.
3. Send the prompt from the repo root context.
4. If the result is too broad, narrow the goal and rerun.

## Good Goals

- Fix Google sign-in callback failure after app relaunch
- Ensure sign-out always routes back to `WelcomeView`
- Review onboarding back navigation for loops and fix the root cause
- Verify RevenueCat restore behavior after fresh login

## Bad Goals

- Improve the whole app
- Refactor everything messy
- Make auth more robust somehow
- Clean up onboarding
