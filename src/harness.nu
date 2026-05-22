// Generic harness contract helpers for NURL Hermes.
//
// Contracts are optional, skill-local JSON files that describe workflow shape:
// entrypoints, required files, dependent skills, evidence, gates, and
// completion requirements. Newer contracts may also describe source indexes,
// read boundaries, conditional reads, and preflight gates.

$ `stdlib/ext/json.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/path.nu`
$ `stdlib/std/time.nu`
$ `stdlib/core/string.nu`
$ `nurl/src/common.nu`

@ harness_contract_path s skill_dir → String {
    : String direct ( path_join skill_dir `harness.json` )
    ? ( file_exists ( string_data direct ) ) { ^ direct } {}
    ( string_free direct )

    : String named ( path_join skill_dir `harness.contract.json` )
    ? ( file_exists ( string_data named ) ) { ^ named } {}
    ( string_free named )

    : String hidden ( path_join skill_dir `.harness.json` )
    ? ( file_exists ( string_data hidden ) ) { ^ hidden } {}
    ( string_free hidden )

    ^ ( string_new )
}

@ harness_contract_exists s skill_dir → b {
    : String path ( harness_contract_path skill_dir )
    : b ok ? > ( string_len path ) 0 T F
    ( string_free path )
    ^ ok
}

@ harness_json_get_string Json obj s field s fallback → String {
    : ?Json v ( json_obj_get obj field )
    ?? v {
        T j → { ^ ( string_from ( json_str_data j ) ) }
        F → {}
    }
    ^ ( string_from fallback )
}

@ harness_json_clone_field_or_empty_array Json obj s field → Json {
    : ?Json v ( json_obj_get obj field )
    ?? v {
        T j → { ^ ( json_clone j ) }
        F → {}
    }
    ^ ( json_arr_new )
}

@ harness_json_clone_field_or_null Json obj s field → Json {
    : ?Json v ( json_obj_get obj field )
    ?? v {
        T j → { ^ ( json_clone j ) }
        F → {}
    }
    ^ ( json_null )
}

@ harness_contract_error_json s path s error → Json {
    : Json result ( json_obj_new )
    ( json_obj_set result `present` ( json_bool T ) )
    ( json_obj_set result `valid` ( json_bool F ) )
    ( json_obj_set result `path` ( json_str_lit path ) )
    ( json_obj_set result `error` ( json_str_lit error ) )
    ^ result
}

@ harness_contract_summary_from_json s path Json contract → Json {
    : Json result ( json_obj_new )
    ( json_obj_set result `present` ( json_bool T ) )
    ( json_obj_set result `valid` ( json_bool T ) )
    ( json_obj_set result `path` ( json_str_lit path ) )

    : String identity ( harness_json_get_string contract `identity` `` )
    ? > ( string_len identity ) 0 {
        ( json_obj_set result `identity` ( json_str_lit ( string_data identity ) ) )
    } {}
    ( string_free identity )

    : String version ( harness_json_get_string contract `version` `` )
    ? > ( string_len version ) 0 {
        ( json_obj_set result `version` ( json_str_lit ( string_data version ) ) )
    } {}
    ( string_free version )

    ( json_obj_set result `entrypoints` ( harness_json_clone_field_or_empty_array contract `entrypoints` ) )
    ( json_obj_set result `required_files` ( harness_json_clone_field_or_empty_array contract `required_files` ) )
    ( json_obj_set result `ignored_paths` ( harness_json_clone_field_or_empty_array contract `ignored_paths` ) )
    : ?Json source_index ( json_obj_get contract `source_index` )
    ?? source_index {
        T si → {
            ( json_obj_set result `source_index` ( json_clone si ) )
        }
        F → {}
    }
    ( json_obj_set result `forbidden_reads` ( harness_json_clone_field_or_empty_array contract `forbidden_reads` ) )
    ( json_obj_set result `conditional_reads` ( harness_json_clone_field_or_empty_array contract `conditional_reads` ) )
    ( json_obj_set result `dependent_skills` ( harness_json_clone_field_or_empty_array contract `dependent_skills` ) )
    ( json_obj_set result `evidence` ( harness_json_clone_field_or_empty_array contract `evidence` ) )
    ( json_obj_set result `gates` ( harness_json_clone_field_or_empty_array contract `gates` ) )
    ( json_obj_set result `preflight_gates` ( harness_json_clone_field_or_empty_array contract `preflight_gates` ) )
    ( json_obj_set result `completion` ( harness_json_clone_field_or_empty_array contract `completion` ) )
    ( json_obj_set result `output_policy` ( harness_json_clone_field_or_null contract `output_policy` ) )
    ^ result
}

