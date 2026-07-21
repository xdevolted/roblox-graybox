# TCK-0002 builder attempts

Risk tier: medium. Builder budget: two complete-gate attempts.

## Attempt 1

- Status: failed; stopped at the first complete-gate stage.
- Scope: approved per-player registry, thin server adapter, bootstrap start, registry specifications, and adapter wiring specifications.
- Outcome: `scripts/Checks.ps1` stopped at the StyLua format check because the two new specification files were not formatted. No later gate ran.

## Attempt 2

- Status: failed; builder budget exhausted.
- Correction scope: apply repository formatting and address only diagnostics in the approved TCK-0002 files.
- Outcome: the StyLua format check passed, then Selene stopped the gate with two `shadowing variable self` warnings in `tests/GameLoop/PlayerRoundAdapter.spec.luau` at lines 20 and 26. No sourcemap, strict analysis, Lune test, whitespace, or Rojo build gate ran.

No third attempt was permitted until the explicit human exception recorded below.

## Exceptional attempt 3 — explicitly human-authorized

- Reason for exception: attempt 2 passed formatting but stopped at exactly two Selene `shadowing variable self` warnings in the narrow adapter signal fake.
- Permitted implementation edits: change only the two local fake connection method declarations in `tests/GameLoop/PlayerRoundAdapter.spec.luau` that produced diagnostics at the previously reported lines 20 and 26; do not change production behavior, APIs, test intent, configuration, dependencies, or scope.
- Actual warning corrections: `connection:Disconnect()` became `connection.Disconnect(_connection)`, and `connection:isConnected()` became `connection.isConnected(_connection)`. Existing colon call sites retain the same behavior.
- Files changed for the exception: `tests/GameLoop/PlayerRoundAdapter.spec.luau`, this attempt record, and `docs/tickets/TCK-0002.json` for truthful exceptional-attempt accounting. The original `attempt_budget` remains two; `attempts_used` records three.
- Complete gate outcome: failed at Luau analysis. StyLua and Selene passed with zero lint errors, warnings, or parse errors, and sourcemap generation completed. Analysis reported unknown imported `RoundLifecycle` types in `PlayerRoundRegistry`, an analyzer-resolved unknown registry require plus dependent unknown types/call/cast errors in `PlayerRoundAdapter`, and stopped the gate. Lune tests, whitespace validation, and Rojo build did not run. No further correction was authorized or made.

## Exceptional correction attempt 4 — explicitly human-authorized

- Reason for exception: exceptional attempt 3 corrected its two authorized Selene warnings, but the complete gate then exposed previously unreached Luau analysis failures in the registry and adapter.
- Initial diagnostics: unresolved `RoundLifecycle.State`/`Rejection` references in the registry; an analyzer-resolved nonexistent `ServerScriptService/shared/GameLoop/PlayerRoundRegistry` require; unresolved registry type exports throughout the adapter; and cascading registry-factory call and controller-cast failures.
- Diagnosed root causes: conditional runtime requires cannot serve as Luau exported-type namespaces; the adapter's literal Lune filesystem path was reinterpreted relative to its Rojo instance; and the optional registry factory could not narrow while its module contract was unresolved.
- Authorized code changes: in `PlayerRoundRegistry.luau`, replace module-qualified type references with narrow structural aliases matching `RoundLifecycle`'s exported state and rejection surface. In `PlayerRoundAdapter.luau`, use matching narrow registry structures, a canonical Roblox require plus computed Lune-only path behind a typed loader, and an explicitly narrowed registry factory.
- Runtime/scope confirmation: lifecycle transitions still come only from `RoundLifecycle`; public runtime methods, session-handle identity/secrecy, player isolation, generation validation, publisher injection, Player attributes, connection ordering, cleanup, and shutdown behavior are unchanged. No test, Bootstrap, dependency, configuration, scenario, or module mapping changed.
- Files changed for this exception: the two authorized production files, this attempt record, and `docs/tickets/TCK-0002.json` for truthful accounting. The original `attempt_budget` remains two; `attempts_used` records four total attempts including both explicit exceptions.
- Complete gate outcome: failed at the first gate, StyLua format check. StyLua requires the `publishSnapshot(player, handle, state)` declaration in `src/server/GameLoop/PlayerRoundAdapter.luau` to be written on one line rather than the current four-line declaration. No correction was authorized or made after the gate. Selene, sourcemap generation, Luau analysis, Lune tests, whitespace validation, and Rojo build did not run.

## Exceptional formatting attempt 5 — explicitly human-authorized

- Reason for exception: exceptional correction attempt 4 stopped at the first gate solely because StyLua required the `publishSnapshot` declaration to use its one-line form.
- Permitted implementation edit: replace only the reported five-line `publishSnapshot` declaration in `src/server/GameLoop/PlayerRoundAdapter.luau` with `local function publishSnapshot(player: any, handle: SessionHandle, state: LifecycleState?)`.
- Actual implementation edit: exactly that declaration formatting changed. SHA-256 comparison confirmed the other six preserved dirty files were byte-for-byte unchanged before exception accounting was recorded.
- Runtime/scope confirmation: formatting only; no source behavior, API, test, Bootstrap, dependency, configuration, scenario, or approved scope changed.
- Files changed for this exception: the authorized adapter declaration, this attempt record, and `docs/tickets/TCK-0002.json` for truthful accounting. The original `attempt_budget` remains two; `attempts_used` records five total attempts including three explicit exceptions.
- Complete gate outcome: failed at Luau analysis. StyLua and Selene passed with zero lint errors, warnings, or parse errors, and sourcemap generation completed. Analysis reported two unique diagnostics: `PlayerRoundRegistry.luau` line 93 returns the lifecycle rejection as broad strings that are not assignable to the narrow registry `Rejection?` union, and `PlayerRoundAdapter.luau` line 44 reports the computed Lune require as an unsupported path. The analyzer repeated those diagnostics across mapped roots. Lune tests, whitespace validation, and Rojo build did not run. No further correction was authorized or made.

