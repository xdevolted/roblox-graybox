# ADR 0001: Minimal-loop workflow

**Status:** Accepted on 2026-07-20

## Decision

Use trunk-based `main` with short-lived `feature/*` branches, one root Rojo project, engine-free tests under pinned Lune, and three active roles: Spec/Planner, Builder, and independent Reviewer. The human drives Studio and judges fun.

Keep Rojo, Wally, Rokit, StyLua, Selene, and luau-lsp. Defer multi-place structure, persistence, unattended Studio automation, evidence manifests, publishing automation, and specialized risk agents until the triggers in `docs/WORKFLOW.md` are met.

## Consequences

The prototype favors short feedback loops and low cognitive overhead over early auditability and parallelism. Reintroduce heavier controls before persistent data or a live returning audience creates material risk.