@ harness_contract_summary_for_dir s skill_dir → Json {
    : String path ( harness_contract_path skill_dir )
    ? == ( string_len path ) 0 {
        ( string_free path )
        ^ ( json_null )
    } {}

    : !String IoErr rd ( read_file ( string_data path ) )
    ?? rd {
        T body → {
            : !Json ParseErr parsed ( json_parse ( string_data body ) )
            ( string_free body )
            ?? parsed {
                T contract → {
                    : Json summary ( harness_contract_summary_from_json ( string_data path ) contract )
                    ( json_free contract )
                    ( string_free path )
                    ^ summary
                }
                F _ → {
                    : Json err ( harness_contract_error_json ( string_data path ) `invalid JSON contract` )
                    ( string_free path )
                    ^ err
                }
            }
        }
        F e → {
            : IoErr ie # IoErr e
            : Json err2 ( harness_contract_error_json ( string_data path ) ( io_err_msg ie ) )
            ( string_free path )
            ^ err2
        }
    }
}

@ harness_string_array_join Json obj s field → String {
    : ?Json got ( json_obj_get obj field )
    ?? got {
        T arr → {
            : String out ( string_new )
            : i n ( json_arr_len arr )
            : ~ i k 0
            ~ < k n {
                : ?Json item ( json_arr_get arr k )
                ?? item {
                    T j → {
                        ? > ( string_len out ) 0 {
                            ( string_push_str out `,` )
                        } {}
                        ( string_push_str out ( json_str_data j ) )
                    }
                    F → {}
                }
                = k + k 1
            }
            ^ out
        }
        F → {}
    }
    ^ ( string_new )
}

@ harness_contract_prompt_fragment s skill_dir → String {
    : String path ( harness_contract_path skill_dir )
    ? == ( string_len path ) 0 {
        ( string_free path )
        ^ ( string_new )
    } {}
    : !String IoErr rd ( read_file ( string_data path ) )
    ?? rd {
        T body → {
            : !Json ParseErr parsed ( json_parse ( string_data body ) )
            ( string_free body )
            ?? parsed {
                T contract → {
                    : String deps ( harness_string_array_join contract `dependent_skills` )
                    : String gates ( harness_string_array_join contract `gates` )
                    : String preflights ( harness_string_array_join contract `preflight_gates` )
                    : String out ( string_from ` [harness` )
                    : ?Json source_index ( json_obj_get contract `source_index` )
                    ?? source_index {
                        T _ → {
                            ( string_push_str out ` source_index=contract` )
                        }
                        F → {}
                    }
                    ? > ( string_len deps ) 0 {
                        ( string_push_str out ` deps=` )
                        ( string_push_str out ( string_data deps ) )
                    } {}
                    ? > ( string_len gates ) 0 {
                        ( string_push_str out ` gates=` )
                        ( string_push_str out ( string_data gates ) )
                    } {}
                    ? > ( string_len preflights ) 0 {
                        ( string_push_str out ` preflights=` )
                        ( string_push_str out ( string_data preflights ) )
                    } {}
                    ( string_push_str out `]` )
                    ( string_free deps )
                    ( string_free gates )
                    ( string_free preflights )
                    ( json_free contract )
                    ( string_free path )
                    ^ out
                }
                F _ → {
                    ( string_free path )
                    ^ ( string_from ` [harness invalid]` )
                }
            }
        }
        F _ → {}
    }
    ( string_free path )
    ^ ( string_new )
}