## Exceptional correction session 6 — explicitly human-authorized, blocked before code change

- Human authorization: resolve only the two remaining Luau diagnostics in `PlayerRoundRegistry.luau` and `PlayerRoundAdapter.luau`, with targeted validation allowed, while prohibiting test, Bootstrap, configuration, dependency, mapping, behavior, API, or scope changes.
- Starting diagnostics: registry line 93 could not narrow the lifecycle rejection to the registry rejection union; adapter line 44 used a computed Lune require that analysis rejected as an unsupported path.
- Registry diagnosis: a local exhaustive normalization function can source-narrow the four actual `RoundLifecycle` rejection literals, preserve `nil`, and fail explicitly on an unexpected non-nil value without changing state-machine behavior.
- Adapter diagnosis: a lazy canonical Roblox require is source-correct only when Lune callers inject `registryFactory`. The adapter test helper at lines 89–95 and the startup-race construction at lines 144–147 do not inject it; only the retained-publication test does. Those unchanged tests would execute the default loader under Lune and access `game`.
- Blocking constraint: making Lune tests use the already-approved injection seam requires a narrow change to `tests/GameLoop/PlayerRoundAdapter.spec.luau`, which session 6 explicitly forbids. Every source-only fallback would retain a prohibited dynamic/computed require, add an environment-specific workaround, or duplicate the registry implementation.
- Exact code constructs changed: none in either authorized production file. The registry correction was not applied partially.
- Targeted validation: read-only inspection of the test import, helper, and all `PlayerRoundAdapter.start`/`registryFactory` call sites. No formatter, analyzer, or complete gate was run because the authorized correction could not satisfy unchanged Lune tests.
- Runtime/scope confirmation: all implementation, tests, runtime behavior, public APIs, and scope remain exactly as they were after attempt 5; only this truthful session record and schema-supported attempt accounting changed.
- Complete gate outcome: not run. A new human decision is required to authorize the minimal test-seam injection change together with the two production corrections.

## Exceptional correction session 7 - explicitly human-authorized

- Reason for exception: session 6 established that the remaining registry and adapter analysis corrections also required the already-approved registry-factory seam to be supplied by every Lune adapter construction.
- Starting state: branch `feature/tck-0002-server-round-adapter` at base HEAD `8610a19b1d80c0287adcab90565182558969128b`; ticket state `BUILDING`; original attempt budget two; six attempts used; zero implementation commits and zero implementation PRs; exactly the same seven TCK-0002 files remained dirty.
- Permitted production edits: exhaustively normalize only the four documented `RoundLifecycle` rejection literals (and `nil`) inside `PlayerRoundRegistry.luau`; replace the adapter's computed Lune require with a lazy canonical Roblox Instance require used only by the default registry factory in `PlayerRoundAdapter.luau`.
- Permitted test edits: inject `PlayerRoundRegistry.new` only in the shared adapter-construction helper and the startup connect/enumeration-race construction in `PlayerRoundAdapter.spec.luau`; retain the existing injection in the retained-publication case.
- Actual code edits: added the exhaustive local rejection normalizer and a narrow local result annotation; moved the canonical `ReplicatedStorage.Shared.GameLoop.PlayerRoundRegistry` require into the default registry factory and removed the computed filesystem loader; added the two authorized real-registry factory injections.
- Files changed for the exception: `src/shared/GameLoop/PlayerRoundRegistry.luau`, `src/server/GameLoop/PlayerRoundAdapter.luau`, `tests/GameLoop/PlayerRoundAdapter.spec.luau`, this attempt record, and `docs/tickets/TCK-0002.json` for truthful accounting. The preserved dirty contents of `src/server/Bootstrap.server.luau` and `tests/GameLoop/PlayerRoundRegistry.spec.luau` were not modified during this session.
- Targeted validation: StyLua completed successfully against only the three authorized code files. The first targeted Luau analysis reported one unique rejection-return narrowing diagnostic at `PlayerRoundRegistry.luau:113`, repeated across mapped roots; adding the narrow local annotation within the authorized normalization fixed it. Repeated targeted analysis then completed with no diagnostics.
- Runtime/scope confirmation: lifecycle transition behavior remains delegated to `RoundLifecycle`; the public runtime API, authority boundary, session handles, player isolation, generation checks, publication behavior, Bootstrap content, registry specifications, dependencies, configuration, Rojo mappings, frozen scenarios, and approved scope are unchanged.
- Complete gate outcome: passed. StyLua passed; Selene reported 0 errors, 0 warnings, and 0 parse errors; sourcemap generation completed; Luau analysis completed with no diagnostics; all Lune suites passed with 40 tests passed and 0 failed; unstaged, staged, and tracked-file whitespace validation passed; and Rojo built `RobloxGraybox.rbxlx` successfully.
