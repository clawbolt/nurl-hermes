// Shared helpers for Hermes NURL binaries.

$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/sqlite.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/time.nu`
$ `stdlib/core/string.nu`
$ `nurl/src/config.nu`

@ VERSION → s { ^ `0.1.0` }

@ MAX_TOOL_BYTES → i { ^ 80000 }

@ hermes_dotenv_path → String {
    ^ ( hermes_path `.env` )
}

@ hermes_dotenv_key_first_char_ok i c → b {
    ? & >= c 65 <= c 90 { ^ T } {}
    ? & >= c 97 <= c 122 { ^ T } {}
    ? == c 95 { ^ T } {}
    ^ F
}

@ hermes_dotenv_key_char_ok i c → b {
    ? ( hermes_dotenv_key_first_char_ok c ) { ^ T } {}
    ? & >= c 48 <= c 57 { ^ T } {}
    ^ F
}

@ hermes_dotenv_key_valid String key → b {
    : i n ( string_len key )
    ? <= n 0 { ^ F } {}
    ? ! ( hermes_dotenv_key_first_char_ok ( string_get key 0 ) ) { ^ F } {}
    : ~ i i 1
    ~ < i n {
        ? ! ( hermes_dotenv_key_char_ok ( string_get key i ) ) { ^ F } {}
        = i + i 1
    }
    ^ T
}

@ hermes_dotenv_unquote String raw → String {
    : i n ( string_len raw )
    ? >= n 2 {
        : i first ( string_get raw 0 )
        : i last ( string_get raw - n 1 )
        ? & == first 34 == last 34 {
            : String out ( string_substr raw 1 - n 2 )
            ( string_free raw )
            ^ out
        } {}
        ? & == first 39 == last 39 {
            : String out ( string_substr raw 1 - n 2 )
            ( string_free raw )
            ^ out
        } {}
    } {}
    ^ raw
}

@ hermes_dotenv_load_line String line → i {
    : String trimmed ( string_trim line )
    ? == ( string_len trimmed ) 0 {
        ( string_free trimmed )
        ^ 0
    } {}
    ? ( string_starts_with trimmed `#` ) {
        ( string_free trimmed )
        ^ 0
    } {}

    : String work ? ( string_starts_with trimmed `export ` ) {
        ( string_substr trimmed 7 - ( string_len trimmed ) 7 )
    } {
        ( string_from ( string_data trimmed ) )
    }
    ( string_free trimmed )

    : ?i eq_pos ( string_index_of work `=` )
    ?? eq_pos {
        T idx → {
            : String raw_key ( string_substr work 0 idx )
            : String key ( string_trim raw_key )
            ( string_free raw_key )
            ? ! ( hermes_dotenv_key_valid key ) {
                ( string_free key )
                ( string_free work )
                ^ 0
            } {}

            : ?String existing ( env_get ( string_data key ) )
            ?? existing {
                T old → {
                    ( string_free old )
                    ( string_free key )
                    ( string_free work )
                    ^ 0
                }
                F → {}
            }

            : i start + idx 1
            : String raw_val ( string_substr work start - ( string_len work ) start )
            : String trimmed_val ( string_trim raw_val )
            ( string_free raw_val )
            : String val ( hermes_dotenv_unquote trimmed_val )
            : !v IoErr set_result ( env_set ( string_data key ) ( string_data val ) )
            : i loaded ?? set_result {
                T _ → 1
                F _ → 0
            }
            ( string_free val )
            ( string_free key )
            ( string_free work )
            ^ loaded
        }
        F → {
            ( string_free work )
            ^ 0
        }
    }
}

@ hermes_load_dotenv → i {
    : String path ( hermes_dotenv_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            : ~ i loaded 0
            : i n ( vec_len [String] lines )
            : ~ i i 0
            ~ < i n {
                : ?String e ( vec_get [String] lines i )
                ?? e {
                    T line → {
                        = loaded + loaded ( hermes_dotenv_load_line line )
                    }
                    F → {}
                }
                = i + i 1
            }
            ( vec_free_with [String] lines drop_str )
            ^ loaded
        }
        F _ → {}
    }
    ^ 0
}

@ env_truthy s name → b {
    : ?String got ( env_get name )
    : ~ b out F
    ?? got {
        T v → {
            : s raw ( string_data v )
            ? != ( nurl_str_eq raw `1` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `true` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `yes` ) 0 { = out T } {}
            ? != ( nurl_str_eq raw `on` ) 0 { = out T } {}
            ( string_free v )
        }
        F → {}
    }
    ^ out
}

