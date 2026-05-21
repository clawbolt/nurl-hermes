// Minimal Hermes configuration paths for the NURL prototype.

$ `stdlib/ext/env.nu`
$ `stdlib/std/path.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`

@ hermes_home → String {
    : ?String explicit ( env_get `HERMES_HOME` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 {
                ^ v
            } {
                ( string_free v )
            }
        }
        F → {}
    }

    : ?String home ( env_get `HOME` )
    ?? home {
        T h → {
            ? > ( string_len h ) 0 {
                : String out ( path_join ( string_data h ) `.hermes` )
                ( string_free h )
                ^ out
            } {
                ( string_free h )
            }
        }
        F → {}
    }

    ^ ( string_from `.hermes` )
}

@ hermes_path s leaf → String {
    : String home ( hermes_home )
    : String out ( path_join ( string_data home ) leaf )
    ( string_free home )
    ^ out
}

@ hermes_config_path → String {
    ^ ( hermes_path `config.yaml` )
}

@ hermes_sessions_path → String {
    ^ ( hermes_path `sessions` )
}

@ hermes_state_db_path → String {
    ^ ( hermes_path `state.db` )
}

@ hermes_config_exists → b {
    : String path ( hermes_config_path )
    : b ok ( file_exists ( string_data path ) )
    ( string_free path )
    ^ ok
}

@ config_line_indent String line → i {
    : i n ( string_len line )
    : ~ i i 0
    : ~ b going T
    ~ going {
        ? >= i n { = going F } {
            ? != ( string_get line i ) 32 { = going F } {
                = i + i 1
            }
        }
    }
    ^ i
}

@ config_line_ignored String trimmed → b {
    ? == ( string_len trimmed ) 0 { ^ T } {}
    ? ( string_starts_with trimmed `#` ) { ^ T } {}
    ^ F
}

@ config_unquote String raw → String {
    : i n ( string_len raw )
    ? >= n 2 {
        : i first ( string_get raw 0 )
        : i last ( string_get raw - n 1 )
        ? | & == first 34 == last 34 & == first 39 == last 39 {
            : String out ( string_substr raw 1 - n 2 )
            ( string_free raw )
            ^ out
        } {}
    } {}
    ^ raw
}

@ config_clean_value String raw → String {
    : ~ String no_comment ( string_from ( string_data raw ) )
    : ?i hash_pos ( string_index_of raw `#` )
    ?? hash_pos {
        T idx → {
            ( string_free no_comment )
            = no_comment ( string_substr raw 0 idx )
        }
        F → {}
    }
    ( string_free raw )
    : String trimmed ( string_trim no_comment )
    ( string_free no_comment )
    ^ ( config_unquote trimmed )
}

@ config_line_key_is String trimmed s wanted → b {
    : ?i colon ( string_index_of trimmed `:` )
    ?? colon {
        T idx → {
            : String raw_key ( string_substr trimmed 0 idx )
            : String key ( string_trim raw_key )
            ( string_free raw_key )
            : b ok ? != ( nurl_str_eq ( string_data key ) wanted ) 0 T F
            ( string_free key )
            ^ ok
        }
        F → {}
    }
    ^ F
}

@ config_key_value String trimmed s wanted → String {
    : ?i colon ( string_index_of trimmed `:` )
    ?? colon {
        T idx → {
            : String raw_key ( string_substr trimmed 0 idx )
            : String key ( string_trim raw_key )
            ( string_free raw_key )
            : b ok ? != ( nurl_str_eq ( string_data key ) wanted ) 0 T F
            ( string_free key )
            ? ok {
                : i start + idx 1
                : String raw_val ( string_substr trimmed start - ( string_len trimmed ) start )
                ^ ( config_clean_value raw_val )
            } {}
        }
        F → {}
    }
    ^ ( string_from `` )
}

@ hermes_config_root_value s wanted → String {
    : String path ( hermes_config_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            : String found ( string_from `` )
            : ~ b done F
            : i n ( vec_len [String] lines )
            : ~ i i 0
            ~ & < i n ! done {
                : ?String e ( vec_get [String] lines i )
                ?? e {
                    T line → {
                        : String trimmed ( string_trim line )
                        ? ( config_line_ignored trimmed ) {} {
                            ? == ( config_line_indent line ) 0 {
                                : String got ( config_key_value trimmed wanted )
                                ? > ( string_len got ) 0 {
                                    ( string_free found )
                                    = found got
                                    = done T
                                } {
                                    ( string_free got )
                                }
                            } {}
                        }
                        ( string_free trimmed )
                    }
                    F → {}
                }
                = i + i 1
            }
            ( vec_free_with [String] lines drop_str )
            ^ found
        }
        F _ → {}
    }
    ^ ( string_from `` )
}

