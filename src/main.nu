$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/io.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/errors.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`
$ `nurl/src/context_budget.nu`
$ `nurl/src/harness.nu`
$ `nurl/src/message_sanitization.nu`
$ `nurl/src/prompt_builder.nu`
$ `nurl/src/skills.nu`
$ `nurl/src/agent.nu`
$ `nurl/src/mcp_external.nu`
$ `nurl/src/model_metadata.nu`
$ `nurl/src/state_cli.nu`
$ `nurl/src/session_resume.nu`
$ `nurl/src/providers/anthropic.nu`
$ `nurl/src/providers/openai_compat.nu`

@ prompt_from_args i start → String {
    : i argc ( env_args_count )
    : String prompt ( string_with_cap 128 )
    ? > argc start {
        : ~ i i start
        ~ < i argc {
            ? > i start { ( string_push_str prompt ` ` ) } {}
            ( string_push_str prompt ( nurl_argv_get i ) )
            = i + i 1
        }
    } {
        : String stdin_text ( read_all_stdin )
        ( string_push_str prompt ( string_data stdin_text ) )
        ( string_free stdin_text )
    }
    ^ prompt
}

@ run_doctor → i {
    ( nurl_print `hermes-nurl ` )
    ( nurl_print ( VERSION ) )
    ( nurl_print `\n` )

    : String selected_provider ( hermes_nurl_provider_from_env )
    ( nurl_print `provider: ` )
    ( nurl_print ( string_data selected_provider ) )
    ( nurl_print `\n` )

    : ~ s key_source `missing`
    ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        = key_source ( openai_compat_api_key_source_from_env )
    } {
        = key_source ( anthropic_api_key_source_from_env )
    }
    ? == ( nurl_str_eq key_source `missing` ) 0 {
        ( nurl_print `api key: set via ` )
        ( nurl_print key_source )
        ( nurl_print `\n` )
    } {
        ( nurl_print `api key: missing\n` )
    }

    : String model ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        ( openai_compat_model_from_env )
    } {
        ( anthropic_model_from_env )
    }
    ( nurl_print `model: ` )
    ( nurl_print ( string_data model ) )
    ( nurl_print `\n` )
    : i max_tokens ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        ( openai_compat_max_tokens_from_env )
    } {
        ( anthropic_max_tokens_from_env )
    }
    ( nurl_print `max tokens: ` )
    ( nurl_print ( nurl_str_int max_tokens ) )
    ( nurl_print `\n` )
    ( nurl_print `api max retries: ` )
    ( nurl_print ( nurl_str_int ( agent_api_max_retries ) ) )
    ( nurl_print `\n` )
    : i api_timeout ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        ( openai_compat_timeout_ms_from_env )
    } {
        ( anthropic_timeout_ms_from_env )
    }
    : i api_connect_timeout ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        ( openai_compat_connect_timeout_ms_from_env )
    } {
        ( anthropic_connect_timeout_ms_from_env )
    }
    ( nurl_print `api timeout ms: ` )
    ( nurl_print ( nurl_str_int api_timeout ) )
    ( nurl_print `\n` )
    ( nurl_print `api connect timeout ms: ` )
    ( nurl_print ( nurl_str_int api_connect_timeout ) )
    ( nurl_print `\n` )
    ( nurl_print `agent max turns: ` )
    ( nurl_print ( nurl_str_int ( agent_max_turns ) ) )
    ( nurl_print `\n` )
    : i ctx ( model_context_length ( string_data model ) )
    : i threshold ( context_threshold_tokens ctx )
    : i request_budget ( context_max_request_tokens ctx max_tokens )
    ( nurl_print `context length: ` )
    ( nurl_print ( nurl_str_int ctx ) )
    ? >= ctx ( MINIMUM_CONTEXT_LENGTH ) {
        ( nurl_print ` (ok)\n` )
    } {
        ( nurl_print ` (below Hermes minimum)\n` )
    }
    ( nurl_print `compression: ` )
    ? ( context_compression_enabled ) {
        ( nurl_print `enabled` )
    } {
        ( nurl_print `disabled` )
    }
    ( nurl_print ` threshold=` )
    ( nurl_print ( nurl_str_int threshold ) )
    ( nurl_print ` tail_budget=` )
    ( nurl_print ( nurl_str_int ( context_tail_budget_tokens threshold ) ) )
    ( nurl_print ` request_budget=` )
    ( nurl_print ( nurl_str_int request_budget ) )
    ( nurl_print ` summary=` )
    ? ( context_summary_enabled ) {
        ( nurl_print `enabled` )
    } {
        ( nurl_print `disabled` )
    }
    ( nurl_print `\n` )
    ? ( context_summary_enabled ) {
        : String summary_provider ( agent_summary_provider_or ( string_data selected_provider ) )
        : String summary_model ( agent_summary_model_or ( string_data summary_provider ) ( string_data selected_provider ) model )
        : String summary_base_url ( agent_summary_base_url_or ( string_data summary_provider ) )
        ( nurl_print `summary provider: ` )
        ( nurl_print ( string_data summary_provider ) )
        ( nurl_print `\n` )
        ( nurl_print `summary model: ` )
        ( nurl_print ( string_data summary_model ) )
        ( nurl_print `\n` )
        ( nurl_print `summary base url: ` )
        ( nurl_print ( string_data summary_base_url ) )
        ( nurl_print `\n` )
        : i summary_timeout ( context_summary_api_timeout_ms )
        ? > summary_timeout 0 {
            ( nurl_print `summary api timeout ms: ` )
            ( nurl_print ( nurl_str_int summary_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `summary api timeout ms: provider default/env\n` )
        }
        : i summary_connect_timeout ( context_summary_api_connect_timeout_ms )
        ? > summary_connect_timeout 0 {
            ( nurl_print `summary api connect timeout ms: ` )
            ( nurl_print ( nurl_str_int summary_connect_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `summary api connect timeout ms: provider default/env\n` )
        }
        ( nurl_print `summary min input tokens: ` )
        ( nurl_print ( nurl_str_int ( context_summary_min_input_tokens ) ) )
        ( nurl_print `\n` )
        ( nurl_print `summary min savings tokens: ` )
        ( nurl_print ( nurl_str_int ( context_summary_min_savings_tokens ) ) )
        ( nurl_print `\n` )
        ( string_free summary_provider )
        ( string_free summary_model )
        ( string_free summary_base_url )
    } {}
    ( string_free model )

    : String base_url ? ( hermes_provider_is_openai_compat ( string_data selected_provider ) ) {
        ( openai_compat_base_url_from_env )
    } {
        ( anthropic_base_url_from_env )
    }
    ( nurl_print `base url: ` )
    ( nurl_print ( string_data base_url ) )
    ( nurl_print `\n` )
    ( string_free base_url )

    : String fallback_provider ( hermes_nurl_fallback_provider_from_env )
    ? > ( string_len fallback_provider ) 0 {
        ( nurl_print `fallback provider: ` )
        ( nurl_print ( string_data fallback_provider ) )
        ( nurl_print `\n` )
        : String fallback_model ( hermes_nurl_fallback_model_from_env )
        ? > ( string_len fallback_model ) 0 {
            ( nurl_print `fallback model: ` )
            ( nurl_print ( string_data fallback_model ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback model: provider default/env\n` )
        }
        ( string_free fallback_model )
        : String fallback_base_url ( hermes_nurl_fallback_base_url_from_env )
        ? > ( string_len fallback_base_url ) 0 {
            ( nurl_print `fallback base url: ` )
            ( nurl_print ( string_data fallback_base_url ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback base url: provider default/env\n` )
        }
        ( string_free fallback_base_url )
        : i fallback_max_tokens ( hermes_nurl_fallback_max_tokens_from_env )
        ? > fallback_max_tokens 0 {
            ( nurl_print `fallback max tokens: ` )
            ( nurl_print ( nurl_str_int fallback_max_tokens ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback max tokens: provider default/env\n` )
        }
        : i fallback_retries ( hermes_nurl_fallback_api_max_retries_from_env )
        ? > fallback_retries 0 {
            ( nurl_print `fallback api max retries: ` )
            ( nurl_print ( nurl_str_int fallback_retries ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback api max retries: default/env\n` )
        }
        : i fallback_timeout ( hermes_nurl_fallback_api_timeout_ms_from_env )
        ? > fallback_timeout 0 {
            ( nurl_print `fallback api timeout ms: ` )
            ( nurl_print ( nurl_str_int fallback_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback api timeout ms: provider default/env\n` )
        }
        : i fallback_connect_timeout ( hermes_nurl_fallback_api_connect_timeout_ms_from_env )
        ? > fallback_connect_timeout 0 {
            ( nurl_print `fallback api connect timeout ms: ` )
            ( nurl_print ( nurl_str_int fallback_connect_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `fallback api connect timeout ms: provider default/env\n` )
        }
        : ~ s fallback_key_source `missing`
        : s fallback_profile_key_source ( hermes_nurl_fallback_api_key_source_from_env )
        ? == ( nurl_str_eq fallback_profile_key_source `missing` ) 0 {
            = fallback_key_source fallback_profile_key_source
        } {
            ? ( hermes_provider_is_anthropic_compat ( string_data fallback_provider ) ) {
                = fallback_key_source ( anthropic_api_key_source_from_env )
            } {
                ? ( hermes_provider_is_openai_compat ( string_data fallback_provider ) ) {
                    = fallback_key_source ( openai_compat_api_key_source_from_env )
                } {
                    = fallback_key_source `unsupported`
                }
            }
        }
        ( nurl_print `fallback api key: ` )
        ( nurl_print fallback_key_source )
        ( nurl_print `\n` )
    } {
        ( nurl_print `fallback provider: disabled\n` )
    }
    ( string_free fallback_provider )

    : String provider ( hermes_config_model_provider )
    ? > ( string_len provider ) 0 {
        ( nurl_print `config provider: ` )
        ( nurl_print ( string_data provider ) )
        ( nurl_print `\n` )
    } {}
    ( string_free provider )
    ( string_free selected_provider )

    : String home ( hermes_home )
    ( nurl_print `hermes home: ` )
    ( nurl_print ( string_data home ) )
    ( nurl_print `\n` )
    ( string_free home )

    : String config_path ( hermes_config_path )
    ( nurl_print `config: ` )
    ( nurl_print ( string_data config_path ) )
    ? ( hermes_config_exists ) {
        ( nurl_print ` (present)\n` )
    } {
        ( nurl_print ` (missing)\n` )
    }
    ( string_free config_path )

    : ?String trace_path ( env_get `HERMES_NURL_TRACE` )
    ?? trace_path {
        T p → {
            ? > ( string_len p ) 0 {
                ( nurl_print `trace: ` )
                ( nurl_print ( string_data p ) )
                ( nurl_print `\n` )
            } {
                ( nurl_print `trace: disabled\n` )
            }
            ( string_free p )
        }
        F → { ( nurl_print `trace: disabled\n` ) }
    }

    : ?String session_path ( env_get `HERMES_NURL_SESSION_LOG` )
    ?? session_path {
        T p → {
            ? > ( string_len p ) 0 {
                ( nurl_print `session log: ` )
                ( nurl_print ( string_data p ) )
                ( nurl_print `\n` )
            } {
                ( nurl_print `session log: disabled\n` )
            }
            ( string_free p )
        }
        F → { ( nurl_print `session log: disabled\n` ) }
    }

    : String db_path ( session_db_path_from_env )
    ? > ( string_len db_path ) 0 {
        ( nurl_print `state db: ` )
        ( nurl_print ( string_data db_path ) )
        ( nurl_print `\n` )
    } {
        ( nurl_print `state db: disabled\n` )
    }
    ( string_free db_path )

    ? ( env_truthy `HERMES_NURL_ALLOW_DESTRUCTIVE` ) {
        ( nurl_print `shell guard: override enabled\n` )
    } {
        ( nurl_print `shell guard: enabled\n` )
    }
    ( nurl_print `production mode: ` )
    ? ( hermes_nurl_production_mode ) {
        ( nurl_print `enabled\n` )
    } {
        ( nurl_print `disabled\n` )
    }
    ( nurl_print `production shell tools: ` )
    ? ( hermes_nurl_shell_allowed ) {
        ( nurl_print `allowed\n` )
    } {
        ( nurl_print `blocked\n` )
    }
    ( nurl_print `production mutating tools: ` )
    ? ( hermes_nurl_mutations_allowed ) {
        ( nurl_print `allowed\n` )
    } {
        ( nurl_print `blocked\n` )
    }
    ( nurl_print `production network tools: ` )
    ? ( hermes_nurl_network_allowed ) {
        ( nurl_print `allowed\n` )
    } {
        ( nurl_print `blocked\n` )
    }
    : String network_hosts ( hermes_nurl_network_allow_hosts_from_env )
    ( nurl_print `network allow hosts: ` )
    ? > ( string_len network_hosts ) 0 {
        ( nurl_print ( string_data network_hosts ) )
        ( nurl_print `\n` )
    } {
        ( nurl_print `missing\n` )
    }
    ( string_free network_hosts )
    : String network_bases ( hermes_nurl_network_allow_base_urls_from_env )
    ( nurl_print `network allow base urls: ` )
    ? > ( string_len network_bases ) 0 {
        ( nurl_print ( string_data network_bases ) )
        ( nurl_print `\n` )
    } {
        ( nurl_print `missing\n` )
    }
    ( string_free network_bases )
    ( nurl_print `network private hosts: ` )
    ? ( hermes_nurl_network_private_allowed ) {
        ( nurl_print `allowed\n` )
    } {
        ( nurl_print `blocked\n` )
    }
    ( nurl_print `network redirect safety: ` )
    ? ( hermes_nurl_network_redirect_safe_runtime ) {
        ( nurl_print `supported\n` )
    } {
        ( nurl_print `unsupported\n` )
    }
    ( nurl_print `network max response bytes: ` )
    ( nurl_print ( nurl_str_int ( hermes_nurl_network_max_response_bytes_from_env ) ) )
    ( nurl_print `\n` )
    ( nurl_print `production staleness guard: ` )
    ? ( env_truthy `HERMES_NURL_REQUIRE_EXPECTED_SHA256` ) {
        ( nurl_print `enabled\n` )
    } {
        ( nurl_print `disabled\n` )
    }
    : String edit_check_cmd ( hermes_nurl_edit_check_command )
    ( nurl_print `edit check command: ` )
    ? > ( string_len edit_check_cmd ) 0 {
        ( nurl_print `configured\n` )
        ( nurl_print `edit check strict: ` )
        ? ( env_truthy `HERMES_NURL_EDIT_CHECK_STRICT` ) {
            ( nurl_print `enabled\n` )
        } {
            ( nurl_print `disabled\n` )
        }
        ( nurl_print `edit check shell: ` )
        ? ( hermes_nurl_shell_allowed ) {
            ( nurl_print `allowed\n` )
        } {
            ( nurl_print `blocked\n` )
        }
    } {
        ( nurl_print `disabled\n` )
    }
    ( string_free edit_check_cmd )

    : !String IoErr cwd ( env_cwd )
    ?? cwd {
        T path → {
            ( nurl_print `cwd: ` )
            ( nurl_print ( string_data path ) )
            ( nurl_print `\n` )
            ( string_free path )
        }
        F _ → { ( nurl_print `cwd: unavailable\n` ) }
    }

    ( nurl_print `tools: run_shell, file_info, read_file, list_dir, write_file, append_file, search_files, patch, skills_list, skill_view, http_request, harness_record\n` )
    : ( Vec McpStdioServerConfig ) mcp_servers ( hermes_mcp_stdio_servers )
    ( nurl_print `mcp servers: ` )
    ( nurl_print ( nurl_str_int ( vec_len [McpStdioServerConfig] mcp_servers ) ) )
    ( nurl_print `\n` )
    : ( @ v McpStdioServerConfig ) drop_cfg \ McpStdioServerConfig cfg → v { ( mcp_config_free cfg ) }
    ( vec_free_with [McpStdioServerConfig] mcp_servers drop_cfg )
    ^ 0
}

@ run_harness_start i start → i {
    : i argc ( env_args_count )
    ? <= argc start {
        ( nurl_eprint `usage: hermes-nurl harness-start <contract-id>\n` )
        ^ 2
    } {}
    : String out ( harness_start_run ( nurl_argv_get start ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ^ 0
}

@ run_harness_evidence i start → i {
    : i argc ( env_args_count )
    ? <= argc + start 1 {
        ( nurl_eprint `usage: hermes-nurl harness-evidence <kind> <value>\n` )
        ^ 2
    } {}
    : String out ( harness_record_evidence ( nurl_argv_get start ) ( nurl_argv_get + start 1 ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ^ 0
}

@ run_harness_handoff i start → i {
    : i argc ( env_args_count )
    ? <= argc + start 1 {
        ( nurl_eprint `usage: hermes-nurl harness-handoff <dependent-skill> <artifact> [detail]\n` )
        ^ 2
    } {}
    : String detail ( string_new )
    ? > argc + start 2 {
        ( string_free detail )
        = detail ( prompt_from_args + start 2 )
    } {}
    : String out ( harness_record_handoff ( nurl_argv_get start ) ( nurl_argv_get + start 1 ) ( string_data detail ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ( string_free detail )
    ^ 0
}

@ run_harness_gate i start → i {
    : i argc ( env_args_count )
    ? <= argc + start 1 {
        ( nurl_eprint `usage: hermes-nurl harness-gate <name> <passed|failed|skipped> [detail]\n` )
        ^ 2
    } {}
    : String detail ( string_new )
    ? > argc + start 2 {
        ( string_free detail )
        = detail ( prompt_from_args + start 2 )
    } {}
    : String out ( harness_record_gate ( nurl_argv_get start ) ( nurl_argv_get + start 1 ) ( string_data detail ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ( string_free detail )
    ^ 0
}

@ run_harness_report i start → i {
    : i argc ( env_args_count )
    ? <= argc start {
        ( nurl_eprint `usage: hermes-nurl harness-report <status> [detail]\n` )
        ^ 2
    } {}
    : String detail ( string_new )
    ? > argc + start 1 {
        ( string_free detail )
        = detail ( prompt_from_args + start 1 )
    } {}
    : String out ( harness_write_report ( nurl_argv_get start ) ( string_data detail ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ( string_free detail )
    ^ 0
}

@ run_harness_complete → i {
    : String out ( harness_completion_check_json )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    : String err ( harness_completion_error )
    : i code ? > ( string_len err ) 0 1 0
    ( string_free err )
    ( string_free out )
    ^ code
}

@ run_selftest → i {
    : b dangerous ( shell_command_blocked `rm -rf /tmp/hermes-nurl-selftest` )
    : b safe ( shell_command_blocked `pwd` )
    : String repaired ( repair_tool_call_arguments `{"path":"nurl/README.md",}` `read_file` )
    : !Json ParseErr parsed ( json_parse ( string_data repaired ) )
    : b repaired_ok ?? parsed {
        T j → {
            ( json_free j )
            T
        }
        F _ → F
    }
    ( string_free repaired )
    : String control_raw ( string_from `{"text":"alpha` )
    ( string_push_char control_raw 10 )
    ( string_push_str control_raw `beta",}` )
    : String repaired_control ( repair_tool_call_arguments ( string_data control_raw ) `write_file` )
    : !Json ParseErr parsed_control ( json_parse ( string_data repaired_control ) )
    : b repaired_control_ok ?? parsed_control {
        T j → {
            ( json_free j )
            T
        }
        F _ → F
    }
    ( string_free repaired_control )
    ( string_free control_raw )
    : String rate_body ( string_from `{"error":{"message":"rate limited"}}` )
    : OpenAICompatErr rate_err ( openai_compat_status_error 429 rate_body )
    : b retry_status_ok & ( openai_compat_err_retryable rate_err ) ( anthropic_status_retryable 429 )
    ( string_free rate_body )
    : String context_body ( string_from `{"error":{"message":"This model's maximum context length was exceeded"}}` )
    : OpenAICompatErr context_err ( openai_compat_status_error 400 context_body )
    : b context_status_ok != ( nurl_str_eq ( openai_compat_err_name context_err ) `OpenAICompatContext` ) 0
    ( string_free context_body )
    : ( Vec Json ) prune_msgs ( vec_new [Json] )
    : String big_tool_output ( string_with_cap 5000 )
    : ~ i bi 0
    ~ < bi 5000 {
        ( string_push_str big_tool_output `x` )
        = bi + bi 1
    }
    : Json old_tool_msg ( json_obj_new )
    ( json_obj_set old_tool_msg `role` ( json_str_lit `tool` ) )
    ( json_obj_set old_tool_msg `tool_call_id` ( json_str_lit `selftest-tool` ) )
    ( json_obj_set old_tool_msg `content` ( json_str_lit ( string_data big_tool_output ) ) )
    ( string_free big_tool_output )
    ( vec_push [Json] prune_msgs old_tool_msg )
    : ~ i mi 0
    ~ < mi 205 {
        ( vec_push [Json] prune_msgs ( openai_compat_msg `user` `tail` ) )
        = mi + mi 1
    }
    : i pruned_count ( context_prune_old_tool_results prune_msgs )
    : ~ b pruned_ok F
    : ?Json first_msg ( vec_get [Json] prune_msgs 0 )
    ?? first_msg {
        T fm → {
            : ?Json content_j ( json_obj_get fm `content` )
            ?? content_j {
                T cj → {
                    : s content ( json_str_data cj )
                    ? & == pruned_count 1 != ( nurl_str_find content `[old tool output pruned:` ) -1 {
                        = pruned_ok T
                    } {}
                }
                F → {}
            }
        }
        F → {}
    }
    : ( @ v Json ) drop_json \ Json j → v { ( json_free j ) }
    ( vec_free_with [Json] prune_msgs drop_json )
    : ( Vec Json ) compact_msgs ( vec_new [Json] )
    : ~ i ci 0
    ~ < ci 35 {
        : String msg ( string_from `message ` )
        ( string_push_int msg ci )
        ( string_push_str msg ` with enough content to summarize deterministically` )
        : i rem - ci * / ci 2 2
        : s role ? == rem 0 `user` `assistant`
        ( vec_push [Json] compact_msgs ( openai_compat_msg role ( string_data msg ) ) )
        ( string_free msg )
        = ci + ci 1
    }
    : i compacted_count ( context_compact_middle compact_msgs 12345 )
    : ~ b compact_ok F
    : i compact_len ( vec_len [Json] compact_msgs )
    : ~ i cmi 0
    ~ < cmi compact_len {
        : ?Json ce ( vec_get [Json] compact_msgs cmi )
        ?? ce {
            T cm → {
                : ?Json content_j ( json_obj_get cm `content` )
                ?? content_j {
                    T cj → {
                        : s content ( json_str_data cj )
                        ? != ( nurl_str_find content `[CONTEXT COMPACTION - REFERENCE ONLY]` ) -1 {
                            = compact_ok T
                        } {}
                    }
                    F → {}
                }
            }
            F → {}
        }
        = cmi + cmi 1
    }
    ( vec_free_with [Json] compact_msgs drop_json )
    : ( Vec Json ) aux_compact_msgs ( vec_new [Json] )
    : ~ i aci 0
    ~ < aci 35 {
        : String msg ( string_from `aux message ` )
        ( string_push_int msg aci )
        ( string_push_str msg ` with details for model summary compaction` )
        : i rem - aci * / aci 2 2
        : s role ? == rem 0 `user` `assistant`
        ( vec_push [Json] aux_compact_msgs ( openai_compat_msg role ( string_data msg ) ) )
        ( string_free msg )
        = aci + aci 1
    }
    : String aux_summary_text ( string_from `selftest auxiliary summary with /tmp/example and command output preserved` )
    : i aux_compacted_count ( context_compact_middle_with_summary aux_compact_msgs 12345 aux_summary_text )
    ( string_free aux_summary_text )
    : ~ b aux_compact_ok F
    : i aux_len ( vec_len [Json] aux_compact_msgs )
    : ~ i acmi 0
    ~ < acmi aux_len {
        : ?Json ae ( vec_get [Json] aux_compact_msgs acmi )
        ?? ae {
            T am → {
                : ?Json content_j ( json_obj_get am `content` )
                ?? content_j {
                    T cj → {
                        : s content ( json_str_data cj )
                        ? != ( nurl_str_find content `selftest auxiliary summary` ) -1 {
                            = aux_compact_ok T
                        } {}
                    }
                    F → {}
                }
            }
            F → {}
        }
        = acmi + acmi 1
    }
    ( vec_free_with [Json] aux_compact_msgs drop_json )
    ? ! pruned_ok {
        ( nurl_print `selftest: failed (context tool-result pruning did not fire)\n` )
        ( trace_event `selftest` `failed_context_prune` )
        ^ 1
    } {}
    ? | ! compact_ok <= compacted_count 0 {
        ( nurl_print `selftest: failed (context middle compaction did not produce summary)\n` )
        ( trace_event `selftest` `failed_context_compaction` )
        ^ 1
    } {}
    ? | ! aux_compact_ok <= aux_compacted_count 0 {
        ( nurl_print `selftest: failed (auxiliary context summary compaction did not preserve supplied summary)\n` )
        ( trace_event `selftest` `failed_context_aux_summary_compaction` )
        ^ 1
    } {}
    ? ! repaired_ok {
        ( nurl_print `selftest: failed (tool argument repair did not produce JSON)\n` )
        ( trace_event `selftest` `failed_tool_argument_repair` )
        ^ 1
    } {}
    ? ! repaired_control_ok {
        ( nurl_print `selftest: failed (tool argument control-char repair did not produce JSON)\n` )
        ( trace_event `selftest` `failed_tool_argument_control_repair` )
        ^ 1
    } {}
    ? ! retry_status_ok {
        ( nurl_print `selftest: failed (provider retry status classification did not fire)\n` )
        ( trace_event `selftest` `failed_retry_status_classification` )
        ^ 1
    } {}
    ? ! context_status_ok {
        ( nurl_print `selftest: failed (provider context status classification did not fire)\n` )
        ( trace_event `selftest` `failed_context_status_classification` )
        ^ 1
    } {}
    ? dangerous {
        ? safe {
            ( nurl_print `selftest: failed (safe command was blocked)\n` )
            ( trace_event `selftest` `failed_safe_blocked` )
            ^ 1
        } {
            : Json args ( json_obj_new )
            ( json_obj_set args `path` ( json_str_lit `nurl/README.md` ) )
            ( session_tool_call_args_json `selftest-call` `read_file` args )
            ( json_free args )
            ( session_tool_result `selftest-call` `read_file` F 0 )
            ( nurl_print `selftest: ok\n` )
            ( trace_event `selftest` `ok` )
            ^ 0
        }
    } {
        ( nurl_print `selftest: failed (dangerous command was allowed)\n` )
        ( trace_event `selftest` `failed_dangerous_allowed` )
        ^ 1
    }
}

@ run_prompt → i {
    : String provider ( hermes_nurl_provider_from_env )
    : String model ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( openai_compat_model_from_env )
    } {
        ( anthropic_model_from_env )
    }
    : String prompt ( build_system_prompt ( string_data provider ) ( string_data model ) )
    ( nurl_print ( string_data prompt ) )
    ( nurl_print `\n` )
    ( string_free prompt )
    ( string_free model )
    ( string_free provider )
    ^ 0
}

@ run_mcp_call s tool_name s args_json → i {
    : !Json ParseErr parsed ( json_parse args_json )
    ?? parsed {
        T args → {
            : String out ( run_agent_tool_input tool_name args )
            ( nurl_print ( string_data out ) )
            ( nurl_print `\n` )
            ( string_free out )
            ( json_free args )
            ^ 0
        }
        F _ → {
            ( nurl_eprint `usage: hermes-nurl mcp-call <mcp__server__tool> <json-args>\n` )
            ( nurl_eprint `error: json-args must be valid JSON\n` )
            ^ 2
        }
    }
}

@ run_mcp_call_stdin s tool_name → i {
    : String args_json ( read_all_stdin )
    : i code ( run_mcp_call tool_name ( string_data args_json ) )
    ( string_free args_json )
    ^ code
}

@ run_model_info i start → i {
    : i argc ( env_args_count )
    : String provider ( hermes_nurl_provider_from_env )
    : String model ? > argc start {
        ( string_from ( nurl_argv_get start ) )
    } {
        ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
            ( openai_compat_model_from_env )
        } {
            ( anthropic_model_from_env )
        }
    }
    : i ctx ( model_context_length ( string_data model ) )
    ( nurl_print `provider: ` )
    ( nurl_print ( string_data provider ) )
    ( nurl_print `\n` )
    ( nurl_print `model: ` )
    ( nurl_print ( string_data model ) )
    ( nurl_print `\n` )
    : i max_tokens ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( openai_compat_max_tokens_from_env )
    } {
        ( anthropic_max_tokens_from_env )
    }
    ( nurl_print `max tokens: ` )
    ( nurl_print ( nurl_str_int max_tokens ) )
    ( nurl_print `\n` )
    ( nurl_print `api max retries: ` )
    ( nurl_print ( nurl_str_int ( agent_api_max_retries ) ) )
    ( nurl_print `\n` )
    : i api_timeout ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( openai_compat_timeout_ms_from_env )
    } {
        ( anthropic_timeout_ms_from_env )
    }
    : i api_connect_timeout ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( openai_compat_connect_timeout_ms_from_env )
    } {
        ( anthropic_connect_timeout_ms_from_env )
    }
    ( nurl_print `api timeout ms: ` )
    ( nurl_print ( nurl_str_int api_timeout ) )
    ( nurl_print `\n` )
    ( nurl_print `api connect timeout ms: ` )
    ( nurl_print ( nurl_str_int api_connect_timeout ) )
    ( nurl_print `\n` )
    ( nurl_print `agent max turns: ` )
    ( nurl_print ( nurl_str_int ( agent_max_turns ) ) )
    ( nurl_print `\n` )
    ( nurl_print `context length: ` )
    ( nurl_print ( nurl_str_int ctx ) )
    ( nurl_print `\n` )
    : i threshold ( context_threshold_tokens ctx )
    ( nurl_print `compression enabled: ` )
    ? ( context_compression_enabled ) {
        ( nurl_print `true\n` )
    } {
        ( nurl_print `false\n` )
    }
    ( nurl_print `summary compression enabled: ` )
    ? ( context_summary_enabled ) {
        ( nurl_print `true\n` )
    } {
        ( nurl_print `false\n` )
    }
    ? ( context_summary_enabled ) {
        : String summary_provider ( agent_summary_provider_or ( string_data provider ) )
        : String summary_model ( agent_summary_model_or ( string_data summary_provider ) ( string_data provider ) model )
        : String summary_base_url ( agent_summary_base_url_or ( string_data summary_provider ) )
        ( nurl_print `summary provider: ` )
        ( nurl_print ( string_data summary_provider ) )
        ( nurl_print `\n` )
        ( nurl_print `summary model: ` )
        ( nurl_print ( string_data summary_model ) )
        ( nurl_print `\n` )
        ( nurl_print `summary base url: ` )
        ( nurl_print ( string_data summary_base_url ) )
        ( nurl_print `\n` )
        : i summary_timeout ( context_summary_api_timeout_ms )
        ? > summary_timeout 0 {
            ( nurl_print `summary api timeout ms: ` )
            ( nurl_print ( nurl_str_int summary_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `summary api timeout ms: provider default/env\n` )
        }
        : i summary_connect_timeout ( context_summary_api_connect_timeout_ms )
        ? > summary_connect_timeout 0 {
            ( nurl_print `summary api connect timeout ms: ` )
            ( nurl_print ( nurl_str_int summary_connect_timeout ) )
            ( nurl_print `\n` )
        } {
            ( nurl_print `summary api connect timeout ms: provider default/env\n` )
        }
        ( nurl_print `summary min input tokens: ` )
        ( nurl_print ( nurl_str_int ( context_summary_min_input_tokens ) ) )
        ( nurl_print `\n` )
        ( nurl_print `summary min savings tokens: ` )
        ( nurl_print ( nurl_str_int ( context_summary_min_savings_tokens ) ) )
        ( nurl_print `\n` )
        ( string_free summary_provider )
        ( string_free summary_model )
        ( string_free summary_base_url )
    } {}
    ( nurl_print `compression threshold: ` )
    ( nurl_print ( nurl_str_int threshold ) )
    ( nurl_print `\n` )
    ( nurl_print `tail budget: ` )
    ( nurl_print ( nurl_str_int ( context_tail_budget_tokens threshold ) ) )
    ( nurl_print `\n` )
    ( nurl_print `request budget: ` )
    ( nurl_print ( nurl_str_int ( context_max_request_tokens ctx max_tokens ) ) )
    ( nurl_print `\n` )
    ( nurl_print `summary max tokens: ` )
    ( nurl_print ( nurl_str_int ( context_max_summary_tokens ctx ) ) )
    ( nurl_print `\n` )
    ( nurl_print `minimum required: ` )
    ( nurl_print ( nurl_str_int ( MINIMUM_CONTEXT_LENGTH ) ) )
    ( nurl_print `\n` )
    ( nurl_print `supported: ` )
    ? >= ctx ( MINIMUM_CONTEXT_LENGTH ) {
        ( nurl_print `true\n` )
    } {
        ( nurl_print `false\n` )
    }
    ( string_free provider )
    ( string_free model )
    ^ 0
}

@ run_skills_list i start → i {
    : i argc ( env_args_count )
    : s category ? > argc start ( nurl_argv_get start ) ``
    : String out ( skills_list_json category )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ^ 0
}

@ run_skills_dirs → i {
    : String out ( skills_dirs_json )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ^ 0
}

@ run_skill_view i start → i {
    : i argc ( env_args_count )
    ? <= argc start {
        ( nurl_eprint `usage: hermes-nurl skill-view <name> [file-path]\n` )
        ^ 2
    } {}
    : s name ( nurl_argv_get start )
    : i file_idx + start 1
    : s file_path ? > argc file_idx ( nurl_argv_get file_idx ) ``
    : String out ( skill_view_json name file_path )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ^ 0
}

@ run_session_json i start → i {
    : i argc ( env_args_count )
    ? <= argc start {
        ( nurl_eprint `usage: hermes-nurl session-json <session-id> [provider]\n` )
        ^ 2
    } {}
    : s session_id ( nurl_argv_get start )
    : i provider_idx + start 1
    : String provider ? > argc provider_idx {
        ( string_from ( nurl_argv_get provider_idx ) )
    } {
        ( hermes_nurl_provider_from_env )
    }
    : String model ? ( hermes_provider_is_openai_compat ( string_data provider ) ) {
        ( openai_compat_model_from_env )
    } {
        ( anthropic_model_from_env )
    }
    : String fresh_system_prompt ( build_system_prompt ( string_data provider ) ( string_data model ) )
    : String system_prompt ( session_resume_system_prompt_or session_id fresh_system_prompt )
    : String out ( session_resume_preview_json session_id ( string_data provider ) ( string_data system_prompt ) )
    ( nurl_print ( string_data out ) )
    ( nurl_print `\n` )
    ( string_free out )
    ( string_free system_prompt )
    ( string_free model )
    ( string_free provider )
    ^ 0
}

@ main → i {
    ( hermes_load_dotenv )
    : i argc ( env_args_count )
    ? > argc 1 {
        : s cmd ( nurl_argv_get 1 )
        ? != 0 ( nurl_str_eq cmd `doctor` ) {
            ^ ( run_doctor )
        } {}
        ? != 0 ( nurl_str_eq cmd `selftest` ) {
            ^ ( run_selftest )
        } {}
        ? != 0 ( nurl_str_eq cmd `prompt` ) {
            ^ ( run_prompt )
        } {}
        ? != 0 ( nurl_str_eq cmd `mcp-tools` ) {
            ^ ( print_configured_mcp_tools )
        } {}
        ? != 0 ( nurl_str_eq cmd `mcp-call` ) {
            ? > argc 3 {
                ^ ( run_mcp_call ( nurl_argv_get 2 ) ( nurl_argv_get 3 ) )
            } {
                ( nurl_eprint `usage: hermes-nurl mcp-call <mcp__server__tool> <json-args>\n` )
                ^ 2
            }
        } {}
        ? != 0 ( nurl_str_eq cmd `mcp-call-stdin` ) {
            ? > argc 2 {
                ^ ( run_mcp_call_stdin ( nurl_argv_get 2 ) )
            } {
                ( nurl_eprint `usage: hermes-nurl mcp-call-stdin <tool-name> < json-args\n` )
                ^ 2
            }
        } {}
        ? != 0 ( nurl_str_eq cmd `model-info` ) {
            ^ ( run_model_info 2 )
        } {}
        ? | != 0 ( nurl_str_eq cmd `skills` ) != 0 ( nurl_str_eq cmd `skills-list` ) {
            ^ ( run_skills_list 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `skills-dirs` ) {
            ^ ( run_skills_dirs )
        } {}
        ? != 0 ( nurl_str_eq cmd `skill-view` ) {
            ^ ( run_skill_view 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-start` ) {
            ^ ( run_harness_start 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-evidence` ) {
            ^ ( run_harness_evidence 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-handoff` ) {
            ^ ( run_harness_handoff 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-gate` ) {
            ^ ( run_harness_gate 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-report` ) {
            ^ ( run_harness_report 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-complete` ) {
            ^ ( run_harness_complete )
        } {}
        ? != 0 ( nurl_str_eq cmd `harness-events` ) {
            ? > argc 2 {
                ^ ( run_harness_events ( nurl_argv_get 2 ) )
            } {
                ( nurl_eprint `usage: hermes-nurl harness-events <run-id>\n` )
                ^ 2
            }
        } {}
        ? != 0 ( nurl_str_eq cmd `chat` ) {
            : String prompt ( prompt_from_args 2 )
            ^ ( run_agent prompt )
        } {}
        ? != 0 ( nurl_str_eq cmd `chat-events` ) {
            : String prompt ( prompt_from_args 2 )
            ^ ( run_agent_events prompt )
        } {}
        ? != 0 ( nurl_str_eq cmd `resume` ) {
            ? > argc 2 {
                : String prompt ( prompt_from_args 3 )
                ^ ( run_agent_resume ( nurl_argv_get 2 ) prompt )
            } {
                ( nurl_eprint `usage: hermes-nurl resume <session-id> <prompt>\n` )
                ^ 2
            }
        } {}
        ? != 0 ( nurl_str_eq cmd `resume-events` ) {
            ? > argc 2 {
                : String prompt ( prompt_from_args 3 )
                ^ ( run_agent_resume_events ( nurl_argv_get 2 ) prompt )
            } {
                ( nurl_eprint `usage: hermes-nurl resume-events <session-id> <prompt>\n` )
                ^ 2
            }
        } {}
        ? | != 0 ( nurl_str_eq cmd `repl` ) != 0 ( nurl_str_eq cmd `interactive` ) {
            ? > argc 2 {
                ^ ( run_agent_repl_resume ( nurl_argv_get 2 ) )
            } {}
            ^ ( run_agent_repl )
        } {}
        ? != 0 ( nurl_str_eq cmd `sessions` ) {
            ^ ( run_sessions )
        } {}
        ? != 0 ( nurl_str_eq cmd `session-json` ) {
            ^ ( run_session_json 2 )
        } {}
        ? != 0 ( nurl_str_eq cmd `session` ) {
            ? > argc 2 {
                ^ ( run_session_show ( nurl_argv_get 2 ) )
            } {
                ( nurl_eprint `usage: hermes-nurl session <session-id>\n` )
                ^ 2
            }
        } {}
        ? != 0 ( nurl_str_eq cmd `--help` ) {
            ( nurl_print `usage: hermes-nurl [doctor|selftest|prompt|model-info|skills|skills-dirs|skill-view|mcp-tools|mcp-call|mcp-call-stdin|chat|chat-events|resume|resume-events|repl|sessions|session|session-json] <args>\n` )
            ^ 0
        } {}
        ? != 0 ( nurl_str_eq cmd `--version` ) {
            ( nurl_print ( VERSION ) )
            ( nurl_print `\n` )
            ^ 0
        } {}
    } {}

    : String prompt ( prompt_from_args 1 )
    ^ ( run_agent prompt )
}