@ env_falsy s name → b {
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

@ hermes_nurl_production_mode → b {
    ^ ( env_truthy `HERMES_NURL_PRODUCTION_MODE` )
}

@ hermes_nurl_shell_allowed → b {
    ? ! ( hermes_nurl_production_mode ) { ^ T } {}
    ^ ( env_truthy `HERMES_NURL_ALLOW_SHELL` )
}

@ hermes_nurl_mutations_allowed → b {
    ? ! ( hermes_nurl_production_mode ) { ^ T } {}
    ^ ( env_truthy `HERMES_NURL_ALLOW_MUTATIONS` )
}

@ hermes_nurl_network_policy_configured → b {
    : String hosts ( hermes_nurl_network_allow_hosts_from_env )
    : String bases ( hermes_nurl_network_allow_base_urls_from_env )
    : b ok ? | > ( string_len hosts ) 0 > ( string_len bases ) 0 T F
    ( string_free hosts )
    ( string_free bases )
    ^ ok
}

@ hermes_nurl_network_redirect_safe_runtime → b {
    // NURL stdlib HTTP currently follows redirects implicitly. Keep the
    // generic tool out of production until final-target policy checks exist.
    ^ F
}

@ hermes_nurl_network_allowed → b {
    ? ( env_truthy `HERMES_NURL_DISABLE_NETWORK` ) { ^ F } {}
    ? ! ( hermes_nurl_production_mode ) {
        ? ( env_falsy `HERMES_NURL_ALLOW_NETWORK` ) { ^ F } {}
        ^ T
    } {}
    ? ! ( env_truthy `HERMES_NURL_ALLOW_NETWORK` ) { ^ F } {}
    ? ! ( hermes_nurl_network_policy_configured ) { ^ F } {}
    ^ ( hermes_nurl_network_redirect_safe_runtime )
}

@ hermes_nurl_network_private_allowed → b {
    ^ ( hermes_nurl_network_allow_private_from_env )
}

@ hermes_nurl_edit_check_command → String {
    : ?String got ( env_get `HERMES_NURL_EDIT_CHECK_COMMAND` )
    ?? got {
        T raw → {
            : String trimmed ( string_trim raw )
            ( string_free raw )
            ^ trimmed
        }
        F → {}
    }
    ^ ( string_new )
}

@ append_jsonl_env s env_name s event s detail → v {
    : ?String path_o ( env_get env_name )
    ?? path_o {
        T path → {
            ? > ( string_len path ) 0 {
                : Json evt ( json_obj_new )
                ( json_obj_set evt `event` ( json_str_lit event ) )
                ( json_obj_set evt `detail` ( json_str_lit detail ) )
                : String line ( json_stringify evt )
                ( string_push_str line `\n` )
                : !v IoErr wr ( append_file ( string_data path ) ( string_data line ) )
                ?? wr {
                    T _ → {}
                    F _ → {
                        ( nurl_eprint `[hermes-nurl] jsonl write failed: ` )
                        ( nurl_eprint ( string_data path ) )
                        ( nurl_eprint `\n` )
                    }
                }
                ( string_free line )
                ( json_free evt )
            } {}
            ( string_free path )
        }
        F → {}
    }
}

@ append_jsonl_env_json s env_name Json evt → v {
    : ?String path_o ( env_get env_name )
    ?? path_o {
        T path → {
            ? > ( string_len path ) 0 {
                : String line ( json_stringify evt )
                ( string_push_str line `\n` )
                : !v IoErr wr ( append_file ( string_data path ) ( string_data line ) )
                ?? wr {
                    T _ → {}
                    F _ → {
                        ( nurl_eprint `[hermes-nurl] jsonl write failed: ` )
                        ( nurl_eprint ( string_data path ) )
                        ( nurl_eprint `\n` )
                    }
                }
                ( string_free line )
            } {}
            ( string_free path )
        }
        F → {}
    }
    ( json_free evt )
}

@ trace_event s event s detail → v {
    ( append_jsonl_env `HERMES_NURL_TRACE` event detail )
}

@ trace_event_int s event i value → v {
    : String detail ( string_with_cap 24 )
    ( string_push_int detail value )
    ( trace_event event ( string_data detail ) )
    ( string_free detail )
}

@ session_event s event s detail → v {
    ( append_jsonl_env `HERMES_NURL_SESSION_LOG` event detail )
    ( session_db_event event detail )
    ? != ( nurl_str_eq event `user` ) 0 {
        ( session_db_append_message `user` detail `` `` `` )
    } {}
    ? != ( nurl_str_eq event `assistant` ) 0 {
        ( session_db_append_message `assistant` detail `` `` `` )
    } {}
}

@ session_tool_call s call_id s tool_name → v {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `event` ( json_str_lit `tool_call` ) )
    ( json_obj_set evt `tool_call_id` ( json_str_lit call_id ) )
    ( json_obj_set evt `tool_name` ( json_str_lit tool_name ) )
    ( append_jsonl_env_json `HERMES_NURL_SESSION_LOG` evt )
    ( session_db_tool_call call_id tool_name )
}

