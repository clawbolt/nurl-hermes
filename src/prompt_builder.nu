// System prompt and context-file assembly for Hermes NURL.
//
// This ports the low-dependency core of agent/prompt_builder.py and
// agent/system_prompt.py: identity, project context discovery, prompt-injection
// scanning, and provider/model metadata. The full Python skill/memory/plugin
// prompt stack can layer on top of this module later.

$ `stdlib/ext/env.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/path.nu`
$ `stdlib/std/time.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/config.nu`
$ `nurl/src/skills.nu`

@ CONTEXT_FILE_MAX_CHARS → i { ^ 20000 }

@ DEFAULT_AGENT_IDENTITY → s {
    ^ `You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct. You assist users with answering questions, writing and editing code, analyzing information, creative work, and executing actions via your tools. You communicate clearly, admit uncertainty when appropriate, and prioritize being genuinely useful over being verbose unless otherwise directed below. Be targeted and efficient in your exploration and investigations.`
}

@ HERMES_AGENT_HELP_GUIDANCE → s {
    ^ `If the user asks about configuring, setting up, or using Hermes Agent itself, inspect the local Hermes documentation and configuration before answering. Docs: https://hermes-agent.nousresearch.com/docs`
}

@ prompt_production_mode → b {
    ^ ( prompt_env_truthy `HERMES_NURL_PRODUCTION_MODE` )
}

@ prompt_shell_allowed → b {
    ? ! ( prompt_production_mode ) { ^ T } {}
    ^ ( prompt_env_truthy `HERMES_NURL_ALLOW_SHELL` )
}

@ prompt_mutations_allowed → b {
    ? ! ( prompt_production_mode ) { ^ T } {}
    ^ ( prompt_env_truthy `HERMES_NURL_ALLOW_MUTATIONS` )
}

@ prompt_network_policy_configured → b {
    : String hosts ( hermes_nurl_network_allow_hosts_from_env )
    : String bases ( hermes_nurl_network_allow_base_urls_from_env )
    : b ok ? | > ( string_len hosts ) 0 > ( string_len bases ) 0 T F
    ( string_free hosts )
    ( string_free bases )
    ^ ok
}

@ prompt_network_redirect_safe_runtime → b {
    ^ F
}

@ prompt_network_allowed → b {
    ? ( prompt_env_truthy `HERMES_NURL_DISABLE_NETWORK` ) { ^ F } {}
    ? ! ( prompt_production_mode ) {
        ? ( prompt_env_falsy `HERMES_NURL_ALLOW_NETWORK` ) { ^ F } {}
        ^ T
    } {}
    ? ! ( prompt_env_truthy `HERMES_NURL_ALLOW_NETWORK` ) { ^ F } {}
    ? ! ( prompt_network_policy_configured ) { ^ F } {}
    ^ ( prompt_network_redirect_safe_runtime )
}

@ prompt_expected_sha_required → b {
    ^ ( prompt_env_truthy `HERMES_NURL_REQUIRE_EXPECTED_SHA256` )
}

@ append_nurl_tool_guidance String out → v {
    ( string_push_str out `You are running inside the NURL native Hermes prototype. You can use file_info for path metadata, read_file for UTF-8 text file inspection only, list_dir for directory inspection, search_files for content or path search, skills_list and skill_view for Hermes skills, and harness_record for contract-backed workflow evidence/gates/reports. Do not use read_file to inspect images or other binary artifacts; use the workflow's visual/image helper instead.` )
    ? ( prompt_shell_allowed ) {
        ( string_push_str out ` You can use run_shell for shell commands; use it sparingly and avoid destructive commands unless explicitly requested.` )
    } {
        ( string_push_str out ` Production mode has disabled shell execution for this run.` )
    }
    ? ( prompt_mutations_allowed ) {
        ( string_push_str out ` You can use write_file, append_file, or patch for UTF-8 edits; prefer patch for targeted changes.` )
        ? ( prompt_expected_sha_required ) {
            ( string_push_str out ` Existing-file edits require expected_sha256; use file_info to get the current sha256 before mutating.` )
        } {}
    } {
        ( string_push_str out ` Production mode has disabled write_file, append_file, and patch for this run.` )
    }
    ? ( prompt_network_allowed ) {
        ( string_push_str out ` You can use http_request for controlled HTTP GET/POST requests; prefer it over shell curl for plain HTTP calls. For slow service preflight/health checks, retry http_request once with a larger timeout_ms instead of probing unrelated endpoints. Prefer installed skill helpers for workflow-specific APIs and never fall back to raw curl for token-bearing requests.` )
    } {
        ( string_push_str out ` Production mode or network policy has disabled generic http_request for this run.` )
    }
    ( string_push_str out ` Prefer file_info/read_file/list_dir/search_files/skills_list/skill_view when possible, and finish with a concise answer.` )
    ( string_push_str out ` When using a skill that provides a workflow verifier under scripts/, run that verifier before the final answer and fix reported failures.` )
}

