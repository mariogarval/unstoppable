# AGENTS_WORKFLOW.md - Agentic Development Workflow for Unstoppable

This document defines a practical multi-agent workflow for actively developing and improving the Unstoppable app without losing control of quality, scope, or verification.

Use this together with `/Users/luisgalvez/Projects/unstoppable/AGENTS.md`. If the two documents conflict, `AGENTS.md` wins.

## Goal

Run the project with one lead agent coordinating several narrowly scoped worker agents that can:

- implement targeted app or backend changes
- review work for regressions and missing coverage
- verify build, launch, and runtime behavior
- investigate backend or auth issues without blocking implementation

This workflow is intended for iterative product improvement, bug fixing, release hardening, and auth/navigation maintenance.

## Core Operating Model

### 1. Lead agent owns the session

The lead agent is responsible for:

- reading repository context before acting
- capturing baseline repo state
- making the plan for the session
- splitting work into independent tasks
- assigning narrow ownership to worker agents
- integrating returned changes and findings
- deciding when work is complete

The lead agent should not delegate vague goals such as "improve onboarding" or "fix auth."

### 2. Worker agents own bounded tasks

Each worker agent should receive:

- one concrete objective
- a defined file or module scope
- explicit constraints
- required verification steps
- a deliverable format

Each worker should be treated as a focused specialist, not a general project owner.

### 3. Verification is a separate responsibility

Implementation alone is not enough. For this repo, validation must include real iOS build and simulator launch checks before handoff when app behavior changes.

Preferred validation path:

```bash
./scripts/run_ios_sim.sh "iPhone 17 Pro"
```

Fallback build command:

```bash
xcodebuild -project /Users/luisgalvez/Projects/unstoppable/Unstoppable.xcodeproj -scheme Unstoppable -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" build
```

## Recommended Agent Roles

### Lead agent

Use for:

- planning the session
- delegating tasks
- resolving overlap between workers
- reviewing diffs before integration
- deciding next actions

Typical outputs:

- task list
- agent assignments
- integrated change set
- final status with risks and next steps

### App implementation worker

Use for:

- SwiftUI feature work
- onboarding flow fixes
- auth/session restore issues
- navigation bugs
- paywall and RevenueCat fixes

Typical scope:

- files under `/Users/luisgalvez/Projects/unstoppable/Unstoppable`

### Backend/API worker

Use for:

- API contract checks
- auth token behavior
- backend profile-completion logic
- payment snapshot issues

Typical scope:

- files under `/Users/luisgalvez/Projects/unstoppable/backend`

### Review worker

Use for:

- regression review
- edge-case analysis
- missing tests
- auth and navigation correctness review

This worker should prioritize findings over summaries.

### Verification worker

Use for:

- build checks
- simulator install/launch checks
- targeted log inspection
- reproducing user-visible bugs

This worker should report facts, not design opinions.

## Session Loop

Use this loop for each session:

1. Confirm context.
2. Capture baseline repo state.
3. Define a short plan.
4. Break work into independent tasks.
5. Delegate implementation, review, and verification in parallel where possible.
6. Integrate results.
7. Run final verification.
8. Update docs if behavior or runbooks changed.
9. Hand off with risks and remaining work.

## Session Start Checklist

At the start of a session, the lead agent should capture:

```bash
cd /Users/luisgalvez/Projects/unstoppable
git status --short
git branch --show-current
```

If the task touches auth or onboarding behavior, also review:

- `/Users/luisgalvez/Projects/unstoppable/AGENTS.md`
- `/Users/luisgalvez/Projects/unstoppable/README.md`
- `/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_PLAN.md` when Google auth behavior is involved

## Delegation Rules

### Delegate only independent tasks

Good parallelism:

- one worker changes iOS auth routing
- one worker reviews sign-out/session-restore regressions
- one worker verifies simulator behavior

Bad parallelism:

- two workers editing the same auth manager at once
- a verifier running before a buildable implementation exists

### Give explicit ownership

Each worker prompt should state:

