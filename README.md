# Hermes NURL Prototype

This directory is the first native NURL rewrite slice for Hermes Agent.

The current executable is intentionally small:

- one-shot prompt input from argv or stdin
- Anthropic Messages API transport via NURL stdlib
- Anthropic-compatible base URL override for providers such as BigModel
- OpenAI-compatible Chat Completions transport for OpenAI-style providers
- conservative chat/resume provider fallback before any tool call is executed
- local tools for shell, path metadata, file read/write/append, directory listing, search, exact replacement patches, and V4A Add/Update/Delete/Move multi-file patches
- Hermes-style system prompt assembly with `SOUL.md`, project context files, prompt-injection blocking, and provider/model metadata
- Hermes-style skill discovery, prompt indexing, `skills_list`, and `skill_view`
- optional skill-local harness contracts, lifecycle events, evidence/gate
  recording, completion blocking, and readiness fixtures
- OpenAI-compatible tool-call argument JSON repair before tool dispatch, including trailing commas, unbalanced closers, and unescaped control characters
- offline model context-length metadata and `model.context_length` override support
- context budget preflight, cost-gated optional no-tool summary compaction, deterministic middle-turn compaction, hard overflow stop, and old tool-output pruning from the core compressor path
- bounded tool-use loop
- context-safe tool result truncation
- line-paged `read_file` with optional line numbers
- paged content and file-name search through `search_files`
- JSONL trace hooks via `HERMES_NURL_TRACE`
- high-level session JSONL via `HERMES_NURL_SESSION_LOG`, including tool events
- compression metrics in trace/session events for prune, provider-summary, deterministic-summary, and over-threshold passes
- production mode that hides shell and mutating tools unless explicit allow flags are set
- optional operator-configured edit check command after successful write/edit tools, with strict failure mode
- optional SQLite event mirror plus Hermes-compatible `sessions` / `messages` rows via `HERMES_NURL_STATE_DB`
- conservative session resume from SQLite transcript rows, including tool-call argument/result replay and stored system prompt reuse
- generated per-process session ids when `HERMES_NURL_SESSION_ID` is not set
- basic shell guardrails for obviously destructive commands
- minimal Hermes home/config path resolution via `HERMES_HOME`, including
  automatic `$HERMES_HOME/.env` loading for unset process variables
- read-only `config.yaml` model defaults for Anthropic-compatible and OpenAI-compatible providers
- a `doctor` command for local readiness checks
- a `prompt` command for inspecting the generated system prompt
- a `model-info` command for inspecting model context metadata
- `skills`, `skills-dirs`, and `skill-view` commands for inspecting skill search roots and skill content
- a `repl` command for in-process multi-turn sessions, with optional SQLite resume
- `sessions`, `session <id>`, and `session-json <id>` commands for inspecting the SQLite transcript
- shared local tool catalog for agent-loop, OpenAI-compatible, Anthropic-compatible, and MCP schemas
- an MCP stdio prototype server with status, echo, chat, and local tools
- a NURL-native local HTTP adapter for browser testing
- external stdio MCP discovery/calls from `mcp_servers` in `config.yaml`

## Layout

```text
nurl/
  nurl.toml
  src/agent.nu
  src/config.nu
  src/common.nu
  src/context_budget.nu
  src/main.nu
  src/message_sanitization.nu
  src/mcp_external.nu
  src/mcp_client_stdio.nu
  src/mcp_stdio.nu
  src/http_adapter.nu
  src/model_metadata.nu
  src/prompt_builder.nu
  src/session_resume.nu
  src/skills.nu
  src/state_cli.nu
  src/providers/anthropic.nu
  src/providers/openai_compat.nu
  src/tools_local.nu
```

The helper script at `scripts/nurl-prototype.sh` expects the NURL compiler
checkout beside this repository at `../nurl-lang-nurl`, which is how this
workspace was bootstrapped.

## Build

```bash
scripts/nurl-prototype.sh build
```

This builds the NURL toolchain if needed, then compiles `nurl/src/main.nu` to
`nurl/build/hermes-nurl`.

The MCP stdio server builds with:

```bash
scripts/nurl-prototype.sh build-mcp
```

The minimal NURL MCP stdio client smoke binary builds with:

```bash
scripts/nurl-prototype.sh build-mcp-client
```

The local browser HTTP adapter builds with:

```bash
scripts/nurl-prototype.sh build-http
```

