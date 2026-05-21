// OpenAI-compatible Chat Completions provider boundary for Hermes NURL.

$ `stdlib/ext/env.nu`
$ `stdlib/ext/http.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/config.nu`
$ `nurl/src/message_sanitization.nu`

: | OpenAICompatErr {
    OpenAICompatAuth
    OpenAICompatHttpConnect
    OpenAICompatHttpTimeout
    OpenAICompatHttpTls
    OpenAICompatHttpDns
    OpenAICompatHttpInvalidUrl
    OpenAICompatHttpOther
    OpenAICompatJson
    OpenAICompatApi
    OpenAICompatRateLimit
    OpenAICompatOverloaded
    OpenAICompatServer
    OpenAICompatContext
    OpenAICompatInvalidRequest
    OpenAICompatShape
}

@ OPENAI_COMPAT_DEFAULT_MODEL → s { ^ `gpt-4.1` }

@ OPENAI_COMPAT_DEFAULT_BASE_URL → s { ^ `https://api.openai.com/v1` }

@ OPENAI_COMPAT_MAX_TOKENS → i { ^ 4096 }

@ OPENAI_COMPAT_TIMEOUT_MS → i { ^ 600000 }

@ OPENAI_COMPAT_CONNECT_TIMEOUT_MS → i { ^ 15000 }

