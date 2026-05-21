// Read-only session replay helpers for Hermes NURL.

$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/sqlite.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`
$ `nurl/src/providers/openai_compat.nu`

@ session_resume_db_path → String {
    : String from_env ( session_db_path_from_env )
    ? > ( string_len from_env ) 0 { ^ from_env } {}
    ( string_free from_env )
    ^ ( hermes_state_db_path )
}

@ session_resume_db_exists → b {
    : String path ( session_resume_db_path )
    : b exists ( file_exists ( string_data path ) )
    ( string_free path )
    ^ exists
}

@ session_resume_open → !Database SqliteErr {
    : String path ( session_resume_db_path )
    ? == ( string_len path ) 0 {
        ( string_free path )
        ^ @ !Database SqliteErr { F @ SqliteErr { SqliteOpen } }
    } {}
    ? ( file_exists ( string_data path ) ) {} {
        ( string_free path )
        ^ @ !Database SqliteErr { F @ SqliteErr { SqliteOpen } }
    }
    : !Database SqliteErr opened ( sqlite_open ( string_data path ) )
    ( string_free path )
    ^ opened
}

@ session_resume_push_anthropic ( Vec Json ) msgs s role s content → v {
    ? > ( nurl_str_len content ) 0 {
        ? != ( nurl_str_eq role `user` ) 0 {
            ( vec_push [Json] msgs ( claude_msg_user_text content ) )
        } {}
        ? != ( nurl_str_eq role `assistant` ) 0 {
            ( vec_push [Json] msgs ( claude_msg_assistant_text content ) )
        } {}
    } {}
}

@ session_resume_tool_call_input Json tc → Json {
    : Json fallback ( json_obj_new )
    : ?Json fn ( json_obj_get tc `function` )
    ?? fn {
        T f → {
            : ?Json args_j ( json_obj_get f `arguments` )
            ?? args_j {
                T aj → {
                    : s args ( json_str_data aj )
                    ? > ( nurl_str_len args ) 0 {
                        : !Json ParseErr parsed ( json_parse args )
                        ?? parsed {
                            T input → {
                                ( json_free fallback )
                                ^ input
                            }
                            F _ → {}
                        }
                    } {}
                }
                F → {}
            }
        }
        F → {}
    }
    ^ fallback
}

@ session_resume_claude_tool_use_block Json tc → Json {
    : Json block ( json_obj_new )
    ( json_obj_set block `type` ( json_str_lit `tool_use` ) )
    ( json_obj_set block `id` ( json_str_lit ( openai_compat_tool_call_id tc ) ) )
    ( json_obj_set block `name` ( json_str_lit ( openai_compat_tool_call_name tc ) ) )
    ( json_obj_set block `input` ( session_resume_tool_call_input tc ) )
    ^ block
}

@ session_resume_push_anthropic_assistant_tool_calls ( Vec Json ) msgs s tool_calls → b {
    ? == ( nurl_str_len tool_calls ) 0 { ^ F } {}
    : !Json ParseErr parsed ( json_parse tool_calls )
    ?? parsed {
        T arr → {
            : ( Vec Json ) blocks ( vec_new [Json] )
            : i n ( json_arr_len arr )
            : ~ i k 0
            ~ < k n {
                : ?Json item ( json_arr_get arr k )
                ?? item {
                    T tc → {
                        ( vec_push [Json] blocks ( session_resume_claude_tool_use_block tc ) )
                    }
                    F → {}
                }
                = k + k 1
            }
            ( json_free arr )
            ? > ( vec_len [Json] blocks ) 0 {
                : Json content_arr ( json_arr_new )
                : i bn ( vec_len [Json] blocks )
                : ~ i bi 0
                ~ < bi bn {
                    : ?Json block ( vec_get [Json] blocks bi )
                    ?? block {
                        T b → ( json_arr_push content_arr b )
                        F → {}
                    }
                    = bi + bi 1
                }
                ( vec_free [Json] blocks )
                : Json msg ( json_obj_new )
                ( json_obj_set msg `role` ( json_str_lit `assistant` ) )
                ( json_obj_set msg `content` content_arr )
                ( vec_push [Json] msgs msg )
                ^ T
            } {}
            ( vec_free [Json] blocks )
            ^ F
        }
        F _ → { ^ F }
    }
}

@ session_resume_flush_anthropic_tool_results ( Vec Json ) msgs ( Vec Json ) pending → ( Vec Json ) {
    ? > ( vec_len [Json] pending ) 0 {
        ( vec_push [Json] msgs ( claude_msg_user_blocks pending ) )
        ^ ( vec_new [Json] )
    } {}
    ^ pending
}

@ session_resume_push_openai ( Vec Json ) msgs s role s content s call_id s tool_calls → v {
    ? > ( nurl_str_len content ) 0 {
        ? != ( nurl_str_eq role `user` ) 0 {
            ( vec_push [Json] msgs ( openai_compat_msg `user` content ) )
        } {}
    } {}
    ? != ( nurl_str_eq role `assistant` ) 0 {
        : ~ b pushed_tool_call F
        ? > ( nurl_str_len tool_calls ) 0 {
            : !Json ParseErr parsed ( json_parse tool_calls )
            ?? parsed {
                T arr → {
                    : Json msg ( openai_compat_msg `assistant` content )
                    ( json_obj_set msg `tool_calls` arr )
                    ( vec_push [Json] msgs msg )
                    = pushed_tool_call T
                }
                F _ → {}
            }
        } {}
        ? & ! pushed_tool_call > ( nurl_str_len content ) 0 {
            ( vec_push [Json] msgs ( openai_compat_msg `assistant` content ) )
        } {}
    } {}
    ? != ( nurl_str_eq role `tool` ) 0 {
        ? & > ( nurl_str_len content ) 0 > ( nurl_str_len call_id ) 0 {
            ( vec_push [Json] msgs ( openai_compat_msg_tool_result call_id content ) )
        } {}
    } {}
}

@ session_resume_load_rows s session_id ( Vec Json ) msgs b openai_format → i {
    ? == ( nurl_str_len session_id ) 0 { ^ 0 } {}
    : !Database SqliteErr opened ( session_resume_open )
    ?? opened {
        T db → {
            : !Statement SqliteErr prep ( sqlite_prepare db `SELECT role, COALESCE(content, ''), COALESCE(tool_call_id, ''), COALESCE(tool_calls, ''), COALESCE(tool_name, '') FROM messages WHERE session_id = ?1 AND role IN ('user','assistant','tool') AND (COALESCE(content, '') != '' OR COALESCE(tool_call_id, '') != '' OR COALESCE(tool_calls, '') != '') ORDER BY id` )
            ?? prep {
                T stmt → {
                    : !v SqliteErr bound ( sqlite_bind_text stmt 1 session_id )
                    ?? bound {
                        T _ → {}
                        F e → {
                            ( session_db_log_err `resume-bind-session` e )
                            ( sqlite_finalize stmt )
                            ( sqlite_close db )
                            ^ 0
                        }
                    }
                    : ~ i rows 0
                    : ~ b going T
                    : ~ ( Vec Json ) pending_tool_results ( vec_new [Json] )
                    ~ going {
                        : !b SqliteErr step ( sqlite_step stmt )
                        ?? step {
                            T has_row → {
                                ? has_row {
                                    : String role ( sqlite_column_text stmt 0 )
                                    : String content ( sqlite_column_text stmt 1 )
                                    : String call_id ( sqlite_column_text stmt 2 )
                                    : String tool_calls ( sqlite_column_text stmt 3 )
                                    : String tool_name ( sqlite_column_text stmt 4 )
                                    ? openai_format {
                                        ( session_resume_push_openai msgs ( string_data role ) ( string_data content ) ( string_data call_id ) ( string_data tool_calls ) )
                                    } {
                                        ? != ( nurl_str_eq ( string_data role ) `tool` ) 0 {
                                            ( vec_push [Json] pending_tool_results ( claude_tool_result_block ( string_data call_id ) ( string_data content ) F ) )
                                        } {
                                            = pending_tool_results ( session_resume_flush_anthropic_tool_results msgs pending_tool_results )
                                            ? != ( nurl_str_eq ( string_data role ) `assistant` ) 0 {
                                                ? ( session_resume_push_anthropic_assistant_tool_calls msgs ( string_data tool_calls ) ) {} {
                                                    ( session_resume_push_anthropic msgs ( string_data role ) ( string_data content ) )
                                                }
                                            } {
                                                ( session_resume_push_anthropic msgs ( string_data role ) ( string_data content ) )
                                            }
                                        }
                                    }
                                    ( string_free role )
                                    ( string_free content )
                                    ( string_free call_id )
                                    ( string_free tool_calls )
                                    ( string_free tool_name )
                                    = rows + rows 1
                                } {
                                    = going F
                                }
                            }
                            F e → {
                                ( session_db_log_err `resume-query` e )
                                = going F
                            }
                        }
                    }
                    ? openai_format {} {
                        = pending_tool_results ( session_resume_flush_anthropic_tool_results msgs pending_tool_results )
                    }
                    ? == ( vec_len [Json] pending_tool_results ) 0 {
                        ( vec_free [Json] pending_tool_results )
                    } {}
                    ( sqlite_finalize stmt )
                    ( sqlite_close db )
                    ^ rows
                }
                F e → {
                    ( session_db_log_err `resume-prepare` e )
                    ( sqlite_close db )
                    ^ 0
                }
            }
        }
        F _ → { ^ 0 }
    }
}

@ session_resume_system_prompt s session_id → String {
    ? == ( nurl_str_len session_id ) 0 { ^ ( string_from `` ) } {}
    : !Database SqliteErr opened ( session_resume_open )
    ?? opened {
        T db → {
            : !Statement SqliteErr prep ( sqlite_prepare db `SELECT COALESCE(system_prompt, '') FROM sessions WHERE id = ?1 LIMIT 1` )
            ?? prep {
                T stmt → {
                    : !v SqliteErr bound ( sqlite_bind_text stmt 1 session_id )
                    ?? bound {
                        T _ → {}
                        F e → {
                            ( session_db_log_err `resume-bind-system-prompt` e )
                            ( sqlite_finalize stmt )
                            ( sqlite_close db )
                            ^ ( string_from `` )
                        }
                    }
                    : !b SqliteErr step ( sqlite_step stmt )
                    ?? step {
                        T has_row → {
                            ? has_row {
                                : String prompt ( sqlite_column_text stmt 0 )
                                ( sqlite_finalize stmt )
                                ( sqlite_close db )
                                ^ prompt
                            } {}
                        }
                        F e → { ( session_db_log_err `resume-system-prompt-query` e ) }
                    }
                    ( sqlite_finalize stmt )
                    ( sqlite_close db )
                }
                F e → {
                    ( session_db_log_err `resume-system-prompt-prepare` e )
                    ( sqlite_close db )
                }
            }
        }
        F _ → {}
    }
    ^ ( string_from `` )
}

@ session_resume_system_prompt_or s session_id String fallback → String {
    : String stored ( session_resume_system_prompt session_id )
    ? > ( string_len stored ) 0 {
        ( string_free fallback )
        ^ stored
    } {}
    ( string_free stored )
    ^ fallback
}

@ session_resume_anthropic_messages s session_id → ( Vec Json ) {
    : ( Vec Json ) msgs ( vec_new [Json] )
    : i rows ( session_resume_load_rows session_id msgs F )
    ( trace_event_int `session_resume_rows` rows )
    ^ msgs
}

@ session_resume_openai_messages s session_id s system_prompt → ( Vec Json ) {
    : ( Vec Json ) msgs ( vec_new [Json] )
    ? > ( nurl_str_len system_prompt ) 0 {
        ( vec_push [Json] msgs ( openai_compat_msg `system` system_prompt ) )
    } {}
    : i rows ( session_resume_load_rows session_id msgs T )
    ( trace_event_int `session_resume_rows` rows )
    ^ msgs
}

@ session_resume_preview_json s session_id s provider s system_prompt → String {
    : ( Vec Json ) msgs ? ( hermes_provider_is_openai_compat provider ) {
        ( session_resume_openai_messages session_id system_prompt )
    } {
        ( session_resume_anthropic_messages session_id )
    }
    : Json arr ( json_arr msgs )
    : String out ( json_stringify arr )
    ( json_free arr )
    ^ out
}