@ session_tool_call_json s call_id s tool_name s tool_calls_json → v {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `event` ( json_str_lit `tool_call` ) )
    ( json_obj_set evt `tool_call_id` ( json_str_lit call_id ) )
    ( json_obj_set evt `tool_name` ( json_str_lit tool_name ) )
    ( append_jsonl_env_json `HERMES_NURL_SESSION_LOG` evt )
    ( session_db_tool_call_json call_id tool_name tool_calls_json )
}

@ session_tool_call_args_json s call_id s tool_name Json args → v {
    : String arguments ( json_stringify args )
    : String tool_calls ( session_db_tool_calls_json_with_arguments call_id tool_name ( string_data arguments ) )
    ( session_tool_call_json call_id tool_name ( string_data tool_calls ) )
    ( string_free tool_calls )
    ( string_free arguments )
}

@ session_tool_call_openai_json s call_id s tool_name Json tool_call → v {
    : Json arr ( json_arr_new )
    ( json_arr_push arr ( json_clone tool_call ) )
    : String tool_calls ( json_stringify arr )
    ( json_free arr )
    ( session_tool_call_json call_id tool_name ( string_data tool_calls ) )
    ( string_free tool_calls )
}

@ session_tool_result s call_id s tool_name b is_error i bytes → v {
    : String content ( string_from `tool result bytes=` )
    ( string_push_int content bytes )
    ( session_tool_result_text call_id tool_name is_error bytes ( string_data content ) )
    ( string_free content )
}

@ session_tool_result_text s call_id s tool_name b is_error i bytes s content → v {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `event` ( json_str_lit `tool_result` ) )
    ( json_obj_set evt `tool_call_id` ( json_str_lit call_id ) )
    ( json_obj_set evt `tool_name` ( json_str_lit tool_name ) )
    ( json_obj_set evt `is_error` ( json_bool is_error ) )
    ( json_obj_set evt `bytes` ( json_int bytes ) )
    ( append_jsonl_env_json `HERMES_NURL_SESSION_LOG` evt )
    ( session_db_tool_result call_id tool_name is_error bytes content )
}

@ session_db_path_from_env → String {
    : ?String got ( env_get `HERMES_NURL_STATE_DB` )
    ?? got {
        T raw → {
            : String value ( string_trim raw )
            ( string_free raw )
            ? == ( string_len value ) 0 { ^ value } {}
            : s p ( string_data value )
            ? | | != ( nurl_str_eq p `0` ) 0 != ( nurl_str_eq p `false` ) 0 != ( nurl_str_eq p `off` ) 0 {
                ( string_free value )
                ^ ( string_from `` )
            } {}
            ? | | | != ( nurl_str_eq p `1` ) 0 != ( nurl_str_eq p `true` ) 0 != ( nurl_str_eq p `yes` ) 0 != ( nurl_str_eq p `on` ) 0 {
                ( string_free value )
                ^ ( hermes_state_db_path )
            } {}
            ^ value
        }
        F → {}
    }
    ^ ( string_from `` )
}

@ session_db_session_id → String {
    : ?String got ( env_get `HERMES_NURL_SESSION_ID` )
    ?? got {
        T raw → {
            : String value ( string_trim raw )
            ( string_free raw )
            ? > ( string_len value ) 0 { ^ value } {}
            ( string_free value )
        }
        F → {}
    }
    : String generated ( string_from `nurl-` )
    ( string_push_int generated ( now_ms ) )
    ( string_push_str generated `-` )
    ( string_push_int generated ( monotonic_ns ) )
    : !v IoErr set_id ( env_set `HERMES_NURL_SESSION_ID` ( string_data generated ) )
    ?? set_id {
        T _ → {}
        F _ → {
            ( nurl_eprint `[hermes-nurl] warning: could not persist generated session id in env\n` )
        }
    }
    ^ generated
}