@ TOOL_USE_ENFORCEMENT_GUIDANCE → s {
    ^ `# Tool-use enforcement
You MUST use your tools to take action; do not describe what you would do or plan to do without actually doing it. When you say you will perform an action, immediately make the corresponding tool call in the same response. Keep working until the task is actually complete and verified.`
}

@ EXECUTION_DISCIPLINE_GUIDANCE → s {
    ^ `# Execution discipline
Use tools whenever they improve correctness, completeness, or grounding. Do not stop early when another tool call would materially improve the result. Use lookup tools for file contents, git history, system state, current time, calculations, and other facts that should not be guessed. Ask for clarification only when the missing information cannot be retrieved and materially changes the action.`
}

@ prompt_model_needs_tool_enforcement s model → b {
    : String m ( string_from model )
    : String lower ( string_to_lower m )
    ( string_free m )
    : ~ b yes F
    ? ( string_contains lower `gpt` ) { = yes T } {}
    ? ( string_contains lower `codex` ) { = yes T } {}
    ? ( string_contains lower `gemini` ) { = yes T } {}
    ? ( string_contains lower `gemma` ) { = yes T } {}
    ? ( string_contains lower `grok` ) { = yes T } {}
    ? ( string_contains lower `glm` ) { = yes T } {}
    ( string_free lower )
    ^ yes
}

@ prompt_env_truthy s name → b {
    : ?String got ( env_get name )
    : ~ b out F
    ?? got {
        T v → {
            : String lower ( string_to_lower v )
            : s raw ( string_data lower )
            ? != ( nurl_str_eq raw `1` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `true` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `yes` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `on` ) 0 { = out T } {}
            ( string_free lower )
            ( string_free v )
        }
        F → {}
    }
    ^ out
}

@ prompt_env_falsy s name → b {
    : ?String got ( env_get name )
    : ~ b out F
    ?? got {
        T v → {
            : String lower ( string_to_lower v )
            ( string_free v )
            ? != ( nurl_str_eq ( string_data lower ) `0` ) 0 { = out T } {}
            ? != ( nurl_str_eq ( string_data lower ) `false` ) 0 { = out T } {}
            ? != ( nurl_str_eq ( string_data lower ) `no` ) 0 { = out T } {}
            ? != ( nurl_str_eq ( string_data lower ) `off` ) 0 { = out T } {}
            ( string_free lower )
        }
        F → {}
    }
    ^ out
}

@ context_blocked_marker s filename s reason → String {
    : String out ( string_with_cap 128 )
    ( string_push_str out `[BLOCKED: ` )
    ( string_push_str out filename )
    ( string_push_str out ` contained potential prompt injection (` )
    ( string_push_str out reason )
    ( string_push_str out `). Content not loaded.]` )
    ^ out
}

@ scan_context_content String content s filename → String {
    : String lower ( string_to_lower content )
    : ~ s reason ``
    ? ( string_contains lower `ignore previous instructions` ) { = reason `prompt_injection` } {}
    ? ( string_contains lower `ignore all instructions` ) { = reason `prompt_injection` } {}
    ? ( string_contains lower `ignore above instructions` ) { = reason `prompt_injection` } {}
    ? ( string_contains lower `ignore prior instructions` ) { = reason `prompt_injection` } {}
    ? ( string_contains lower `do not tell the user` ) { = reason `deception_hide` } {}
    ? ( string_contains lower `system prompt override` ) { = reason `system_prompt_override` } {}
    ? ( string_contains lower `disregard your instructions` ) { = reason `disregard_rules` } {}
    ? ( string_contains lower `disregard all instructions` ) { = reason `disregard_rules` } {}
    ? ( string_contains lower `curl ` ) {
        ? | | | ( string_contains lower `api_key` ) ( string_contains lower `token` ) ( string_contains lower `secret` ) ( string_contains lower `password` ) {
            = reason `possible_exfiltration`
        } {}
    } {}
    ? ( string_contains lower `cat ` ) {
        ? | | | ( string_contains lower `.env` ) ( string_contains lower `credentials` ) ( string_contains lower `.netrc` ) ( string_contains lower `.pgpass` ) {
            = reason `read_secrets`
        } {}
    } {}
    ( string_free lower )
    ? > ( nurl_str_len reason ) 0 {
        ( string_free content )
        ^ ( context_blocked_marker filename reason )
    } {}
    ^ content
}