Install or update the built NURL Hermes binaries into a local prefix:

```bash
scripts/nurl-install.sh --prefix ~/.local
```

This installs `hermes-nurl`, `hermes-nurl-mcp`, `hermes-nurl-mcp-client`, and
`hermes-nurl-http` into `PREFIX/bin`.

## Dogfood

Run the repeatable offline dogfood suite:

```bash
scripts/nurl-dogfood.sh
```

Set `HERMES_NURL_DOGFOOD_LIVE=1` to include an opt-in live provider smoke when
provider API key environment variables are configured.

Run the production-readiness gate:

```bash
scripts/nurl-production-readiness.sh
```

The same gate is available in GitHub Actions as
`.github/workflows/nurl-production-readiness.yml` for NURL core changes.

Run the beta-readiness gate before a controlled beta rollout:

```bash
scripts/nurl-beta-readiness.sh
```

This runs production readiness plus `scripts/nurl-long-task-stress.sh`, which
exercises repeated production edits, structural V4A patches, a long MCP stream,
large SQLite resume, and deterministic compression metrics. Set
`HERMES_NURL_BETA_LIVE=1` to include live provider stress in the same gate.

Run the harness-specific readiness lane directly:

```bash
scripts/nurl-harness-readiness.sh
```

This proves contract discovery, source/runtime separation, dependent skill
handoff evidence, completion blocking, failed-gate handling, SQLite inspection,
and production defaults.

## Run

```bash
export ANTHROPIC_API_KEY=...
scripts/nurl-prototype.sh run "read README.md and explain what Hermes does"
```

Run an in-process multi-turn session:

```bash
scripts/nurl-prototype.sh repl
```

Resume a SQLite-backed session by id:

```bash
export HERMES_NURL_STATE_DB=nurl/build/state.db
scripts/nurl-prototype.sh resume my-session "continue from the last answer"
scripts/nurl-prototype.sh repl my-session
scripts/nurl-prototype.sh session-json my-session openai
```

Inspect the system prompt that will be sent to a provider:

```bash
scripts/nurl-prototype.sh prompt
```

Inspect and call configured external MCP tools:

```bash
scripts/nurl-prototype.sh mcp-tools
scripts/nurl-prototype.sh mcp-call mcp__filesystem__read_file '{"path":"/tmp/a.txt"}'
```

Run the local NURL-native HTTP adapter for browser testing:

```bash
scripts/nurl-prototype.sh http
```

Then open `http://127.0.0.1:18081/`. Installed/static packages can run it with:

```bash
HERMES_NURL_AGENT_BIN=bin/hermes-nurl bin/hermes-nurl-http
```

The browser UI uses `POST /api/chat-stream`, a chunked
`text/event-stream` endpoint. It streams lifecycle events such as `turn`,
`tool`, `final`, `usage`, and `exit` as newline-delimited JSON inside SSE
frames, so the page can show progress before the agent subprocess exits. The
older `POST /api/chat` endpoint remains available for callers that want one
buffered JSON response.

For raw event output without HTTP:

```bash
printf '%s' "Say hello." | nurl/build/hermes-nurl chat-events
```

`hermes-nurl` and `hermes-nurl-http` load `$HERMES_HOME/.env` automatically
for variables that are not already present in the process environment, so
explicitly exported values still win.

Override the bind address with either command-line args or environment:

```bash
bin/hermes-nurl-http 127.0.0.1 18082
HERMES_NURL_HTTP_HOST=127.0.0.1 HERMES_NURL_HTTP_PORT=18082 bin/hermes-nurl-http
```

Inspect model metadata used by preflight/compression work:

```bash
scripts/nurl-prototype.sh model-info glm-5.1
```

Inspect skills and load skill content:

```bash
scripts/nurl-prototype.sh skills
scripts/nurl-prototype.sh skill-view hermes-agent
scripts/nurl-prototype.sh skill-view writer references/style.md
```

Use the generic HTTP tool for small, controlled GET/POST calls in
non-production runs:

```bash
printf '%s' '{"url":"https://example.com","max_response_bytes":2000}' \
  | nurl/build/hermes-nurl mcp-call-stdin http_request
```

`http_request` rejects non-HTTP(S) schemes, embedded credentials,
token-bearing URLs, CRLF header injection, non-string headers, and oversized
responses are capped. It is intentionally still hidden in
`HERMES_NURL_PRODUCTION_MODE=1`: the current NURL stdlib HTTP runtime follows
redirects implicitly, so production exposure waits for redirect-safe runtime
support and final-target policy checks.