@ hermes_config_section_value s section s wanted → String {
    : String path ( hermes_config_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            : String found ( string_from `` )
            : ~ b done F
            : ~ b in_section F
            : i n ( vec_len [String] lines )
            : ~ i i 0
            ~ & < i n ! done {
                : ?String e ( vec_get [String] lines i )
                ?? e {
                    T line → {
                        : String trimmed ( string_trim line )
                        ? ( config_line_ignored trimmed ) {} {
                            : i indent ( config_line_indent line )
                            ? == indent 0 {
                                ? ( config_line_key_is trimmed section ) {
                                    = in_section T
                                } {
                                    = in_section F
                                }
                            } {
                                ? in_section {
                                    : String got ( config_key_value trimmed wanted )
                                    ? > ( string_len got ) 0 {
                                        ( string_free found )
                                        = found got
                                        = done T
                                    } {
                                        ( string_free got )
                                    }
                                } {}
                            }
                        }
                        ( string_free trimmed )
                    }
                    F → {}
                }
                = i + i 1
            }
            ( vec_free_with [String] lines drop_str )
            ^ found
        }
        F _ → {}
    }
    ^ ( string_from `` )
}

@ hermes_config_model_value s wanted → String {
    : String path ( hermes_config_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            : String found ( string_from `` )
            : ~ b done F
            : ~ b in_model F
            : i n ( vec_len [String] lines )
            : ~ i i 0
            ~ & < i n ! done {
                : ?String e ( vec_get [String] lines i )
                ?? e {
                    T line → {
                        : String trimmed ( string_trim line )
                        ? ( config_line_ignored trimmed ) {} {
                            : i indent ( config_line_indent line )
                            ? == indent 0 {
                                ? ( config_line_key_is trimmed `model` ) {
                                    = in_model T
                                } {
                                    = in_model F
                                }
                            } {
                                ? in_model {
                                    : String got ( config_key_value trimmed wanted )
                                    ? > ( string_len got ) 0 {
                                        ( string_free found )
                                        = found got
                                        = done T
                                    } {
                                        ( string_free got )
                                    }
                                } {}
                            }
                        }
                        ( string_free trimmed )
                    }
                    F → {}
                }
                = i + i 1
            }
            ( vec_free_with [String] lines drop_str )
            ^ found
        }
        F _ → {}
    }
    ^ ( string_from `` )
}

@ hermes_config_model_default → String {
    : String got ( hermes_config_model_value `default` )
    ? > ( string_len got ) 0 { ^ got } {}
    ( string_free got )

    : String nested_model ( hermes_config_model_value `model` )
    ? > ( string_len nested_model ) 0 { ^ nested_model } {}
    ( string_free nested_model )

    ^ ( hermes_config_root_value `model` )
}

@ hermes_config_model_base_url → String {
    : String got ( hermes_config_model_value `base_url` )
    ? > ( string_len got ) 0 { ^ got } {}
    ( string_free got )
    ^ ( hermes_config_root_value `base_url` )
}

@ hermes_config_model_provider → String {
    : String got ( hermes_config_model_value `provider` )
    ? > ( string_len got ) 0 { ^ got } {}
    ( string_free got )
    ^ ( hermes_config_root_value `provider` )
}

@ hermes_config_model_fallback_provider → String {
    : String got ( hermes_config_model_value `fallback_provider` )
    ? > ( string_len got ) 0 { ^ got } {}
    ( string_free got )
    ^ ( hermes_config_root_value `fallback_provider` )
}

@ hermes_config_model_fallback_model → String {
    : String got ( hermes_config_model_value `fallback_model` )
    ? > ( string_len got ) 0 { ^ got } {}
    ( string_free got )

    : String got2 ( hermes_config_model_value `fallback_default` )
    ? > ( string_len got2 ) 0 { ^ got2 } {}
    ( string_free got2 )

    ^ ( hermes_config_root_value `fallback_model` )
}

@ hermes_config_model_fallback_base_url → String {
    ^ ( hermes_config_model_value `fallback_base_url` )
}

