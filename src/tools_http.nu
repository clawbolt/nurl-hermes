// Controlled outbound HTTP tools for Hermes NURL.

$ `stdlib/ext/http.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`

@ http_input_int Json input s field i default → i {
    : ?Json v ( json_obj_get input field )
    ?? v {
        T j → {
            : ?i n ( json_num_as_i j )
            ?? n {
                T got → {
                    ? > got 0 { ^ got } {}
                }
                F → {}
            }
        }
        F → {}
    }
    ^ default
}

@ http_request_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json method_prop ( json_obj_new )
    ( json_obj_set method_prop `type` ( json_str_lit `string` ) )
    : Json methods ( json_arr_new )
    ( json_arr_push methods ( json_str_lit `GET` ) )
    ( json_arr_push methods ( json_str_lit `POST` ) )
    ( json_obj_set method_prop `enum` methods )
    ( json_obj_set method_prop `description` ( json_str_lit `HTTP method. Supported values: GET, POST.` ) )

    : Json url_prop ( json_obj_new )
    ( json_obj_set url_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set url_prop `description` ( json_str_lit `HTTP or HTTPS URL. Token-bearing URLs, embedded credentials, and disallowed hosts are rejected.` ) )

    : Json headers_prop ( json_obj_new )
    ( json_obj_set headers_prop `type` ( json_str_lit `object` ) )
    ( json_obj_set headers_prop `description` ( json_str_lit `Optional request headers as a JSON object of string values. CRLF injection is rejected. Authorization values are redacted from traces.` ) )

    : Json body_prop ( json_obj_new )
    ( json_obj_set body_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set body_prop `description` ( json_str_lit `Optional text request body. Not persisted in traces or session logs.` ) )

    : Json json_body_prop ( json_obj_new )
    ( json_obj_set json_body_prop `type` ( json_str_lit `object` ) )
    ( json_obj_set json_body_prop `description` ( json_str_lit `Optional JSON object request body. Used when body is empty.` ) )

    : Json ct_prop ( json_obj_new )
    ( json_obj_set ct_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set ct_prop `description` ( json_str_lit `Optional Content-Type. Defaults to application/json when a body is present.` ) )

    : Json max_prop ( json_obj_new )
    ( json_obj_set max_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set max_prop `description` ( json_str_lit `Optional response body byte cap. Clamped to the configured network maximum.` ) )

    : Json timeout_prop ( json_obj_new )
    ( json_obj_set timeout_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set timeout_prop `description` ( json_str_lit `Optional total timeout in milliseconds.` ) )

    : Json connect_prop ( json_obj_new )
    ( json_obj_set connect_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set connect_prop `description` ( json_str_lit `Optional connect timeout in milliseconds.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `method` method_prop )
    ( json_obj_set props `url` url_prop )
    ( json_obj_set props `headers` headers_prop )
    ( json_obj_set props `body` body_prop )
    ( json_obj_set props `json_body` json_body_prop )
    ( json_obj_set props `content_type` ct_prop )
    ( json_obj_set props `max_response_bytes` max_prop )
    ( json_obj_set props `timeout_ms` timeout_prop )
    ( json_obj_set props `connect_timeout_ms` connect_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `url` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ http_s_has_crlf s raw → b {
    ? != ( nurl_str_find raw `\n` ) -1 { ^ T } {}
    ? != ( nurl_str_find raw `\r` ) -1 { ^ T } {}
    ? != ( nurl_str_find raw `\\n` ) -1 { ^ T } {}
    ? != ( nurl_str_find raw `\\r` ) -1 { ^ T } {}
    : String copy ( string_from raw )
    : ~ b escaped F
    ? ( string_contains copy `\\n` ) { = escaped T } {}
    ? ( string_contains copy `\\r` ) { = escaped T } {}
    : i n ( string_len copy )
    : ~ b bad escaped
    : ~ i k 0
    ~ & < k n ! bad {
        : i ch ( string_get copy k )
        ? | == ch 10 == ch 13 { = bad T } {}
        = k + k 1
    }
    ( string_free copy )
    ^ bad
}

@ http_clean_lower String raw → String {
    : String trimmed ( string_trim raw )
    ( string_free raw )
    : String lower ( string_to_lower trimmed )
    ( string_free trimmed )
    ^ lower
}

@ http_trim_trailing_dot String raw → String {
    : ~ String cur raw
    : ~ b going T
    ~ going {
        ? ( string_ends_with cur `.` ) {
            : i n ( string_len cur )
            : String next ( string_substr cur 0 - n 1 )
            ( string_free cur )
            = cur next
        } {
            = going F
        }
    }
    ^ cur
}

@ http_url_authority s url → String {
    : String src ( string_from url )
    : String lower ( string_to_lower src )
    : i start -1
    ? ( string_starts_with lower `https://` ) { = start 8 } {}
    ? ( string_starts_with lower `http://` ) { = start 7 } {}
    ( string_free lower )
    ? < start 0 {
        ( string_free src )
        ^ ( string_new )
    } {}
    : i n ( string_len src )
    : String out ( string_with_cap 64 )
    : ~ i k start
    : ~ b going T
    ~ & going < k n {
        : i ch ( string_get src k )
        ? | | == ch 47 == ch 63 == ch 35 {
            = going F
        } {
            ( string_push_char out ch )
            = k + k 1
        }
    }
    ( string_free src )
    ^ out
}

@ http_authority_host String authority → String {
    : String lower ( http_clean_lower authority )
    : i n ( string_len lower )
    ? == n 0 { ^ lower } {}
    ? ( string_contains lower `%` ) { ^ lower } {}
    ? == ( string_get lower 0 ) 91 {
        : ?i end_o ( string_index_of lower `]` )
        ?? end_o {
            T end_idx → {
                ? > end_idx 1 {
                    : String inside ( string_substr lower 1 - end_idx 1 )
                    ( string_free lower )
                    ^ inside
                } {}
            }
            F → {}
        }
    } {}
    : ?i colon ( string_index_of lower `:` )
    ?? colon {
        T idx → {
            : String host ( string_substr lower 0 idx )
            ( string_free lower )
            ^ ( http_trim_trailing_dot host )
        }
        F → {}
    }
    ^ ( http_trim_trailing_dot lower )
}

@ http_url_host s url → String {
    : String authority ( http_url_authority url )
    ^ ( http_authority_host authority )
}

@ http_url_scheme_ok s url → b {
    : String raw ( string_from url )
    : String lower ( string_to_lower raw )
    ( string_free raw )
    : b ok ? | ( string_starts_with lower `http://` ) ( string_starts_with lower `https://` ) T F
    ( string_free lower )
    ^ ok
}

@ http_url_has_credentials s url → b {
    : String authority ( http_url_authority url )
    : b bad ( string_contains authority `@` )
    ( string_free authority )
    ^ bad
}

@ http_url_has_token_query s url → b {
    : String raw ( string_from url )
    : String lower ( string_to_lower raw )
    ( string_free raw )
    : ~ b bad F
    ? ( string_contains lower `api_key=` ) { = bad T } {}
    ? ( string_contains lower `apikey=` ) { = bad T } {}
    ? ( string_contains lower `access_token=` ) { = bad T } {}
    ? ( string_contains lower `auth_token=` ) { = bad T } {}
    ? ( string_contains lower `token=` ) { = bad T } {}
    ? ( string_contains lower `authorization=` ) { = bad T } {}
    ( string_free lower )
    ^ bad
}

@ http_host_private_or_metadata s host → b {
    : String h0 ( string_from host )
    : String h ( string_to_lower h0 )
    ( string_free h0 )
    : ~ b bad F
    ? != ( nurl_str_eq ( string_data h ) `localhost` ) 0 { = bad T } {}
    ? != ( nurl_str_eq ( string_data h ) `::1` ) 0 { = bad T } {}
    ? != ( nurl_str_eq ( string_data h ) `metadata.google.internal` ) 0 { = bad T } {}
    ? != ( nurl_str_eq ( string_data h ) `metadata` ) 0 { = bad T } {}
    ? ( string_starts_with h `127.` ) { = bad T } {}
    ? ( string_starts_with h `10.` ) { = bad T } {}
    ? ( string_starts_with h `192.168.` ) { = bad T } {}
    ? ( string_starts_with h `169.254.` ) { = bad T } {}
    ? ( string_starts_with h `0.` ) { = bad T } {}
    ? ( string_starts_with h `172.16.` ) { = bad T } {}
    ? ( string_starts_with h `172.17.` ) { = bad T } {}
    ? ( string_starts_with h `172.18.` ) { = bad T } {}
    ? ( string_starts_with h `172.19.` ) { = bad T } {}
    ? ( string_starts_with h `172.20.` ) { = bad T } {}
    ? ( string_starts_with h `172.21.` ) { = bad T } {}
    ? ( string_starts_with h `172.22.` ) { = bad T } {}
    ? ( string_starts_with h `172.23.` ) { = bad T } {}
    ? ( string_starts_with h `172.24.` ) { = bad T } {}
    ? ( string_starts_with h `172.25.` ) { = bad T } {}
    ? ( string_starts_with h `172.26.` ) { = bad T } {}
    ? ( string_starts_with h `172.27.` ) { = bad T } {}
    ? ( string_starts_with h `172.28.` ) { = bad T } {}
    ? ( string_starts_with h `172.29.` ) { = bad T } {}
    ? ( string_starts_with h `172.30.` ) { = bad T } {}
    ? ( string_starts_with h `172.31.` ) { = bad T } {}
    ? ( string_starts_with h `fe80` ) { = bad T } {}
    ? ( string_starts_with h `fc` ) { = bad T } {}
    ? ( string_starts_with h `fd` ) { = bad T } {}
    ( string_free h )
    ^ bad
}

@ http_list_has_host s csv s host → b {
    : String raw ( string_from csv )
    : ( Vec String ) parts ( string_split raw `,` )
    ( string_free raw )
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    : String target0 ( string_from host )
    : String target ( http_clean_lower target0 )
    : ~ b found F
    : i n ( vec_len [String] parts )
    : ~ i k 0
    ~ & < k n ! found {
        : ?String e ( vec_get [String] parts k )
        ?? e {
            T part → {
                : String item0 ( string_from ( string_data part ) )
                : String item ( http_trim_trailing_dot ( http_clean_lower item0 ) )
                ? != ( nurl_str_eq ( string_data item ) ( string_data target ) ) 0 { = found T } {}
                ( string_free item )
            }
            F → {}
        }
        = k + k 1
    }
    ( string_free target )
    ( vec_free_with [String] parts drop_str )
    ^ found
}

@ http_list_has_base_url s csv String lower_url → b {
    : String raw ( string_from csv )
    : ( Vec String ) parts ( string_split raw `,` )
    ( string_free raw )
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    : ~ b found F
    : i n ( vec_len [String] parts )
    : ~ i k 0
    ~ & < k n ! found {
        : ?String e ( vec_get [String] parts k )
        ?? e {
            T part → {
                : String item0 ( string_from ( string_data part ) )
                : String item ( http_clean_lower item0 )
                ? > ( string_len item ) 0 {
                    ? ( string_starts_with lower_url ( string_data item ) ) { = found T } {}
                } {}
                ( string_free item )
            }
            F → {}
        }
        = k + k 1
    }
    ( vec_free_with [String] parts drop_str )
    ^ found
}

@ http_policy_error s url String host → String {
    ? ! ( http_url_scheme_ok url ) {
        ^ ( string_from `error: http_request only supports http:// and https:// URLs` )
    } {}
    ? == ( string_len host ) 0 {
        ^ ( string_from `error: http_request URL is missing a host` )
    } {}
    ? ( string_contains host `%` ) {
        ^ ( string_from `error: http_request rejected percent-encoded host` )
    } {}
    ? ( http_url_has_credentials url ) {
        ^ ( string_from `error: http_request rejected URL with embedded credentials` )
    } {}
    ? ( http_url_has_token_query url ) {
        ^ ( string_from `error: http_request rejected token-bearing URL` )
    } {}
    ? & & ( hermes_nurl_production_mode ) ( http_host_private_or_metadata ( string_data host ) ) ! ( hermes_nurl_network_private_allowed ) {
        ^ ( string_from `error: http_request rejected private, loopback, link-local, or metadata host` )
    } {}
    ? ! ( hermes_nurl_production_mode ) {
        ^ ( string_new )
    } {}
    : String hosts ( hermes_nurl_network_allow_hosts_from_env )
    : String bases ( hermes_nurl_network_allow_base_urls_from_env )
    : String raw_url ( string_from url )
    : String lower_url ( string_to_lower raw_url )
    ( string_free raw_url )
    : b host_ok ( http_list_has_host ( string_data hosts ) ( string_data host ) )
    : b base_ok ( http_list_has_base_url ( string_data bases ) lower_url )
    ( string_free hosts )
    ( string_free bases )
    ( string_free lower_url )
    ? | host_ok base_ok { ^ ( string_new ) } {}
    ^ ( string_from `error: http_request URL host is not allowed by HERMES_NURL_NETWORK_ALLOW_HOSTS or HERMES_NURL_NETWORK_ALLOW_BASE_URLS` )
}

@ http_method_from_input Json input → String {
    : s raw ( input_str input `method` )
    ? == ( nurl_str_len raw ) 0 { ^ ( string_from `GET` ) } {}
    : String m0 ( string_from raw )
    : String lower ( string_to_lower m0 )
    ( string_free m0 )
    ? != ( nurl_str_eq ( string_data lower ) `get` ) 0 {
        ( string_free lower )
        ^ ( string_from `GET` )
    } {}
    ? != ( nurl_str_eq ( string_data lower ) `post` ) 0 {
        ( string_free lower )
        ^ ( string_from `POST` )
    } {}
    ( string_free lower )
    ^ ( string_new )
}

@ http_body_from_input Json input → String {
    : s raw ( input_str input `body` )
    ? > ( nurl_str_len raw ) 0 { ^ ( string_from raw ) } {}
    : ?Json json_body ( json_obj_get input `json_body` )
    ?? json_body {
        T j → {
            ? ( json_is_obj j ) {
                ^ ( json_stringify j )
            } {}
        }
        F → {}
    }
    ^ ( string_new )
}

@ http_headers_blob Json input String body → String {
    : String out ( string_new )
    : s content_type ( input_str input `content_type` )
    ? & > ( string_len body ) 0 > ( nurl_str_len content_type ) 0 {
        ? ( http_s_has_crlf content_type ) {
            ( string_free out )
            ^ ( string_from `error: header content_type contains CRLF` )
        } {}
        ( string_push_str out `Content-Type: ` )
        ( string_push_str out content_type )
        ( string_push_str out `\r\n` )
    } {
        ? > ( string_len body ) 0 {
            ( string_push_str out `Content-Type: application/json\r\n` )
        } {}
    }

    : ?Json headers ( json_obj_get input `headers` )
    ?? headers {
        T h → {
            ? ! ( json_is_obj h ) {
                ( string_free out )
                ^ ( string_from `error: headers must be an object of string values` )
            } {}
            : String err ( string_new )
            ( json_obj_each h \ s key Json val → v {
                ? > ( string_len err ) 0 {} {
                    ? ( http_s_has_crlf key ) {
                        ( string_push_str err `error: headers must be string values without CRLF` )
                    } {
                        ? | == ( nurl_str_len key ) 0 != ( nurl_str_find key `:` ) -1 {
                            ( string_push_str err `error: headers must be string values without CRLF` )
                        } {
                            ? ! ( json_is_str val ) {
                                ( string_push_str err `error: headers must be string values without CRLF` )
                            } {
                                : s value ( json_str_data val )
                                ? ( http_s_has_crlf value ) {
                                    ( string_push_str err `error: headers must be string values without CRLF` )
                                } {
                                    ( string_push_str out key )
                                    ( string_push_str out `: ` )
                                    ( string_push_str out value )
                                    ( string_push_str out `\r\n` )
                                }
                            }
                        }
                    }
                }
            } )
            ? > ( string_len err ) 0 {
                ( string_free out )
                ^ err
            } {
                ( string_free err )
            }
        }
        F → {}
    }
    ^ out
}

@ http_body_redacted_or_capped String body i cap → String {
    : i n ( string_len body )
    : String safe ? | <= cap 0 <= n cap {
        body
    } {
        : String out ( string_substr body 0 cap )
        ( string_push_str out `\n...[truncated, ` )
        ( string_push_int out - n cap )
        ( string_push_str out ` more bytes]` )
        ( string_free body )
        out
    }
    : String lower ( string_to_lower safe )
    : ~ b redact F
    ? & ( string_contains lower `authorization` ) ( string_contains lower `bearer` ) { = redact T } {}
    ? ( string_contains lower `access_token=` ) { = redact T } {}
    ? ( string_contains lower `"access_token"` ) { = redact T } {}
    ? ( string_contains lower `api_key=` ) { = redact T } {}
    ? ( string_contains lower `"api_key"` ) { = redact T } {}
    ? ( string_contains lower `sk-` ) {
        ? | ( string_contains lower `token` ) ( string_contains lower `key` ) { = redact T } {}
    } {}
    ( string_free lower )
    ? redact {
        ( string_free safe )
        ^ ( string_from `[redacted response body: token-like content]` )
    } {}
    ^ safe
}

@ http_content_type Response r → String {
    : String out ( string_new )
    : i n ( http_header_count r )
    : ~ i k 0
    : ~ b done F
    ~ & < k n ! done {
        : s name ( http_header_name r k )
        : String ns ( string_from name )
        : String lower ( string_to_lower ns )
        ( string_free ns )
        ? != ( nurl_str_eq ( string_data lower ) `content-type` ) 0 {
            ( string_free out )
            = out ( string_from ( http_header_value r k ) )
            = done T
        } {}
        ( string_free lower )
        = k + k 1
    }
    ^ out
}

@ http_err_label HttpErr e → s {
    ^ ( http_err_name e )
}

@ run_http_request_tool Json input → String {
    ? ! ( hermes_nurl_network_allowed ) {
        ( trace_event `tool_blocked` `production_mode:http_request` )
        ^ ( string_from `error: http_request is disabled. In production set HERMES_NURL_ALLOW_NETWORK=1 and configure HERMES_NURL_NETWORK_ALLOW_HOSTS or HERMES_NURL_NETWORK_ALLOW_BASE_URLS.` )
    } {}
    : s url ( input_str input `url` )
    ? == ( nurl_str_len url ) 0 {
        ^ ( string_from `error: tool 'http_request' requires non-empty 'url' field` )
    } {}
    : String method ( http_method_from_input input )
    ? == ( string_len method ) 0 {
        ^ ( string_from `error: http_request method must be GET or POST` )
    } {}
    : String host ( http_url_host url )
    : String policy_err ( http_policy_error url host )
    ? > ( string_len policy_err ) 0 {
        : String detail ( string_from `http_request:` )
        ( string_push_str detail ( string_data host ) )
        ( trace_event `tool_blocked` ( string_data detail ) )
        ( string_free detail )
        ( string_free host )
        ( string_free method )
        ^ policy_err
    } {
        ( string_free policy_err )
    }

    : String body ( http_body_from_input input )
    ? & != ( nurl_str_eq ( string_data method ) `GET` ) 0 > ( string_len body ) 0 {
        ( string_free body )
        ( string_free host )
        ( string_free method )
        ^ ( string_from `error: http_request GET does not accept a request body` )
    } {}
    : String headers ( http_headers_blob input body )
    ? ( string_starts_with headers `error:` ) {
        ( string_free body )
        ( string_free host )
        ( string_free method )
        ^ headers
    } {}

    : i policy_cap ( hermes_nurl_network_max_response_bytes_from_env )
    : i requested_cap ( http_input_int input `max_response_bytes` 0 )
    : i cap ? > requested_cap 0 {
        ? < requested_cap policy_cap requested_cap policy_cap
    } {
        policy_cap
    }
    : i timeout ( http_input_int input `timeout_ms` ( hermes_nurl_network_timeout_ms_from_env ) )
    : i connect_timeout ( http_input_int input `connect_timeout_ms` ( hermes_nurl_network_connect_timeout_ms_from_env ) )

    : String trace ( string_from `method=` )
    ( string_push_str trace ( string_data method ) )
    ( string_push_str trace ` host=` )
    ( string_push_str trace ( string_data host ) )
    ( string_push_str trace ` request_bytes=` )
    ( string_push_int trace ( string_len body ) )
    ( trace_event `tool_http_request_start` ( string_data trace ) )
    ( string_free trace )

    : !Response HttpErr res ( http_request_to ( string_data method ) url ( string_data body ) ( string_data headers ) timeout connect_timeout )
    ( string_free body )
    ( string_free headers )

    ?? res {
        T r → {
            : i st ( http_status r )
            : String ctype ( http_content_type r )
            : String body_owned ( string_from ( http_body_str r ) )
            : i raw_bytes ( string_len body_owned )
            : b truncated ? > raw_bytes cap T F
            : String safe_body ( http_body_redacted_or_capped body_owned cap )
            ( response_free r )

            : String done ( string_from `method=` )
            ( string_push_str done ( string_data method ) )
            ( string_push_str done ` host=` )
            ( string_push_str done ( string_data host ) )
            ( string_push_str done ` status=` )
            ( string_push_int done st )
            ( string_push_str done ` bytes=` )
            ( string_push_int done raw_bytes )
            ( trace_event `tool_http_request_done` ( string_data done ) )
            ( string_free done )

            : String out ( string_with_cap 256 )
            ( string_push_str out `status: ` )
            ( string_push_int out st )
            ( string_push_str out `\nhost: ` )
            ( string_push_str out ( string_data host ) )
            ? > ( string_len ctype ) 0 {
                ( string_push_str out `\ncontent_type: ` )
                ( string_push_str out ( string_data ctype ) )
            } {}
            ( string_push_str out `\nbytes: ` )
            ( string_push_int out raw_bytes )
            ( string_push_str out `\ntruncated: ` )
            ? truncated { ( string_push_str out `true` ) } { ( string_push_str out `false` ) }
            ( string_push_str out `\nbody:\n` )
            ( string_push_str out ( string_data safe_body ) )
            ( string_free safe_body )
            ( string_free ctype )
            ( string_free host )
            ( string_free method )
            ^ out
        }
        F e → {
            : String out ( string_from `error: http_request transport failed: ` )
            ( string_push_str out ( http_err_label e ) )
            : String detail ( string_from `method=` )
            ( string_push_str detail ( string_data method ) )
            ( string_push_str detail ` host=` )
            ( string_push_str detail ( string_data host ) )
            ( string_push_str detail ` error=` )
            ( string_push_str detail ( http_err_label e ) )
            ( trace_event `tool_http_request_error` ( string_data detail ) )
            ( string_free detail )
            ( string_free host )
            ( string_free method )
            ^ out
        }
    }
}