- what to change
- which files or module area it owns
- what it must not touch
- which validations it must run

### Keep tasks small

Prefer tasks that can finish in one pass, such as:

- "Fix sign-out so it returns to `WelcomeView` instead of onboarding"
- "Add coverage for profile-complete vs incomplete restore routing"
- "Inspect `HomeView` routine sync flow for duplicate writes"

Avoid:

- "Refactor the app architecture"
- "Make onboarding better"

## Worker Prompt Template

Use a prompt shaped like this:

```text
Goal: Fix one concrete issue.
Scope: Only these files or this module area.
Context: Relevant app behavior and constraints for this repo.
Constraints:
- Preserve existing UI/UX unless explicitly asked otherwise.
- Do not revert unrelated user changes.
- Keep changes small and targeted.
Deliver:
- Summary of what changed
- Files touched
- Risks or open questions
- Verification run
```

## Lead Agent Prompt Template

For a full session, the lead agent should frame work like this:

```text
Objective: Ship one specific improvement to Unstoppable.
Baseline:
- Capture branch and worktree state.
- Read repo instructions and relevant runbooks.
Plan:
- Split into implementation, review, and verification tracks where possible.
Constraints:
- Preserve current app look-and-feel.
- Use small targeted changes.
- Do not stop at build-only verification when app behavior changes.
- Update README when auth, flow, or runbook behavior changes.
Definition of done:
- Code integrated
- Risks reviewed
- App built and launched in simulator when applicable
```

## Repo-Specific Rules for This Workflow

### Preserve the current product feel

Agents should not redesign the app unless the task explicitly requests design changes.

### Keep changes narrow

Prefer surgical fixes over large refactors unless the refactor is the actual task.

### Respect auth and navigation expectations

The workflow must preserve these behaviors:

- `Continue with Google` authenticates via Firebase and configures bearer-token API auth
- session restore happens on app launch when a valid Firebase session exists
- Settings sign-out works
- sign-out returns the user to `WelcomeView`

### Update docs when behavior changes

If auth behavior, navigation flow, or local runbook steps change, update:

- `/Users/luisgalvez/Projects/unstoppable/README.md`
- `/Users/luisgalvez/Projects/unstoppable/GOOGLE_AUTH_PLAN.md` when Google auth execution behavior changes

### Do not create agent logs unless explicitly requested

This repo only wants `agent_logs` updates when the user explicitly asks for them.

## Definition of Done

Work is done only when all applicable items are satisfied:

- baseline repo state was captured
- scope stayed within the assigned task
- unrelated user changes were preserved
- implementation was reviewed for regressions or obvious edge cases
- relevant docs were updated
- app changes were validated with simulator launch, not only build output
- remaining risks are clearly stated

## Backlog Structure for Continuous Improvement

Keep an agent-friendly backlog using small, testable items. Each item should include:

- title
- user-visible problem
- expected behavior
- likely files/modules
- verification method
- priority

Good backlog items:

- Fix session restore when backend profile is incomplete
- Prevent onboarding back-navigation loops
- Verify RevenueCat restore flow after relaunch
- Add runtime logging around bootstrap auth mode transitions
- Review `POST /v1/user/profile` calls for duplicate onboarding writes

## Example Multi-Agent Session

Example session for an auth/navigation bug:

1. Lead agent confirms branch and clean worktree.
2. Lead agent reviews `AGENTS.md`, `README.md`, and auth-related files.
3. App worker fixes restore or sign-out logic.
4. Review worker checks for regressions in onboarding and post-auth routing.
5. Verification worker runs `./scripts/run_ios_sim.sh "iPhone 17 Pro"` and checks runtime logs.
6. Lead agent integrates results, updates docs if needed, and reports remaining risks.

## When Not to Parallelize

Do not split work across multiple workers when:

- the task is a one-file fix
- the next step is blocked on a single investigation
- multiple workers would edit the same files
- the integration cost is higher than the time saved

For small tasks, one lead agent doing the work directly is usually faster and safer.