@ hermes_config_model_fallback_api_key → String {
    ^ ( hermes_config_model_value `fallback_api_key` )
}

@ hermes_config_model_fallback_max_tokens → i {
    : String got ( hermes_config_model_value `fallback_max_tokens` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_model_api_key → String {
    ^ ( hermes_config_model_value `api_key` )
}

@ hermes_config_model_context_length → i {
    : String got ( hermes_config_model_value `context_length` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → { ^ n }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_model_max_tokens → i {
    : String got ( hermes_config_model_value `max_tokens` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_agent_api_max_retries → i {
    : String got ( hermes_config_section_value `agent` `api_max_retries` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_agent_fallback_api_max_retries → i {
    : String got ( hermes_config_section_value `agent` `fallback_api_max_retries` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_section_positive_int s section s key → i {
    : String got ( hermes_config_section_value section key )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_agent_api_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `agent` `api_timeout_ms` )
}

@ hermes_config_agent_api_connect_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `agent` `api_connect_timeout_ms` )
}

@ hermes_config_agent_fallback_api_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `agent` `fallback_api_timeout_ms` )
}

@ hermes_config_agent_fallback_api_connect_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `agent` `fallback_api_connect_timeout_ms` )
}

@ hermes_config_agent_max_turns → i {
    : String got ( hermes_config_section_value `agent` `max_turns` )
    ? > ( string_len got ) 0 {
        : !i ParseErr parsed ( string_to_int got )
        ( string_free got )
        ?? parsed {
            T n → {
                ? > n 0 { ^ n } {}
            }
            F _ → {}
        }
    } {
        ( string_free got )
    }
    ^ 0
}

@ hermes_config_network_value s wanted → String {
    ^ ( hermes_config_section_value `network` wanted )
}

@ hermes_config_network_allow_hosts → String {
    ^ ( hermes_config_network_value `allow_hosts` )
}

@ hermes_config_network_allow_base_urls → String {
    ^ ( hermes_config_network_value `allow_base_urls` )
}

@ hermes_config_network_max_response_bytes → i {
    ^ ( hermes_config_section_positive_int `network` `max_response_bytes` )
}

@ hermes_config_network_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `network` `timeout_ms` )
}

@ hermes_config_network_connect_timeout_ms → i {
    ^ ( hermes_config_section_positive_int `network` `connect_timeout_ms` )
}

@ hermes_config_network_allow_private → b {
    : String got ( hermes_config_network_value `allow_private` )
    : String lower ( string_to_lower got )
    ( string_free got )
    : ~ b yes F
    ? != ( nurl_str_eq ( string_data lower ) `1` ) 0 { = yes T } {}
    ? != ( nurl_str_eq ( string_data lower ) `true` ) 0 { = yes T } {}
    ? != ( nurl_str_eq ( string_data lower ) `yes` ) 0 { = yes T } {}
    ? != ( nurl_str_eq ( string_data lower ) `on` ) 0 { = yes T } {}
    ( string_free lower )
    ^ yes
}

@ hermes_nurl_provider_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_PROVIDER` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    : String configured ( hermes_config_model_provider )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )

    ^ ( string_from `anthropic` )
}

@ hermes_nurl_fallback_provider_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_FALLBACK_PROVIDER` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    : String configured ( hermes_config_model_fallback_provider )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )

    ^ ( string_from `` )
}

@ hermes_nurl_fallback_model_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_FALLBACK_MODEL` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    ^ ( hermes_config_model_fallback_model )
}

@ hermes_nurl_fallback_base_url_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_FALLBACK_BASE_URL` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    ^ ( hermes_config_model_fallback_base_url )
}

