// Agent loop for Hermes NURL.

$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/io.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/std/time.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`
$ `nurl/src/context_budget.nu`
$ `nurl/src/harness.nu`
$ `nurl/src/prompt_builder.nu`
$ `nurl/src/mcp_external.nu`
$ `nurl/src/session_resume.nu`
$ `nurl/src/providers/anthropic.nu`
$ `nurl/src/providers/openai_compat.nu`

@ AGENT_MAX_TURNS → i { ^ 8 }

@ agent_clamp_max_turns i n → i {
    ? < n 1 { ^ 1 } {}
    ? > n 128 { ^ 128 } {}
    ^ n
}

@ agent_max_turns_env_value s name → i {
    : ?String got ( env_get name )
    ?? got {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            : !i ParseErr parsed ( string_to_int trimmed )
            ( string_free trimmed )
            ?? parsed {
                T n → {
                    ? > n 0 { ^ n } {}
                }
                F _ → {}
            }
        }
        F → {}
    }
    ^ 0
}

@ agent_max_turns → i {
    : i env_turns ( agent_max_turns_env_value `HERMES_NURL_AGENT_MAX_TURNS` )
    ? > env_turns 0 { ^ ( agent_clamp_max_turns env_turns ) } {}
    : i configured ( hermes_config_agent_max_turns )
    ? > configured 0 { ^ ( agent_clamp_max_turns configured ) } {}
    ^ ( AGENT_MAX_TURNS )
}

@ agent_clamp_retries i n → i {
    ? < n 1 { ^ 1 } {}
    ? > n 8 { ^ 8 } {}
    ^ n
}

@ agent_api_max_retries_env_value s name → i {
    : ?String got ( env_get name )
    ?? got {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            : !i ParseErr parsed ( string_to_int trimmed )
            ( string_free trimmed )
            ?? parsed {
                T n → {
                    ? > n 0 { ^ n } {}
                }
                F _ → {}
            }
        }
        F → {}
    }
    ^ 0
}

@ agent_api_max_retries → i {
    : i env_retries ( agent_api_max_retries_env_value `HERMES_NURL_API_MAX_RETRIES` )
    ? > env_retries 0 { ^ ( agent_clamp_retries env_retries ) } {}
    : i configured ( hermes_config_agent_api_max_retries )
    ? > configured 0 { ^ ( agent_clamp_retries configured ) } {}
    ^ 3
}

@ claude_err_retryable ClaudeErr e → b {
    ^ ?? e {
        ClaudeHttpConnect → T
        ClaudeHttpTimeout → T
        ClaudeHttpDns → T
        ClaudeHttpOther → T
        ClaudeApi → F
        _ → F
    }
}

@ openai_compat_err_retryable OpenAICompatErr e → b {
    ^ ?? e {
        OpenAICompatHttpConnect → T
        OpenAICompatHttpTimeout → T
        OpenAICompatHttpDns → T
        OpenAICompatHttpOther → T
        OpenAICompatRateLimit → T
        OpenAICompatOverloaded → T
        OpenAICompatServer → T
        _ → F
    }
}

@ agent_retry_delay_ms i attempt → i {
    : i delay * attempt 250
    ? > delay 2000 { ^ 2000 } {}
    ^ delay
}

@ trace_retry s provider s err_name i attempt i max_retries → v {
    : String detail ( string_with_cap 96 )
    ( string_push_str detail provider )
    ( string_push_str detail ` ` )
    ( string_push_str detail err_name )
    ( string_push_str detail ` attempt=` )
    ( string_push_int detail attempt )
    ( string_push_str detail `/` )
    ( string_push_int detail max_retries )
    ( trace_event `api_retry` ( string_data detail ) )
    ( string_free detail )
}

@ agent_set_fallback_safe b safe → v {
    ? safe {
        : !v IoErr r ( env_set `HERMES_NURL_FALLBACK_SAFE` `1` )
        ?? r { T _ → {} F _ → {} }
    } {
        : !v IoErr r2 ( env_set `HERMES_NURL_FALLBACK_SAFE` `0` )
        ?? r2 { T _ → {} F _ → {} }
    }
}

@ agent_fallback_safe → b {
    ^ ( env_truthy `HERMES_NURL_FALLBACK_SAFE` )
}

@ agent_restore_env s name ? String old → v {
    ?? old {
        T value → {
            : !v IoErr r ( env_set name ( string_data value ) )
            ?? r { T _ → {} F _ → {} }
            ( string_free value )
        }
        F → {
            : !v IoErr r2 ( env_unset name )
            ?? r2 { T _ → {} F _ → {} }
        }
    }
}

@ agent_set_env_if_nonempty s name s value → v {
    ? > ( nurl_str_len value ) 0 {
        : !v IoErr r ( env_set name value )
        ?? r { T _ → {} F _ → {} }
    } {}
}

@ agent_set_env_int_if_positive s name i value → v {
    ? > value 0 {
        : String rendered ( string_from ( nurl_str_int value ) )
        : !v IoErr r ( env_set name ( string_data rendered ) )
        ?? r { T _ → {} F _ → {} }
        ( string_free rendered )
    } {}
}

@ agent_stdout_events_enabled → b {
    ^ ( env_truthy `HERMES_NURL_STDOUT_EVENTS` )
}

@ agent_event_log_env_missing s name → b {
    : ?String got ( env_get name )
    ?? got {
        T value → {
            : b missing ? <= ( string_len value ) 0 T F
            ( string_free value )
            ^ missing
        }
        F → {
            ^ T
        }
    }
}

@ agent_events_ensure_default_logs → v {
    ? ( agent_event_log_env_missing `HERMES_NURL_TRACE` ) {
        : String trace_path ( hermes_path `events-trace.jsonl` )
        : !v IoErr sr ( env_set `HERMES_NURL_TRACE` ( string_data trace_path ) )
        ?? sr { T _ → {} F _ → {} }
        ( string_free trace_path )
    } {}
    ? ( agent_event_log_env_missing `HERMES_NURL_SESSION_LOG` ) {
        : String session_path ( hermes_path `events-session.jsonl` )
        : !v IoErr sr2 ( env_set `HERMES_NURL_SESSION_LOG` ( string_data session_path ) )
        ?? sr2 { T _ → {} F _ → {} }
        ( string_free session_path )
    } {}
}

@ agent_emit_event_text s event_type s field s value → v {
    ? ( agent_stdout_events_enabled ) {
        : Json evt ( json_obj_new )
        ( json_obj_set evt `type` ( json_str_lit event_type ) )
        ( json_obj_set evt field ( json_str_lit value ) )
        : String line ( json_stringify evt )
        ( nurl_print ( string_data line ) )
        ( nurl_print `\n` )
        ( string_free line )
        ( json_free evt )
    } {}
}

@ agent_emit_event_int s event_type s field i value → v {
    ? ( agent_stdout_events_enabled ) {
        : Json evt ( json_obj_new )
        ( json_obj_set evt `type` ( json_str_lit event_type ) )
        ( json_obj_set evt field ( json_int value ) )
        : String line ( json_stringify evt )
        ( nurl_print ( string_data line ) )
        ( nurl_print `\n` )
        ( string_free line )
        ( json_free evt )
    } {}
}

@ agent_emit_tool_event s name s id → v {
    ? ( agent_stdout_events_enabled ) {
        : Json evt ( json_obj_new )
        ( json_obj_set evt `type` ( json_str_lit `tool` ) )
        ( json_obj_set evt `name` ( json_str_lit name ) )
        ( json_obj_set evt `id` ( json_str_lit id ) )
        : String line ( json_stringify evt )
        ( nurl_print ( string_data line ) )
        ( nurl_print `\n` )
        ( string_free line )
        ( json_free evt )
    } {}
}

@ agent_emit_usage_event i input_tokens i output_tokens i turns → v {
    ? ( agent_stdout_events_enabled ) {
        : Json evt ( json_obj_new )
        ( json_obj_set evt `type` ( json_str_lit `usage` ) )
        ( json_obj_set evt `input_tokens` ( json_int input_tokens ) )
        ( json_obj_set evt `output_tokens` ( json_int output_tokens ) )
        ( json_obj_set evt `turns` ( json_int turns ) )
        : String line ( json_stringify evt )
        ( nurl_print ( string_data line ) )
        ( nurl_print `\n` )
        ( string_free line )
        ( json_free evt )
    } {}
}

@ agent_print_final s final_text → v {
    ? ( agent_stdout_events_enabled ) {
        ( agent_emit_event_text `final` `text` final_text )
    } {
        ( nurl_print final_text )
        ( nurl_print `\n` )
    }
}

@ anthropic_messages_with_retries
s api_key
String model
String system_prompt
( Vec Json ) msgs
( Vec Json ) tools
i max_tokens
→ !Json ClaudeErr {
    : i max_retries ( agent_api_max_retries )
    : ~ i attempt 1
    : ~ b keep T
    ~ keep {
        : !Json ClaudeErr r ( anthropic_messages api_key ( string_data model ) ( string_data system_prompt ) msgs tools `auto` max_tokens )
        ?? r {
            T resp → {
                ^ @ !Json ClaudeErr { T resp }
            }
            F e → {
                : ClaudeErr ce # ClaudeErr e
                ? & < attempt max_retries ( claude_err_retryable ce ) {
                    ( nurl_eprint `[hermes-nurl] retrying API call after ` )
                    ( nurl_eprint ( claude_err_name ce ) )
                    ( nurl_eprint ` (` )
                    ( nurl_eprint ( nurl_str_int attempt ) )
                    ( nurl_eprint `/` )
                    ( nurl_eprint ( nurl_str_int max_retries ) )
                    ( nurl_eprint `)\n` )
                    ( trace_retry `anthropic` ( claude_err_name ce ) attempt max_retries )
                    ( sleep_ms ( agent_retry_delay_ms attempt ) )
                    = attempt + attempt 1
                } {
                    ^ @ !Json ClaudeErr { F ce }
                }
            }
        }
    }
    ^ @ !Json ClaudeErr { F @ ClaudeErr { ClaudeShape } }
}

@ openai_compat_chat_with_retries
s api_key
String model
( Vec Json ) msgs
( Vec Json ) tools
i max_tokens
→ !Json OpenAICompatErr {
    : i max_retries ( agent_api_max_retries )
    : ~ i attempt 1
    : ~ b keep T
    ~ keep {
        : !Json OpenAICompatErr r ( openai_compat_chat api_key ( string_data model ) msgs tools `auto` max_tokens )
        ?? r {
            T resp → {
                ^ @ !Json OpenAICompatErr { T resp }
            }
            F e → {
                : OpenAICompatErr oe # OpenAICompatErr e
                ? & < attempt max_retries ( openai_compat_err_retryable oe ) {
                    ( nurl_eprint `[hermes-nurl] retrying API call after ` )
                    ( nurl_eprint ( openai_compat_err_name oe ) )
                    ( nurl_eprint ` (` )
                    ( nurl_eprint ( nurl_str_int attempt ) )
                    ( nurl_eprint `/` )
                    ( nurl_eprint ( nurl_str_int max_retries ) )
                    ( nurl_eprint `)\n` )
                    ( trace_retry `openai-compatible` ( openai_compat_err_name oe ) attempt max_retries )
                    ( sleep_ms ( agent_retry_delay_ms attempt ) )
                    = attempt + attempt 1
                } {
                    ^ @ !Json OpenAICompatErr { F oe }
                }
            }
        }
    }
    ^ @ !Json OpenAICompatErr { F @ OpenAICompatErr { OpenAICompatShape } }
}

@ anthropic_messages_url_with_retries
s url
s api_key
String model
String system_prompt
( Vec Json ) msgs
( Vec Json ) tools
i max_tokens
→ !Json ClaudeErr {
    : i max_retries ( agent_api_max_retries )
    : ~ i attempt 1
    : ~ b keep T
    ~ keep {
        : !Json ClaudeErr r ( anthropic_messages_to_url url api_key ( string_data model ) ( string_data system_prompt ) msgs tools `auto` max_tokens )
        ?? r {
            T resp → {
                ^ @ !Json ClaudeErr { T resp }
            }
            F e → {
                : ClaudeErr ce # ClaudeErr e
                ? & < attempt max_retries ( claude_err_retryable ce ) {
                    ( nurl_eprint `[hermes-nurl] retrying summary API call after ` )
                    ( nurl_eprint ( claude_err_name ce ) )
                    ( nurl_eprint ` (` )
                    ( nurl_eprint ( nurl_str_int attempt ) )
                    ( nurl_eprint `/` )
                    ( nurl_eprint ( nurl_str_int max_retries ) )
                    ( nurl_eprint `)\n` )
                    ( trace_retry `anthropic-summary` ( claude_err_name ce ) attempt max_retries )
                    ( sleep_ms ( agent_retry_delay_ms attempt ) )
                    = attempt + attempt 1
                } {
                    ^ @ !Json ClaudeErr { F ce }
                }
            }
        }
    }
    ^ @ !Json ClaudeErr { F @ ClaudeErr { ClaudeShape } }
}

@ openai_compat_chat_url_with_retries
s url
s api_key
String model
( Vec Json ) msgs
( Vec Json ) tools
i max_tokens
→ !Json OpenAICompatErr {
    : i max_retries ( agent_api_max_retries )
    : ~ i attempt 1
    : ~ b keep T
    ~ keep {
        : !Json OpenAICompatErr r ( openai_compat_chat_to_url url api_key ( string_data model ) msgs tools `auto` max_tokens )
        ?? r {
            T resp → {
                ^ @ !Json OpenAICompatErr { T resp }
            }
            F e → {
                : OpenAICompatErr oe # OpenAICompatErr e
                ? & < attempt max_retries ( openai_compat_err_retryable oe ) {
                    ( nurl_eprint `[hermes-nurl] retrying summary API call after ` )
                    ( nurl_eprint ( openai_compat_err_name oe ) )
                    ( nurl_eprint ` (` )
                    ( nurl_eprint ( nurl_str_int attempt ) )
                    ( nurl_eprint `/` )
                    ( nurl_eprint ( nurl_str_int max_retries ) )
                    ( nurl_eprint `)\n` )
                    ( trace_retry `openai-compatible-summary` ( openai_compat_err_name oe ) attempt max_retries )
                    ( sleep_ms ( agent_retry_delay_ms attempt ) )
                    = attempt + attempt 1
                } {
                    ^ @ !Json OpenAICompatErr { F oe }
                }
            }
        }
    }
    ^ @ !Json OpenAICompatErr { F @ OpenAICompatErr { OpenAICompatShape } }
}

@ agent_set_session_id s session_id → v {
    ? > ( nurl_str_len session_id ) 0 {
        : !v IoErr r ( env_set `HERMES_NURL_SESSION_ID` session_id )
        ?? r {
            T _ → {}
            F _ → {
                ( nurl_eprint `[hermes-nurl] warning: could not set HERMES_NURL_SESSION_ID\n` )
            }
        }
    } {}
}

@ agent_trace_resume s session_id i rows → v {
    : String detail ( string_with_cap 96 )
    ( string_push_str detail session_id )
    ( string_push_str detail ` rows=` )
    ( string_push_int detail rows )
    ( trace_event `session_resume` ( string_data detail ) )
    ( string_free detail )
}

@ agent_context_preflight s provider String model i request_tokens i max_tokens → b {
    : i context_len ( model_context_length ( string_data model ) )
    : i max_request ( context_max_request_tokens context_len max_tokens )
    ? <= request_tokens max_request { ^ T } {}

    : String detail ( string_with_cap 128 )
    ( string_push_str detail provider )
    ( string_push_str detail ` request_tokens=` )
    ( string_push_int detail request_tokens )
    ( string_push_str detail ` max_request_tokens=` )
    ( string_push_int detail max_request )
    ( string_push_str detail ` context_length=` )
    ( string_push_int detail context_len )
    ( string_push_str detail ` max_tokens=` )
    ( string_push_int detail max_tokens )
    ( trace_event `context_overflow` ( string_data detail ) )
    ( session_event `agent_error` ( string_data detail ) )

    ( nurl_eprint `[hermes-nurl] error: request is over the model context budget after preflight (` )
    ( nurl_eprint ( nurl_str_int request_tokens ) )
    ( nurl_eprint `/` )
    ( nurl_eprint ( nurl_str_int max_request ) )
    ( nurl_eprint ` estimated input tokens; lower max_tokens, prune history, or resume with a shorter session)\n` )
    ( string_free detail )
    ^ F
}

@ agent_log_compression_metric s provider s stage i before_tokens i after_tokens i changed_count → v {
    : String detail ( string_with_cap 160 )
    ( string_push_str detail `provider=` )
    ( string_push_str detail provider )
    ( string_push_str detail ` stage=` )
    ( string_push_str detail stage )
    ( string_push_str detail ` before_tokens=` )
    ( string_push_int detail before_tokens )
    ( string_push_str detail ` after_tokens=` )
    ( string_push_int detail after_tokens )
    ( string_push_str detail ` saved_tokens=` )
    ( string_push_int detail - before_tokens after_tokens )
    ( string_push_str detail ` changed_count=` )
    ( string_push_int detail changed_count )
    ( trace_event `context_compression_metric` ( string_data detail ) )
    ( session_event `compression` ( string_data detail ) )
    ( string_free detail )
}

@ agent_log_compression_remaining s provider i tokens i threshold → v {
    : String detail ( string_with_cap 96 )
    ( string_push_str detail `provider=` )
    ( string_push_str detail provider )
    ( string_push_str detail ` tokens=` )
    ( string_push_int detail tokens )
    ( string_push_str detail ` threshold=` )
    ( string_push_int detail threshold )
    ( trace_event `context_compression_remaining` ( string_data detail ) )
    ( session_event `compression_remaining` ( string_data detail ) )
    ( string_free detail )
}

@ agent_summary_max_tokens String model i max_tokens → i {
    : i context_len ( model_context_length ( string_data model ) )
    : ~ i out ( context_max_summary_tokens context_len )
    ? & > max_tokens 0 > out max_tokens {
        = out max_tokens
    } {}
    ? < out 256 { = out 256 } {}
    ^ out
}

@ agent_env_nonempty s name → ?String {
    : ?String got ( env_get name )
    ?? got {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            ? > ( string_len trimmed ) 0 {
                ^ @ ?String { T trimmed }
            } {}
            ( string_free trimmed )
        }
        F → {}
    }
    ^ @ ?String { F # String 0 }
}

@ agent_provider_same_family s a s b → b {
    ? & ( hermes_provider_is_openai_compat a ) ( hermes_provider_is_openai_compat b ) { ^ T } {}
    ? & ( hermes_provider_is_anthropic_compat a ) ( hermes_provider_is_anthropic_compat b ) { ^ T } {}
    ^ F
}

@ agent_summary_provider_or s active_provider → String {
    : String configured ( context_summary_provider )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ^ ( string_from active_provider )
}

@ agent_summary_model_or s summary_provider s active_provider String active_model → String {
    : String configured ( context_summary_model )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ? ( agent_provider_same_family summary_provider active_provider ) {
        ^ ( string_from ( string_data active_model ) )
    } {}
    ? ( hermes_provider_is_openai_compat summary_provider ) {
        ^ ( openai_compat_model_from_env )
    } {}
    ^ ( anthropic_model_from_env )
}

@ agent_summary_base_url_or s summary_provider → String {
    : String configured ( context_summary_base_url )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ? ( hermes_provider_is_openai_compat summary_provider ) {
        ^ ( openai_compat_base_url_from_env )
    } {}
    ^ ( anthropic_base_url_from_env )
}

@ agent_summary_api_key_for s summary_provider s active_provider s active_api_key → ?String {
    ? ( hermes_provider_is_openai_compat summary_provider ) {
        : ?String scoped ( agent_env_nonempty `HERMES_NURL_COMPRESSION_SUMMARY_OPENAI_API_KEY` )
        ?? scoped {
            T key → { ^ @ ?String { T key } }
            F → {}
        }
        ? ( agent_provider_same_family summary_provider active_provider ) {
            ^ @ ?String { T ( string_from active_api_key ) }
        } {}
        ^ ( openai_compat_api_key_from_env )
    } {}

    ? ( hermes_provider_is_anthropic_compat summary_provider ) {
        : ?String scoped2 ( agent_env_nonempty `HERMES_NURL_COMPRESSION_SUMMARY_ANTHROPIC_API_KEY` )
        ?? scoped2 {
            T key2 → { ^ @ ?String { T key2 } }
            F → {}
        }
        ? ( agent_provider_same_family summary_provider active_provider ) {
            ^ @ ?String { T ( string_from active_api_key ) }
        } {}
        ^ ( anthropic_api_key_from_env )
    } {}

    ^ @ ?String { F # String 0 }
}

@ agent_trace_summary_range s provider i start i end i before_tokens → v {
    : String detail ( string_with_cap 128 )
    ( string_push_str detail provider )
    ( string_push_str detail ` messages=` )
    ( string_push_int detail start )
    ( string_push_str detail `..` )
    ( string_push_int detail - end 1 )
    ( string_push_str detail ` before_tokens=` )
    ( string_push_int detail before_tokens )
    ( trace_event `context_summary_start` ( string_data detail ) )
    ( string_free detail )
}

@ agent_trace_summary_skip s provider s reason i candidate_tokens i expected_tokens i min_input i min_savings → v {
    : String detail ( string_with_cap 160 )
    ( string_push_str detail `provider=` )
    ( string_push_str detail provider )
    ( string_push_str detail ` reason=` )
    ( string_push_str detail reason )
    ( string_push_str detail ` candidate_tokens=` )
    ( string_push_int detail candidate_tokens )
    ( string_push_str detail ` expected_summary_tokens=` )
    ( string_push_int detail expected_tokens )
    ( string_push_str detail ` min_input_tokens=` )
    ( string_push_int detail min_input )
    ( string_push_str detail ` min_savings_tokens=` )
    ( string_push_int detail min_savings )
    ( trace_event `context_summary_skipped` ( string_data detail ) )
    ( session_event `compression_skipped` ( string_data detail ) )
    ( string_free detail )
}

@ agent_anthropic_summary_text s api_key String model String base_url ( Vec Json ) msgs i before_tokens i max_tokens → String {
    : String empty ( string_from `` )
    ? ! ( context_summary_enabled ) { ^ empty } {}
    : i start ( context_compaction_range_start msgs )
    ? < start 0 { ^ empty } {}
    : i end ( context_compaction_range_end msgs start )
    ? <= end start { ^ empty } {}

    ( agent_trace_summary_range `anthropic` start end before_tokens )
    : String source ( context_make_compaction_source msgs start end before_tokens )
    : ( Vec Json ) summary_msgs ( vec_new [Json] )
    ( vec_push [Json] summary_msgs ( claude_msg_user_text ( string_data source ) ) )
    ( string_free source )
    : ( Vec Json ) empty_tools ( vec_new [Json] )
    : i summary_tokens ( agent_summary_max_tokens model max_tokens )
    : String summary_system ( string_from ( CONTEXT_SUMMARY_SYSTEM_PROMPT ) )
    : String url ( anthropic_messages_url_from_base ( string_from ( string_data base_url ) ) )
    : ?String old_timeout ( env_get `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` )
    : ?String old_connect_timeout ( env_get `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` )
    ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` ( context_summary_api_timeout_ms ) )
    ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` ( context_summary_api_connect_timeout_ms ) )
    : !Json ClaudeErr r ( anthropic_messages_url_with_retries ( string_data url ) api_key model summary_system summary_msgs empty_tools summary_tokens )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` old_timeout )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` old_connect_timeout )
    ( string_free url )
    ( string_free summary_system )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    ( vec_free_with [Json] summary_msgs drop_json )
    ( vec_free_with [Json] empty_tools drop_json )
    ?? r {
        T resp → {
            : s text ( claude_text resp )
            ? > ( nurl_str_len text ) 0 {
                ( string_free empty )
                : String out ( string_from text )
                ( claude_response_free resp )
                ( trace_event_int `context_summary_chars` ( string_len out ) )
                ^ out
            } {}
            ( claude_response_free resp )
            ( trace_event `context_summary_error` `anthropic_empty_summary` )
        }
        F e → {
            : ClaudeErr ce # ClaudeErr e
            ( trace_event `context_summary_error` ( claude_err_name ce ) )
        }
    }
    ^ empty
}

@ agent_openai_summary_text s api_key String model String base_url ( Vec Json ) msgs i before_tokens i max_tokens → String {
    : String empty ( string_from `` )
    ? ! ( context_summary_enabled ) { ^ empty } {}
    : i start ( context_compaction_range_start msgs )
    ? < start 0 { ^ empty } {}
    : i end ( context_compaction_range_end msgs start )
    ? <= end start { ^ empty } {}

    ( agent_trace_summary_range `openai-compatible` start end before_tokens )
    : String source ( context_make_compaction_source msgs start end before_tokens )
    : ( Vec Json ) summary_msgs ( vec_new [Json] )
    ( vec_push [Json] summary_msgs ( openai_compat_msg `system` ( CONTEXT_SUMMARY_SYSTEM_PROMPT ) ) )
    ( vec_push [Json] summary_msgs ( openai_compat_msg `user` ( string_data source ) ) )
    ( string_free source )
    : ( Vec Json ) empty_tools ( vec_new [Json] )
    : i summary_tokens ( agent_summary_max_tokens model max_tokens )
    : String url ( openai_compat_chat_url_from_base ( string_from ( string_data base_url ) ) )
    : ?String old_timeout ( env_get `HERMES_NURL_OPENAI_TIMEOUT_MS` )
    : ?String old_connect_timeout ( env_get `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` )
    ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_TIMEOUT_MS` ( context_summary_api_timeout_ms ) )
    ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` ( context_summary_api_connect_timeout_ms ) )
    : !Json OpenAICompatErr r ( openai_compat_chat_url_with_retries ( string_data url ) api_key model summary_msgs empty_tools summary_tokens )
    ( agent_restore_env `HERMES_NURL_OPENAI_TIMEOUT_MS` old_timeout )
    ( agent_restore_env `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` old_connect_timeout )
    ( string_free url )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    ( vec_free_with [Json] summary_msgs drop_json )
    ( vec_free_with [Json] empty_tools drop_json )
    ?? r {
        T resp → {
            : s text ( openai_compat_text resp )
            ? > ( nurl_str_len text ) 0 {
                ( string_free empty )
                : String out ( string_from text )
                ( openai_compat_response_free resp )
                ( trace_event_int `context_summary_chars` ( string_len out ) )
                ^ out
            } {}
            ( openai_compat_response_free resp )
            ( trace_event `context_summary_error` `openai_compatible_empty_summary` )
        }
        F e → {
            : OpenAICompatErr oe # OpenAICompatErr e
            ( trace_event `context_summary_error` ( openai_compat_err_name oe ) )
        }
    }
    ^ empty
}

@ agent_summary_text s active_provider s active_api_key String active_model ( Vec Json ) msgs i before_tokens i max_tokens → String {
    : String empty ( string_from `` )
    ? ! ( context_summary_enabled ) { ^ empty } {}
    : String summary_provider ( agent_summary_provider_or active_provider )
    : String summary_model ( agent_summary_model_or ( string_data summary_provider ) active_provider active_model )
    : String summary_base_url ( agent_summary_base_url_or ( string_data summary_provider ) )
    : i summary_tokens ( agent_summary_max_tokens summary_model max_tokens )
    : i candidate_tokens ( context_compaction_candidate_tokens msgs )
    : i expected_tokens ( context_summary_expected_tokens candidate_tokens summary_tokens )
    : i estimated_savings ( context_summary_estimated_savings candidate_tokens expected_tokens )
    : i min_input ( context_summary_min_input_tokens )
    : i min_savings ( context_summary_min_savings_tokens )
    ? < candidate_tokens min_input {
        ( agent_trace_summary_skip ( string_data summary_provider ) `low_input` candidate_tokens expected_tokens min_input min_savings )
        ( string_free summary_provider )
        ( string_free summary_model )
        ( string_free summary_base_url )
        ^ empty
    } {}
    ? < estimated_savings min_savings {
        ( agent_trace_summary_skip ( string_data summary_provider ) `low_savings` candidate_tokens expected_tokens min_input min_savings )
        ( string_free summary_provider )
        ( string_free summary_model )
        ( string_free summary_base_url )
        ^ empty
    } {}
    : ?String key ( agent_summary_api_key_for ( string_data summary_provider ) active_provider active_api_key )
    : s api_key ?? key {
        T k → ( string_data k )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        : String detail ( string_from `missing summary api key for ` )
        ( string_push_str detail ( string_data summary_provider ) )
        ( trace_event `context_summary_error` ( string_data detail ) )
        ( string_free detail )
        ( string_free summary_provider )
        ( string_free summary_model )
        ( string_free summary_base_url )
        ?? key { T k2 → ( string_free k2 ) F → {} }
        ^ empty
    } {}

    ( trace_event `context_summary_provider` ( string_data summary_provider ) )
    ( trace_event `context_summary_model` ( string_data summary_model ) )
    ( trace_event `context_summary_base_url` ( string_data summary_base_url ) )
    : String out ? ( hermes_provider_is_openai_compat ( string_data summary_provider ) ) {
        ( agent_openai_summary_text api_key summary_model summary_base_url msgs before_tokens max_tokens )
    } {
        ? ( hermes_provider_is_anthropic_compat ( string_data summary_provider ) ) {
            ( agent_anthropic_summary_text api_key summary_model summary_base_url msgs before_tokens max_tokens )
        } {
            : String msg ( string_from `unsupported summary provider ` )
            ( string_push_str msg ( string_data summary_provider ) )
            ( trace_event `context_summary_error` ( string_data msg ) )
            ( string_free msg )
            ( string_new )
        }
    }
    ( string_free empty )
    ( string_free summary_provider )
    ( string_free summary_model )
    ( string_free summary_base_url )
    ?? key { T k3 → ( string_free k3 ) F → {} }
    ^ out
}

@ agent_apply_summary s active_provider s api_key String model ( Vec Json ) msgs i before_tokens i max_tokens → i {
    : String summary ( agent_summary_text active_provider api_key model msgs before_tokens max_tokens )
    : i compacted ( context_compact_middle_with_summary msgs before_tokens summary )
    ( string_free summary )
    ? > compacted 0 {
        ( trace_event_int `context_summarized_messages` compacted )
        ( nurl_eprint `[hermes-nurl] summarized ` )
        ( nurl_eprint ( nurl_str_int compacted ) )
        ( nurl_eprint ` middle message(s) with a no-tool model call\n` )
    } {}
    ^ compacted
}

@ run_anthropic_turn s api_key String model String system_prompt ( Vec Json ) msgs ( Vec Json ) tools i max_tokens → i {
    : ~ i turn 0
    : ~ b done F
    : ~ i exit_code 1
    : ~ i total_in 0
    : ~ i total_out 0
    : ~ b context_warned F
    : i max_turns ( agent_max_turns )

    ~ & ! done < turn max_turns {
        ( nurl_eprint `[hermes-nurl] turn ` )
        ( nurl_eprint ( nurl_str_int turn ) )
        ( nurl_eprint `\n` )
        ( agent_emit_event_int `turn` `turn` turn )
        ( trace_event_int `turn_start` turn )

        : i request_tokens ( context_request_tokens ( string_data system_prompt ) msgs tools )
        : i context_len ( model_context_length ( string_data model ) )
        : i threshold ( context_threshold_tokens context_len )
        ( trace_event_int `context_request_tokens` request_tokens )
        ? & ( context_compression_enabled ) >= request_tokens threshold {
            : i pruned ( context_prune_old_tool_results msgs )
            ? > pruned 0 {
                ( trace_event_int `context_pruned_tool_results` pruned )
                : i before_prune_tokens request_tokens
                = request_tokens ( context_request_tokens ( string_data system_prompt ) msgs tools )
                ( trace_event_int `context_request_tokens_after_prune` request_tokens )
                ( agent_log_compression_metric `anthropic` `prune_tool_results` before_prune_tokens request_tokens pruned )
            } {}
            ? >= request_tokens threshold {
                : i before_summary_tokens request_tokens
                : i summarized ( agent_apply_summary `anthropic` api_key model msgs request_tokens max_tokens )
                ? > summarized 0 {
                    = request_tokens ( context_request_tokens ( string_data system_prompt ) msgs tools )
                    ( trace_event_int `context_request_tokens_after_summary` request_tokens )
                    ( agent_log_compression_metric `anthropic` `provider_summary` before_summary_tokens request_tokens summarized )
                } {}
            } {}
            ? >= request_tokens threshold {
                : i before_compaction_tokens request_tokens
                : i compacted ( context_compact_middle msgs request_tokens )
                ? > compacted 0 {
                    ( trace_event_int `context_compacted_messages` compacted )
                    = request_tokens ( context_request_tokens ( string_data system_prompt ) msgs tools )
                    ( trace_event_int `context_request_tokens_after_compaction` request_tokens )
                    ( agent_log_compression_metric `anthropic` `deterministic_summary` before_compaction_tokens request_tokens compacted )
                    ( nurl_eprint `[hermes-nurl] compacted ` )
                    ( nurl_eprint ( nurl_str_int compacted ) )
                    ( nurl_eprint ` middle message(s) into a context summary\n` )
                } {}
            } {}
            ? & >= request_tokens threshold ! context_warned {
                ( nurl_eprint `[hermes-nurl] context budget still over threshold after compression passes\n` )
                ( agent_log_compression_remaining `anthropic` request_tokens threshold )
                = context_warned T
            } {}
        } {}

        ? ( agent_context_preflight `anthropic` model request_tokens max_tokens ) {
            : !Json ClaudeErr r ( anthropic_messages_with_retries api_key model system_prompt msgs tools max_tokens )
            ?? r {
                T resp → {
                    = total_in + total_in ( claude_input_tokens resp )
                    = total_out + total_out ( claude_output_tokens resp )
                    ( vec_push [Json] msgs ( claude_msg_assistant_response resp ) )

                    ? ( claude_has_tool_use resp ) {
                        ( agent_set_fallback_safe F )
                        : ( Vec Json ) tcs ( claude_tool_calls resp )
                        : ( Vec Json ) results ( vec_new [Json] )

                        : i tn ( vec_len [Json] tcs )
                        : ~ i k 0
                        ~ < k tn {
                            : ?Json e ( vec_get [Json] tcs k )
                            ?? e {
                                T tu → {
                                    : s tu_id ( claude_tool_use_id tu )
                                    : s tu_name ( claude_tool_use_name tu )

                                    ( nurl_eprint `[hermes-nurl] tool ` )
                                    ( nurl_eprint tu_name )
                                    ( nurl_eprint ` (` )
                                    ( nurl_eprint tu_id )
                                    ( nurl_eprint `)\n` )
                                    ( agent_emit_tool_event tu_name tu_id )
                                    ( trace_event `tool_call` tu_name )
                                    : ?Json input_for_log ( claude_tool_use_input tu )
                                    ?? input_for_log {
                                        T input_json → { ( session_tool_call_args_json tu_id tu_name input_json ) }
                                        F → { ( session_tool_call tu_id tu_name ) }
                                    }

                                    : ~ b is_err F
                                    ? ( is_agent_tool tu_name ) {} {
                                        = is_err T
                                    }
                                    : String out ( run_agent_claude_tool tu )
                                    : ~ b result_is_err is_err
                                    ? result_is_err {} {
                                        ? ( string_starts_with out `error:` ) { = result_is_err T } {}
                                    }
                                    ( vec_push [Json] results
                                    ( claude_tool_result_block tu_id ( string_data out ) result_is_err ) )
                                    : i result_bytes ( string_len out )
                                    ( trace_event_int `tool_result_bytes` result_bytes )
                                    ( session_tool_result_text tu_id tu_name result_is_err result_bytes ( string_data out ) )
                                    ( string_free out )
                                }
                                F → {}
                            }
                            = k + k 1
                        }
                        : ( @ v Json ) drop_tool_json \ Json e → v { ( json_free e ) }
                        ( vec_free_with [Json] tcs drop_tool_json )
                        ( vec_push [Json] msgs ( claude_msg_user_blocks results ) )
                        ( claude_response_free resp )
                    } {
                        : s final_text ( claude_text resp )
                        ? == ( nurl_str_len final_text ) 0 {
                            ( trace_event `agent_error` `empty_final_text` )
                            ( session_event `agent_error` `empty_final_text` )
                            ( nurl_eprint `[hermes-nurl] error: empty final response\n` )
                            ( agent_emit_event_text `error` `message` `empty final response` )
                            ( claude_response_free resp )
                            = done T
                        } {
                            : String harness_block ( harness_completion_error )
                            ? > ( string_len harness_block ) 0 {
                                ( trace_event `harness_completion_blocked` ( string_data harness_block ) )
                                ( session_event `harness_completion_blocked` ( string_data harness_block ) )
                                ( nurl_eprint `[hermes-nurl] harness completion blocked final response: ` )
                                ( nurl_eprint ( string_data harness_block ) )
                                ( nurl_eprint `\n` )
                                ( vec_push [Json] msgs ( claude_msg_user_text ( string_data harness_block ) ) )
                                ( string_free harness_block )
                                ( claude_response_free resp )
                            } {
                                ( string_free harness_block )
                                ( trace_event `final_text` final_text )
                                ( session_event `assistant` final_text )
                                ( agent_print_final final_text )
                                ( claude_response_free resp )
                                = done T
                                = exit_code 0
                            }
                        }
                    }
                }
                F e → {
                    : ClaudeErr ce # ClaudeErr e
                    ( nurl_eprint `[hermes-nurl] error: ` )
                    ( nurl_eprint ( claude_err_name ce ) )
                    ( nurl_eprint `\n` )
                    ( agent_emit_event_text `error` `message` ( claude_err_name ce ) )
                    ( trace_event `agent_error` ( claude_err_name ce ) )
                    ( session_event `agent_error` ( claude_err_name ce ) )
                    = done T
                }
            }
        } {
            = done T
        }

        = turn + turn 1
    }

    ? & ! done >= turn max_turns {
        ( nurl_eprint `[hermes-nurl] hit AGENT_MAX_TURNS without final reply\n` )
        ( agent_emit_event_text `error` `message` `max turns without final reply` )
        ( trace_event `agent_error` `max_turns` )
        ( session_event `agent_error` `max_turns` )
    } {}

    ( nurl_eprint `[hermes-nurl] tokens in=` )
    ( nurl_eprint ( nurl_str_int total_in ) )
    ( nurl_eprint ` out=` )
    ( nurl_eprint ( nurl_str_int total_out ) )
    ( nurl_eprint ` turns=` )
    ( nurl_eprint ( nurl_str_int turn ) )
    ( nurl_eprint `\n` )
    ( agent_emit_usage_event total_in total_out turn )

    : String summary ( string_with_cap 64 )
    ( string_push_str summary `tokens in=` )
    ( string_push_int summary total_in )
    ( string_push_str summary ` out=` )
    ( string_push_int summary total_out )
    ( string_push_str summary ` turns=` )
    ( string_push_int summary turn )
    ( trace_event `agent_finish` ( string_data summary ) )
    ( string_free summary )
    ^ exit_code
}

@ run_anthropic_agent_core String prompt b record_user → i {
    ? == ( string_len prompt ) 0 {
        ( nurl_print `usage: hermes-nurl [doctor|selftest|chat] <prompt>\n` )
        ( nurl_print `       echo "<prompt>" | hermes-nurl chat\n` )
        ( string_free prompt )
        ^ 1
    } {}
    ? record_user {
        ( session_event `user` ( string_data prompt ) )
    } {}

    : ?String key ( anthropic_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_anthropic_api_key` )
        ( session_event `agent_error` `missing_anthropic_api_key` )
        ( nurl_eprint `error: ANTHROPIC_API_KEY or HERMES_NURL_ANTHROPIC_API_KEY not set\n` )
        ( agent_emit_event_text `error` `message` `missing anthropic api key` )
        ?? key { T s → ( string_free s ) F → {} }
        ( string_free prompt )
        ^ 1
    } {}

    : String model ( anthropic_model_from_env )
    : String system_prompt ( build_system_prompt `anthropic` ( string_data model ) )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    ( trace_event `agent_start` ( string_data model ) )
    : ( Vec Json ) msgs ( vec_new [Json] )
    ( vec_push [Json] msgs ( claude_msg_user_text ( string_data prompt ) ) )
    ( string_free prompt )

    : ( Vec Json ) tools ( build_agent_claude_tools )
    : i max_tokens ( anthropic_max_tokens_from_env )
    : i exit_code ( run_anthropic_turn api_key model system_prompt msgs tools max_tokens )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }

    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }

    ^ exit_code
}