@ session_db_log_err s context SqliteErr err → v {
    ( nurl_eprint `[hermes-nurl] sqlite ` )
    ( nurl_eprint context )
    ( nurl_eprint ` failed: ` )
    ( nurl_eprint ( sqlite_err_name err ) )
    ( nurl_eprint `\n` )
}

@ session_db_init Database db → b {
    : !i SqliteErr events ( sqlite_exec db `CREATE TABLE IF NOT EXISTS nurl_session_events (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL, event TEXT NOT NULL, detail TEXT, tool_call_id TEXT, tool_name TEXT, is_error INTEGER DEFAULT 0, bytes INTEGER DEFAULT 0, created_at TEXT DEFAULT CURRENT_TIMESTAMP)` )
    ?? events {
        T _ → {}
        F e → {
            ( session_db_log_err `schema` e )
            ^ F
        }
    }
    : !i SqliteErr idx_events ( sqlite_exec db `CREATE INDEX IF NOT EXISTS idx_nurl_session_events_session ON nurl_session_events(session_id, id)` )
    ?? idx_events {
        T _ → {}
        F e → {
            ( session_db_log_err `index` e )
            ^ F
        }
    }
    : !i SqliteErr sessions ( sqlite_exec db `CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, source TEXT NOT NULL, user_id TEXT, model TEXT, model_config TEXT, system_prompt TEXT, parent_session_id TEXT, started_at REAL NOT NULL, ended_at REAL, end_reason TEXT, message_count INTEGER DEFAULT 0, tool_call_count INTEGER DEFAULT 0, input_tokens INTEGER DEFAULT 0, output_tokens INTEGER DEFAULT 0, cache_read_tokens INTEGER DEFAULT 0, cache_write_tokens INTEGER DEFAULT 0, reasoning_tokens INTEGER DEFAULT 0, billing_provider TEXT, billing_base_url TEXT, billing_mode TEXT, estimated_cost_usd REAL, actual_cost_usd REAL, cost_status TEXT, cost_source TEXT, pricing_version TEXT, title TEXT, api_call_count INTEGER DEFAULT 0, handoff_state TEXT, handoff_platform TEXT, handoff_error TEXT)` )
    ?? sessions {
        T _ → {}
        F e → {
            ( session_db_log_err `sessions-schema` e )
            ^ F
        }
    }
    : !i SqliteErr messages ( sqlite_exec db `CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL REFERENCES sessions(id), role TEXT NOT NULL, content TEXT, tool_call_id TEXT, tool_calls TEXT, tool_name TEXT, timestamp REAL NOT NULL, token_count INTEGER, finish_reason TEXT, reasoning TEXT, reasoning_content TEXT, reasoning_details TEXT, codex_reasoning_items TEXT, codex_message_items TEXT)` )
    ?? messages {
        T _ → {}
        F e → {
            ( session_db_log_err `messages-schema` e )
            ^ F
        }
    }
    : !i SqliteErr idx_sessions ( sqlite_exec db `CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at DESC)` )
    ?? idx_sessions {
        T _ → {}
        F e → {
            ( session_db_log_err `sessions-index` e )
            ^ F
        }
    }
    : !i SqliteErr idx_messages ( sqlite_exec db `CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, timestamp)` )
    ?? idx_messages {
        T _ → { ^ T }
        F e → {
            ( session_db_log_err `messages-index` e )
            ^ F
        }
    }
    ^ T
}

@ session_db_ensure_session Database db s session_id → b {
    : !Statement SqliteErr prep ( sqlite_prepare db `INSERT OR IGNORE INTO sessions (id, source, started_at) VALUES (?1, 'nurl', CAST(strftime('%s','now') AS REAL))` )
    ?? prep {
        T stmt → {
            : !v SqliteErr b1 ( sqlite_bind_text stmt 1 session_id )
            ?? b1 {
                T _ → {}
                F e → {
                    ( session_db_log_err `bind-session-row-id` e )
                    ( sqlite_finalize stmt )
                    ^ F
                }
            }
            : !b SqliteErr stepped ( sqlite_step stmt )
            ?? stepped {
                T _ → {
                    ( sqlite_finalize stmt )
                    ^ T
                }
                F e → {
                    ( session_db_log_err `insert-session-row` e )
                    ( sqlite_finalize stmt )
                    ^ F
                }
            }
        }
        F e → {
            ( session_db_log_err `prepare-session-row` e )
            ^ F
        }
    }
    ^ F
}

