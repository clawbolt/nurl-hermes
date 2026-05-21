// Small session-state inspection commands for Hermes NURL.

$ `stdlib/ext/env.nu`
$ `stdlib/ext/sqlite.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/core/string.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`

@ state_cli_db_path → String {
    : String from_env ( session_db_path_from_env )
    ? > ( string_len from_env ) 0 { ^ from_env } {}
    ( string_free from_env )
    ^ ( hermes_state_db_path )
}

@ state_cli_open → !Database SqliteErr {
    : String path ( state_cli_db_path )
    ? == ( string_len path ) 0 {
        ( string_free path )
        ^ @ !Database SqliteErr { F @ SqliteErr { SqliteOpen } }
    } {}
    ? ( file_exists ( string_data path ) ) {} {
        ( nurl_eprint `error: state db not found: ` )
        ( nurl_eprint ( string_data path ) )
        ( nurl_eprint `\n` )
        ( string_free path )
        ^ @ !Database SqliteErr { F @ SqliteErr { SqliteOpen } }
    }
    : !Database SqliteErr opened ( sqlite_open ( string_data path ) )
    ( string_free path )
    ^ opened
}

@ run_sessions → i {
    : !Database SqliteErr opened ( state_cli_open )
    ?? opened {
        T db → {
            : !Statement SqliteErr prep ( sqlite_prepare db `SELECT id, source, message_count, tool_call_count FROM sessions ORDER BY started_at DESC LIMIT 50` )
            ?? prep {
                T stmt → {
                    : ~ i rows 0
                    : ~ b going T
                    ~ going {
                        : !b SqliteErr step ( sqlite_step stmt )
                        ?? step {
                            T has_row → {
                                ? has_row {
                                    : String sid ( sqlite_column_text stmt 0 )
                                    : String source ( sqlite_column_text stmt 1 )
                                    : i messages ( sqlite_column_int stmt 2 )
                                    : i tools ( sqlite_column_int stmt 3 )
                                    ( nurl_print ( string_data sid ) )
                                    ( nurl_print `\t` )
                                    ( nurl_print ( string_data source ) )
                                    ( nurl_print `\tmessages=` )
                                    ( nurl_print ( nurl_str_int messages ) )
                                    ( nurl_print `\ttools=` )
                                    ( nurl_print ( nurl_str_int tools ) )
                                    ( nurl_print `\n` )
                                    ( string_free sid )
                                    ( string_free source )
                                    = rows + rows 1
                                } {
                                    = going F
                                }
                            }
                            F e → {
                                ( session_db_log_err `sessions-query` e )
                                = going F
                            }
                        }
                    }
                    ( sqlite_finalize stmt )
                    ( sqlite_close db )
                    ? == rows 0 {
                        ( nurl_print `no sessions\n` )
                    } {}
                    ^ 0
                }
                F e → {
                    ( session_db_log_err `prepare-sessions-query` e )
                    ( sqlite_close db )
                    ^ 1
                }
            }
        }
        F e → {
            ( session_db_log_err `open-state-cli` e )
            ^ 1
        }
    }
}