@ run_anthropic_agent String prompt → i {
    ^ ( run_anthropic_agent_core prompt T )
}

@ run_anthropic_agent_resume_core s session_id String prompt b record_user → i {
    ? | == ( nurl_str_len session_id ) 0 == ( string_len prompt ) 0 {
        ( nurl_print `usage: hermes-nurl resume <session-id> <prompt>\n` )
        ( string_free prompt )
        ^ 1
    } {}
    ( agent_set_session_id session_id )

    : String model ( anthropic_model_from_env )
    : String fresh_system_prompt ( build_system_prompt `anthropic` ( string_data model ) )
    : String system_prompt ( session_resume_system_prompt_or session_id fresh_system_prompt )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    ( trace_event `agent_resume_start` ( string_data model ) )
    : ( Vec Json ) msgs ( session_resume_anthropic_messages session_id )
    : i restored ( vec_len [Json] msgs )
    ( agent_trace_resume session_id restored )
    ? == restored 0 {
        ( nurl_eprint `[hermes-nurl] warning: no replayable user/assistant messages found for session ` )
        ( nurl_eprint session_id )
        ( nurl_eprint `\n` )
    } {}
    ? record_user {
        ( session_event `user` ( string_data prompt ) )
    } {}
    ( vec_push [Json] msgs ( claude_msg_user_text ( string_data prompt ) ) )
    ( string_free prompt )

    : ?String key ( anthropic_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_anthropic_api_key` )
        ( session_event `agent_error` `missing_anthropic_api_key` )
        ( nurl_eprint `error: ANTHROPIC_API_KEY or HERMES_NURL_ANTHROPIC_API_KEY not set\n` )
        ( agent_emit_event_text `error` `message` `missing anthropic api key` )
        : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
        ( vec_free_with [Json] msgs drop_json )
        ( string_free system_prompt )
        ( string_free model )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : ( Vec Json ) tools ( build_agent_claude_tools )
    : i max_tokens ( anthropic_max_tokens_from_env )
    : i exit_code ( run_anthropic_turn api_key model system_prompt msgs tools max_tokens )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }

    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }

    ^ exit_code
}

@ run_anthropic_agent_resume s session_id String prompt → i {
    ^ ( run_anthropic_agent_resume_core session_id prompt T )
}

@ run_openai_compat_turn s api_key String model ( Vec Json ) msgs ( Vec Json ) tools i max_tokens → i {
    : ~ i turn 0
    : ~ b done F
    : ~ i exit_code 1
    : ~ i total_in 0
    : ~ i total_out 0
    : ~ b context_warned F
    : i max_turns ( agent_max_turns )

    ~ & ! done < turn max_turns {
        ( nurl_eprint `[hermes-nurl] turn ` )
        ( nurl_eprint ( nurl_str_int turn ) )
        ( nurl_eprint `\n` )
        ( agent_emit_event_int `turn` `turn` turn )
        ( trace_event_int `turn_start` turn )

        : i request_tokens ( context_request_tokens `` msgs tools )
        : i context_len ( model_context_length ( string_data model ) )
        : i threshold ( context_threshold_tokens context_len )
        ( trace_event_int `context_request_tokens` request_tokens )
        ? & ( context_compression_enabled ) >= request_tokens threshold {
            : i pruned ( context_prune_old_tool_results msgs )
            ? > pruned 0 {
                ( trace_event_int `context_pruned_tool_results` pruned )
                : i before_prune_tokens request_tokens
                = request_tokens ( context_request_tokens `` msgs tools )
                ( trace_event_int `context_request_tokens_after_prune` request_tokens )
                ( agent_log_compression_metric `openai-compatible` `prune_tool_results` before_prune_tokens request_tokens pruned )
            } {}
            ? >= request_tokens threshold {
                : i before_summary_tokens request_tokens
                : i summarized ( agent_apply_summary `openai-compatible` api_key model msgs request_tokens max_tokens )
                ? > summarized 0 {
                    = request_tokens ( context_request_tokens `` msgs tools )
                    ( trace_event_int `context_request_tokens_after_summary` request_tokens )
                    ( agent_log_compression_metric `openai-compatible` `provider_summary` before_summary_tokens request_tokens summarized )
                } {}
            } {}
            ? >= request_tokens threshold {
                : i before_compaction_tokens request_tokens
                : i compacted ( context_compact_middle msgs request_tokens )
                ? > compacted 0 {
                    ( trace_event_int `context_compacted_messages` compacted )
                    = request_tokens ( context_request_tokens `` msgs tools )
                    ( trace_event_int `context_request_tokens_after_compaction` request_tokens )
                    ( agent_log_compression_metric `openai-compatible` `deterministic_summary` before_compaction_tokens request_tokens compacted )
                    ( nurl_eprint `[hermes-nurl] compacted ` )
                    ( nurl_eprint ( nurl_str_int compacted ) )
                    ( nurl_eprint ` middle message(s) into a context summary\n` )
                } {}
            } {}
            ? & >= request_tokens threshold ! context_warned {
                ( nurl_eprint `[hermes-nurl] context budget still over threshold after compression passes\n` )
                ( agent_log_compression_remaining `openai-compatible` request_tokens threshold )
                = context_warned T
            } {}
        } {}

        ? ( agent_context_preflight `openai-compatible` model request_tokens max_tokens ) {
            : !Json OpenAICompatErr r ( openai_compat_chat_with_retries api_key model msgs tools max_tokens )
            ?? r {
                T resp → {
                    = total_in + total_in ( openai_compat_input_tokens resp )
                    = total_out + total_out ( openai_compat_output_tokens resp )
                    ( vec_push [Json] msgs ( openai_compat_msg_assistant_response resp ) )

                    ? ( openai_compat_has_tool_calls resp ) {
                        ( agent_set_fallback_safe F )
                        : ( Vec Json ) tcs ( openai_compat_tool_calls resp )

                        : i tn ( vec_len [Json] tcs )
                        : ~ i k 0
                        ~ < k tn {
                            : ?Json e ( vec_get [Json] tcs k )
                            ?? e {
                                T tu → {
                                    : s tu_id ( openai_compat_tool_call_id tu )
                                    : s tu_name ( openai_compat_tool_call_name tu )

                                    ( nurl_eprint `[hermes-nurl] tool ` )
                                    ( nurl_eprint tu_name )
                                    ( nurl_eprint ` (` )
                                    ( nurl_eprint tu_id )
                                    ( nurl_eprint `)\n` )
                                    ( agent_emit_tool_event tu_name tu_id )
                                    ( trace_event `tool_call` tu_name )
                                    ( session_tool_call_openai_json tu_id tu_name tu )

                                    : ~ b is_err F
                                    ? ( is_agent_tool tu_name ) {} {
                                        = is_err T
                                    }
                                    : Json input ( openai_compat_tool_call_input tu )
                                    : String out ( run_agent_tool_input tu_name input )
                                    ( json_free input )
                                    : ~ b result_is_err is_err
                                    ? result_is_err {} {
                                        ? ( string_starts_with out `error:` ) { = result_is_err T } {}
                                    }
                                    ( vec_push [Json] msgs ( openai_compat_msg_tool_result tu_id ( string_data out ) ) )
                                    : i result_bytes ( string_len out )
                                    ( trace_event_int `tool_result_bytes` result_bytes )
                                    ( session_tool_result_text tu_id tu_name result_is_err result_bytes ( string_data out ) )
                                    ( string_free out )
                                }
                                F → {}
                            }
                            = k + k 1
                        }
                        : ( @ v Json ) drop_tool_json \ Json e → v { ( json_free e ) }
                        ( vec_free_with [Json] tcs drop_tool_json )
                        ( openai_compat_response_free resp )
                    } {
                        : s final_text ( openai_compat_text resp )
                        ? == ( nurl_str_len final_text ) 0 {
                            ( trace_event `agent_error` `empty_final_text` )
                            ( session_event `agent_error` `empty_final_text` )
                            ( nurl_eprint `[hermes-nurl] error: empty final response\n` )
                            ( agent_emit_event_text `error` `message` `empty final response` )
                            ( openai_compat_response_free resp )
                            = done T
                        } {
                            : String harness_block ( harness_completion_error )
                            ? > ( string_len harness_block ) 0 {
                                ( trace_event `harness_completion_blocked` ( string_data harness_block ) )
                                ( session_event `harness_completion_blocked` ( string_data harness_block ) )
                                ( nurl_eprint `[hermes-nurl] harness completion blocked final response: ` )
                                ( nurl_eprint ( string_data harness_block ) )
                                ( nurl_eprint `\n` )
                                ( vec_push [Json] msgs ( openai_compat_msg `user` ( string_data harness_block ) ) )
                                ( string_free harness_block )
                                ( openai_compat_response_free resp )
                            } {
                                ( string_free harness_block )
                                ( trace_event `final_text` final_text )
                                ( session_event `assistant` final_text )
                                ( agent_print_final final_text )
                                ( openai_compat_response_free resp )
                                = done T
                                = exit_code 0
                            }
                        }
                    }
                }
                F e → {
                    : OpenAICompatErr oe # OpenAICompatErr e
                    ( nurl_eprint `[hermes-nurl] error: ` )
                    ( nurl_eprint ( openai_compat_err_name oe ) )
                    ( nurl_eprint `\n` )
                    ( agent_emit_event_text `error` `message` ( openai_compat_err_name oe ) )
                    ( trace_event `agent_error` ( openai_compat_err_name oe ) )
                    ( session_event `agent_error` ( openai_compat_err_name oe ) )
                    = done T
                }
            }
        } {
            = done T
        }

        = turn + turn 1
    }

    ? & ! done >= turn max_turns {
        ( nurl_eprint `[hermes-nurl] hit AGENT_MAX_TURNS without final reply\n` )
        ( agent_emit_event_text `error` `message` `max turns without final reply` )
        ( trace_event `agent_error` `max_turns` )
        ( session_event `agent_error` `max_turns` )
    } {}

    ( nurl_eprint `[hermes-nurl] tokens in=` )
    ( nurl_eprint ( nurl_str_int total_in ) )
    ( nurl_eprint ` out=` )
    ( nurl_eprint ( nurl_str_int total_out ) )
    ( nurl_eprint ` turns=` )
    ( nurl_eprint ( nurl_str_int turn ) )
    ( nurl_eprint `\n` )
    ( agent_emit_usage_event total_in total_out turn )

    : String summary ( string_with_cap 64 )
    ( string_push_str summary `tokens in=` )
    ( string_push_int summary total_in )
    ( string_push_str summary ` out=` )
    ( string_push_int summary total_out )
    ( string_push_str summary ` turns=` )
    ( string_push_int summary turn )
    ( trace_event `agent_finish` ( string_data summary ) )
    ( string_free summary )
    ^ exit_code
}

@ run_openai_compat_agent_core String prompt b record_user → i {
    ? == ( string_len prompt ) 0 {
        ( nurl_print `usage: hermes-nurl [doctor|selftest|chat] <prompt>\n` )
        ( nurl_print `       echo "<prompt>" | hermes-nurl chat\n` )
        ( string_free prompt )
        ^ 1
    } {}
    ? record_user {
        ( session_event `user` ( string_data prompt ) )
    } {}

    : ?String key ( openai_compat_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_openai_compatible_api_key` )
        ( session_event `agent_error` `missing_openai_compatible_api_key` )
        ( nurl_eprint `error: OPENAI_API_KEY or HERMES_NURL_OPENAI_API_KEY not set\n` )
        ( agent_emit_event_text `error` `message` `missing openai compatible api key` )
        ?? key { T s → ( string_free s ) F → {} }
        ( string_free prompt )
        ^ 1
    } {}

    : String model ( openai_compat_model_from_env )
    : String system_prompt ( build_system_prompt `openai-compatible` ( string_data model ) )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    ( trace_event `agent_start` ( string_data model ) )
    : ( Vec Json ) msgs ( vec_new [Json] )
    ( vec_push [Json] msgs ( openai_compat_msg `system` ( string_data system_prompt ) ) )
    ( vec_push [Json] msgs ( openai_compat_msg `user` ( string_data prompt ) ) )
    ( string_free prompt )

    : ( Vec Json ) tools ( build_agent_openai_tools )
    : i max_tokens ( openai_compat_max_tokens_from_env )
    : i exit_code ( run_openai_compat_turn api_key model msgs tools max_tokens )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }

    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }

    ^ exit_code
}

