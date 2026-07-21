# Phase 0 compliance audit

**Audited:** 2026-07-20
**Baseline:** `05dfdb58352bd56d5e6d3257261ee7a7d5b55f48`

This audit treats the prior workflow-foundation report as untrusted and checks the repository, GitHub remote, command behavior, and recovery references directly. Studio observations are recorded separately because they were supplied by the human owner rather than reproduced by a filesystem-only audit.

## Compliance matrix

| Requirement | State | Evidence |
| --- | --- | --- |
| Clean `main` equals `origin/main` | Verified complete | `git status --short --branch`; `git rev-parse HEAD`; `git rev-parse origin/main` |
| Recovery tag and backup branch | Verified complete | `pre-workflow-redesign-2026-07-20`; remote `backup/pre-multiplace-layout`; `git fsck --full` |
| PR #1 and merged-main CI | Verified complete | GitHub PR #1; successful Actions runs `29784925566`, `29784931828`, and `29785025968` |
| One root Rojo project | Verified complete | `default.project.json`; no tracked or local `places/Main` tree remains after closure cleanup |
| Pinned toolchain without TestEZ | Verified complete | `rokit.toml`; `wally.toml`; `wally.lock`; repository search |
| Repo-owned deterministic tests | Verified complete | `tests/run.luau`; `scripts/Test.ps1` |
| Setup and complete local gate | Verified complete | `scripts/Setup.ps1`; `scripts/Checks.ps1`; both executed successfully |
| CI/local command parity | Verified complete | `.github/workflows/ci.yml` runs `Setup.ps1` and `Checks.ps1` on Windows |
| Generated output isolation | Verified complete | `.gitignore`; generated definitions, sourcemap, and place under ignored `build/` |
| Five structurally valid skills | Verified complete | `.codex/skills/*`; each passed `quick_validate.py` |
| Studio/Rojo/MCP mapping and repeatability | Requires human evidence | See `docs/playtests/2026-07-20-phase-0-studio-checkpoint.md` |
| Phase 1 gameplay and operational skill behavior | Intentionally deferred | Requires the approved concept, frozen scenarios, ticket, implementation, and independent review |
| Phase 2 and live-game infrastructure | Intentionally deferred | Blocked by the milestone triggers in `docs/WORKFLOW.md` |

## Disposable failure probes

The following probes were run in an ignored disposable clone. Each deliberate defect was removed, the clone returned to a clean state, and the normal complete gate passed afterward.

| Probe | Expected rejecting gate | Observed result |
| --- | --- | --- |
| Spec whose case calls `assert(false)` | Lune tests | Rejected; `Test.ps1` exited nonzero |
| Syntactically malformed `.luau` file | StyLua parser/format gate | Rejected with parse error |
| Valid but unformatted `.luau` file | StyLua format gate | Rejected with formatting diff |
| Undefined global | Selene | Rejected as `undefined_variable` |
| String assigned to a strict `number` | `luau-lsp analyze` | Rejected with a type error |
| Rojo `$path` targeting a missing directory | Rojo build | Rejected with a missing-path build error |
| Staged Markdown with trailing spaces | Git whitespace gate | Initially exposed a gap; closure adds cached-diff and tracked-file scans, then rejects it |

Do not reproduce these probes in the primary worktree. Use a disposable clone, verify the expected nonzero result, remove the defect, and finish with `Setup.ps1`, `Checks.ps1`, and a clean `git status`.