@ harness_run_id → String {
    : ?String got ( env_get `HERMES_NURL_RUN_ID` )
    ?? got {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            ? > ( string_len trimmed ) 0 { ^ trimmed } {}
            ( string_free trimmed )
        }
        F → {}
    }
    : String generated ( string_from `run-` )
    ( string_push_int generated ( now_ms ) )
    ( string_push_str generated `-` )
    ( string_push_int generated ( monotonic_ns ) )
    : !v IoErr set_id ( env_set `HERMES_NURL_RUN_ID` ( string_data generated ) )
    ?? set_id { T _ → {} F _ → {} }
    ^ generated
}

@ harness_add_session_id Json evt → v {
    : ?String sid ( env_get `HERMES_NURL_SESSION_ID` )
    ?? sid {
        T raw → {
            ? > ( string_len raw ) 0 {
                ( json_obj_set evt `session_id` ( json_str_lit ( string_data raw ) ) )
            } {}
            ( string_free raw )
        }
        F → {}
    }
}

@ harness_emit_event s event s detail Json fields → v {
    : String run_id ( harness_run_id )
    : Json evt ( json_obj_new )
    ( json_obj_set evt `event` ( json_str_lit event ) )
    ( json_obj_set evt `run_id` ( json_str_lit ( string_data run_id ) ) )
    ( json_obj_set evt `detail` ( json_str_lit detail ) )
    ( harness_add_session_id evt )
    : ?Json field_keys ( json_obj_get fields `fields` )
    ?? field_keys {
        T extra → {
            ( json_obj_set evt `fields` ( json_clone extra ) )
        }
        F → {}
    }
    : String rendered ( json_stringify evt )
    ( append_jsonl_env_json `HERMES_NURL_TRACE` ( json_clone evt ) )
    ( append_jsonl_env_json `HERMES_NURL_SESSION_LOG` ( json_clone evt ) )
    ( session_db_event event ( string_data rendered ) )
    ( json_free evt )
    ( json_free fields )
    ( string_free rendered )
    ( string_free run_id )
}

@ harness_result_json s event s detail → String {
    : String run_id ( harness_run_id )
    : Json result ( json_obj_new )
    ( json_obj_set result `success` ( json_bool T ) )
    ( json_obj_set result `event` ( json_str_lit event ) )
    ( json_obj_set result `run_id` ( json_str_lit ( string_data run_id ) ) )
    ( json_obj_set result `detail` ( json_str_lit detail ) )
    : String out ( json_stringify result )
    ( json_free result )
    ( string_free run_id )
    ^ out
}

@ harness_set_flag s name s value → v {
    : !v IoErr r ( env_set name value )
    ?? r { T _ → {} F _ → {} }
}

@ harness_status_good s status → b {
    ? != ( nurl_str_eq status `passed` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `passed ` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `passed:` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `passed-` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `pass` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `pass ` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `ok` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `ok ` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `success` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `success ` ) 0 { ^ T } {}
    ^ F
}

@ harness_status_blocked s status → b {
    ? != ( nurl_str_eq status `blocked` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `blocked ` ) 0 { ^ T } {}
    ? == ( nurl_str_find status `blocked:` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `no-go` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `nogo` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `not_ready` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `unavailable` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `rejected` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `refused` ) 0 { ^ T } {}
    ? != ( nurl_str_eq status `cannot_continue` ) 0 { ^ T } {}
    ^ F
}

@ harness_fields1 s key s value → Json {
    : Json outer ( json_obj_new )
    : Json fields ( json_obj_new )
    ( json_obj_set fields key ( json_str_lit value ) )
    ( json_obj_set outer `fields` fields )
    ^ outer
}

@ harness_fields2 s key1 s value1 s key2 s value2 → Json {
    : Json outer ( json_obj_new )
    : Json fields ( json_obj_new )
    ( json_obj_set fields key1 ( json_str_lit value1 ) )
    ( json_obj_set fields key2 ( json_str_lit value2 ) )
    ( json_obj_set outer `fields` fields )
    ^ outer
}

@ harness_fields3 s key1 s value1 s key2 s value2 s key3 s value3 → Json {
    : Json outer ( json_obj_new )
    : Json fields ( json_obj_new )
    ( json_obj_set fields key1 ( json_str_lit value1 ) )
    ( json_obj_set fields key2 ( json_str_lit value2 ) )
    ( json_obj_set fields key3 ( json_str_lit value3 ) )
    ( json_obj_set outer `fields` fields )
    ^ outer
}