@ run_openai_compat_agent String prompt → i {
    ^ ( run_openai_compat_agent_core prompt T )
}

@ run_openai_compat_agent_resume_core s session_id String prompt b record_user → i {
    ? | == ( nurl_str_len session_id ) 0 == ( string_len prompt ) 0 {
        ( nurl_print `usage: hermes-nurl resume <session-id> <prompt>\n` )
        ( string_free prompt )
        ^ 1
    } {}
    ( agent_set_session_id session_id )

    : String model ( openai_compat_model_from_env )
    : String fresh_system_prompt ( build_system_prompt `openai-compatible` ( string_data model ) )
    : String system_prompt ( session_resume_system_prompt_or session_id fresh_system_prompt )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    ( trace_event `agent_resume_start` ( string_data model ) )
    : ( Vec Json ) msgs ( session_resume_openai_messages session_id ( string_data system_prompt ) )
    : i restored - ( vec_len [Json] msgs ) 1
    ( agent_trace_resume session_id restored )
    ? <= restored 0 {
        ( nurl_eprint `[hermes-nurl] warning: no replayable user/assistant messages found for session ` )
        ( nurl_eprint session_id )
        ( nurl_eprint `\n` )
    } {}
    ? record_user {
        ( session_event `user` ( string_data prompt ) )
    } {}
    ( vec_push [Json] msgs ( openai_compat_msg `user` ( string_data prompt ) ) )
    ( string_free prompt )

    : ?String key ( openai_compat_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_openai_compatible_api_key` )
        ( session_event `agent_error` `missing_openai_compatible_api_key` )
        ( nurl_eprint `error: OPENAI_API_KEY or HERMES_NURL_OPENAI_API_KEY not set\n` )
        ( agent_emit_event_text `error` `message` `missing openai compatible api key` )
        : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
        ( vec_free_with [Json] msgs drop_json )
        ( string_free system_prompt )
        ( string_free model )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : ( Vec Json ) tools ( build_agent_openai_tools )
    : i max_tokens ( openai_compat_max_tokens_from_env )
    : i exit_code ( run_openai_compat_turn api_key model msgs tools max_tokens )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }

    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }

    ^ exit_code
}

@ run_openai_compat_agent_resume s session_id String prompt → i {
    ^ ( run_openai_compat_agent_resume_core session_id prompt T )
}

@ repl_line_is_exit String line → b {
    : s raw ( string_data line )
    ? != ( nurl_str_eq raw `/exit` ) 0 { ^ T } {}
    ? != ( nurl_str_eq raw `/quit` ) 0 { ^ T } {}
    ? != ( nurl_str_eq raw `exit` ) 0 { ^ T } {}
    ? != ( nurl_str_eq raw `quit` ) 0 { ^ T } {}
    ^ F
}

@ run_anthropic_repl → i {
    : ?String key ( anthropic_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_anthropic_api_key` )
        ( session_event `agent_error` `missing_anthropic_api_key` )
        ( nurl_eprint `error: ANTHROPIC_API_KEY or HERMES_NURL_ANTHROPIC_API_KEY not set\n` )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : String model ( anthropic_model_from_env )
    : String system_prompt ( build_system_prompt `anthropic` ( string_data model ) )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    : ( Vec Json ) msgs ( vec_new [Json] )
    : ( Vec Json ) tools ( build_agent_claude_tools )
    : i max_tokens ( anthropic_max_tokens_from_env )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    ( trace_event `agent_repl_start` ( string_data model ) )
    ( nurl_print `hermes-nurl repl. Type /exit to quit.\n` )

    : ~ i exit_code 0
    : ~ b done F
    ~ ! done {
        ( nurl_print `hermes-nurl> ` )
        ( flush )
        : String line ( read_line )
        ? & ( stdin_eof ) == ( string_len line ) 0 {
            ( string_free line )
            = done T
        } {
            : String trimmed ( string_trim line )
            ( string_free line )
            ? ( repl_line_is_exit trimmed ) {
                ( string_free trimmed )
                = done T
            } {
                ? == ( string_len trimmed ) 0 {
                    ( string_free trimmed )
                } {
                    ( session_event `user` ( string_data trimmed ) )
                    ( vec_push [Json] msgs ( claude_msg_user_text ( string_data trimmed ) ) )
                    ( string_free trimmed )
                    : i turn_code ( run_anthropic_turn api_key model system_prompt msgs tools max_tokens )
                    ? != turn_code 0 {
                        = exit_code turn_code
                        = done T
                    } {}
                }
            }
        }
    }

    ( trace_event `agent_repl_finish` `done` )
    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }
    ^ exit_code
}