@ session_db_message_tool_increment s role s tool_calls → i {
    ? != ( nurl_str_eq role `tool` ) 0 { ^ 1 } {}
    ? > ( nurl_str_len tool_calls ) 0 { ^ 1 } {}
    ^ 0
}

@ session_db_update_message_counts Database db s session_id i tool_inc → v {
    : !Statement SqliteErr prep ( sqlite_prepare db `UPDATE sessions SET message_count = message_count + 1, tool_call_count = tool_call_count + ?1 WHERE id = ?2` )
    ?? prep {
        T stmt → {
            : !v SqliteErr b1 ( sqlite_bind_int stmt 1 tool_inc )
            : !v SqliteErr b2 ( sqlite_bind_text stmt 2 session_id )
            ?? b1 { T _ → {} F e → { ( session_db_log_err `bind-message-count-tool` e ) } }
            ?? b2 { T _ → {} F e → { ( session_db_log_err `bind-message-count-session` e ) } }
            : !b SqliteErr stepped ( sqlite_step stmt )
            ?? stepped { T _ → {} F e → { ( session_db_log_err `update-message-counts` e ) } }
            ( sqlite_finalize stmt )
        }
        F e → { ( session_db_log_err `prepare-message-counts` e ) }
    }
}

@ session_db_update_system_prompt Database db s session_id s prompt → v {
    ? ( session_db_ensure_session db session_id ) {
        : !Statement SqliteErr prep ( sqlite_prepare db `UPDATE sessions SET system_prompt = ?1 WHERE id = ?2` )
        ?? prep {
            T stmt → {
                : !v SqliteErr b1 ( sqlite_bind_text stmt 1 prompt )
                : !v SqliteErr b2 ( sqlite_bind_text stmt 2 session_id )
                ?? b1 { T _ → {} F e → { ( session_db_log_err `bind-system-prompt` e ) } }
                ?? b2 { T _ → {} F e → { ( session_db_log_err `bind-system-prompt-session` e ) } }
                : !b SqliteErr stepped ( sqlite_step stmt )
                ?? stepped { T _ → {} F e → { ( session_db_log_err `update-system-prompt` e ) } }
                ( sqlite_finalize stmt )
            }
            F e → { ( session_db_log_err `prepare-system-prompt` e ) }
        }
    } {}
}

@ session_db_set_current_system_prompt s prompt → v {
    : String path ( session_db_path_from_env )
    ? == ( string_len path ) 0 {
        ( string_free path )
    } {
        : !Database SqliteErr opened ( sqlite_open ( string_data path ) )
        ?? opened {
            T db → {
                ? ( session_db_init db ) {
                    : String sid ( session_db_session_id )
                    ( session_db_update_system_prompt db ( string_data sid ) prompt )
                    ( string_free sid )
                } {}
                ( sqlite_close db )
            }
            F e → { ( session_db_log_err `open-system-prompt` e ) }
        }
        ( string_free path )
    }
}

@ session_db_insert_message Database db s session_id s role s content s call_id s tool_calls s tool_name → v {
    ? ( session_db_ensure_session db session_id ) {
        : !Statement SqliteErr prep ( sqlite_prepare db `INSERT INTO messages (session_id, role, content, tool_call_id, tool_calls, tool_name, timestamp) VALUES (?1, ?2, ?3, ?4, ?5, ?6, CAST(strftime('%s','now') AS REAL))` )
        ?? prep {
            T stmt → {
                : !v SqliteErr b1 ( sqlite_bind_text stmt 1 session_id )
                : !v SqliteErr b2 ( sqlite_bind_text stmt 2 role )
                : !v SqliteErr b3 ( sqlite_bind_text stmt 3 content )
                : !v SqliteErr b4 ( sqlite_bind_text stmt 4 call_id )
                : !v SqliteErr b5 ( sqlite_bind_text stmt 5 tool_calls )
                : !v SqliteErr b6 ( sqlite_bind_text stmt 6 tool_name )
                ?? b1 { T _ → {} F e → { ( session_db_log_err `bind-message-session` e ) } }
                ?? b2 { T _ → {} F e → { ( session_db_log_err `bind-message-role` e ) } }
                ?? b3 { T _ → {} F e → { ( session_db_log_err `bind-message-content` e ) } }
                ?? b4 { T _ → {} F e → { ( session_db_log_err `bind-message-call-id` e ) } }
                ?? b5 { T _ → {} F e → { ( session_db_log_err `bind-message-tool-calls` e ) } }
                ?? b6 { T _ → {} F e → { ( session_db_log_err `bind-message-tool-name` e ) } }
                : !b SqliteErr stepped ( sqlite_step stmt )
                ?? stepped {
                    T _ → {
                        : i tool_inc ( session_db_message_tool_increment role tool_calls )
                        ( session_db_update_message_counts db session_id tool_inc )
                    }
                    F e → { ( session_db_log_err `insert-message` e ) }
                }
                ( sqlite_finalize stmt )
            }
            F e → { ( session_db_log_err `prepare-message` e ) }
        }
    } {}
}

