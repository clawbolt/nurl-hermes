// Anthropic provider boundary for Hermes NURL.

$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/ext/http.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/config.nu`

@ ANTHROPIC_DEFAULT_MODEL → s { ^ `claude-opus-4-7` }

@ ANTHROPIC_DEFAULT_BASE_URL → s { ^ `https://api.anthropic.com` }

@ ANTHROPIC_MAX_TOKENS → i { ^ 4096 }

@ anthropic_max_tokens_env_value s name → i {
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

@ anthropic_max_tokens_from_env → i {
    : i scoped ( anthropic_max_tokens_env_value `HERMES_NURL_ANTHROPIC_MAX_TOKENS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( anthropic_max_tokens_env_value `HERMES_NURL_MAX_TOKENS` )
    ? > generic 0 { ^ generic } {}
    : i configured ( hermes_config_model_max_tokens )
    ? > configured 0 { ^ configured } {}
    ^ ( ANTHROPIC_MAX_TOKENS )
}

@ anthropic_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_ANTHROPIC_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( hermes_nurl_api_timeout_ms_from_env )
    ? > generic 0 { ^ generic } {}
    ^ ( __claude_timeout_ms )
}

@ anthropic_connect_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_ANTHROPIC_CONNECT_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( hermes_nurl_api_connect_timeout_ms_from_env )
    ? > generic 0 { ^ generic } {}
    ^ ( __claude_connect_timeout_ms )
}

@ anthropic_model_from_env → String {
    : ?String explicit ( env_get `HERMES_NURL_MODEL` )
    ?? explicit {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

    : String configured ( hermes_config_model_default )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ^ ( string_from ( ANTHROPIC_DEFAULT_MODEL ) )
}

@ anthropic_api_key_from_env → ?String {
    : ?String primary ( env_get `ANTHROPIC_API_KEY` )
    ?? primary {
        T key → {
            ? > ( string_len key ) 0 { ^ @ ?String { T key } } {}
            ( string_free key )
        }
        F → {}
    }

    : ?String scoped ( env_get `HERMES_NURL_ANTHROPIC_API_KEY` )
    ?? scoped {
        T key → {
            ? > ( string_len key ) 0 { ^ @ ?String { T key } } {}
            ( string_free key )
        }
        F → {}
    }

    : String configured ( hermes_config_model_api_key )
    ? > ( string_len configured ) 0 { ^ @ ?String { T configured } } {}
    ( string_free configured )

    ^ @ ?String { F # String 0 }
}

@ anthropic_api_key_source_from_env → s {
    : ?String primary ( env_get `ANTHROPIC_API_KEY` )
    ?? primary {
        T key → {
            ? > ( string_len key ) 0 {
                ( string_free key )
                ^ `ANTHROPIC_API_KEY`
            } {}
            ( string_free key )
        }
        F → {}
    }

    : ?String scoped ( env_get `HERMES_NURL_ANTHROPIC_API_KEY` )
    ?? scoped {
        T key → {
            ? > ( string_len key ) 0 {
                ( string_free key )
                ^ `HERMES_NURL_ANTHROPIC_API_KEY`
            } {}
            ( string_free key )
        }
        F → {}
    }

    : String configured ( hermes_config_model_api_key )
    ? > ( string_len configured ) 0 {
        ( string_free configured )
        ^ `config.yaml:model.api_key`
    } {}
    ( string_free configured )

    ^ `missing`
}

@ anthropic_base_url_from_env → String {
    : ?String got ( env_get `HERMES_NURL_ANTHROPIC_BASE_URL` )
    ?? got {
        T s → {
            ? > ( string_len s ) 0 {
                ^ s
            } {
                ( string_free s )
            }
        }
        F → {}
    }
    : String configured ( hermes_config_model_base_url )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ^ ( string_from ( ANTHROPIC_DEFAULT_BASE_URL ) )
}

@ anthropic_messages_url_from_base String base → String {
    ? ( string_ends_with base `/v1/messages` ) {
        ^ base
    } {}

    : ~ String root ( string_from ( string_data base ) )
    ? ( string_ends_with base `/` ) {
        ( string_free root )
        = root ( string_substr base 0 - ( string_len base ) 1 )
    } {}

    : String url ( string_with_cap + ( string_len root ) 12 )
    ( string_push_str url ( string_data root ) )
    ( string_push_str url `/v1/messages` )
    ( string_free root )
    ( string_free base )
    ^ url
}

@ anthropic_messages_url_from_env → String {
    ^ ( anthropic_messages_url_from_base ( anthropic_base_url_from_env ) )
}

@ anthropic_status_retryable i status → b {
    ? == status 408 { ^ T } {}
    ? == status 409 { ^ T } {}
    ? == status 425 { ^ T } {}
    ? == status 429 { ^ T } {}
    ? & >= status 500 <= status 599 { ^ T } {}
    ^ F
}

@ anthropic_status_error i status → ClaudeErr {
    ? | == status 401 == status 403 { ^ @ ClaudeErr { ClaudeAuth } } {}
    ? ( anthropic_status_retryable status ) { ^ @ ClaudeErr { ClaudeHttpOther } } {}
    ^ @ ClaudeErr { ClaudeApi }
}

@ anthropic_messages
s api_key
s model
s system_prompt
( Vec Json ) messages
( Vec Json ) tools
s tool_choice
i max_tokens
→ !Json ClaudeErr {
    : String url ( anthropic_messages_url_from_env )
    : !Json ClaudeErr out
    ( anthropic_messages_to_url
    ( string_data url ) api_key model system_prompt messages tools tool_choice max_tokens )
    ( string_free url )
    ^ out
}

@ anthropic_messages_to_url
s url
s api_key
s model
s system_prompt
( Vec Json ) messages
( Vec Json ) tools
s tool_choice
i max_tokens
→ !Json ClaudeErr {
    ? == ( nurl_str_len api_key ) 0 {
        ^ @ !Json ClaudeErr { F @ ClaudeErr { ClaudeAuth } }
    } {}

    : Json body
    ( __claude_build_body_full_ex model system_prompt messages tools tool_choice max_tokens F F 0 )
    : String body_str ( json_stringify body )
    ( json_free body )

    : String headers ( __claude_headers api_key )
    : !Response HttpErr res
    ( http_request_to `POST`
    url
    ( string_data body_str )
    ( string_data headers )
    ( anthropic_timeout_ms_from_env )
    ( anthropic_connect_timeout_ms_from_env ) )
    ( string_free body_str )
    ( string_free headers )

    ?? res {
        T r → {
            : i st ( http_status r )
            : String body_owned ( string_from ( http_body_str r ) )
            ( response_free r )

            : !Json ParseErr pj ( json_parse ( string_data body_owned ) )

            ?? pj {
                T j → {
                    ? != st 200 {
                        : ClaudeErr api_err ( anthropic_status_error st )
                        ( json_free j )
                        ( string_free body_owned )
                        ^ @ !Json ClaudeErr { F api_err }
                    } {}
                    ( string_free body_owned )
                    ^ @ !Json ClaudeErr { T j }
                }
                F _ → {
                    ? != st 200 {
                        : ClaudeErr api_err ( anthropic_status_error st )
                        ( string_free body_owned )
                        ^ @ !Json ClaudeErr { F api_err }
                    } {}
                    ( string_free body_owned )
                    ^ @ !Json ClaudeErr { F @ ClaudeErr { ClaudeJson } }
                }
            }
        }
        F he → {
            ^ @ !Json ClaudeErr { F ( __claude_map_http # HttpErr he ) }
        }
    }
    ^ @ !Json ClaudeErr { F @ ClaudeErr { ClaudeShape } }
}