@ run_anthropic_repl_resume s session_id → i {
    ? == ( nurl_str_len session_id ) 0 {
        ( nurl_print `usage: hermes-nurl repl <session-id>\n` )
        ^ 1
    } {}
    ( agent_set_session_id session_id )

    : ?String key ( anthropic_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_anthropic_api_key` )
        ( session_event `agent_error` `missing_anthropic_api_key` )
        ( nurl_eprint `error: ANTHROPIC_API_KEY or HERMES_NURL_ANTHROPIC_API_KEY not set\n` )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : String model ( anthropic_model_from_env )
    : String fresh_system_prompt ( build_system_prompt `anthropic` ( string_data model ) )
    : String system_prompt ( session_resume_system_prompt_or session_id fresh_system_prompt )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    : ( Vec Json ) msgs ( session_resume_anthropic_messages session_id )
    : ( Vec Json ) tools ( build_agent_claude_tools )
    : i max_tokens ( anthropic_max_tokens_from_env )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    : i restored ( vec_len [Json] msgs )
    ( agent_trace_resume session_id restored )
    ( trace_event `agent_repl_resume_start` ( string_data model ) )
    ( nurl_print `hermes-nurl repl resumed ` )
    ( nurl_print session_id )
    ( nurl_print `. Type /exit to quit.\n` )

    : ~ i exit_code 0
    : ~ b done F
    ~ ! done {
        ( nurl_print `hermes-nurl> ` )
        ( flush )
        : String line ( read_line )
        ? & ( stdin_eof ) == ( string_len line ) 0 {
            ( string_free line )
            = done T
        } {
            : String trimmed ( string_trim line )
            ( string_free line )
            ? ( repl_line_is_exit trimmed ) {
                ( string_free trimmed )
                = done T
            } {
                ? == ( string_len trimmed ) 0 {
                    ( string_free trimmed )
                } {
                    ( session_event `user` ( string_data trimmed ) )
                    ( vec_push [Json] msgs ( claude_msg_user_text ( string_data trimmed ) ) )
                    ( string_free trimmed )
                    : i turn_code ( run_anthropic_turn api_key model system_prompt msgs tools max_tokens )
                    ? != turn_code 0 {
                        = exit_code turn_code
                        = done T
                    } {}
                }
            }
        }
    }

    ( trace_event `agent_repl_finish` `done` )
    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }
    ^ exit_code
}

@ run_openai_compat_repl → i {
    : ?String key ( openai_compat_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_openai_compatible_api_key` )
        ( session_event `agent_error` `missing_openai_compatible_api_key` )
        ( nurl_eprint `error: OPENAI_API_KEY or HERMES_NURL_OPENAI_API_KEY not set\n` )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : String model ( openai_compat_model_from_env )
    : String system_prompt ( build_system_prompt `openai-compatible` ( string_data model ) )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    : ( Vec Json ) msgs ( vec_new [Json] )
    ( vec_push [Json] msgs ( openai_compat_msg `system` ( string_data system_prompt ) ) )
    : ( Vec Json ) tools ( build_agent_openai_tools )
    : i max_tokens ( openai_compat_max_tokens_from_env )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    ( trace_event `agent_repl_start` ( string_data model ) )
    ( nurl_print `hermes-nurl repl. Type /exit to quit.\n` )

    : ~ i exit_code 0
    : ~ b done F
    ~ ! done {
        ( nurl_print `hermes-nurl> ` )
        ( flush )
        : String line ( read_line )
        ? & ( stdin_eof ) == ( string_len line ) 0 {
            ( string_free line )
            = done T
        } {
            : String trimmed ( string_trim line )
            ( string_free line )
            ? ( repl_line_is_exit trimmed ) {
                ( string_free trimmed )
                = done T
            } {
                ? == ( string_len trimmed ) 0 {
                    ( string_free trimmed )
                } {
                    ( session_event `user` ( string_data trimmed ) )
                    ( vec_push [Json] msgs ( openai_compat_msg `user` ( string_data trimmed ) ) )
                    ( string_free trimmed )
                    : i turn_code ( run_openai_compat_turn api_key model msgs tools max_tokens )
                    ? != turn_code 0 {
                        = exit_code turn_code
                        = done T
                    } {}
                }
            }
        }
    }

    ( trace_event `agent_repl_finish` `done` )
    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }
    ^ exit_code
}