@ harness_fields4 s key1 s value1 s key2 s value2 s key3 s value3 s key4 s value4 → Json {
    : Json outer ( json_obj_new )
    : Json fields ( json_obj_new )
    ( json_obj_set fields key1 ( json_str_lit value1 ) )
    ( json_obj_set fields key2 ( json_str_lit value2 ) )
    ( json_obj_set fields key3 ( json_str_lit value3 ) )
    ( json_obj_set fields key4 ( json_str_lit value4 ) )
    ( json_obj_set outer `fields` fields )
    ^ outer
}

@ harness_start_run s contract_id → String {
    ( harness_set_flag `HERMES_NURL_ACTIVE_HARNESS_CONTRACT` contract_id )
    ( harness_set_flag `HERMES_NURL_HARNESS_REPORT_WRITTEN` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_GATE_PASSED` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_GATE_FAILED` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_READ_VIOLATION` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_READ_UNLOCKS` `` )
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_REQUIRED` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_PASSED` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` `0` )
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_NAMES` `` )
    ( harness_set_flag `HERMES_NURL_HARNESS_NO_GO_REPORT` `0` )
    ( harness_emit_event `harness_run_started` contract_id ( harness_fields1 `contract` contract_id ) )
    ^ ( harness_result_json `harness_run_started` contract_id )
}

@ harness_name_in_csv s csv s name → b {
    : String hay ( string_from `,` )
    ( string_push_str hay csv )
    ( string_push_str hay `,` )
    : String needle ( string_from `,` )
    ( string_push_str needle name )
    ( string_push_str needle `,` )
    : b ok ( string_contains hay ( string_data needle ) )
    ( string_free hay )
    ( string_free needle )
    ^ ok
}

@ harness_maybe_mark_preflight_from_gate s name s status → v {
    : ?String got ( env_get `HERMES_NURL_HARNESS_PREFLIGHT_NAMES` )
    ?? got {
        T names → {
            ? ( harness_name_in_csv ( string_data names ) name ) {
                ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_REQUIRED` `1` )
                ? ( harness_status_good status ) {
                    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_PASSED` `1` )
                    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` `0` )
                } {
                    ? != ( nurl_str_eq status `skipped` ) 0 {} {
                        ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` `1` )
                    }
                }
            } {}
            ( string_free names )
        }
        F → {}
    }
}