@ strip_yaml_frontmatter String content → String {
    ? ( string_starts_with content `---` ) {
        : ?i end_o ( string_index_of content `\n---` )
        ?? end_o {
            T idx → {
                : i start + idx 4
                : i n ( string_len content )
                ? < start n {
                    : i first ( string_get content start )
                    ? == first 10 { = start + start 1 } {}
                } {}
                : String body ( string_substr content start - n start )
                ? > ( string_len body ) 0 {
                    ( string_free content )
                    ^ body
                } {
                    ( string_free body )
                }
            }
            F → {}
        }
    } {}
    ^ content
}

@ truncate_context_content String content s filename → String {
    : i n ( string_len content )
    : i max ( CONTEXT_FILE_MAX_CHARS )
    ? <= n max { ^ content } {}

    : i head 12000
    : i tail 6000
    : i tail_start - n tail
    : String out ( string_with_cap max )
    : String h ( string_substr content 0 head )
    : String t ( string_substr content tail_start tail )
    ( string_push_str out ( string_data h ) )
    ( string_push_str out `\n\n[...truncated ` )
    ( string_push_str out filename )
    ( string_push_str out `: kept 12000+6000 of ` )
    ( string_push_int out n )
    ( string_push_str out ` chars. Use file tools to read the full file.]\n\n` )
    ( string_push_str out ( string_data t ) )
    ( string_free h )
    ( string_free t )
    ( string_free content )
    ^ out
}

@ read_context_file s path s section_name b strip_frontmatter → String {
    : !String IoErr rd ( read_file path )
    ?? rd {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            ? == ( string_len trimmed ) 0 {
                ( string_free trimmed )
                ^ ( string_new )
            } {}
            : String body ? strip_frontmatter ( strip_yaml_frontmatter trimmed ) trimmed
            = body ( scan_context_content body section_name )
            : String out ( string_with_cap + ( string_len body ) 64 )
            ( string_push_str out `## ` )
            ( string_push_str out section_name )
            ( string_push_str out `\n\n` )
            ( string_push_str out ( string_data body ) )
            ( string_free body )
            ^ ( truncate_context_content out section_name )
        }
        F _ → {}
    }
    ^ ( string_new )
}

@ cwd_for_context → String {
    : ?String terminal_cwd ( env_get `TERMINAL_CWD` )
    ?? terminal_cwd {
        T p → {
            ? > ( string_len p ) 0 { ^ p } {}
            ( string_free p )
        }
        F → {}
    }
    : !String IoErr cwd ( env_cwd )
    ?? cwd {
        T p → { ^ p }
        F _ → {}
    }
    ^ ( string_from `.` )
}

@ maybe_read_name s dir s name b strip_frontmatter → String {
    : String path ( path_join dir name )
    : String out ( string_new )
    ? ( file_exists ( string_data path ) ) {
        ( string_free out )
        = out ( read_context_file ( string_data path ) name strip_frontmatter )
    } {}
    ( string_free path )
    ^ out
}

@ find_git_root s cwd → String {
    : String cur ( path_normalize cwd )
    : ~ String found ( string_new )
    : ~ b done F
    ~ ! done {
        : String git_path ( path_join ( string_data cur ) `.git` )
        ? ( file_exists ( string_data git_path ) ) {
            ( string_free found )
            = found ( string_from ( string_data cur ) )
            = done T
        } {}
        ( string_free git_path )
        ? ! done {
            : String parent ( path_dirname ( string_data cur ) )
            ? | == ( string_len parent ) 0 != ( nurl_str_eq ( string_data parent ) ( string_data cur ) ) 0 {
                ( string_free parent )
                = done T
            } {
                ( string_free cur )
                = cur parent
            }
        } {}
    }
    ( string_free cur )
    ^ found
}