@ openai_compat_max_tokens_env_value s name → i {
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

@ openai_compat_max_tokens_from_env → i {
    : i scoped ( openai_compat_max_tokens_env_value `HERMES_NURL_OPENAI_MAX_TOKENS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( openai_compat_max_tokens_env_value `HERMES_NURL_MAX_TOKENS` )
    ? > generic 0 { ^ generic } {}
    : i configured ( hermes_config_model_max_tokens )
    ? > configured 0 { ^ configured } {}
    ^ ( OPENAI_COMPAT_MAX_TOKENS )
}

@ openai_compat_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_OPENAI_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( hermes_nurl_api_timeout_ms_from_env )
    ? > generic 0 { ^ generic } {}
    ^ ( OPENAI_COMPAT_TIMEOUT_MS )
}

@ openai_compat_connect_timeout_ms_from_env → i {
    : i scoped ( hermes_config_int_env_value `HERMES_NURL_OPENAI_CONNECT_TIMEOUT_MS` )
    ? > scoped 0 { ^ scoped } {}
    : i generic ( hermes_nurl_api_connect_timeout_ms_from_env )
    ? > generic 0 { ^ generic } {}
    ^ ( OPENAI_COMPAT_CONNECT_TIMEOUT_MS )
}

@ openai_compat_err_name OpenAICompatErr e → s {
    ^ ?? e {
        OpenAICompatAuth → `OpenAICompatAuth`
        OpenAICompatHttpConnect → `OpenAICompatHttpConnect`
        OpenAICompatHttpTimeout → `OpenAICompatHttpTimeout`
        OpenAICompatHttpTls → `OpenAICompatHttpTls`
        OpenAICompatHttpDns → `OpenAICompatHttpDns`
        OpenAICompatHttpInvalidUrl → `OpenAICompatHttpInvalidUrl`
        OpenAICompatHttpOther → `OpenAICompatHttpOther`
        OpenAICompatJson → `OpenAICompatJson`
        OpenAICompatApi → `OpenAICompatApi`
        OpenAICompatRateLimit → `OpenAICompatRateLimit`
        OpenAICompatOverloaded → `OpenAICompatOverloaded`
        OpenAICompatServer → `OpenAICompatServer`
        OpenAICompatContext → `OpenAICompatContext`
        OpenAICompatInvalidRequest → `OpenAICompatInvalidRequest`
        OpenAICompatShape → `OpenAICompatShape`
    }
}

@ openai_compat_map_http HttpErr e → OpenAICompatErr {
    ^ ?? e {
        HttpConnect → @ OpenAICompatErr { OpenAICompatHttpConnect }
        HttpTimeout → @ OpenAICompatErr { OpenAICompatHttpTimeout }
        HttpTls → @ OpenAICompatErr { OpenAICompatHttpTls }
        HttpDns → @ OpenAICompatErr { OpenAICompatHttpDns }
        HttpInvalidUrl → @ OpenAICompatErr { OpenAICompatHttpInvalidUrl }
        HttpOther → @ OpenAICompatErr { OpenAICompatHttpOther }
    }
}

@ openai_compat_body_context_error String body → b {
    : String lower ( string_to_lower body )
    : ~ b found F
    ? ( string_contains lower `context_length_exceeded` ) { = found T } {}
    ? ( string_contains lower `context length` ) { = found T } {}
    ? ( string_contains lower `maximum context` ) { = found T } {}
    ? ( string_contains lower `max context` ) { = found T } {}
    ? ( string_contains lower `too many tokens` ) { = found T } {}
    ? ( string_contains lower `token limit` ) { = found T } {}
    ? ( string_contains lower `reduce the length` ) { = found T } {}
    ( string_free lower )
    ^ found
}

@ openai_compat_status_error i status String body → OpenAICompatErr {
    ? | == status 401 == status 403 { ^ @ OpenAICompatErr { OpenAICompatAuth } } {}
    ? ( openai_compat_body_context_error body ) { ^ @ OpenAICompatErr { OpenAICompatContext } } {}
    ? == status 429 { ^ @ OpenAICompatErr { OpenAICompatRateLimit } } {}
    ? | | == status 408 == status 409 == status 425 { ^ @ OpenAICompatErr { OpenAICompatOverloaded } } {}
    ? & >= status 500 <= status 599 { ^ @ OpenAICompatErr { OpenAICompatServer } } {}
    ? | == status 400 == status 413 { ^ @ OpenAICompatErr { OpenAICompatInvalidRequest } } {}
    ^ @ OpenAICompatErr { OpenAICompatApi }
}

@ openai_compat_model_from_env → String {
    : ?String scoped ( env_get `HERMES_NURL_OPENAI_MODEL` )
    ?? scoped {
        T v → {
            ? > ( string_len v ) 0 { ^ v } {}
            ( string_free v )
        }
        F → {}
    }

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
    ^ ( string_from ( OPENAI_COMPAT_DEFAULT_MODEL ) )
}

@ openai_compat_api_key_from_env → ?String {
    : ?String primary ( env_get `OPENAI_API_KEY` )
    ?? primary {
        T key → {
            ? > ( string_len key ) 0 { ^ @ ?String { T key } } {}
            ( string_free key )
        }
        F → {}
    }

    : ?String scoped ( env_get `HERMES_NURL_OPENAI_API_KEY` )
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

@ openai_compat_api_key_source_from_env → s {
    : ?String primary ( env_get `OPENAI_API_KEY` )
    ?? primary {
        T key → {
            ? > ( string_len key ) 0 {
                ( string_free key )
                ^ `OPENAI_API_KEY`
            } {}
            ( string_free key )
        }
        F → {}
    }

    : ?String scoped ( env_get `HERMES_NURL_OPENAI_API_KEY` )
    ?? scoped {
        T key → {
            ? > ( string_len key ) 0 {
                ( string_free key )
                ^ `HERMES_NURL_OPENAI_API_KEY`
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

@ openai_compat_base_url_from_env → String {
    : ?String got ( env_get `HERMES_NURL_OPENAI_BASE_URL` )
    ?? got {
        T s → {
            ? > ( string_len s ) 0 { ^ s } {}
            ( string_free s )
        }
        F → {}
    }
    : String configured ( hermes_config_model_base_url )
    ? > ( string_len configured ) 0 { ^ configured } {}
    ( string_free configured )
    ^ ( string_from ( OPENAI_COMPAT_DEFAULT_BASE_URL ) )
}

@ openai_compat_chat_url_from_base String base → String {
    ? ( string_ends_with base `/chat/completions` ) {
        ^ base
    } {}

    : ~ String root ( string_from ( string_data base ) )
    ? ( string_ends_with base `/` ) {
        ( string_free root )
        = root ( string_substr base 0 - ( string_len base ) 1 )
    } {}

    : String url ( string_with_cap + ( string_len root ) 20 )
    ( string_push_str url ( string_data root ) )
    ( string_push_str url `/chat/completions` )
    ( string_free root )
    ( string_free base )
    ^ url
}

@ openai_compat_chat_url_from_env → String {
    ^ ( openai_compat_chat_url_from_base ( openai_compat_base_url_from_env ) )
}

@ openai_compat_headers s api_key → String {
    : String b ( string_with_cap 256 )
    ( string_push_str b `authorization: Bearer ` )
    ( string_push_str b api_key )
    ( string_push_str b `\r\n` )
    ( string_push_str b `content-type: application/json\r\n` )
    ^ b
}

@ openai_compat_clone_vec_json ( Vec Json ) src → ( Vec Json ) {
    : ( Vec Json ) out ( vec_new [Json] )
    : i n ( vec_len [Json] src )
    : ~ i k 0
    ~ < k n {
        : ?Json e ( vec_get [Json] src k )
        ?? e {
            T jv → ( vec_push [Json] out ( json_clone jv ) )
            F → {}
        }
        = k + k 1
    }
    ^ out
}

@ openai_compat_msg s role s content → Json {
    : Json m ( json_obj_new )
    ( json_obj_set m `role` ( json_str_lit role ) )
    ( json_obj_set m `content` ( json_str_lit content ) )
    ^ m
}

@ openai_compat_msg_assistant_response Json r → Json {
    : ?Json msg ( openai_compat_first_message r )
    ?? msg {
        T m → { ^ ( json_clone m ) }
        F → {}
    }
    ^ ( openai_compat_msg `assistant` `` )
}

@ openai_compat_msg_tool_result s tool_call_id s content → Json {
    : Json m ( json_obj_new )
    ( json_obj_set m `role` ( json_str_lit `tool` ) )
    ( json_obj_set m `tool_call_id` ( json_str_lit tool_call_id ) )
    ( json_obj_set m `content` ( json_str_lit content ) )
    ^ m
}

@ openai_compat_build_body
s model
( Vec Json ) messages
( Vec Json ) tools
s tool_choice
i max_tokens → Json {
    : Json body ( json_obj_new )
    ( json_obj_set body `model` ( json_str_lit model ) )

    ? > max_tokens 0 {
        ( json_obj_set body `max_tokens` ( json_int max_tokens ) )
    } {}

    : ( Vec Json ) msgs_cloned ( openai_compat_clone_vec_json messages )
    ( json_obj_set body `messages` ( json_arr msgs_cloned ) )

    : i tn ( vec_len [Json] tools )
    ? > tn 0 {
        : ( Vec Json ) tools_cloned ( openai_compat_clone_vec_json tools )
        ( json_obj_set body `tools` ( json_arr tools_cloned ) )
        ? > ( nurl_str_len tool_choice ) 0 {
            ( json_obj_set body `tool_choice` ( json_str_lit tool_choice ) )
        } {}
    } {}

    ^ body
}

@ openai_compat_chat
s api_key
s model
( Vec Json ) messages
( Vec Json ) tools
s tool_choice
i max_tokens
→ !Json OpenAICompatErr {
    : String url ( openai_compat_chat_url_from_env )
    : !Json OpenAICompatErr out
    ( openai_compat_chat_to_url
    ( string_data url ) api_key model messages tools tool_choice max_tokens )
    ( string_free url )
    ^ out
}

@ openai_compat_chat_to_url
s url
s api_key
s model
( Vec Json ) messages
( Vec Json ) tools
s tool_choice
i max_tokens
→ !Json OpenAICompatErr {
    ? == ( nurl_str_len api_key ) 0 {
        ^ @ !Json OpenAICompatErr { F @ OpenAICompatErr { OpenAICompatAuth } }
    } {}

    : Json body ( openai_compat_build_body model messages tools tool_choice max_tokens )
    : String body_str ( json_stringify body )
    ( json_free body )

    : String headers ( openai_compat_headers api_key )
    : !Response HttpErr res ( http_request_to `POST` url ( string_data body_str ) ( string_data headers ) ( openai_compat_timeout_ms_from_env ) ( openai_compat_connect_timeout_ms_from_env ) )
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
                        : OpenAICompatErr api_err ( openai_compat_status_error st body_owned )
                        ( json_free j )
                        ( string_free body_owned )
                        ^ @ !Json OpenAICompatErr { F api_err }
                    } {}
                    ( string_free body_owned )
                    ^ @ !Json OpenAICompatErr { T j }
                }
                F _ → {
                    ? != st 200 {
                        : OpenAICompatErr api_err ( openai_compat_status_error st body_owned )
                        ( string_free body_owned )
                        ^ @ !Json OpenAICompatErr { F api_err }
                    } {}
                    ( string_free body_owned )
                    ^ @ !Json OpenAICompatErr { F @ OpenAICompatErr { OpenAICompatJson } }
                }
            }
        }
        F he → {
            ^ @ !Json OpenAICompatErr { F ( openai_compat_map_http # HttpErr he ) }
        }
    }
    ^ @ !Json OpenAICompatErr { F @ OpenAICompatErr { OpenAICompatShape } }
}

@ openai_compat_first_message Json r → ?Json {
    : ?Json choices ( json_obj_get r `choices` )
    ?? choices {
        T arr → {
            : ?Json first ( json_arr_get arr 0 )
            ?? first {
                T choice → {
                    ^ ( json_obj_get choice `message` )
                }
                F → {}
            }
        }
        F → {}
    }
    ^ @ ?Json { F @ Json { JNull } }
}

@ openai_compat_text Json r → s {
    : ?Json msg ( openai_compat_first_message r )
    ?? msg {
        T m → {
            : ?Json c ( json_obj_get m `content` )
            ?? c {
                T cj → { ^ ( json_str_data cj ) }
                F → {}
            }
        }
        F → {}
    }
    ^ ``
}

@ openai_compat_has_tool_calls Json r → b {
    : ?Json msg ( openai_compat_first_message r )
    ?? msg {
        T m → {
            : ?Json tcs ( json_obj_get m `tool_calls` )
            ?? tcs {
                T arr → { ^ > ( json_arr_len arr ) 0 }
                F → {}
            }
        }
        F → {}
    }
    ^ F
}

@ openai_compat_tool_calls Json r → ( Vec Json ) {
    : ( Vec Json ) out ( vec_new [Json] )
    : ?Json msg ( openai_compat_first_message r )
    ?? msg {
        T m → {
            : ?Json tcs ( json_obj_get m `tool_calls` )
            ?? tcs {
                T arr → {
                    : i n ( json_arr_len arr )
                    : ~ i k 0
                    ~ < k n {
                        : ?Json item ( json_arr_get arr k )
                        ?? item {
                            T tc → ( vec_push [Json] out ( json_clone tc ) )
                            F → {}
                        }
                        = k + k 1
                    }
                }
                F → {}
            }
        }
        F → {}
    }
    ^ out
}

@ openai_compat_tool_call_id Json tc → s {
    : ?Json id ( json_obj_get tc `id` )
    ?? id {
        T j → { ^ ( json_str_data j ) }
        F → { ^ `` }
    }
    ^ ``
}

@ openai_compat_tool_call_name Json tc → s {
    : ?Json fn ( json_obj_get tc `function` )
    ?? fn {
        T f → {
            : ?Json n ( json_obj_get f `name` )
            ?? n {
                T j → { ^ ( json_str_data j ) }
                F → {}
            }
        }
        F → {}
    }
    ^ ``
}

@ openai_compat_tool_call_input Json tc → Json {
    : ?Json fn ( json_obj_get tc `function` )
    ?? fn {
        T f → {
            : ?Json args ( json_obj_get f `arguments` )
            ?? args {
                T a → {
                    : s raw ( json_str_data a )
                    ? > ( nurl_str_len raw ) 0 {
                        : String repaired ( repair_tool_call_arguments raw ( openai_compat_tool_call_name tc ) )
                        : !Json ParseErr parsed ( json_parse ( string_data repaired ) )
                        ?? parsed {
                            T j → {
                                ( string_free repaired )
                                ^ j
                            }
                            F _ → {}
                        }
                        ( string_free repaired )
                    } {
                        ^ ( json_clone a )
                    }
                }
                F → {}
            }
        }
        F → {}
    }
    ^ ( json_obj_new )
}

@ openai_compat_usage_int Json r s field → i {
    : ?Json u ( json_obj_get r `usage` )
    ?? u {
        T uo → {
            : ?Json got ( json_obj_get uo field )
            ?? got {
                T j → {
                    : ?i n ( json_num_as_i j )
                    ?? n {
                        T x → { ^ x }
                        F → {}
                    }
                }
                F → {}
            }
        }
        F → {}
    }
    ^ 0
}

@ openai_compat_input_tokens Json r → i {
    ^ ( openai_compat_usage_int r `prompt_tokens` )
}

@ openai_compat_output_tokens Json r → i {
    ^ ( openai_compat_usage_int r `completion_tokens` )
}

@ openai_compat_response_free Json r → v {
    ( json_free r )
}