@ run_openai_compat_repl_resume s session_id → i {
    ? == ( nurl_str_len session_id ) 0 {
        ( nurl_print `usage: hermes-nurl repl <session-id>\n` )
        ^ 1
    } {}
    ( agent_set_session_id session_id )

    : ?String key ( openai_compat_api_key_from_env )
    : s api_key ?? key {
        T s → ( string_data s )
        F → ``
    }
    ? == ( nurl_str_len api_key ) 0 {
        ( trace_event `agent_error` `missing_openai_compatible_api_key` )
        ( session_event `agent_error` `missing_openai_compatible_api_key` )
        ( nurl_eprint `error: OPENAI_API_KEY or HERMES_NURL_OPENAI_API_KEY not set\n` )
        ?? key { T s → ( string_free s ) F → {} }
        ^ 1
    } {}

    : String model ( openai_compat_model_from_env )
    : String fresh_system_prompt ( build_system_prompt `openai-compatible` ( string_data model ) )
    : String system_prompt ( session_resume_system_prompt_or session_id fresh_system_prompt )
    ( session_db_set_current_system_prompt ( string_data system_prompt ) )
    : ( Vec Json ) msgs ( session_resume_openai_messages session_id ( string_data system_prompt ) )
    : ( Vec Json ) tools ( build_agent_openai_tools )
    : i max_tokens ( openai_compat_max_tokens_from_env )
    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
    : i restored - ( vec_len [Json] msgs ) 1
    ( agent_trace_resume session_id restored )
    ( trace_event `agent_repl_resume_start` ( string_data model ) )
    ( nurl_print `hermes-nurl repl resumed ` )
    ( nurl_print session_id )
    ( nurl_print `. Type /exit to quit.\n` )

    : ~ i exit_code 0
    : ~ b done F
    ~ ! done {
        ( nurl_print `hermes-nurl> ` )
        ( flush )
        : String line ( read_line )
        ? & ( stdin_eof ) == ( string_len line ) 0 {
            ( string_free line )
            = done T
        } {
            : String trimmed ( string_trim line )
            ( string_free line )
            ? ( repl_line_is_exit trimmed ) {
                ( string_free trimmed )
                = done T
            } {
                ? == ( string_len trimmed ) 0 {
                    ( string_free trimmed )
                } {
                    ( session_event `user` ( string_data trimmed ) )
                    ( vec_push [Json] msgs ( openai_compat_msg `user` ( string_data trimmed ) ) )
                    ( string_free trimmed )
                    : i turn_code ( run_openai_compat_turn api_key model msgs tools max_tokens )
                    ? != turn_code 0 {
                        = exit_code turn_code
                        = done T
                    } {}
                }
            }
        }
    }

    ( trace_event `agent_repl_finish` `done` )
    ( vec_free_with [Json] msgs drop_json )
    ( vec_free_with [Json] tools drop_json )
    ( string_free system_prompt )
    ( string_free model )
    ?? key { T s → ( string_free s ) F → {} }
    ^ exit_code
}