@ load_hermes_md s cwd → String {
    : String root ( find_git_root cwd )
    : String cur ( path_normalize cwd )
    : ~ String out ( string_new )
    : ~ b done F
    ~ ! done {
        : String h1 ( maybe_read_name ( string_data cur ) `.hermes.md` T )
        ? > ( string_len h1 ) 0 {
            ( string_free out )
            = out h1
            = done T
        } {
            ( string_free h1 )
            : String h2 ( maybe_read_name ( string_data cur ) `HERMES.md` T )
            ? > ( string_len h2 ) 0 {
                ( string_free out )
                = out h2
                = done T
            } {
                ( string_free h2 )
            }
        }
        ? ! done {
            ? & > ( string_len root ) 0 != ( nurl_str_eq ( string_data cur ) ( string_data root ) ) 0 {
                = done T
            } {
                : String parent ( path_dirname ( string_data cur ) )
                ? | == ( string_len parent ) 0 != ( nurl_str_eq ( string_data parent ) ( string_data cur ) ) 0 {
                    ( string_free parent )
                    = done T
                } {
                    ( string_free cur )
                    = cur parent
                }
            }
        } {}
    }
    ( string_free root )
    ( string_free cur )
    ^ out
}

@ load_cwd_project_context s cwd → String {
    : String hermes_md ( load_hermes_md cwd )
    ? > ( string_len hermes_md ) 0 { ^ hermes_md } {}
    ( string_free hermes_md )

    : String agents ( maybe_read_name cwd `AGENTS.md` F )
    ? > ( string_len agents ) 0 { ^ agents } {}
    ( string_free agents )

    : String agents_lower ( maybe_read_name cwd `agents.md` F )
    ? > ( string_len agents_lower ) 0 { ^ agents_lower } {}
    ( string_free agents_lower )

    : String claude ( maybe_read_name cwd `CLAUDE.md` F )
    ? > ( string_len claude ) 0 { ^ claude } {}
    ( string_free claude )

    : String claude_lower ( maybe_read_name cwd `claude.md` F )
    ? > ( string_len claude_lower ) 0 { ^ claude_lower } {}
    ( string_free claude_lower )

    : String cursorrules ( maybe_read_name cwd `.cursorrules` F )
    ? > ( string_len cursorrules ) 0 { ^ cursorrules } {}
    ( string_free cursorrules )

    : String rules_dir ( path_join cwd `.cursor/rules` )
    : String out ( string_new )
    ? ( file_exists ( string_data rules_dir ) ) {
        : !( Vec String ) IoErr dl ( dir_list ( string_data rules_dir ) )
        ?? dl {
            T entries → {
                : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
                : i n ( vec_len [String] entries )
                : ~ i k 0
                ~ < k n {
                    : ?String e ( vec_get [String] entries k )
                    ?? e {
                        T item → {
                            ? ( string_ends_with item `.mdc` ) {
                                : String path ( path_join ( string_data rules_dir ) ( string_data item ) )
                                : String section ( string_from `.cursor/rules/` )
                                ( string_push_str section ( string_data item ) )
                                : String one ( read_context_file ( string_data path ) ( string_data section ) F )
                                ? > ( string_len one ) 0 {
                                    ? > ( string_len out ) 0 { ( string_push_str out `\n\n` ) } {}
                                    ( string_push_str out ( string_data one ) )
                                } {}
                                ( string_free path )
                                ( string_free section )
                                ( string_free one )
                            } {}
                        }
                        F → {}
                    }
                    = k + k 1
                }
                ( vec_free_with [String] entries drop_str )
            }
            F _ → {}
        }
    } {}
    ( string_free rules_dir )
    ? > ( string_len out ) 0 {
        ^ ( truncate_context_content out `.cursorrules` )
    } {}
    ^ out
}