Install a local skill archive, such as a standard `SKILL.md` tarball or a
command-style bundle with `AGENTS.md`, `commands/*.md`, and brand assets but no
top-level `SKILL.md`:

```bash
export HERMES_HOME=~/.hermes
scripts/nurl-install-skill-zip.py ~/Downloads/mint-main.zip --name mint --replace
scripts/nurl-install-skill-zip.py ~/Downloads/lide-mint-publish-skill.zip --replace
scripts/nurl-install-skill-zip.py ~/Downloads/lide-html2png-skill.tar.gz --replace
scripts/nurl-prototype.sh skills
scripts/nurl-prototype.sh skill-view mint
scripts/nurl-prototype.sh skill-view mint commands/mint.md
scripts/nurl-prototype.sh skill-view mint-publish
scripts/nurl-prototype.sh skill-view html2png
```

For mint-style image generation, configure `GPT_IMAGE2_API_ENDPOINT` and
`GPT_IMAGE2_API_KEY`. The optional helper below normalizes trailing slashes,
keeps the key out of command logs, and decodes `b64_json` responses:

```bash
scripts/mint-image2-generate.py \
  --prompt-file nurl/build/mint/prompt.txt \
  --response-json nurl/build/mint/response.json \
  --output nurl/build/mint/bg_01.png
```

The intended mint delivery chain is: `mint` writes the local output bundle,
`mint-publish` publishes that bundle and returns a public `html_url`, and
`html2png` consumes that public URL to export final PNGs. The importer installs
runtime helpers for the relay skills so agents do not hand-write token-bearing
`curl` or Python API calls:

```bash
python3 "$HERMES_HOME/skills/mint-publish/scripts/mint-publish.py" \
  --output-dir "$HERMES_HOME/skills/mint/brands/格润富德/output/20260519_夏至" \
  --entry-html "夏至.html" \
  --publish-path "brands/格润富德"

python3 "$HERMES_HOME/skills/html2png/scripts/html2png-export.py" \
  --html-url "https://example.com/夏至.html" \
  --output-dir "$HERMES_HOME/skills/mint/brands/格润富德/output/20260519_夏至/成品图"
```

The html2png helper defaults to full-size `.canvas` export (`1024x1536`, scale
`0.3` from `.canvas-wrapper > .canvas`) for mint-style preview pages and crops
minor remote-renderer overshoot such as `1025x1536` back to `1024x1536`.
For mint output directories under `brands/<brand>/output/<run>`, the publish
helper packages `canvas.css`, referenced fonts/logos/assets, and the current
output run under the brand root. This keeps relative paths such as
`../../canvas.css` and `../../assets/logos/...` valid after publishing.

Mint-style imports also install `scripts/mint-workflow-check.py`. The generated
`SKILL.md` stays intentionally thin and points the model back to
`commands/mint.md` as the workflow source of truth; use the verifier before
reporting a completed mint job so command/brand/copy/layout/export constraints
are verified against artifacts and the NURL trace:

```bash
scripts/mint-workflow-check.py \
  --skill-dir "$HERMES_HOME/skills/mint" \
  --output-dir "$HERMES_HOME/skills/mint/brands/格润富德/output/20260519_夏至" \
  --trace "$HERMES_NURL_TRACE"
```

Optional:

```bash
export HERMES_HOME=~/.hermes
export HERMES_NURL_ANTHROPIC_API_KEY=...
export HERMES_NURL_ANTHROPIC_BASE_URL=https://api.anthropic.com
export HERMES_NURL_MODEL=claude-opus-4-7
export HERMES_NURL_MAX_TOKENS=4096
export HERMES_NURL_API_MAX_RETRIES=3
export HERMES_NURL_AGENT_MAX_TURNS=8
export HERMES_NURL_TRACE=nurl/build/trace.jsonl
export HERMES_NURL_SESSION_LOG=nurl/build/session.jsonl
export HERMES_NURL_STATE_DB=nurl/build/state.db
export HERMES_NURL_SESSION_ID=my-session
```

Select the provider surface with `HERMES_NURL_PROVIDER` or
`model.provider` in `$HERMES_HOME/config.yaml`. Supported values are
`anthropic`, `anthropic-compatible`, `openai`, `openai-compatible`, and
`custom`. `custom` follows the existing Hermes convention for an
OpenAI-compatible endpoint.

