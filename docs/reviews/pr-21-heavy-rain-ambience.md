# PR #21 independent gameplay review

**Review type:** Independent initial review

**Reviewed range:** `main...origin/feature/tck-0008-heavy-rain-ambience`

**Base commit:** `3e1b526f0ccc00a8782aed1bae41c0b5b45b7cda`

**Reviewed head:** `e5008368f4f469f4c190575f006d32d1a18a3d1f`

**Contracts:** Approved cosmetic-rain and heavy-rain ambience specifications,
frozen RAIN-01 through RAIN-08 and HRA-01 through HRA-08 scenarios, both approved
slice plans, `AGENTS.md`, and `docs/WORKFLOW.md`

## Findings

- BLOCKER: 1
- MAJOR: 2
- MINOR: 0
- NIT: 0

### BLOCKER — TCK-0008 was built before TCK-0007 merged to authoritative `main`

The heavy-rain plan's dependency gate requires TCK-0007 to complete review, Studio
validation, human approval, and merge to `main` before TCK-0008 receives a ticket or
implementation branch. It also requires the TCK-0008 branch to begin from that updated
authoritative `main`.

Git contradicts the branch records. Both local and remote `main` resolve to `3e1b526`,
which is also this PR's merge base. TCK-0007 commits `605123a` and `31774d4`, followed
by the documentation-only `49a1b9c` state transition, exist only in PR #21's linear
feature-branch ancestry. No TCK-0007 pull request exists, yet
`docs/tickets/TCK-0007.json` records `MERGED` and the TCK-0008 builder record calls
`49a1b9c` authoritative `main`.

The result is a 19-file PR containing both TCK-0007 and TCK-0008. This violates
`AGENTS.md`'s requirement to work on one small behavioral slice from `main`,
`docs/WORKFLOW.md`'s one-slice builder boundary, and the approved TCK-0008 dependency
gate. It also causes the full PR to change `Bootstrap.client.luau`, which the TCK-0008
plan explicitly prohibits because bootstrap was supposed to arrive through the already
merged TCK-0007 baseline.

Land TCK-0007 as its own reviewed change first. Then base TCK-0008 on the resulting
authoritative `main`, correct the provenance/state records, and re-run the exact-head
gate and review. Do not merge the stacked history as-is.

### MAJOR — TCK-0008 claims human approval that the recorded evidence reserves

`docs/playtests/2026-08-25-tck-0008-studio-checkpoint.md` records an owner-approved
`STUDIO_PASS` and explicitly says human approval and merge remain separate decisions.
The subsequent `e500836` commit changes `docs/tickets/TCK-0008.json` from
`STUDIO_PASS` to `HUMAN_APPROVED` and clears the pending human decision without
recording a separate approval. The owner's current request to decide whether to merge
confirms that decision was still pending. Restore the truthful lifecycle state until
the owner makes the merge decision after the corrected review.

### MAJOR — Partial sound cleanup is not guaranteed for construction failures

The heavy-rain plan requires any partially created sound to be destroyed when sound
construction or `Play()` fails. In
`src/client/Prototype/RainController.luau:106`, the production factory creates and
configures the `Sound`, including parenting it, before the protected `Play()` call.
The outer factory `pcall` catches a construction/configuration/parenting error but has
no handle with which to destroy the partial object.

HRC-06 does not exercise this production cleanup path. Its fake factory increments
`partialSoundDestroyCount` itself before throwing, so the assertion proves only the
fake's bookkeeping. Protect the complete production construction/configuration/play
sequence with cleanup that retains the partial handle, and add a deterministic case
for failure after partial construction or parenting.

## Standards

Two hard standards findings remain: the stacked TCK-0007/TCK-0008 history violates
the repository's one-slice and authoritative-main rules, and the resulting PR exceeds
TCK-0008's approved file boundary. No separate baseline code smell was material; the
controller seams and visual/audio ownership are explicitly required by the approved
plan.

## Spec

The dependency gate, truthful lifecycle state, and partial-sound cleanup requirements
are not met. Apart from those findings, the implementation matches the frozen
player-facing contract: two finite-positioned client-local rain layers, one looped
nonspatial `SoundService` ambience at asset `1516791621` and volume `0.35`, singleton
start, retained-callback protection, restart cleanup, and no gameplay-authority path.

## Assumptions and check result

- Git and the filesystem were treated as authoritative. The PR body is empty, PR #21
  has no human GitHub review, and GitHub still reports review required.
- `scripts/Checks.ps1` was run locally at exact PR head `e500836` in detached mode
  while preserving the owner's unrelated edits. Formatting, Selene linting, sourcemap
  generation, strict Luau analysis, all 142 Lune cases, unstaged/staged/tracked
  whitespace validation, and Rojo build passed.
- GitHub reports three passing checks and zero failures for PR #21.
- The recorded TCK-0007 and TCK-0008 Studio checkpoints provide human-reported visual,
  audio, replay, late-join, readability, quality, and performance evidence at exact
  implementation commits, with their stated lack of automated transcripts and numeric
  frame-time capture.
- No server/shared gameplay code, remote, Player attribute writer, damage, reward,
  persistence, economy, dependency, framework, or project-map change is present.
- The owner's pre-existing `.gitignore`, `README.md`, `.axi/`, and `tests/playtests/`
  work remained unchanged. Generated ignored `build/` output was permitted by the
  static-gate procedure.

## Disposition

**Blocked as-is.** Separate and land TCK-0007 first, rebase/rebuild TCK-0008 on the
actual updated `main`, correct the ticket/provenance records, and fix/test partial sound
cleanup before re-review. The rain behavior itself otherwise appears ready for human
validation after those corrections.
