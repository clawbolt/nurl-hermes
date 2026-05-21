// Provider-agnostic message/tool-payload sanitization helpers for Hermes NURL.
//
// This ports the highest-value part of agent/message_sanitization.py for the
// OpenAI-compatible boundary: repair malformed function-call argument JSON
// before the agent tries to dispatch a tool.

$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`

@ json_parse_ok String raw → b {
    : !Json ParseErr parsed ( json_parse ( string_data raw ) )
    ?? parsed {
        T j → {
            ( json_free j )
            ^ T
        }
        F _ → {}
    }
    ^ F
}

@ count_char String raw i wanted → i {
    : i n ( string_len raw )
    : ~ i count 0
    : ~ i k 0
    ~ < k n {
        ? == ( string_get raw k ) wanted {
            = count + count 1
        } {}
        = k + k 1
    }
    ^ count
}

@ strip_trailing_commas_before_closers String raw → String {
    : i n ( string_len raw )
    : String out ( string_with_cap n )
    : ~ i k 0
    ~ < k n {
        : i c ( string_get raw k )
        ? & == c 44 < + k 1 n {
            : ~ i j + k 1
            : ~ b scanning T
            ~ scanning {
                ? >= j n {
                    = scanning F
                } {
                    : i cj ( string_get raw j )
                    ? == ( nurl_is_space cj ) 0 {
                        = scanning F
                    } {
                        = j + j 1
                    }
                }
            }
            ? < j n {
                : i next ( string_get raw j )
                ? | == next 125 == next 93 {
                    // Drop the comma; whitespace and closer will be copied normally.
                } {
                    ( string_push_char out c )
                }
            } {
                ( string_push_char out c )
            }
        } {
            ( string_push_char out c )
        }
        = k + k 1
    }
    ^ out
}

@ balance_json_closers String raw → String {
    : i open_curly ( count_char raw 123 )
    : i close_curly ( count_char raw 125 )
    : i open_bracket ( count_char raw 91 )
    : i close_bracket ( count_char raw 93 )
    : String out ( string_from ( string_data raw ) )
    : ~ i need_curly - open_curly close_curly
    : ~ i need_bracket - open_bracket close_bracket
    ~ > need_curly 0 {
        ( string_push_char out 125 )
        = need_curly - need_curly 1
    }
    ~ > need_bracket 0 {
        ( string_push_char out 93 )
        = need_bracket - need_bracket 1
    }
    ^ out
}

@ trim_excess_closing_tail String raw → String {
    : ~ String cur ( string_from ( string_data raw ) )
    : ~ i tries 50
    : ~ b done F
    ~ & > tries 0 ! done {
        ? ( json_parse_ok cur ) {
            = done T
        } {
            : i n ( string_len cur )
            ? <= n 0 {
                = done T
            } {
                : i last ( string_get cur - n 1 )
                ? & == last 125 > ( count_char cur 125 ) ( count_char cur 123 ) {
                    : String next ( string_substr cur 0 - n 1 )
                    ( string_free cur )
                    = cur next
                } {
                    ? & == last 93 > ( count_char cur 93 ) ( count_char cur 91 ) {
                        : String next ( string_substr cur 0 - n 1 )
                        ( string_free cur )
                        = cur next
                    } {
                        = done T
                    }
                }
            }
        }
        = tries - tries 1
    }
    ^ cur
}

@ json_hex_digit i nibble → i {
    ? < nibble 10 { ^ + 48 nibble } {}
    ^ + 87 nibble
}

@ push_json_unicode_escape String out i code → v {
    ( string_push_str out `\\u00` )
    : i high / code 16
    : i low - code * high 16
    ( string_push_char out ( json_hex_digit high ) )
    ( string_push_char out ( json_hex_digit low ) )
}

@ escape_invalid_chars_in_json_strings String raw → String {
    : i n ( string_len raw )
    : String out ( string_with_cap + n 16 )
    : ~ b in_string F
    : ~ i k 0
    ~ < k n {
        : i c ( string_get raw k )
        ? in_string {
            ? & == c 92 < + k 1 n {
                ( string_push_char out c )
                ( string_push_char out ( string_get raw + k 1 ) )
                = k + k 2
            } {
                ? == c 34 {
                    = in_string F
                    ( string_push_char out c )
                } {
                    ? < c 32 {
                        ( push_json_unicode_escape out c )
                    } {
                        ( string_push_char out c )
                    }
                }
                = k + k 1
            }
        } {
            ? == c 34 { = in_string T } {}
            ( string_push_char out c )
            = k + k 1
        }
    }
    ^ out
}

@ repair_tool_call_arguments s raw_args s tool_name → String {
    : String raw_owned ( string_from raw_args )
    : String trimmed ( string_trim raw_owned )
    ( string_free raw_owned )

    ? == ( string_len trimmed ) 0 {
        ( string_free trimmed )
        ^ ( string_from `{}` )
    } {}
    ? != ( nurl_str_eq ( string_data trimmed ) `None` ) 0 {
        ( string_free trimmed )
        ^ ( string_from `{}` )
    } {}

    ? ( json_parse_ok trimmed ) {
        ^ trimmed
    } {}

    : String no_trailing ( strip_trailing_commas_before_closers trimmed )
    ( string_free trimmed )
    ? ( json_parse_ok no_trailing ) {
        ^ no_trailing
    } {}

    : String balanced ( balance_json_closers no_trailing )
    ( string_free no_trailing )
    ? ( json_parse_ok balanced ) {
        ^ balanced
    } {}

    : String trimmed_tail ( trim_excess_closing_tail balanced )
    ( string_free balanced )
    ? ( json_parse_ok trimmed_tail ) {
        ^ trimmed_tail
    } {}

    : String escaped ( escape_invalid_chars_in_json_strings trimmed_tail )
    ? ( json_parse_ok escaped ) {
        ( string_free trimmed_tail )
        ^ escaped
    } {}
    ( string_free escaped )

    ( string_free trimmed_tail )
    : String fallback ( string_from `{}` )
    ? > ( nurl_str_len tool_name ) 0 {
        // Tool name is accepted to mirror Hermes' Python helper and to keep
        // the call site explicit; diagnostics will be added when NURL has a
        // shared warning log sink for provider repair paths.
    } {}
    ^ fallback
}