Anthropic-compatible providers can be tested by changing the base URL and
model, for example:

```bash
export HERMES_NURL_ANTHROPIC_API_KEY=...
export HERMES_NURL_ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic
export HERMES_NURL_MODEL=glm-5.1
scripts/nurl-prototype.sh run "Reply exactly: nurl-bigmodel-ok"
```

API key lookup order is `ANTHROPIC_API_KEY`, then
`HERMES_NURL_ANTHROPIC_API_KEY`, then `model.api_key` in
`$HERMES_HOME/config.yaml`. Use the scoped variable for Anthropic-compatible
providers that also expose other API-compatible surfaces.

OpenAI-compatible providers use their own scoped environment variables:

```bash
export HERMES_NURL_PROVIDER=openai
export HERMES_NURL_OPENAI_API_KEY=...
export HERMES_NURL_OPENAI_BASE_URL=https://api.openai.com/v1
export HERMES_NURL_OPENAI_MODEL=gpt-4.1
scripts/nurl-prototype.sh run "Reply exactly: nurl-openai-ok"
```

OpenAI-compatible API key lookup order is `OPENAI_API_KEY`, then
`HERMES_NURL_OPENAI_API_KEY`, then `model.api_key` in
`$HERMES_HOME/config.yaml`. Anthropic-compatible and OpenAI-compatible
BigModel keys should be set through the matching scoped variable for the
surface being used.

Process environment variables are resolved after automatic `$HERMES_HOME/.env`
loading, so putting API keys in `~/.hermes/.env` works without sourcing it
first.

`config.yaml` can supply the current provider defaults:

```yaml
model:
  provider: "anthropic"
  default: "glm-5.1"
  base_url: "https://open.bigmodel.cn/api/anthropic"
  api_key: "..."
  context_length: 202752
  max_tokens: 4096
```

Environment variables still win over config values.
Use `HERMES_NURL_ANTHROPIC_MAX_TOKENS` or
`HERMES_NURL_OPENAI_MAX_TOKENS` when one provider surface needs a different
output-token cap than the generic `HERMES_NURL_MAX_TOKENS`.

Provider fallback is opt-in. Set `HERMES_NURL_FALLBACK_PROVIDER` or
`model.fallback_provider`, and optionally `HERMES_NURL_FALLBACK_MODEL` or
`model.fallback_model`. Fallback can use its own profile values:
`HERMES_NURL_FALLBACK_BASE_URL`, `HERMES_NURL_FALLBACK_API_KEY`,
`HERMES_NURL_FALLBACK_MAX_TOKENS`, and
`HERMES_NURL_FALLBACK_API_MAX_RETRIES`,
`HERMES_NURL_FALLBACK_API_TIMEOUT_MS`, and
`HERMES_NURL_FALLBACK_API_CONNECT_TIMEOUT_MS`, or `model.fallback_base_url`,
`model.fallback_api_key`, `model.fallback_max_tokens`,
`agent.fallback_api_max_retries`, `agent.fallback_api_timeout_ms`, and
`agent.fallback_api_connect_timeout_ms` in `config.yaml`. The fallback path is
intentionally conservative: chat and resume retry the prompt on the fallback
provider only when the primary provider fails before any tool call is executed.
Once a tool has run, NURL does not replay the turn automatically because local
tools can write files or touch external MCP servers.

```bash
export HERMES_NURL_PROVIDER=anthropic
export HERMES_NURL_FALLBACK_PROVIDER=openai
export HERMES_NURL_FALLBACK_MODEL=gpt-4.1
export HERMES_NURL_OPENAI_API_KEY=...
```

`config.yaml` can also supply the current pure compression subset:

```yaml
compression:
  enabled: true
  threshold: 0.50
  target_ratio: 0.20
  summary_enabled: false
  summary_provider: "anthropic"
  summary_model: "glm-5.1"
  summary_base_url: "https://open.bigmodel.cn/api/anthropic"
  summary_api_timeout_ms: 300000
  summary_api_connect_timeout_ms: 10000
  summary_max_tokens: 12000
  summary_min_input_tokens: 4096
  summary_min_savings_tokens: 2048
  protect_first_n: 3
  protect_last_n: 20
agent:
  api_max_retries: 3
  api_timeout_ms: 600000
  api_connect_timeout_ms: 15000
  max_turns: 8
```

