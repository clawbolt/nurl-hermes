// Tool registry, descriptions, schema dispatch, and provider-specific builders.
// Extracted from tools_local.nu for maintainability.

$ `stdlib/ext/json.nu`
$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/mcp.nu`
$ `nurl/src/common.nu`

@ edit_check_strict_enabled → b {
    ^ ( env_truthy `HERMES_NURL_EDIT_CHECK_STRICT` )
}

@ edit_check_strict_result String summary s label → String {
    ? ( edit_check_strict_enabled ) {
        : String out ( string_from `error: ` )
        ( string_push_str out label )
        ( string_push_str out ` after edit\n` )
        ( string_push_str out ( string_data summary ) )
        ( string_free summary )
        ^ ( truncate_for_model out )
    } {}
    ^ summary
}

@ append_edit_check_result String summary → String {
    : String cmd ( hermes_nurl_edit_check_command )
    ? == ( string_len cmd ) 0 {
        ( string_free cmd )
        ^ summary
    } {}
    ? ! ( hermes_nurl_shell_allowed ) {
        ( trace_event `edit_check_skipped` `shell_disabled` )
        ( string_push_str summary `\n[edit check skipped]\nHERMES_NURL_EDIT_CHECK_COMMAND is set, but shell execution is disabled. Set HERMES_NURL_ALLOW_SHELL=1 in production mode to run it.` )
        ( string_free cmd )
        ^ ( edit_check_strict_result summary `edit check skipped` )
    } {}
    ? ( shell_command_blocked ( string_data cmd ) ) {
        ? ( env_truthy `HERMES_NURL_ALLOW_DESTRUCTIVE` ) {} {
            ( trace_event `edit_check_blocked` `shell_guard` )
            ( string_push_str summary `\n[edit check blocked]\nConfigured command was refused by the shell guard: ` )
            ( string_push_str summary ( string_data cmd ) )
            ( string_free cmd )
            ^ ( edit_check_strict_result summary `edit check blocked` )
        }
    } {}
    ( trace_event `edit_check_start` ( string_data cmd ) )
    : !Output ProcessErr r ( process_run_shell ( string_data cmd ) )
    ?? r {
        T out → {
            : i ec ( output_exit_code out )
            ? == ec 0 {
                ( trace_event `edit_check_passed` ( string_data cmd ) )
                ( string_push_str summary `\n[edit check passed]\ncommand: ` )
            } {
                : String detail ( string_from ( string_data cmd ) )
                ( string_push_str detail ` exit=` )
                ( string_push_int detail ec )
                ( trace_event `edit_check_failed` ( string_data detail ) )
                ( string_free detail )
                ( string_push_str summary `\n[edit check failed: exit ` )
                ( string_push_int summary ec )
                ( string_push_str summary `]\ncommand: ` )
            }
            ( string_push_str summary ( string_data cmd ) )
            : s stdout ( output_stdout out )
            ? > ( nurl_str_len stdout ) 0 {
                ( string_push_str summary `\n[stdout]\n` )
                ( string_push_str summary stdout )
            } {}
            : i errlen ( output_stderr_len out )
            ? > errlen 0 {
                ( string_push_str summary `\n[stderr]\n` )
                ( string_push_str summary ( output_stderr out ) )
            } {}
            ( output_free out )
            ( string_free cmd )
            ? != ec 0 {
                ^ ( edit_check_strict_result summary `edit check failed` )
            } {}
            ^ ( truncate_for_model summary )
        }
        F e → {
            : ProcessErr pe # ProcessErr e
            ( trace_event `edit_check_error` ( process_err_name pe ) )
            ( string_push_str summary `\n[edit check error]\n` )
            ( string_push_str summary ( process_err_name pe ) )
            ( string_free cmd )
            ^ ( edit_check_strict_result summary `edit check error` )
        }
    }
}

@ local_tool_count → i { ^ 12 }

@ local_tool_name i idx → s {
    ? == idx 0 { ^ `run_shell` } {}
    ? == idx 1 { ^ `file_info` } {}
    ? == idx 2 { ^ `read_file` } {}
    ? == idx 3 { ^ `list_dir` } {}
    ? == idx 4 { ^ `write_file` } {}
    ? == idx 5 { ^ `append_file` } {}
    ? == idx 6 { ^ `search_files` } {}
    ? == idx 7 { ^ `patch` } {}
    ? == idx 8 { ^ `skills_list` } {}
    ? == idx 9 { ^ `skill_view` } {}
    ? == idx 10 { ^ `http_request` } {}
    ? == idx 11 { ^ `harness_record` } {}
    ^ ``
}

@ local_tool_is_mutating s name → b {
    ? != ( nurl_str_eq name `write_file` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `append_file` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `patch` ) 0 { ^ T } {}
    ^ F
}

@ local_tool_enabled s name → b {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ ( hermes_nurl_shell_allowed )
    } {}
    ? ( local_tool_is_mutating name ) {
        ^ ( hermes_nurl_mutations_allowed )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( hermes_nurl_network_allowed )
    } {}
    ^ T
}

@ local_tool_blocked_message s name → String {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ( trace_event `tool_blocked` `production_mode:run_shell` )
        ^ ( string_from `error: run_shell is disabled in HERMES_NURL_PRODUCTION_MODE. Set HERMES_NURL_ALLOW_SHELL=1 to expose it.` )
    } {}
    ? ( local_tool_is_mutating name ) {
        : String detail ( string_from `production_mode:` )
        ( string_push_str detail name )
        ( trace_event `tool_blocked` ( string_data detail ) )
        ( string_free detail )
        ^ ( string_from `error: mutating tools are disabled in HERMES_NURL_PRODUCTION_MODE. Set HERMES_NURL_ALLOW_MUTATIONS=1 to expose write_file, append_file, and patch.` )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ( trace_event `tool_blocked` `production_mode:http_request` )
        ^ ( string_from `error: http_request is disabled. In production set HERMES_NURL_ALLOW_NETWORK=1 and configure HERMES_NURL_NETWORK_ALLOW_HOSTS or HERMES_NURL_NETWORK_ALLOW_BASE_URLS.` )
    } {}
    ^ ( string_from `` )
}

@ local_tool_description s name → s {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ `Run a shell command and return stdout plus stderr. Use sparingly.`
    } {}
    ? != ( nurl_str_eq name `file_info` ) 0 {
        ^ `Return basic path metadata such as existence, kind, and file size.`
    } {}
    ? != ( nurl_str_eq name `read_file` ) 0 {
        ^ `Read a UTF-8 text file, optionally by line offset and limit.`
    } {}
    ? != ( nurl_str_eq name `list_dir` ) 0 {
        ^ `List entries in a directory.`
    } {}
    ? != ( nurl_str_eq name `write_file` ) 0 {
        ^ `Write UTF-8 content to a file, replacing existing contents.`
    } {}
    ? != ( nurl_str_eq name `append_file` ) 0 {
        ^ `Append UTF-8 content to a file.`
    } {}
    ? != ( nurl_str_eq name `search_files` ) 0 {
        ^ `Search file contents or file paths with ripgrep.`
    } {}
    ? != ( nurl_str_eq name `patch` ) 0 {
        ^ `Targeted exact string replacement or V4A Add/Update/Delete/Move multi-file patches in UTF-8 files.`
    } {}
    ? != ( nurl_str_eq name `skills_list` ) 0 {
        ^ `List available Hermes skills with compact metadata. Use skill_view to load full instructions.`
    } {}
    ? != ( nurl_str_eq name `skill_view` ) 0 {
        ^ `Load a Hermes skill's SKILL.md content or one linked file from references, templates, assets, scripts, commands, or brand bundles.`
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ `Make a controlled HTTP GET or POST request with production policy checks, response caps, and secret redaction. Prefer skill helpers for workflow-specific APIs.`
    } {}
    ? != ( nurl_str_eq name `harness_record` ) 0 {
        ^ `Record harness lifecycle evidence, gate status, and final report state for contract-backed workflows.`
    } {}
    ^ `Local Hermes NURL tool`
}