@ session_db_append_message s role s content s call_id s tool_calls s tool_name → v {
    : String path ( session_db_path_from_env )
    ? == ( string_len path ) 0 {
        ( string_free path )
    } {
        : !Database SqliteErr opened ( sqlite_open ( string_data path ) )
        ?? opened {
            T db → {
                ? ( session_db_init db ) {
                    : String sid ( session_db_session_id )
                    ( session_db_insert_message db ( string_data sid ) role content call_id tool_calls tool_name )
                    ( string_free sid )
                } {}
                ( sqlite_close db )
            }
            F e → { ( session_db_log_err `open-message` e ) }
        }
        ( string_free path )
    }
}

@ session_db_tool_calls_json_with_arguments s call_id s tool_name s arguments → String {
    : Json fn ( json_obj_new )
    ( json_obj_set fn `name` ( json_str_lit tool_name ) )
    ( json_obj_set fn `arguments` ( json_str_lit arguments ) )
    : Json tc ( json_obj_new )
    ( json_obj_set tc `id` ( json_str_lit call_id ) )
    ( json_obj_set tc `type` ( json_str_lit `function` ) )
    ( json_obj_set tc `function` fn )
    : Json arr ( json_arr_new )
    ( json_arr_push arr tc )
    : String out ( json_stringify arr )
    ( json_free arr )
    ^ out
}

@ session_db_tool_calls_json s call_id s tool_name → String {
    ^ ( session_db_tool_calls_json_with_arguments call_id tool_name `{}` )
}

@ session_db_write s event s detail s call_id s tool_name b is_error i bytes → v {
    : String path ( session_db_path_from_env )
    ? == ( string_len path ) 0 {
        ( string_free path )
    } {
        : !Database SqliteErr opened ( sqlite_open ( string_data path ) )
        ?? opened {
            T db → {
                ? ( session_db_init db ) {
                    : !Statement SqliteErr prep ( sqlite_prepare db `INSERT INTO nurl_session_events (session_id, event, detail, tool_call_id, tool_name, is_error, bytes) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)` )
                    ?? prep {
                        T stmt → {
                            : String sid ( session_db_session_id )
                            : i err_int ? is_error 1 0
                            : !v SqliteErr b1 ( sqlite_bind_text stmt 1 ( string_data sid ) )
                            : !v SqliteErr b2 ( sqlite_bind_text stmt 2 event )
                            : !v SqliteErr b3 ( sqlite_bind_text stmt 3 detail )
                            : !v SqliteErr b4 ( sqlite_bind_text stmt 4 call_id )
                            : !v SqliteErr b5 ( sqlite_bind_text stmt 5 tool_name )
                            : !v SqliteErr b6 ( sqlite_bind_int stmt 6 err_int )
                            : !v SqliteErr b7 ( sqlite_bind_int stmt 7 bytes )
                            ?? b1 { T _ → {} F e → { ( session_db_log_err `bind-session-id` e ) } }
                            ?? b2 { T _ → {} F e → { ( session_db_log_err `bind-event` e ) } }
                            ?? b3 { T _ → {} F e → { ( session_db_log_err `bind-detail` e ) } }
                            ?? b4 { T _ → {} F e → { ( session_db_log_err `bind-tool-call-id` e ) } }
                            ?? b5 { T _ → {} F e → { ( session_db_log_err `bind-tool-name` e ) } }
                            ?? b6 { T _ → {} F e → { ( session_db_log_err `bind-is-error` e ) } }
                            ?? b7 { T _ → {} F e → { ( session_db_log_err `bind-bytes` e ) } }
                            : !b SqliteErr stepped ( sqlite_step stmt )
                            ?? stepped {
                                T _ → {}
                                F e → { ( session_db_log_err `insert` e ) }
                            }
                            ( string_free sid )
                            ( sqlite_finalize stmt )
                        }
                        F e → { ( session_db_log_err `prepare` e ) }
                    }
                } {}
                ( sqlite_close db )
            }
            F e → { ( session_db_log_err `open` e ) }
        }
        ( string_free path )
    }
}