@ harness_record_evidence s kind s value → String {
    : String detail ( string_from kind )
    ( string_push_str detail `=` )
    ( string_push_str detail value )
    ( harness_emit_event `harness_evidence_recorded` ( string_data detail ) ( harness_fields2 `kind` kind `value` value ) )
    : String out ( harness_result_json `harness_evidence_recorded` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_record_handoff s skill s artifact s detail_text → String {
    : String detail ( string_from skill )
    ( string_push_str detail ` -> ` )
    ( string_push_str detail artifact )
    ? > ( nurl_str_len detail_text ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail detail_text )
    } {}
    ( harness_emit_event `harness_handoff_recorded` ( string_data detail ) ( harness_fields3 `skill` skill `artifact` artifact `detail` detail_text ) )
    : String out ( harness_result_json `harness_handoff_recorded` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_record_gate s name s status s detail_text → String {
    ? ( harness_status_good status ) {
        ( harness_set_flag `HERMES_NURL_HARNESS_GATE_PASSED` `1` )
    } {
        ? != ( nurl_str_eq status `skipped` ) 0 {} {
            ( harness_set_flag `HERMES_NURL_HARNESS_GATE_FAILED` `1` )
        }
    }
    ( harness_maybe_mark_preflight_from_gate name status )
    : String detail ( string_from name )
    ( string_push_str detail `:` )
    ( string_push_str detail status )
    ? > ( nurl_str_len detail_text ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail detail_text )
    } {}
    ( harness_emit_event `harness_gate_recorded` ( string_data detail ) ( harness_fields2 `name` name `status` status ) )
    : String out ( harness_result_json `harness_gate_recorded` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_require_preflight s reason → v {
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_REQUIRED` `1` )
    ( harness_emit_event `harness_preflight_required` reason ( harness_fields1 `reason` reason ) )
}

@ harness_record_preflight s name s status s detail_text → String {
    ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_REQUIRED` `1` )
    ? ( harness_status_good status ) {
        ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_PASSED` `1` )
        ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` `0` )
    } {
        ? != ( nurl_str_eq status `skipped` ) 0 {} {
            ( harness_set_flag `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` `1` )
        }
    }
    : String detail ( string_from name )
    ( string_push_str detail `:` )
    ( string_push_str detail status )
    ? > ( nurl_str_len detail_text ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail detail_text )
    } {}
    ( harness_emit_event `harness_preflight_recorded` ( string_data detail ) ( harness_fields2 `name` name `status` status ) )
    : String out ( harness_result_json `harness_preflight_recorded` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_write_report s status s detail_text → String {
    ( harness_set_flag `HERMES_NURL_HARNESS_REPORT_WRITTEN` `1` )
    ? ( harness_status_blocked status ) {
        ( harness_set_flag `HERMES_NURL_HARNESS_NO_GO_REPORT` `1` )
    } {
        ( harness_set_flag `HERMES_NURL_HARNESS_NO_GO_REPORT` `0` )
    }
    ? | | != ( nurl_str_eq status `failed` ) 0 != ( nurl_str_eq status `fail` ) 0 != ( nurl_str_eq status `error` ) 0 {
        ( harness_set_flag `HERMES_NURL_HARNESS_GATE_FAILED` `1` )
    } {
        ( harness_set_flag `HERMES_NURL_HARNESS_GATE_FAILED` `0` )
    }
    : String detail ( string_from status )
    ? > ( nurl_str_len detail_text ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail detail_text )
    } {}
    ( harness_emit_event `harness_report_written` ( string_data detail ) ( harness_fields1 `status` status ) )
    : String out ( harness_result_json `harness_report_written` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_read_unlock_token s skill s path → String {
    : String token ( string_from skill )
    ( string_push_str token `:` )
    ( string_push_str token path )
    ^ token
}

@ harness_read_unlocked s skill s path → b {
    : String token ( harness_read_unlock_token skill path )
    : ?String got ( env_get `HERMES_NURL_HARNESS_READ_UNLOCKS` )
    ?? got {
        T raw → {
            : b ok ( string_contains raw ( string_data token ) )
            ( string_free raw )
            ( string_free token )
            ^ ok
        }
        F → {}
    }
    ( string_free token )
    ^ F
}

@ harness_unlock_read s skill s path s reason → String {
    : String token ( harness_read_unlock_token skill path )
    : String next ( string_new )
    : ?String got ( env_get `HERMES_NURL_HARNESS_READ_UNLOCKS` )
    ?? got {
        T raw → {
            ( string_push_str next ( string_data raw ) )
            ( string_free raw )
        }
        F → {}
    }
    ? > ( string_len next ) 0 {
        ( string_push_str next `\n` )
    } {}
    ( string_push_str next ( string_data token ) )
    ( harness_set_flag `HERMES_NURL_HARNESS_READ_UNLOCKS` ( string_data next ) )
    : String detail ( string_from skill )
    ( string_push_str detail `:` )
    ( string_push_str detail path )
    ? > ( nurl_str_len reason ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail reason )
    } {}
    ( harness_emit_event `harness_read_unlocked` ( string_data detail ) ( harness_fields3 `skill` skill `path` path `reason` reason ) )
    : String out ( harness_result_json `harness_read_unlocked` ( string_data detail ) )
    ( string_free token )
    ( string_free next )
    ( string_free detail )
    ^ out
}

@ harness_record_read_violation s skill s path s rule s reason → String {
    ( harness_set_flag `HERMES_NURL_HARNESS_READ_VIOLATION` `1` )
    : String detail ( string_from skill )
    ( string_push_str detail `:` )
    ( string_push_str detail path )
    ( string_push_str detail ` ` )
    ( string_push_str detail rule )
    ? > ( nurl_str_len reason ) 0 {
        ( string_push_str detail ` ` )
        ( string_push_str detail reason )
    } {}
    ( harness_emit_event `harness_read_violation` ( string_data detail ) ( harness_fields4 `skill` skill `path` path `rule` rule `reason` reason ) )
    : String out ( harness_result_json `harness_read_violation` ( string_data detail ) )
    ( string_free detail )
    ^ out
}

@ harness_completion_error → String {
    : ?String active ( env_get `HERMES_NURL_ACTIVE_HARNESS_CONTRACT` )
    ?? active {
        T contract → {
            : String trimmed ( string_trim contract )
            ( string_free contract )
            ? == ( string_len trimmed ) 0 {
                ^ trimmed
            } {}

            ? ( env_truthy `HERMES_NURL_HARNESS_READ_VIOLATION` ) {
                : String msg0 ( string_from `Harness contract '` )
                ( string_push_str msg0 ( string_data trimmed ) )
                ( string_push_str msg0 `' has an unresolved read-boundary violation. Inspect harness-events and repair or restart before final reporting.` )
                ( string_free trimmed )
                ^ msg0
            } {}

            ? ( env_truthy `HERMES_NURL_HARNESS_PREFLIGHT_FAILED` ) {
                ? ( env_truthy `HERMES_NURL_HARNESS_NO_GO_REPORT` ) {
                    ( string_free trimmed )
                    ^ ( string_new )
                } {}
                : String msgp0 ( string_from `Harness contract '` )
                ( string_push_str msgp0 ( string_data trimmed ) )
                ( string_push_str msgp0 `' has a failed required preflight gate. Inspect harness-events and repair before final reporting.` )
                ( string_free trimmed )
                ^ msgp0
            } {}

            ? & ( env_truthy `HERMES_NURL_HARNESS_PREFLIGHT_REQUIRED` ) ! ( env_truthy `HERMES_NURL_HARNESS_PREFLIGHT_PASSED` ) {
                ? ( env_truthy `HERMES_NURL_HARNESS_NO_GO_REPORT` ) {
                    ( string_free trimmed )
                    ^ ( string_new )
                } {}
                : String msgp1 ( string_from `Harness contract '` )
                ( string_push_str msgp1 ( string_data trimmed ) )
                ( string_push_str msgp1 `' has no passed required preflight gate. Run and record the preflight before final reporting.` )
                ( string_free trimmed )
                ^ msgp1
            } {}

            ? ( env_truthy `HERMES_NURL_HARNESS_GATE_FAILED` ) {
                ? ( env_truthy `HERMES_NURL_HARNESS_NO_GO_REPORT` ) {
                    ( string_free trimmed )
                    ^ ( string_new )
                } {}
                : String msg ( string_from `Harness contract '` )
                ( string_push_str msg ( string_data trimmed ) )
                ( string_push_str msg `' has a failed required gate. Inspect harness-events and repair before final reporting.` )
                ( string_free trimmed )
                ^ msg
            } {}

            ? ! ( env_truthy `HERMES_NURL_HARNESS_GATE_PASSED` ) {
                ? ( env_truthy `HERMES_NURL_HARNESS_NO_GO_REPORT` ) {
                    ( string_free trimmed )
                    ^ ( string_new )
                } {}
                : String msg2 ( string_from `Harness contract '` )
                ( string_push_str msg2 ( string_data trimmed ) )
                ( string_push_str msg2 `' has no passed verification gate. Run the required gate and record it before final reporting.` )
                ( string_free trimmed )
                ^ msg2
            } {}

            ? ! ( env_truthy `HERMES_NURL_HARNESS_REPORT_WRITTEN` ) {
                : String msg3 ( string_from `Harness contract '` )
                ( string_push_str msg3 ( string_data trimmed ) )
                ( string_push_str msg3 `' has no final run report evidence. Write the report before final reporting.` )
                ( string_free trimmed )
                ^ msg3
            } {}

            ( string_free trimmed )
        }
        F → {}
    }
    ^ ( string_new )
}

@ harness_completion_check_json → String {
    : String err ( harness_completion_error )
    : Json result ( json_obj_new )
    ? > ( string_len err ) 0 {
        ( json_obj_set result `success` ( json_bool F ) )
        ( json_obj_set result `error` ( json_str_lit ( string_data err ) ) )
    } {
        ( json_obj_set result `success` ( json_bool T ) )
        ( json_obj_set result `status` ( json_str_lit `complete` ) )
    }
    : String out ( json_stringify result )
    ( json_free result )
    ( string_free err )
    ^ out
}