@ local_tool_schema s name → Json {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ ( one_string_schema `command` `Shell command to execute via /bin/sh -c` )
    } {}
    ? != ( nurl_str_eq name `file_info` ) 0 {
        ^ ( file_info_schema )
    } {}
    ? != ( nurl_str_eq name `read_file` ) 0 {
        ^ ( read_file_schema )
    } {}
    ? != ( nurl_str_eq name `list_dir` ) 0 {
        ^ ( one_string_schema `path` `Directory path to list` )
    } {}
    ? != ( nurl_str_eq name `write_file` ) 0 {
        ^ ( path_content_schema )
    } {}
    ? != ( nurl_str_eq name `append_file` ) 0 {
        ^ ( path_content_schema )
    } {}
    ? != ( nurl_str_eq name `search_files` ) 0 {
        ^ ( search_files_schema )
    } {}
    ? != ( nurl_str_eq name `patch` ) 0 {
        ^ ( patch_schema )
    } {}
    ? != ( nurl_str_eq name `skills_list` ) 0 {
        ^ ( skills_list_schema )
    } {}
    ? != ( nurl_str_eq name `skill_view` ) 0 {
        ^ ( skill_view_schema )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( http_request_schema )
    } {}
    ? != ( nurl_str_eq name `harness_record` ) 0 {
        ^ ( harness_record_schema )
    } {}
    : Json empty ( json_obj_new )
    ( json_obj_set empty `type` ( json_str_lit `object` ) )
    ^ empty
}

@ build_local_claude_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( vec_new [Json] )
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( claude_tool_def name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
    ^ tools
}

@ openai_compat_tool_def s name s description Json parameters → Json {
    : Json fn ( json_obj_new )
    ( json_obj_set fn `name` ( json_str_lit name ) )
    ( json_obj_set fn `description` ( json_str_lit description ) )
    ( json_obj_set fn `parameters` parameters )

    : Json t ( json_obj_new )
    ( json_obj_set t `type` ( json_str_lit `function` ) )
    ( json_obj_set t `function` fn )
    ^ t
}

@ build_local_openai_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( vec_new [Json] )
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( openai_compat_tool_def name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
    ^ tools
}

@ add_local_mcp_tools ( Vec Json ) tools → v {
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( mcp_tool_descriptor name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
}
