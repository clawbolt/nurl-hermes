---
date: 2026-05-26
topic: structural-hardening
status: defined
---

# Structural Hardening — Six-Phase Improvement Plan

## Problem Frame

nurl-hermes is a 15.5k-line NURL rewrite of the Hermes Agent runtime. The architecture is sound for its current scope, but six structural carrying costs will increasingly slow development as the codebase grows: no test framework, a monolithic tool file, provider path duplication, hand-rolled config parsing, explicit RFC 1918 enumeration, and pervasive env-variable state coupling. These are not independent — the test framework is a prerequisite for safe refactoring, and env coupling complicates every other change. A phased sequence respects these dependencies.

## Requirements

### Phase 1: RFC 1918 Range Check

- R1.1. Replace the 16-line explicit `172.16`–`172.31` prefix check in `http_host_private_or_metadata` with a numeric range check against `172.16.0.0/12`.
- R1.2. All existing private-host detection behavior must be preserved exactly — no new hosts accepted, no existing hosts dropped.
- R1.3. The IPv6 unique-local (`fc`/`fd`) and link-local (`fe80`) checks remain as-is.

### Phase 2: Test Framework

- R2.1. Introduce a minimal test runner convention that can be invoked from the existing `selftest` command and from shell scripts (dogfood, readiness gates).
- R2.2. Each test case reports pass/fail with a stable name. A failed test produces a short diagnostic line.
- R2.3. Test output is machine-parseable (one line per test, name + result) so CI and shell gates can consume it.
- R2.4. The existing monolithic selftest is decomposed into individually named test cases using the new convention.
- R2.5. New tests can be added without modifying a central registry — discovery is file-based or naming-convention-based.
- R2.6. Tests run in-process (no subprocess spawn per test) to keep the suite fast.

### Phase 3: Config Parser Hardening

- R3.1. The hand-rolled YAML parser in `config.nu` gains explicit support for the shapes already consumed: `model`, `compression`, `agent`, `network`, `mcp_servers`, `skills`.
- R3.2. Unknown keys at the root level are ignored silently (current behavior preserved).
- R3.3. Malformed values (non-integer where integer expected, empty where non-empty required) produce a warning to stderr rather than silent fallback.
- R3.4. The `mcp_servers` section parsing is robust enough to handle nested server entries with `command`, `args` (inline or multi-line list), and `timeout` without line-count assumptions.

### Phase 4: Env-Variable State Reduction

- R4.1. Identify env variables used as runtime state (not configuration) — e.g., `HERMES_NURL_HARNESS_*`, `HERMES_NURL_FALLBACK_SAFE`, `HERMES_NURL_SESSION_ID` — and document which are config vs. state.
- R4.2. For each state variable, evaluate whether a process-local data structure (NURL struct or global) can replace it without changing external behavior.
- R4.3. Where replacement is feasible, migrate the variable to a process-local mechanism. Where it is not feasible (e.g., subprocess communication via env), document the constraint explicitly in a comment.
- R4.4. The agent fallback env-save/restore pattern (`run_agent_provider_no_user_with_profile`) is simplified or replaced so that provider profile switching does not require saving and restoring 14 env variables.

### Phase 5: Tool File Decomposition

- R5.1. Decompose `tools_local.nu` (2,758 lines) into logical modules — at minimum: file tools, shell tool, search tools, patch tools, skills tools, harness tools, tool schemas, and dispatch.
- R5.2. The public dispatch surface (`is_local_tool`, `run_local_tool_input`, `build_local_claude_tools`, `build_local_openai_tools`, `add_local_mcp_tools`) remains stable so that `agent.nu`, `mcp_stdio.nu`, and `mcp_external.nu` require no changes.
- R5.3. No behavioral changes — this is a pure structural refactor. All existing tool behavior, error messages, and trace events are preserved.
- R5.4. The decomposed files are included via the same `$` include mechanism and compile into the same binary.

### Phase 6: Provider Path Deduplication

- R6.1. Extract the shared agent-turn loop pattern (call provider, parse response, check for tool calls, dispatch tools, loop) into a provider-agnostic core that accepts a single provider-call interface.
- R6.2. The Anthropic and OpenAI-specific code is reduced to: (a) provider-call adapters that return a normalized response, (b) message-format helpers, (c) retry/error classification.
- R6.3. Adding a new provider surface requires only a new adapter module, not a full copy of the agent loop, REPL, resume, events, and fallback paths.
- R6.4. Provider fallback profile switching uses the mechanism from Phase 4 (no 14-variable env save/restore).
- R6.5. All existing provider behavior is preserved: retry logic, error classification, tool-call argument repair, usage tracking, event emission, compression callbacks.

## Success Criteria

- Phases 1 and 3 have zero behavioral change — existing tests and gates pass identically.
- Phase 2 allows a developer to add a new test by writing a single function, with no central registry edit.
- Phase 4 reduces the number of env-save/restore operations in the agent fallback path.
- Phase 5 brings `tools_local.nu` (or its successor modules) to under 500 lines per file.
- Phase 6 reduces the agent-loop + REPL + resume code paths from 6 near-duplicates (anthropic/openai × loop/repl/resume) to 1 shared core with 2 thin adapters.
- All existing readiness gates (dogfood, production, beta, harness) pass at each phase boundary.

## Scope Boundaries

- No new tools, providers, or user-facing features in any phase.
- No changes to the NURL language or stdlib — these phases work within the existing language.
- No changes to external interfaces: CLI commands, MCP protocol, HTTP adapter, SQLite schema.
- No performance optimization passes — structural improvements only.
- Phase ordering is a dependency constraint, not a scheduling commitment. Phases can be landed incrementally.

## Key Decisions

- **Phase ordering (1→2→3→4→5→6):** RFC 1918 first because it's trivial and proves the test framework works. Test framework second because it's a prerequisite for safe refactoring in phases 5 and 6. Config hardening third because it's self-contained. Env coupling fourth because it unblocks cleaner provider switching. Tool decomposition fifth because it's the highest-risk refactor and needs tests + cleaner state. Provider deduplication last because it depends on all of the above.
- **In-process test runner:** Avoids subprocess-per-test overhead and works within NURL's compilation model. Discovery by naming convention keeps the barrier to adding tests low.
- **Struct/struct-based state over env vars:** Where the NURL type system allows it, process-local state is preferable to env-var smuggling. Where subprocess boundaries require env vars, that constraint is documented rather than fought.
- **Thin adapter pattern for providers:** Full provider abstraction (trait/interface) is avoided because NURL's type system would make it leaky. Instead, a shared core loop calls through adapter functions — the same pragmatic pattern already used for tool dispatch.

## Open Questions

### Resolve Before Building

- Q1. For Phase 2: Should the test runner live in a new `src/test_framework.nu` or be embedded in `common.nu` alongside existing helpers?
- Q2. For Phase 4: Does NURL support mutable global structs, or are all process-local data structures passed as function parameters? This determines whether state migration uses globals or threaded parameters.
- Q3. For Phase 5: What is the natural decomposition of `tools_local.nu` given NURL's `$` include model — one file per tool, or grouped by domain (file I/O together, search together, etc.)?

### Defer to Building

- Q4. For Phase 6: The exact shape of the provider adapter interface will emerge from extracting the shared loop. Define it during implementation, not here.
- Q5. For Phase 3: Whether to add support for YAML anchors/aliases is out of scope for now but may matter if config files grow.