The NURL agent estimates request size before each model call. When the request
crosses the configured threshold, it first prunes older large tool outputs to
small markers. If pressure remains high and `summary_enabled` is true, it asks
a no-tool compressor profile for a summary of the compactable middle range,
then replaces that range while preserving configured head and tail messages.
Before spending a provider call, the agent estimates the compactable range and
skips no-tool summary when the range is below `summary_min_input_tokens` or the
expected saved tokens are below `summary_min_savings_tokens`. The matching
environment overrides are `HERMES_NURL_COMPRESSION_SUMMARY_MIN_INPUT_TOKENS`
and `HERMES_NURL_COMPRESSION_SUMMARY_MIN_SAVINGS_TOKENS`.
When `summary_provider`, `summary_model`, or `summary_base_url` are omitted,
the summary call falls back to the active provider profile. Summary keys remain
compatibility-scoped: set `HERMES_NURL_COMPRESSION_SUMMARY_ANTHROPIC_API_KEY`
or `HERMES_NURL_COMPRESSION_SUMMARY_OPENAI_API_KEY` to override the normal
provider key for compression. Summary calls can also use
`HERMES_NURL_COMPRESSION_SUMMARY_API_TIMEOUT_MS` and
`HERMES_NURL_COMPRESSION_SUMMARY_API_CONNECT_TIMEOUT_MS` when the compressor
needs a tighter timeout than the main turn. If the summary call is disabled or fails, it
falls back to the deterministic handoff summary. It then stops before the
provider call if the estimated input no longer fits after reserving output and
safety tokens. External context-engine plugins and persistence side effects
from Python Hermes' full compressor are intentionally deferred.
Each compression pass emits `context_compression_metric` trace rows and
`compression` session events with provider, stage, before/after token estimates,
estimated saved tokens, and changed message/tool-result counts. If compression
still exceeds the configured threshold, `context_compression_remaining` and
`compression_remaining` record the remaining token estimate and threshold.
Cost-gate skips emit `context_summary_skipped` and `compression_skipped`.
API retries are conservative and cover transport-like failures plus provider
HTTP status classes that are usually transient, including rate limits,
temporary overloads, and 5xx server errors. Auth failures, invalid requests,
and context-window errors stay on the non-retry path. Primary request timeouts
can be set globally with `HERMES_NURL_API_TIMEOUT_MS` and
`HERMES_NURL_API_CONNECT_TIMEOUT_MS`, or per compatibility surface with
`HERMES_NURL_ANTHROPIC_TIMEOUT_MS`, `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS`,
`HERMES_NURL_OPENAI_TIMEOUT_MS`, and `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS`.
The bounded tool loop defaults to 8 turns and can be adjusted with
`HERMES_NURL_AGENT_MAX_TURNS` or `agent.max_turns`.

Production mode narrows the local tool surface for controlled deployments:

```bash
export HERMES_NURL_PRODUCTION_MODE=1
```

With production mode enabled, `run_shell` is hidden unless
`HERMES_NURL_ALLOW_SHELL=1`, and `write_file`, `append_file`, and `patch` are
hidden unless `HERMES_NURL_ALLOW_MUTATIONS=1`. Direct calls to disabled tools
return an error and emit a `tool_blocked` trace event. The system prompt also
reflects the narrowed tool surface. The production-readiness gate in
`scripts/nurl-production-readiness.sh` verifies these defaults and the explicit
allow toggles. In the MCP stdio server, production-mode mutating tool calls
that are explicitly allowed are dispatched through the configured
`HERMES_NURL_AGENT_BIN` subprocess via `mcp-call-stdin`, keeping the MCP server
process isolated from edit-tool faults. Explicitly allowed production mutations
are still path-guarded: write/edit targets must be relative workspace paths and
cannot contain `..`, `~`, or `.git` / `.hg` / `.svn` path markers.
Set `HERMES_NURL_REQUIRE_EXPECTED_SHA256=1` to require write/edit calls against
existing files to include the current `expected_sha256`. `file_info` reports a
file `sha256` so production callers can do a read-check-write flow.

Set `HERMES_NURL_EDIT_CHECK_COMMAND` to a fixed lint/test command that should
run after successful `write_file`, `append_file`, or non-dry-run `patch`
operations. In production mode this command only runs when shell execution is
explicitly allowed with `HERMES_NURL_ALLOW_SHELL=1`; otherwise the edit result
reports that the check was skipped. Set `HERMES_NURL_EDIT_CHECK_STRICT=1` to
turn skipped, blocked, failed, or errored edit checks into `error:` tool
results so MCP clients and agent loops can treat lint/test failures as failed
edits.

