# Minimal autonomous workflow

## Ticket lifecycle

`BACKLOG -> SPEC_READY -> ACCEPTANCE_TESTS_FROZEN -> PLAN_APPROVED -> BUILDING -> STATIC_PASS -> CODE_REVIEW_PASS -> STUDIO_PASS -> HUMAN_APPROVED -> MERGED -> OBSERVING -> CLOSED`

- The human approves material product decisions, frozen scenarios, Studio results, fun, and merges.
- The planner writes behavior and slices, the builder implements one slice, and the reviewer performs an independent read-only pass.
- The builder never edits frozen acceptance scenarios. The reviewer never fixes reviewed code.
- `docs/tickets/schema.json` defines durable state. Create the first ticket only after the game concept and first-playable scenarios are approved.

## Per-slice evidence

Before Studio, require a green `Checks.ps1` run and no unresolved review blockers. For Studio or a human playtest, record the exact commit, frozen scenarios exercised, console warnings/errors, result, observations, and remaining human decisions. A video or confidence score is never the sole exit condition.

## Graybox playtest protocol

- Comprehension: can the tester restate the objective and primary action within 60 seconds without prompting?
- Tension: where do they lean in, hesitate, or react?
- Mastery: is the second attempt visibly better than the first?
- Replay intent: do they choose one more round immediately when offered?

Fix comprehension failures first because they obscure every other signal. Discard placeholder geometry, debug UI, tuning, and mechanic-specific scaffolding when evidence rejects the mechanic; keep generally useful authority, validation, state, and reset/replay logic.

## Deferred triggers

- Add a Studio playtest skill only after frozen scenarios are run manually more than twice per day and MCP play-mode has been stable for one week.
- Add persistence safeguards only after external validation and a real need for persistent progression.
- Adopt evidence manifests, a Studio lock/queue, concurrent worktrees, staging-place automation, and required PR gates only when the loop is proven, persistence is being introduced, and a published place has returning players.
- Production publishing, migrations, economy, moderation, and account permissions remain human-only.