@ agent_provider_supported s provider → b {
    ? ( hermes_provider_is_openai_compat provider ) { ^ T } {}
    ? ( hermes_provider_is_anthropic_compat provider ) { ^ T } {}
    ^ F
}

@ run_agent_provider_no_user s provider String prompt → i {
    ? ( hermes_provider_is_openai_compat provider ) {
        ^ ( run_openai_compat_agent_core prompt F )
    } {}
    ? ( hermes_provider_is_anthropic_compat provider ) {
        ^ ( run_anthropic_agent_core prompt F )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( string_free prompt )
    ^ 1
}

@ run_agent_resume_provider_no_user s provider s session_id String prompt → i {
    ? ( hermes_provider_is_openai_compat provider ) {
        ^ ( run_openai_compat_agent_resume_core session_id prompt F )
    } {}
    ? ( hermes_provider_is_anthropic_compat provider ) {
        ^ ( run_anthropic_agent_resume_core session_id prompt F )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( string_free prompt )
    ^ 1
}

@ run_agent_provider_no_user_with_model s provider String prompt s model_override → i {
    ? > ( nurl_str_len model_override ) 0 {
        : ?String old_model ( env_get `HERMES_NURL_MODEL` )
        : !v IoErr sr ( env_set `HERMES_NURL_MODEL` model_override )
        ?? sr { T _ → {} F _ → {} }
        : i code ( run_agent_provider_no_user provider prompt )
        ( agent_restore_env `HERMES_NURL_MODEL` old_model )
        ^ code
    } {}
    ^ ( run_agent_provider_no_user provider prompt )
}

@ run_agent_resume_provider_no_user_with_model s provider s session_id String prompt s model_override → i {
    ? > ( nurl_str_len model_override ) 0 {
        : ?String old_model ( env_get `HERMES_NURL_MODEL` )
        : !v IoErr sr ( env_set `HERMES_NURL_MODEL` model_override )
        ?? sr { T _ → {} F _ → {} }
        : i code ( run_agent_resume_provider_no_user provider session_id prompt )
        ( agent_restore_env `HERMES_NURL_MODEL` old_model )
        ^ code
    } {}
    ^ ( run_agent_resume_provider_no_user provider session_id prompt )
}

@ run_agent_provider_no_user_with_profile s provider String prompt s model_override s base_url_override s api_key_override i max_tokens_override i retries_override i timeout_override i connect_timeout_override → i {
    : ?String old_model ( env_get `HERMES_NURL_MODEL` )
    : ?String old_openai_model ( env_get `HERMES_NURL_OPENAI_MODEL` )
    : ?String old_anthropic_base ( env_get `HERMES_NURL_ANTHROPIC_BASE_URL` )
    : ?String old_openai_base ( env_get `HERMES_NURL_OPENAI_BASE_URL` )
    : ?String old_anthropic_key ( env_get `HERMES_NURL_ANTHROPIC_API_KEY` )
    : ?String old_openai_key ( env_get `HERMES_NURL_OPENAI_API_KEY` )
    : ?String old_anthropic_tokens ( env_get `HERMES_NURL_ANTHROPIC_MAX_TOKENS` )
    : ?String old_openai_tokens ( env_get `HERMES_NURL_OPENAI_MAX_TOKENS` )
    : ?String old_anthropic_timeout ( env_get `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` )
    : ?String old_openai_timeout ( env_get `HERMES_NURL_OPENAI_TIMEOUT_MS` )
    : ?String old_anthropic_connect_timeout ( env_get `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` )
    : ?String old_openai_connect_timeout ( env_get `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` )
    : ?String old_retries ( env_get `HERMES_NURL_API_MAX_RETRIES` )
    ( agent_set_env_int_if_positive `HERMES_NURL_API_MAX_RETRIES` retries_override )

    ? ( hermes_provider_is_openai_compat provider ) {
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_MODEL` model_override )
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_BASE_URL` base_url_override )
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_API_KEY` api_key_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_MAX_TOKENS` max_tokens_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_TIMEOUT_MS` timeout_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` connect_timeout_override )
    } {
        ? ( hermes_provider_is_anthropic_compat provider ) {
            ( agent_set_env_if_nonempty `HERMES_NURL_MODEL` model_override )
            ( agent_set_env_if_nonempty `HERMES_NURL_ANTHROPIC_BASE_URL` base_url_override )
            ( agent_set_env_if_nonempty `HERMES_NURL_ANTHROPIC_API_KEY` api_key_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_MAX_TOKENS` max_tokens_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` timeout_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` connect_timeout_override )
        } {}
    }

    : i code ( run_agent_provider_no_user provider prompt )

    ( agent_restore_env `HERMES_NURL_MODEL` old_model )
    ( agent_restore_env `HERMES_NURL_OPENAI_MODEL` old_openai_model )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_BASE_URL` old_anthropic_base )
    ( agent_restore_env `HERMES_NURL_OPENAI_BASE_URL` old_openai_base )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_API_KEY` old_anthropic_key )
    ( agent_restore_env `HERMES_NURL_OPENAI_API_KEY` old_openai_key )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_MAX_TOKENS` old_anthropic_tokens )
    ( agent_restore_env `HERMES_NURL_OPENAI_MAX_TOKENS` old_openai_tokens )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` old_anthropic_timeout )
    ( agent_restore_env `HERMES_NURL_OPENAI_TIMEOUT_MS` old_openai_timeout )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` old_anthropic_connect_timeout )
    ( agent_restore_env `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` old_openai_connect_timeout )
    ( agent_restore_env `HERMES_NURL_API_MAX_RETRIES` old_retries )
    ^ code
}