@ session_db_event s event s detail → v {
    ( session_db_write event detail `` `` F ( nurl_str_len detail ) )
}

@ session_db_tool_call_json s call_id s tool_name s tool_calls_json → v {
    ( session_db_write `tool_call` `` call_id tool_name F 0 )
    ( session_db_append_message `assistant` `` call_id tool_calls_json tool_name )
}

@ session_db_tool_call s call_id s tool_name → v {
    : String tool_calls ( session_db_tool_calls_json call_id tool_name )
    ( session_db_tool_call_json call_id tool_name ( string_data tool_calls ) )
    ( string_free tool_calls )
}

@ session_db_tool_result s call_id s tool_name b is_error i bytes s content → v {
    ( session_db_write `tool_result` `` call_id tool_name is_error bytes )
    ( session_db_append_message `tool` content call_id `` tool_name )
}

@ shell_command_blocked s cmd → b {
    : String c ( string_from cmd )
    : String lower ( string_to_lower c )
    : ~ b blocked F
    ? ( string_contains c `rm -rf` ) { = blocked T } {}
    ? ( string_contains c `rm -fr` ) { = blocked T } {}
    ? ( string_contains c `mkfs` ) { = blocked T } {}
    ? ( string_contains c `diskutil erase` ) { = blocked T } {}
    ? ( string_contains c `shutdown` ) { = blocked T } {}
    ? ( string_contains c `reboot` ) { = blocked T } {}
    ? ( string_contains c `git reset --hard` ) { = blocked T } {}
    ? ( string_contains c `dd if=` ) { = blocked T } {}
    ? & ( string_contains lower `authorization` ) ( string_contains lower `bearer` ) { = blocked T } {}
    ? ( string_contains lower `gpt_image2_api_key` ) { = blocked T } {}
    ? ( string_contains lower `api_relay_token` ) { = blocked T } {}
    ? ( string_contains lower `sk-relay-` ) { = blocked T } {}
    ? & ( string_contains lower `curl` ) ( string_contains lower ` api_key` ) { = blocked T } {}
    ( string_free lower )
    ( string_free c )
    ^ blocked
}

@ shell_prompt_file_write_blocked s cmd → b {
    : String c ( string_from cmd )
    : String lower ( string_to_lower c )
    : ~ b blocked F
    ? & & ( string_contains lower `prompt_` ) ( string_contains lower `.txt` ) ( string_contains lower `>` ) {
        ? ( string_contains lower `printf` ) { = blocked T } {}
        ? ( string_contains lower `echo` ) { = blocked T } {}
        ? ( string_contains lower `cat >` ) { = blocked T } {}
        ? ( string_contains lower `cat >>` ) { = blocked T } {}
        ? ( string_contains lower `<<` ) { = blocked T } {}
        ? ( string_contains lower `tee ` ) { = blocked T } {}
    } {}
    ( string_free lower )
    ( string_free c )
    ^ blocked
}

@ one_string_schema s field_name s field_desc → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json prop ( json_obj_new )
    ( json_obj_set prop `type` ( json_str_lit `string` ) )
    ( json_obj_set prop `description` ( json_str_lit field_desc ) )

    : Json props ( json_obj_new )
    ( json_obj_set props field_name prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit field_name ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ input_str Json input s field → s {
    : ?Json v ( json_obj_get input field )
    ?? v {
        T j → { ^ ( json_str_data j ) }
        F → { ^ `` }
    }
    ^ ``
}

@ truncate_for_model String src → String {
    : i n ( string_len src )
    : i lim ( MAX_TOOL_BYTES )
    ? <= n lim {
        ^ src
    } {}
    : String head ( string_substr src 0 lim )
    ( string_push_str head `\n...[truncated, ` )
    ( string_push_int head - n lim )
    ( string_push_str head ` more bytes]` )
    ( string_free src )
    ^ head
}