@ load_soul_md → String {
    : String path ( hermes_path `SOUL.md` )
    : String out ( string_new )
    ? ( file_exists ( string_data path ) ) {
        : !String IoErr rd ( read_file ( string_data path ) )
        ?? rd {
            T raw → {
                : String trimmed ( string_trim raw )
                ( string_free raw )
                ? > ( string_len trimmed ) 0 {
                    ( string_free out )
                    = out ( scan_context_content trimmed `SOUL.md` )
                    = out ( truncate_context_content out `SOUL.md` )
                } {
                    ( string_free trimmed )
                }
            }
            F _ → {}
        }
    } {}
    ( string_free path )
    ^ out
}

@ build_context_files_prompt b skip_soul → String {
    ? ( prompt_env_truthy `HERMES_NURL_SKIP_CONTEXT_FILES` ) { ^ ( string_new ) } {}

    : String cwd ( cwd_for_context )
    : String project ( load_cwd_project_context ( string_data cwd ) )
    ( string_free cwd )
    : String soul ( string_new )
    ? skip_soul {} {
        ( string_free soul )
        = soul ( load_soul_md )
    }

    ? & == ( string_len project ) 0 == ( string_len soul ) 0 {
        ( string_free project )
        ( string_free soul )
        ^ ( string_new )
    } {}

    : String out ( string_with_cap + + ( string_len project ) ( string_len soul ) 160 )
    ( string_push_str out `# Project Context\n\nThe following project context files have been loaded and should be followed:\n\n` )
    ? > ( string_len project ) 0 {
        ( string_push_str out ( string_data project ) )
    } {}
    ? > ( string_len soul ) 0 {
        ? > ( string_len project ) 0 { ( string_push_str out `\n\n` ) } {}
        ( string_push_str out ( string_data soul ) )
    } {}
    ( string_free project )
    ( string_free soul )
    ^ out
}

@ system_message_from_env → String {
    : ?String got ( env_get `HERMES_NURL_SYSTEM_MESSAGE` )
    ?? got {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }
    ^ ( string_new )
}

@ build_system_prompt s provider s model → String {
    : String soul ( load_soul_md )
    : b soul_loaded ? > ( string_len soul ) 0 T F
    : String context ( build_context_files_prompt soul_loaded )
    : String extra_system ( system_message_from_env )

    : String out ( string_with_cap 4096 )
    ? soul_loaded {
        ( string_push_str out ( string_data soul ) )
    } {
        ( string_push_str out ( DEFAULT_AGENT_IDENTITY ) )
    }
    ( string_free soul )

    ( string_push_str out `\n\n` )
    ( string_push_str out ( HERMES_AGENT_HELP_GUIDANCE ) )
    ( string_push_str out `\n\n` )
    ( append_nurl_tool_guidance out )

    : String skills_prompt ( build_skills_system_prompt )
    ? > ( string_len skills_prompt ) 0 {
        ( string_push_str out `\n\n` )
        ( string_push_str out ( string_data skills_prompt ) )
    } {}
    ( string_free skills_prompt )

    ? ( prompt_model_needs_tool_enforcement model ) {
        ( string_push_str out `\n\n` )
        ( string_push_str out ( TOOL_USE_ENFORCEMENT_GUIDANCE ) )
        ( string_push_str out `\n\n` )
        ( string_push_str out ( EXECUTION_DISCIPLINE_GUIDANCE ) )
    } {}

    ? > ( string_len extra_system ) 0 {
        ( string_push_str out `\n\n` )
        ( string_push_str out ( string_data extra_system ) )
    } {}
    ( string_free extra_system )

    ? > ( string_len context ) 0 {
        ( string_push_str out `\n\n` )
        ( string_push_str out ( string_data context ) )
    } {}
    ( string_free context )

    : Time now ( time_now )
    : String iso ( time_format_iso now )
    ( string_push_str out `\n\nConversation started: ` )
    ( string_push_str out ( string_data iso ) )
    ( string_free iso )

    : ?String sid ( env_get `HERMES_NURL_SESSION_ID` )
    ?? sid {
        T s → {
            ? > ( string_len s ) 0 {
                ( string_push_str out `\nSession ID: ` )
                ( string_push_str out ( string_data s ) )
            } {}
            ( string_free s )
        }
        F → {}
    }
    ? > ( nurl_str_len model ) 0 {
        ( string_push_str out `\nModel: ` )
        ( string_push_str out model )
    } {}
    ? > ( nurl_str_len provider ) 0 {
        ( string_push_str out `\nProvider: ` )
        ( string_push_str out provider )
    } {}
    ^ out
}