@ run_agent_resume_provider_no_user_with_profile s provider s session_id String prompt s model_override s base_url_override s api_key_override i max_tokens_override i retries_override i timeout_override i connect_timeout_override → i {
    : ?String old_model ( env_get `HERMES_NURL_MODEL` )
    : ?String old_openai_model ( env_get `HERMES_NURL_OPENAI_MODEL` )
    : ?String old_anthropic_base ( env_get `HERMES_NURL_ANTHROPIC_BASE_URL` )
    : ?String old_openai_base ( env_get `HERMES_NURL_OPENAI_BASE_URL` )
    : ?String old_anthropic_key ( env_get `HERMES_NURL_ANTHROPIC_API_KEY` )
    : ?String old_openai_key ( env_get `HERMES_NURL_OPENAI_API_KEY` )
    : ?String old_anthropic_tokens ( env_get `HERMES_NURL_ANTHROPIC_MAX_TOKENS` )
    : ?String old_openai_tokens ( env_get `HERMES_NURL_OPENAI_MAX_TOKENS` )
    : ?String old_anthropic_timeout ( env_get `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` )
    : ?String old_openai_timeout ( env_get `HERMES_NURL_OPENAI_TIMEOUT_MS` )
    : ?String old_anthropic_connect_timeout ( env_get `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` )
    : ?String old_openai_connect_timeout ( env_get `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` )
    : ?String old_retries ( env_get `HERMES_NURL_API_MAX_RETRIES` )
    ( agent_set_env_int_if_positive `HERMES_NURL_API_MAX_RETRIES` retries_override )

    ? ( hermes_provider_is_openai_compat provider ) {
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_MODEL` model_override )
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_BASE_URL` base_url_override )
        ( agent_set_env_if_nonempty `HERMES_NURL_OPENAI_API_KEY` api_key_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_MAX_TOKENS` max_tokens_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_TIMEOUT_MS` timeout_override )
        ( agent_set_env_int_if_positive `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` connect_timeout_override )
    } {
        ? ( hermes_provider_is_anthropic_compat provider ) {
            ( agent_set_env_if_nonempty `HERMES_NURL_MODEL` model_override )
            ( agent_set_env_if_nonempty `HERMES_NURL_ANTHROPIC_BASE_URL` base_url_override )
            ( agent_set_env_if_nonempty `HERMES_NURL_ANTHROPIC_API_KEY` api_key_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_MAX_TOKENS` max_tokens_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` timeout_override )
            ( agent_set_env_int_if_positive `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` connect_timeout_override )
        } {}
    }

    : i code ( run_agent_resume_provider_no_user provider session_id prompt )

    ( agent_restore_env `HERMES_NURL_MODEL` old_model )
    ( agent_restore_env `HERMES_NURL_OPENAI_MODEL` old_openai_model )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_BASE_URL` old_anthropic_base )
    ( agent_restore_env `HERMES_NURL_OPENAI_BASE_URL` old_openai_base )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_API_KEY` old_anthropic_key )
    ( agent_restore_env `HERMES_NURL_OPENAI_API_KEY` old_openai_key )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_MAX_TOKENS` old_anthropic_tokens )
    ( agent_restore_env `HERMES_NURL_OPENAI_MAX_TOKENS` old_openai_tokens )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` old_anthropic_timeout )
    ( agent_restore_env `HERMES_NURL_OPENAI_TIMEOUT_MS` old_openai_timeout )
    ( agent_restore_env `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` old_anthropic_connect_timeout )
    ( agent_restore_env `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` old_openai_connect_timeout )
    ( agent_restore_env `HERMES_NURL_API_MAX_RETRIES` old_retries )
    ^ code
}