`config.yaml` can also supply the current stdio MCP subset:

```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    timeout: 120
```

Configured tools are exposed to the agent with `mcp__<server>__<tool>` names.
The prototype currently supports stdio MCP servers; HTTP/SSE transports, OAuth,
sampling, and dynamic notification handling are later slices.

`config.yaml` can also supply the current skills subset:

```yaml
skills:
  disabled: ["legacy-skill"]
  external_dirs:
    - "~/team-skills"
    - "shared-skills"
```

Skills are discovered from `$HERMES_HOME/skills` first, then configured
`skills.external_dirs`. Local skills take precedence when names collide.
`skills_list` returns compact metadata; `skill_view` loads full `SKILL.md`
content or a linked file under `references/`, `templates/`, `assets/`,
`scripts/`, `commands/`, or `brands/`. The NURL prompt builder injects a
compact skills index when any skills are visible.

Skills can optionally ship a `harness.json`, `harness.contract.json`, or
`.harness.json` file. Contracts declare entrypoints, required files, dependent
skills, evidence, gates, completion rules, ignored runtime paths, and output
policy. Contract metadata appears in `skills_list`, `skill_view`, and the
compact skills prompt fragment. The runtime records contract work through
`harness_record` / `harness-*` commands and blocks final answers while an active
contract has missing gates, failed gates, or no final report. See
`docs/nurl-harness-runtime.md`.

`scripts/nurl-install-skill-zip.py` is a local setup bridge for command-style
skill bundles. It extracts Unicode filenames with Python's zip handling,
installs into `$HERMES_HOME/skills/<name>`, generates a thin command-entry
`SKILL.md` when needed, writes a `.skillignore` so runtime artifacts such as
`output/` are not treated as skill source material, exposes slash-command files
through `skill_view`, and rewrites obvious author-machine absolute project paths
to the installed skill root. It is intentionally local-only; `skill_manage`,
skills hub install/update
flows, plugin skill namespaces, and template/inline-shell preprocessing are
later slices.

Prompt assembly loads `SOUL.md` from `HERMES_HOME` and the first matching
project context source from `TERMINAL_CWD` or the current working directory:
`.hermes.md` / `HERMES.md` while walking to the git root, then `AGENTS.md`,
`CLAUDE.md`, `.cursorrules`, or `.cursor/rules/*.mdc` from the working
directory. Set `HERMES_NURL_SKIP_CONTEXT_FILES=1` to disable project context
loading for a run. Suspicious context files are replaced with a blocked marker
instead of being injected.

## Check

```bash
scripts/nurl-prototype.sh check
```

This formats, builds, runs `doctor`, inspects the generated prompt, runs the
built-in `selftest`, and checks
that chat mode fails cleanly when no Anthropic-compatible key is configured. It
also verifies Anthropic-compatible and OpenAI-compatible provider config
selection, provider fallback configuration and safe missing-key routing, model
context-length fallback/override behavior, compression
threshold/tail-budget/summary config, SOUL/AGENTS context
loading, context injection blocking, tool-call argument repair, external stdio
MCP discovery/call dispatch, smoke-tests the MCP stdio server handshake, tool listing, echo call, local
`list_dir` call, write/append/read cycle, paged `read_file`, `search_files`
content search, `search_files` file-name search with paging, `patch` replace
mode, `patch` V4A Add/Update/Delete mode, and chat tool error propagation. It
also verifies skill discovery, external skill dirs, disabled skill filtering,
linked-file loading, skills prompt indexing, MCP skill tools, and session JSONL
for user, agent error, tool call, and tool result events. The check also
verifies that REPL mode fails cleanly when the selected provider key is missing.
`scripts/nurl-production-readiness.sh` layers production-mode checks on top of
prototype and dogfood, including read-only default tool exposure, blocked
mutations, explicit allow toggles, trace/session/state path readiness, and an
optional live gate via `HERMES_NURL_PRODUCTION_LIVE=1`. The GitHub Actions
workflow checks out the pinned `nurl-lang/nurl` toolchain, runs the same gate,
publishes the report to the job summary, and uploads readiness artifacts.
`scripts/nurl-beta-readiness.sh` adds long-task stress for beta rollouts,
including repeated production edits with `expected_sha256`, strict edit checks,
structural V4A patching, long MCP streams, SQLite resume pressure, and
deterministic compression metrics.
`scripts/nurl-harness-readiness.sh` adds a focused harness lane for contract
discovery, evidence, handoffs, completion blocking, failed gates, SQLite
inspection, and production defaults; production readiness includes it.
`scripts/nurl-prototype.sh check` also verifies the edit-check hook after MCP
write/patch calls. The readiness gate also runs `scripts/nurl-install.sh` into
an isolated prefix and verifies the installed `hermes-nurl`.