@ hermes_nurl_fallback_api_key_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_FALLBACK_API_KEY` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    ^ ( hermes_config_model_fallback_api_key )
}

@ hermes_nurl_fallback_api_key_source_from_env → s {
    : ?String explicit ( env_get `HERMES_NURL_FALLBACK_API_KEY` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 {
                ( string_free v )
                ^ `HERMES_NURL_FALLBACK_API_KEY`
            } {}
            ( string_free v )
        }
        F → {}
    }

    : String configured ( hermes_config_model_fallback_api_key )
    ? > ( string_len configured ) 0 {
        ( string_free configured )
        ^ `config.yaml:model.fallback_api_key`
    } {}
    ( string_free configured )

    ^ `missing`
}

@ hermes_config_int_env_value s name → i {
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

@ hermes_nurl_fallback_max_tokens_from_env → i {
    : i env_tokens ( hermes_config_int_env_value `HERMES_NURL_FALLBACK_MAX_TOKENS` )
    ? > env_tokens 0 { ^ env_tokens } {}
    ^ ( hermes_config_model_fallback_max_tokens )
}

@ hermes_nurl_fallback_api_max_retries_from_env → i {
    : i env_retries ( hermes_config_int_env_value `HERMES_NURL_FALLBACK_API_MAX_RETRIES` )
    ? > env_retries 0 { ^ env_retries } {}
    ^ ( hermes_config_agent_fallback_api_max_retries )
}

@ hermes_nurl_api_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_API_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    ^ ( hermes_config_agent_api_timeout_ms )
}

@ hermes_nurl_api_connect_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_API_CONNECT_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    ^ ( hermes_config_agent_api_connect_timeout_ms )
}

@ hermes_nurl_fallback_api_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_FALLBACK_API_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    ^ ( hermes_config_agent_fallback_api_timeout_ms )
}

@ hermes_nurl_fallback_api_connect_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_FALLBACK_API_CONNECT_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    ^ ( hermes_config_agent_fallback_api_connect_timeout_ms )
}

@ hermes_nurl_network_allow_hosts_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_NETWORK_ALLOW_HOSTS` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }
    ^ ( hermes_config_network_allow_hosts )
}

@ hermes_nurl_network_allow_base_urls_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_NETWORK_ALLOW_BASE_URLS` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }
    ^ ( hermes_config_network_allow_base_urls )
}

@ hermes_nurl_network_max_response_bytes_from_env → i {
    : i env_value ( hermes_config_int_env_value `HERMES_NURL_NETWORK_MAX_RESPONSE_BYTES` )
    ? > env_value 0 { ^ env_value } {}
    : i configured ( hermes_config_network_max_response_bytes )
    ? > configured 0 { ^ configured } {}
    ^ 80000
}

@ hermes_nurl_network_timeout_ms_from_env → i {
    : i env_value ( hermes_config_int_env_value `HERMES_NURL_NETWORK_TIMEOUT_MS` )
    ? > env_value 0 { ^ env_value } {}
    : i configured ( hermes_config_network_timeout_ms )
    ? > configured 0 { ^ configured } {}
    ^ 30000
}

@ hermes_nurl_network_connect_timeout_ms_from_env → i {
    : i env_value ( hermes_config_int_env_value `HERMES_NURL_NETWORK_CONNECT_TIMEOUT_MS` )
    ? > env_value 0 { ^ env_value } {}
    : i configured ( hermes_config_network_connect_timeout_ms )
    ? > configured 0 { ^ configured } {}
    ^ 10000
}

@ hermes_nurl_network_allow_private_from_env → b {
    : ?String explicit ( env_get `HERMES_NURL_NETWORK_ALLOW_PRIVATE` )
    ?? explicit {
        T v → {
            : String lower ( string_to_lower v )
            ( string_free v )
            : ~ b yes F
            ? != ( nurl_str_eq ( string_data lower ) `1` ) 0 { = yes T } {}
            ? != ( nurl_str_eq ( string_data lower ) `true` ) 0 { = yes T } {}
            ? != ( nurl_str_eq ( string_data lower ) `yes` ) 0 { = yes T } {}
            ? != ( nurl_str_eq ( string_data lower ) `on` ) 0 { = yes T } {}
            ( string_free lower )
            ^ yes
        }
        F → {}
    }
    ^ ( hermes_config_network_allow_private )
}

@ hermes_provider_is_openai_compat s provider → b {
    ? != ( nurl_str_eq provider `openai` ) 0 { ^ T } {}
    ? != ( nurl_str_eq provider `openai-compatible` ) 0 { ^ T } {}
    ? != ( nurl_str_eq provider `openai_compatible` ) 0 { ^ T } {}
    ? != ( nurl_str_eq provider `custom` ) 0 { ^ T } {}
    ^ F
}

@ hermes_provider_is_anthropic_compat s provider → b {
    ? != ( nurl_str_eq provider `anthropic` ) 0 { ^ T } {}
    ? != ( nurl_str_eq provider `anthropic-compatible` ) 0 { ^ T } {}
    ? != ( nurl_str_eq provider `anthropic_compatible` ) 0 { ^ T } {}
    ^ F
}