@ agent_trace_provider_fallback s primary s fallback s reason → v {
    : String detail ( string_with_cap 128 )
    ( string_push_str detail primary )
    ( string_push_str detail ` -> ` )
    ( string_push_str detail fallback )
    ( string_push_str detail ` ` )
    ( string_push_str detail reason )
    ( trace_event `provider_fallback` ( string_data detail ) )
    ( string_free detail )
}

@ run_agent_with_fallback String prompt s primary s fallback s fallback_model → i {
    ? | == ( string_len prompt ) 0 == ( nurl_str_len fallback ) 0 {
        ^ ( run_agent_provider_no_user primary prompt )
    } {}
    ( session_event `user` ( string_data prompt ) )
    ? != ( nurl_str_eq primary fallback ) 0 {
        ^ ( run_agent_provider_no_user primary prompt )
    } {}
    ? ! ( agent_provider_supported fallback ) {
        ( nurl_eprint `[hermes-nurl] warning: fallback provider is unsupported: ` )
        ( nurl_eprint fallback )
        ( nurl_eprint `\n` )
        ^ ( run_agent_provider_no_user primary prompt )
    } {}

    ( agent_set_fallback_safe T )
    : String primary_prompt ( string_from ( string_data prompt ) )
    : i code ( run_agent_provider_no_user primary primary_prompt )
    ? & != code 0 ( agent_fallback_safe ) {
        ( nurl_eprint `[hermes-nurl] provider fallback ` )
        ( nurl_eprint primary )
        ( nurl_eprint ` -> ` )
        ( nurl_eprint fallback )
        ( nurl_eprint `\n` )
        ( agent_trace_provider_fallback primary fallback `safe_retry` )
        : String fallback_base_url ( hermes_nurl_fallback_base_url_from_env )
        : String fallback_api_key ( hermes_nurl_fallback_api_key_from_env )
        : i fallback_max_tokens ( hermes_nurl_fallback_max_tokens_from_env )
        : i fallback_retries ( hermes_nurl_fallback_api_max_retries_from_env )
        : i fallback_timeout ( hermes_nurl_fallback_api_timeout_ms_from_env )
        : i fallback_connect_timeout ( hermes_nurl_fallback_api_connect_timeout_ms_from_env )
        : i fallback_code ( run_agent_provider_no_user_with_profile fallback prompt fallback_model ( string_data fallback_base_url ) ( string_data fallback_api_key ) fallback_max_tokens fallback_retries fallback_timeout fallback_connect_timeout )
        ( string_free fallback_base_url )
        ( string_free fallback_api_key )
        ^ fallback_code
    } {}
    ? != code 0 {
        ? ! ( agent_fallback_safe ) {
            ( agent_trace_provider_fallback primary fallback `skipped_after_tool_use` )
        } {}
    } {}
    ( string_free prompt )
    ^ code
}

@ run_agent_resume_with_fallback s session_id String prompt s primary s fallback s fallback_model → i {
    ? | | == ( nurl_str_len session_id ) 0 == ( string_len prompt ) 0 == ( nurl_str_len fallback ) 0 {
        ^ ( run_agent_resume_provider_no_user primary session_id prompt )
    } {}
    ( agent_set_session_id session_id )
    ( session_event `user` ( string_data prompt ) )
    ? != ( nurl_str_eq primary fallback ) 0 {
        ^ ( run_agent_resume_provider_no_user primary session_id prompt )
    } {}
    ? ! ( agent_provider_supported fallback ) {
        ( nurl_eprint `[hermes-nurl] warning: fallback provider is unsupported: ` )
        ( nurl_eprint fallback )
        ( nurl_eprint `\n` )
        ^ ( run_agent_resume_provider_no_user primary session_id prompt )
    } {}

    ( agent_set_fallback_safe T )
    : String primary_prompt ( string_from ( string_data prompt ) )
    : i code ( run_agent_resume_provider_no_user primary session_id primary_prompt )
    ? & != code 0 ( agent_fallback_safe ) {
        ( nurl_eprint `[hermes-nurl] provider fallback ` )
        ( nurl_eprint primary )
        ( nurl_eprint ` -> ` )
        ( nurl_eprint fallback )
        ( nurl_eprint `\n` )
        ( agent_trace_provider_fallback primary fallback `safe_resume_retry` )
        : String fallback_base_url ( hermes_nurl_fallback_base_url_from_env )
        : String fallback_api_key ( hermes_nurl_fallback_api_key_from_env )
        : i fallback_max_tokens ( hermes_nurl_fallback_max_tokens_from_env )
        : i fallback_retries ( hermes_nurl_fallback_api_max_retries_from_env )
        : i fallback_timeout ( hermes_nurl_fallback_api_timeout_ms_from_env )
        : i fallback_connect_timeout ( hermes_nurl_fallback_api_connect_timeout_ms_from_env )
        : i fallback_code ( run_agent_resume_provider_no_user_with_profile fallback session_id prompt fallback_model ( string_data fallback_base_url ) ( string_data fallback_api_key ) fallback_max_tokens fallback_retries fallback_timeout fallback_connect_timeout )
        ( string_free fallback_base_url )
        ( string_free fallback_api_key )
        ^ fallback_code
    } {}
    ? != code 0 {
        ? ! ( agent_fallback_safe ) {
            ( agent_trace_provider_fallback primary fallback `skipped_resume_after_tool_use` )
        } {}
    } {}
    ( string_free prompt )
    ^ code
}

@ run_agent String prompt → i {
    : String provider ( hermes_nurl_provider_from_env )
    : String fallback ( hermes_nurl_fallback_provider_from_env )
    : String fallback_model ( hermes_nurl_fallback_model_from_env )
    ? > ( string_len fallback ) 0 {
        : i code ( run_agent_with_fallback prompt ( string_data provider ) ( string_data fallback ) ( string_data fallback_model ) )
        ( string_free provider )
        ( string_free fallback )
        ( string_free fallback_model )
        ^ code
    } {}
    ( string_free fallback )
    ( string_free fallback_model )
    ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_openai_compat_agent prompt )
    } {}
    ? ( hermes_provider_is_anthropic_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_anthropic_agent prompt )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( agent_emit_event_text `error` `message` `unsupported provider` )
    ( string_free provider )
    ( string_free prompt )
    ^ 1
}

@ run_agent_resume s session_id String prompt → i {
    : String provider ( hermes_nurl_provider_from_env )
    : String fallback ( hermes_nurl_fallback_provider_from_env )
    : String fallback_model ( hermes_nurl_fallback_model_from_env )
    ? > ( string_len fallback ) 0 {
        : i code ( run_agent_resume_with_fallback session_id prompt ( string_data provider ) ( string_data fallback ) ( string_data fallback_model ) )
        ( string_free provider )
        ( string_free fallback )
        ( string_free fallback_model )
        ^ code
    } {}
    ( string_free fallback )
    ( string_free fallback_model )
    ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_openai_compat_agent_resume session_id prompt )
    } {}
    ? ( hermes_provider_is_anthropic_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_anthropic_agent_resume session_id prompt )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( agent_emit_event_text `error` `message` `unsupported provider` )
    ( string_free provider )
    ( string_free prompt )
    ^ 1
}

@ run_agent_events String prompt → i {
    : !v IoErr sr ( env_set `HERMES_NURL_STDOUT_EVENTS` `1` )
    ?? sr { T _ → {} F _ → {} }
    ( agent_events_ensure_default_logs )
    ( agent_emit_event_text `status` `state` `started` )
    : i code ( run_agent prompt )
    ( agent_emit_event_int `exit` `exit_code` code )
    ^ code
}

@ run_agent_resume_events s session_id String prompt → i {
    : !v IoErr sr ( env_set `HERMES_NURL_STDOUT_EVENTS` `1` )
    ?? sr { T _ → {} F _ → {} }
    ( agent_events_ensure_default_logs )
    ( agent_emit_event_text `status` `state` `started` )
    : i code ( run_agent_resume session_id prompt )
    ( agent_emit_event_int `exit` `exit_code` code )
    ^ code
}

@ run_agent_repl → i {
    : String provider ( hermes_nurl_provider_from_env )
    ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_openai_compat_repl )
    } {}
    ? ( hermes_provider_is_anthropic_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_anthropic_repl )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( string_free provider )
    ^ 1
}

@ run_agent_repl_resume s session_id → i {
    : String provider ( hermes_nurl_provider_from_env )
    ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_openai_compat_repl_resume session_id )
    } {}
    ? ( hermes_provider_is_anthropic_compat ( string_data provider ) ) {
        ( string_free provider )
        ^ ( run_anthropic_repl_resume session_id )
    } {}

    ( nurl_eprint `error: unsupported HERMES_NURL_PROVIDER/config model.provider. Use anthropic, openai, or custom.\n` )
    ( string_free provider )
    ^ 1
}