@ run_session_show s session_id → i {
    ? == ( nurl_str_len session_id ) 0 {
        ( nurl_eprint `usage: hermes-nurl session <session-id>\n` )
        ^ 2
    } {}

    : !Database SqliteErr opened ( state_cli_open )
    ?? opened {
        T db → {
            : !Statement SqliteErr prep ( sqlite_prepare db `SELECT role, COALESCE(content, ''), COALESCE(tool_call_id, ''), COALESCE(tool_name, '') FROM messages WHERE session_id = ?1 ORDER BY id` )
            ?? prep {
                T stmt → {
                    : !v SqliteErr b1 ( sqlite_bind_text stmt 1 session_id )
                    ?? b1 {
                        T _ → {}
                        F e → {
                            ( session_db_log_err `bind-session-query-id` e )
                            ( sqlite_finalize stmt )
                            ( sqlite_close db )
                            ^ 1
                        }
                    }
                    : ~ i rows 0
                    : ~ b going T
                    ~ going {
                        : !b SqliteErr step ( sqlite_step stmt )
                        ?? step {
                            T has_row → {
                                ? has_row {
                                    : String role ( sqlite_column_text stmt 0 )
                                    : String content ( sqlite_column_text stmt 1 )
                                    : String call_id ( sqlite_column_text stmt 2 )
                                    : String tool_name ( sqlite_column_text stmt 3 )
                                    ( nurl_print ( string_data role ) )
                                    ? > ( string_len tool_name ) 0 {
                                        ( nurl_print `[` )
                                        ( nurl_print ( string_data tool_name ) )
                                        ( nurl_print `]` )
                                    } {}
                                    ? > ( string_len call_id ) 0 {
                                        ( nurl_print `#` )
                                        ( nurl_print ( string_data call_id ) )
                                    } {}
                                    ( nurl_print `: ` )
                                    ( nurl_print ( string_data content ) )
                                    ( nurl_print `\n` )
                                    ( string_free role )
                                    ( string_free content )
                                    ( string_free call_id )
                                    ( string_free tool_name )
                                    = rows + rows 1
                                } {
                                    = going F
                                }
                            }
                            F e → {
                                ( session_db_log_err `session-query` e )
                                = going F
                            }
                        }
                    }
                    ( sqlite_finalize stmt )
                    ( sqlite_close db )
                    ? == rows 0 {
                        ( nurl_print `no messages\n` )
                    } {}
                    ^ 0
                }
                F e → {
                    ( session_db_log_err `prepare-session-query` e )
                    ( sqlite_close db )
                    ^ 1
                }
            }
        }
        F e → {
            ( session_db_log_err `open-state-cli` e )
            ^ 1
        }
    }
}

@ run_harness_events s run_id → i {
    ? == ( nurl_str_len run_id ) 0 {
        ( nurl_eprint `usage: hermes-nurl harness-events <run-id>\n` )
        ^ 2
    } {}

    : !Database SqliteErr opened ( state_cli_open )
    ?? opened {
        T db → {
            : !Statement SqliteErr prep ( sqlite_prepare db `SELECT event, COALESCE(detail, '') FROM nurl_session_events WHERE event LIKE 'harness_%' AND detail LIKE ?1 ORDER BY id` )
            ?? prep {
                T stmt → {
                    : String pattern ( string_from `%` )
                    ( string_push_str pattern run_id )
                    ( string_push_str pattern `%` )
                    : !v SqliteErr b1 ( sqlite_bind_text stmt 1 ( string_data pattern ) )
                    ( string_free pattern )
                    ?? b1 {
                        T _ → {}
                        F e → {
                            ( session_db_log_err `bind-harness-run-id` e )
                            ( sqlite_finalize stmt )
                            ( sqlite_close db )
                            ^ 1
                        }
                    }
                    : ~ i rows 0
                    : ~ b going T
                    ~ going {
                        : !b SqliteErr step ( sqlite_step stmt )
                        ?? step {
                            T has_row → {
                                ? has_row {
                                    : String event ( sqlite_column_text stmt 0 )
                                    : String detail ( sqlite_column_text stmt 1 )
                                    ( nurl_print ( string_data event ) )
                                    ( nurl_print `: ` )
                                    ( nurl_print ( string_data detail ) )
                                    ( nurl_print `\n` )
                                    ( string_free event )
                                    ( string_free detail )
                                    = rows + rows 1
                                } {
                                    = going F
                                }
                            }
                            F e → {
                                ( session_db_log_err `harness-events-query` e )
                                = going F
                            }
                        }
                    }
                    ( sqlite_finalize stmt )
                    ( sqlite_close db )
                    ? == rows 0 {
                        ( nurl_print `no harness events\n` )
                    } {}
                    ^ 0
                }
                F e → {
                    ( session_db_log_err `prepare-harness-events-query` e )
                    ( sqlite_close db )
                    ^ 1
                }
            }
        }
        F e → {
            ( session_db_log_err `open-state-cli` e )
            ^ 1
        }
    }
}
