// Shared local tool registry and dispatch for Hermes NURL.
//
// Decomposed into domain-grouped modules:
//   tools_schemas.nu   — JSON schema builders + utility helpers
//   tools_v4a_parse.nu — V4A patch parser + line matching
//   tools_v4a_apply.nu — V4A hunk matching + file apply
//   tools_v4a_stage.nu — V4A staging, commit, preview
//   tools_registry.nu  — Tool registry, descriptions, schema dispatch, builders
//   tools_local.nu     — Execution dispatch + is_local_tool (this file)

$ `stdlib/ext/json.nu`
$ `stdlib/ext/anthropic.nu`
$ `stdlib/std/process.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/harness.nu`
$ `nurl/src/skills.nu`
$ `nurl/src/tools_http.nu`
$ `nurl/src/tools_schemas.nu`
$ `nurl/src/tools_v4a_parse.nu`
$ `nurl/src/tools_v4a_apply.nu`
$ `nurl/src/tools_v4a_stage.nu`
$ `nurl/src/tools_registry.nu`

@ run_local_tool_input s name Json input → String {
    ? ! ( local_tool_enabled name ) {
        ? != ( nurl_str_eq name `patch` ) 0 {
            : b dry_run_allowed ( input_bool input `dry_run` F )
            ? dry_run_allowed {} {
                ^ ( local_tool_blocked_message name )
            }
        } {
            ^ ( local_tool_blocked_message name )
        }
    } {}

    ? != ( nurl_str_eq name `run_shell` ) 0 {
        : s cmd ( input_str input `command` )
        ? == ( nurl_str_len cmd ) 0 {
            ^ ( string_from `error: tool 'run_shell' requires non-empty 'command' field` )
        } {}
        ? ( shell_prompt_file_write_blocked cmd ) {
            ( trace_event `tool_blocked` `prompt_file_shell_write` )
            ^ ( string_from `error: run_shell refused shell redirection into prompt_*.txt. Use write_file with a relative path so long prompts are not corrupted by shell quoting or printf formatting.` )
        } {}
        ? ( shell_command_blocked cmd ) {
            ? ( env_truthy `HERMES_NURL_ALLOW_DESTRUCTIVE` ) {} {
                ( trace_event `tool_blocked` `shell_guard` )
                ^ ( string_from `error: run_shell refused a dangerous command. Set HERMES_NURL_ALLOW_DESTRUCTIVE=1 to override.` )
            }
        } {}
        ( trace_event `tool_run_shell` cmd )
        : !Output ProcessErr r ( process_run_shell cmd )
        ?? r {
            T out → {
                : i ec ( output_exit_code out )
                : String body ( string_with_cap 256 )
                ? != ec 0 {
                    ( string_push_str body `[exit ` )
                    ( string_push_int body ec )
                    ( string_push_str body `]\n` )
                } {}
                ( string_push_str body ( output_stdout out ) )
                : i errlen ( output_stderr_len out )
                ? > errlen 0 {
                    ( string_push_str body `\n[stderr]\n` )
                    ( string_push_str body ( output_stderr out ) )
                } {}
                ( output_free out )
                ^ ( truncate_for_model body )
            }
            F e → {
                : ProcessErr pe # ProcessErr e
                : String msg ( string_from `error: process_run failed: ` )
                ( string_push_str msg ( process_err_name pe ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( run_http_request_tool input )
    } {}

    ? != ( nurl_str_eq name `file_info` ) 0 {
        : s path ( input_str input `path` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'file_info' requires non-empty 'path' field` )
        } {}
        : String read_guard ( skill_active_read_guard_error path )
        ? > ( string_len read_guard ) 0 {
            : String msg ( string_from `error: ` )
            ( string_push_str msg ( string_data read_guard ) )
            ( string_free read_guard )
            ^ msg
        } {}
        ( string_free read_guard )
        ( trace_event `tool_file_info` path )
        : String out ( string_with_cap 128 )
        ( string_push_str out `path: ` )
        ( string_push_str out path )
        ( string_push_str out `\n` )
        ? ( file_exists path ) {
            ( string_push_str out `exists: true\n` )
            : !i IoErr sz ( file_size path )
            ?? sz {
                T bytes → {
                    ( string_push_str out `kind: file\nbytes: ` )
                    ( string_push_int out bytes )
                    ( string_push_str out `\n` )
                    : !String IoErr fr ( read_file path )
                    ?? fr {
                        T contents → {
                            : String digest ( sha256_hex ( string_data contents ) )
                            ( string_push_str out `sha256: ` )
                            ( string_push_str out ( string_data digest ) )
                            ( string_push_str out `\n` )
                            ( string_free digest )
                            ( string_free contents )
                        }
                        F _ → {}
                    }
                }
                F _ → {
                    : !( Vec String ) IoErr dl ( dir_list path )
                    ?? dl {
                        T entries → {
                            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
                            ( string_push_str out `kind: directory\nentries: ` )
                            ( string_push_int out ( vec_len [String] entries ) )
                            ( string_push_str out `\n` )
                            ( vec_free_with [String] entries drop_str )
                        }
                        F e → {
                            : IoErr ie # IoErr e
                            ( string_push_str out `kind: unknown\nerror: ` )
                            ( string_push_str out ( io_err_msg ie ) )
                            ( string_push_str out `\n` )
                        }
                    }
                }
            }
        } {
            ( string_push_str out `exists: false\n` )
        }
        ^ out
    } {}

    ? != ( nurl_str_eq name `read_file` ) 0 {
        : s path ( input_str input `path` )
        : i offset ( input_int input `offset` 0 )
        : i limit ( input_int input `limit` 0 )
        : b line_numbers ( input_bool input `line_numbers` F )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'read_file' requires non-empty 'path' field` )
        } {}
        : String read_guard ( skill_active_read_guard_error path )
        ? > ( string_len read_guard ) 0 {
            : String msg ( string_from `error: ` )
            ( string_push_str msg ( string_data read_guard ) )
            ( string_free read_guard )
            ^ msg
        } {}
        ( string_free read_guard )
        : String binary_guard ( read_file_binary_media_guard path )
        ? > ( string_len binary_guard ) 0 {
            ^ binary_guard
        } {}
        ( string_free binary_guard )
        ( trace_event `tool_read_file` path )
        : !String IoErr r ( read_file path )
        ?? r {
            T contents → {
                ? line_numbers {
                    ^ ( truncate_for_model ( slice_lines_numbered contents offset limit ) )
                } {
                    ^ ( truncate_for_model ( slice_lines contents offset limit ) )
                }
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: read_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `list_dir` ) 0 {
        : s path ( input_str input `path` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'list_dir' requires non-empty 'path' field` )
        } {}
        ( trace_event `tool_list_dir` path )
        : !( Vec String ) IoErr r ( dir_list path )
        ?? r {
            T entries → {
                : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
                : i n ( vec_len [String] entries )
                : String out ( string_with_cap 256 )
                ? == n 0 {
                    ( string_push_str out `(empty)\n` )
                } {}
                : ~ i k 0
                ~ < k n {
                    : ?String e ( vec_get [String] entries k )
                    ?? e {
                        T item → {
                            ( string_push_str out ( string_data item ) )
                            ( string_push_str out `\n` )
                        }
                        F → {}
                    }
                    = k + k 1
                }
                ( vec_free_with [String] entries drop_str )
                ^ ( truncate_for_model out )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: list_dir: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `write_file` ) 0 {
        : s path ( input_str input `path` )
        : s content ( input_str input `content` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'write_file' requires non-empty 'path' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String stale ( mutation_check_expected_sha path expected_sha256 )
        ? > ( string_len stale ) 0 {
            ^ stale
        } {}
        ( string_free stale )
        ( trace_event `tool_write_file` path )
        : !v IoErr r ( write_file path content )
        ?? r {
            T _ → {
                : String msg ( string_from `wrote ` )
                ( string_push_int msg ( nurl_str_len content ) )
                ( string_push_str msg ` bytes to ` )
                ( string_push_str msg path )
                ^ ( append_edit_check_result msg )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: write_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `append_file` ) 0 {
        : s path ( input_str input `path` )
        : s content ( input_str input `content` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'append_file' requires non-empty 'path' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String stale ( mutation_check_expected_sha path expected_sha256 )
        ? > ( string_len stale ) 0 {
            ^ stale
        } {}
        ( string_free stale )
        ( trace_event `tool_append_file` path )
        : !v IoErr r ( append_file path content )
        ?? r {
            T _ → {
                : String msg ( string_from `appended ` )
                ( string_push_int msg ( nurl_str_len content ) )
                ( string_push_str msg ` bytes to ` )
                ( string_push_str msg path )
                ^ ( append_edit_check_result msg )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: append_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `search_files` ) 0 {
        : s pattern ( input_str input `pattern` )
        : s path_raw ( input_str input `path` )
        : s target ( input_str input `target` )
        : i limit ( input_int input `limit` 50 )
        : i offset ( input_int input `offset` 0 )
        ? == ( nurl_str_len pattern ) 0 {
            ^ ( string_from `error: tool 'search_files' requires non-empty 'pattern' field` )
        } {}
        : s path ? == ( nurl_str_len path_raw ) 0 `.` path_raw
        ( trace_event `tool_search_files` pattern )

        : ( Vec s ) args ( vec_with_cap [s] 8 )
        ? != ( nurl_str_eq target `files` ) 0 {
            ( vec_push [s] args `--files` )
            ( vec_push [s] args `-g` )
            ( vec_push [s] args pattern )
            ( vec_push [s] args path )
        } {
            ? | == ( nurl_str_len target ) 0 != ( nurl_str_eq target `content` ) 0 {
                ( vec_push [s] args `--line-number` )
                ( vec_push [s] args `--no-heading` )
                ( vec_push [s] args `--with-filename` )
                ( vec_push [s] args `--color` )
                ( vec_push [s] args `never` )
                ( vec_push [s] args pattern )
                ( vec_push [s] args path )
            } {
                ( vec_free [s] args )
                ^ ( string_from `error: search_files target must be 'content' or 'files'` )
            }
        }
        : !Output ProcessErr r ( process_run `rg` args `` )
        ( vec_free [s] args )
        ?? r {
            T out → {
                : String body ( string_with_cap 256 )
                ( string_push_str body ( output_stdout out ) )
                : i errlen ( output_stderr_len out )
                ? > errlen 0 {
                    ( string_push_str body `\n[stderr]\n` )
                    ( string_push_str body ( output_stderr out ) )
                } {}
                ( output_free out )
                ^ ( truncate_for_model ( page_lines body offset limit ) )
            }
            F e → {
                : ProcessErr pe # ProcessErr e
                : String msg ( string_from `error: search_files requires rg: ` )
                ( string_push_str msg ( process_err_name pe ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `patch` ) 0 {
        : s mode ( input_str input `mode` )
        : b dry_run ( input_bool input `dry_run` F )
        ? != ( nurl_str_eq mode `patch` ) 0 {
            : s patch_text ( input_str input `patch` )
            ? == ( nurl_str_len patch_text ) 0 {
                ^ ( string_from `error: tool 'patch' requires non-empty 'patch' field when mode='patch'` )
            } {}
            ? dry_run {
                ( trace_event `tool_patch_v4a_dry_run` `multi-file` )
            } {
                ( trace_event `tool_patch_v4a` `multi-file` )
            }
            : String result ( apply_v4a_patch patch_text dry_run )
            ? | dry_run ( string_starts_with result `error:` ) {
                ^ result
            } {}
            ^ ( append_edit_check_result result )
        } {}
        ? & > ( nurl_str_len mode ) 0 == ( nurl_str_eq mode `replace` ) 0 {
            ^ ( string_from `error: patch mode must be 'replace' or 'patch'` )
        } {}

        : s path ( input_str input `path` )
        : s old_string ( input_str input `old_string` )
        : s new_string ( input_str input `new_string` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        : b replace_all ( input_bool input `replace_all` F )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'patch' requires non-empty 'path' field` )
        } {}
        ? == ( nurl_str_len old_string ) 0 {
            ^ ( string_from `error: tool 'patch' requires non-empty 'old_string' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String required ( mutation_expected_sha_guard path expected_sha256 )
        ? > ( string_len required ) 0 {
            ^ required
        } {}
        ( string_free required )
        ? dry_run {
            ( trace_event `tool_patch_dry_run` path )
        } {
            ( trace_event `tool_patch` path )
        }

        : !String IoErr rr ( read_file path )
        ?? rr {
            T contents → {
                : String stale ( patch_check_expected_sha256 path contents expected_sha256 )
                ? > ( string_len stale ) 0 {
                    ( string_free contents )
                    ^ stale
                } {}
                ( string_free stale )
                : i count ( string_count_occurrences contents old_string )
                ? == count 0 {
                    ( string_free contents )
                    ^ ( string_from `error: patch old_string not found` )
                } {}
                ? & ! replace_all > count 1 {
                    : String msg ( string_from `error: patch old_string occurs ` )
                    ( string_push_int msg count )
                    ( string_push_str msg ` times; set replace_all=true or include more context` )
                    ( string_free contents )
                    ^ msg
                } {}
                ? dry_run {
                    : String msg ( string_from `validated replace patch (dry run): would patch ` )
                    ( string_push_int msg count )
                    ( string_push_str msg ` occurrence` )
                    ? != count 1 { ( string_push_str msg `s` ) } {}
                    ( string_push_str msg ` in ` )
                    ( string_push_str msg path )
                    ( string_free contents )
                    ^ msg
                } {}
                : String patched ( string_replace contents old_string new_string )
                : !v IoErr wr ( write_file path ( string_data patched ) )
                ?? wr {
                    T _ → {
                        : String msg ( string_from `patched ` )
                        ( string_push_int msg count )
                        ( string_push_str msg ` occurrence` )
                        ? != count 1 { ( string_push_str msg `s` ) } {}
                        ( string_push_str msg ` in ` )
                        ( string_push_str msg path )
                        ( string_free contents )
                        ( string_free patched )
                        ^ ( append_edit_check_result msg )
                    }
                    F e → {
                        : IoErr ie # IoErr e
                        : String msg ( string_from `error: patch write_file: ` )
                        ( string_push_str msg ( io_err_msg ie ) )
                        ( string_free contents )
                        ( string_free patched )
                        ^ msg
                    }
                }
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: patch read_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `skills_list` ) 0 {
        : s category ( input_str input `category` )
        ( trace_event `tool_skills_list` category )
        ^ ( skills_list_json category )
    } {}

    ? != ( nurl_str_eq name `skill_view` ) 0 {
        : s skill_name ( input_str input `name` )
        : s file_path ( input_str input `file_path` )
        ? == ( nurl_str_len skill_name ) 0 {
            ^ ( string_from `error: tool 'skill_view' requires non-empty 'name' field` )
        } {}
        : String detail ( string_from skill_name )
        ? > ( nurl_str_len file_path ) 0 {
            ( string_push_str detail `:` )
            ( string_push_str detail file_path )
        } {}
        ( trace_event `tool_skill_view` ( string_data detail ) )
        ( string_free detail )
        ^ ( skill_view_json skill_name file_path )
    } {}

    ? != ( nurl_str_eq name `harness_record` ) 0 {
        : s action ( input_str input `action` )
        : s hname ( input_str input `name` )
        : s value ( input_str input `value` )
        : s detail ( input_str input `detail` )
        ( trace_event `tool_harness_record` action )
        ? != ( nurl_str_eq action `start` ) 0 {
            ? == ( nurl_str_len hname ) 0 {
                ^ ( string_from `error: harness_record start requires name=<contract-id>` )
            } {}
            ^ ( harness_start_run hname )
        } {}
        ? != ( nurl_str_eq action `evidence` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record evidence requires name=<kind> and value=<evidence>` )
            } {}
            ^ ( harness_record_evidence hname value )
        } {}
        ? != ( nurl_str_eq action `handoff` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record handoff requires name=<dependent-skill> and value=<artifact>` )
            } {}
            ^ ( harness_record_handoff hname value detail )
        } {}
        ? != ( nurl_str_eq action `gate` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record gate requires name=<gate> and value=<status>` )
            } {}
            ^ ( harness_record_gate hname value detail )
        } {}
        ? != ( nurl_str_eq action `preflight` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record preflight requires name=<preflight> and value=<status>` )
            } {}
            ^ ( harness_record_preflight hname value detail )
        } {}
        ? != ( nurl_str_eq action `report` ) 0 {
            ? == ( nurl_str_len hname ) 0 {
                ^ ( string_from `error: harness_record report requires name=<status>` )
            } {}
            ^ ( harness_write_report hname value )
        } {}
        ? != ( nurl_str_eq action `allow_read` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record allow_read requires name=<skill> and value=<relative-path>` )
            } {}
            ^ ( harness_unlock_read hname value detail )
        } {}
        ? != ( nurl_str_eq action `complete` ) 0 {
            ^ ( harness_completion_check_json )
        } {}
        ^ ( string_from `error: harness_record action must be start, evidence, handoff, gate, preflight, report, allow_read, or complete` )
    } {}

    : String unknown ( string_from `error: unknown tool '` )
    ( string_push_str unknown name )
    ( string_push_str unknown `'` )
    ^ unknown
}

@ run_local_claude_tool Json tu → String {
    : s name ( claude_tool_use_name tu )
    : ?Json input_o ( claude_tool_use_input tu )

    : Json input ?? input_o {
        T j → j
        F → @ Json { JNull }
    }

    ^ ( run_local_tool_input name input )
}

@ is_local_tool s name → b {
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        ? != ( nurl_str_eq name ( local_tool_name k ) ) 0 { ^ T } {}
        = k + k 1
    }
    ^ F
}