## MCP

```bash
scripts/nurl-prototype.sh mcp
```

The server speaks newline-delimited JSON-RPC over stdio and currently exposes
`hermes_nurl_status`, `echo`, `hermes_nurl_chat`, `run_shell`, `file_info`,
`read_file`, `list_dir`, `write_file`, `append_file`, `search_files`, `patch`,
`skills_list`, `skill_view`, and `harness_record`. The chat tool shells out to the agent binary named by `HERMES_NURL_AGENT_BIN`,
defaulting to `nurl/build/hermes-nurl`. The local tools are backed by the same
NURL dispatch module used by the agent loop. `mcp-call-stdin` is an internal
CLI helper used by the MCP server to run production-mode mutating local tools in
a child process while passing JSON arguments on stdin.

`nurl/build/hermes-nurl-mcp-client` is a small client-side smoke binary. It
uses NURL stdlib's `ext/mcp_stdio.nu` client to spawn an MCP stdio server, send
`initialize`, `tools/list`, and an `echo` `tools/call`, then print the server
responses. It is the first NURL-side client boundary for future external MCP
tool discovery and dispatch.

`read_file` accepts optional line-based `offset` and `limit` fields. Set
`line_numbers` to `true` to prefix returned lines with 1-based line numbers.
`file_info` returns basic existence, kind, and size metadata for a path.
`search_files` defaults to content search and accepts optional `limit` and
`offset` fields. Set `target` to `files` to search file paths by ripgrep glob.
`patch` supports `mode="replace"` for exact single-file replacement and
`mode="patch"` for a constrained V4A core: `*** Add File`,
`*** Update File`, `*** Delete File`, and `*** Move to:` operations with exact
hunk matching, CRLF-normalized hunk fallback, trim-end fuzzy hunk fallback, and
a conservative structural fuzzy fallback that uniquely matches whole trimmed
lines and reindents the replacement to the matched block. It also supports
optional `*** Expected SHA256:` staleness guards for update/delete operations. Multi-file
V4A patches are staged before any file is written or deleted, so parse, hunk,
sha, path, and duplicate-touch conflict failures do not leave earlier operations
half-applied. Replace mode also accepts `expected_sha256`. Set `dry_run=true`
on replace or V4A patches to validate and preview the change without writing or deleting files;
production mode allows this direct dry-run path even when mutation tools are not
exposed. Broader file-state guards are still Hermes Python features to port
later.

## State

Set `HERMES_NURL_STATE_DB` to a SQLite path to mirror session events into the
`nurl_session_events` table and append a minimal Hermes-compatible transcript
to `sessions` / `messages`. Setting it to `1`, `true`, `yes`, or `on` uses
`$HERMES_HOME/state.db`. Leave it unset or set it to `0` to keep SQLite writes
disabled. Use `HERMES_NURL_SESSION_ID` to choose the logical session id.
When a session is written, NURL stores the assembled system prompt on the
`sessions` row and resumed runs reuse that snapshot before falling back to the
current project prompt builder.

Inspect stored sessions with:

```bash
HERMES_NURL_STATE_DB=nurl/build/state.db nurl/build/hermes-nurl sessions
HERMES_NURL_STATE_DB=nurl/build/state.db nurl/build/hermes-nurl session my-session
```

## Next Code Moves

- Promote the shared local tool catalog into a generated NURL registry.
- Harden `patch` with structural fuzzy matching, lint filtering, and broader file-state guards.
- Add more provider surfaces behind the scoped `providers/*` boundary.
- Keep tightening Hermes-compatible `sessions` / `messages` parity as the
  event shape settles.
- Keep `skill_manage`, skill preprocessing, plugin skill namespaces, skills hub
  install/update flows, cron, and gateway side effects out of the current core
  porting lane.
