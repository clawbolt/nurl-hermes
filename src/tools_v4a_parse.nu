// V4A patch parser and line-matching helpers for Hermes NURL.
// Extracted from tools_local.nu for maintainability.

$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/std/hash.nu`
$ `nurl/src/common.nu`

@ v4a_marker_path String line s prefix → String {
    : i plen ( nurl_str_len prefix )
    : i n ( string_len line )
    : String raw ( string_substr line plen - n plen )
    : String trimmed ( string_trim raw )
    ( string_free raw )
    ^ trimmed
}

@ v4a_push_op_ex ( Vec Json ) ops i kind String path String body String move_to String expected_sha256 → v {
    : Json op ( json_obj_new )
    ( json_obj_set op `kind` ( json_int kind ) )
    ( json_obj_set op `path` ( json_str_lit ( string_data path ) ) )
    ( json_obj_set op `body` ( json_str_lit ( string_data body ) ) )
    ? > ( string_len move_to ) 0 {
        ( json_obj_set op `move_to` ( json_str_lit ( string_data move_to ) ) )
    } {}
    ? > ( string_len expected_sha256 ) 0 {
        ( json_obj_set op `expected_sha256` ( json_str_lit ( string_data expected_sha256 ) ) )
    } {}
    ( vec_push [Json] ops op )
}

@ v4a_flush_current ( Vec Json ) ops b has_current i current_kind String current_path String current_body String current_move_to String current_expected → b {
    ? has_current {
        ( v4a_push_op_ex ops current_kind current_path current_body current_move_to current_expected )
        ( string_clear current_path )
        ( string_clear current_body )
        ( string_clear current_move_to )
        ( string_clear current_expected )
        ^ F
    } {}
    ^ has_current
}

@ v4a_parse_into ( Vec Json ) ops s patch_text → String {
    ? == ( nurl_str_len patch_text ) 0 {
        ^ ( patch_error `requires non-empty V4A patch content` )
    } {}

    : String src ( string_from patch_text )
    : ( Vec String ) lines ( string_split src `\n` )
    ( string_free src )
    : i n ( vec_len [String] lines )
    : ~ b has_current F
    : ~ b seen_op F
    : ~ i current_kind 0
    : ~ String current_path ( string_new )
    : ~ String current_body ( string_new )
    : ~ String current_move_to ( string_new )
    : ~ String current_expected ( string_new )
    : ~ i k 0
    : ~ b going T
    ~ & going < k n {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                ? ( string_starts_with line `*** End Patch` ) {
                    = has_current ( v4a_flush_current ops has_current current_kind current_path current_body current_move_to current_expected )
                    = seen_op T
                    = going F
                } {
                    ? ( string_starts_with line `*** Begin Patch` ) {
                    } {
                        ? ( string_starts_with line `*** Move File:` ) {
                            ^ ( patch_error `use Update File plus *** Move to: for V4A moves` )
                        } {
                            ? ( string_starts_with line `*** Update File:` ) {
                                = has_current ( v4a_flush_current ops has_current current_kind current_path current_body current_move_to current_expected )
                                : String p ( v4a_marker_path line `*** Update File:` )
                                ? == ( string_len p ) 0 {
                                    ^ ( patch_error `Update File path is empty` )
                                } {}
                                ( string_push_str current_path ( string_data p ) )
                                ( string_free p )
                                = current_kind 2
                                = has_current T
                                = seen_op T
                            } {
                                ? ( string_starts_with line `*** Add File:` ) {
                                    = has_current ( v4a_flush_current ops has_current current_kind current_path current_body current_move_to current_expected )
                                    : String p2 ( v4a_marker_path line `*** Add File:` )
                                    ? == ( string_len p2 ) 0 {
                                        ^ ( patch_error `Add File path is empty` )
                                    } {}
                                    ( string_push_str current_path ( string_data p2 ) )
                                    ( string_free p2 )
                                    = current_kind 1
                                    = has_current T
                                    = seen_op T
                                } {
                                    ? ( string_starts_with line `*** Delete File:` ) {
                                        = has_current ( v4a_flush_current ops has_current current_kind current_path current_body current_move_to current_expected )
                                        : String p3 ( v4a_marker_path line `*** Delete File:` )
                                        ? == ( string_len p3 ) 0 {
                                            ^ ( patch_error `Delete File path is empty` )
                                        } {}
                                        ( string_push_str current_path ( string_data p3 ) )
                                        ( string_free p3 )
                                        = current_kind 3
                                        = has_current T
                                        = seen_op T
                                    } {
                                        ? has_current {
                                            ? ( string_starts_with line `*** Move to:` ) {
                                                ? == current_kind 2 {} {
                                                    ^ ( patch_error `Move to is only valid after Update File` )
                                                }
                                                : String mp ( v4a_marker_path line `*** Move to:` )
                                                ? == ( string_len mp ) 0 {
                                                    ^ ( patch_error `Move to path is empty` )
                                                } {}
                                                ( string_clear current_move_to )
                                                ( string_push_str current_move_to ( string_data mp ) )
                                                ( string_free mp )
                                            } {
                                                ? ( string_starts_with line `*** Expected SHA256:` ) {
                                                    ? | == current_kind 2 == current_kind 3 {} {
                                                        ^ ( patch_error `Expected SHA256 is only valid after Update File or Delete File` )
                                                    }
                                                    : String ep ( v4a_marker_path line `*** Expected SHA256:` )
                                                    ? == ( string_len ep ) 0 {
                                                        ^ ( patch_error `Expected SHA256 value is empty` )
                                                    } {}
                                                    ( string_clear current_expected )
                                                    ( string_push_str current_expected ( string_data ep ) )
                                                    ( string_free ep )
                                                } {
                                                    ? > ( string_len current_body ) 0 {
                                                        ( string_push_str current_body `\n` )
                                                    } {}
                                                    ( string_push_str current_body ( string_data line ) )
                                                }
                                            }
                                        } {
                                            ? > ( string_len line ) 0 {
                                                ^ ( patch_error `content appeared before a file directive` )
                                            } {}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            F → {}
        }
        = k + k 1
    }
    ? going {
        = has_current ( v4a_flush_current ops has_current current_kind current_path current_body current_move_to current_expected )
    } {}
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    ( vec_free_with [String] lines drop_str )
    ? ! seen_op {
        ^ ( patch_error `did not contain any Add/Update/Delete/Move File operations` )
    } {}
    ^ ( string_new )
}

@ v4a_append_payload_line String dst String line i start → v {
    ? > ( string_len dst ) 0 {
        ( string_push_str dst `\n` )
    } {}
    : i n ( string_len line )
    : String piece ( string_substr line start - n start )
    ( string_push_str dst ( string_data piece ) )
    ( string_free piece )
}

@ patch_check_expected_sha256 s path String contents s expected_sha256 → String {
    ? == ( nurl_str_len expected_sha256 ) 0 {
        ^ ( string_new )
    } {}
    : String actual ( sha256_hex ( string_data contents ) )
    ? != ( nurl_str_eq ( string_data actual ) expected_sha256 ) 0 {
        ( string_free actual )
        ^ ( string_new )
    } {}
    : String msg ( patch_error `stale file ` )
    ( string_push_str msg path )
    ( string_push_str msg `: expected sha256 ` )
    ( string_push_str msg expected_sha256 )
    ( string_push_str msg ` got ` )
    ( string_push_str msg ( string_data actual ) )
    ( string_free actual )
    ^ msg
}

@ mutation_expected_sha_required → b {
    ^ ( env_truthy `HERMES_NURL_REQUIRE_EXPECTED_SHA256` )
}

@ mutation_missing_sha_error s path → String {
    : String msg ( string_from `error: production staleness guard requires expected_sha256 for existing file ` )
    ( string_push_str msg path )
    ( trace_event `tool_blocked` ( string_data msg ) )
    ^ msg
}

@ mutation_expected_sha_guard s path s expected_sha256 → String {
    ? ! ( mutation_expected_sha_required ) {
        ^ ( string_new )
    } {}
    ? > ( nurl_str_len expected_sha256 ) 0 {
        ^ ( string_new )
    } {}
    ? ( file_exists path ) {
        ^ ( mutation_missing_sha_error path )
    } {}
    ^ ( string_new )
}

@ mutation_check_expected_sha s path s expected_sha256 → String {
    : String required ( mutation_expected_sha_guard path expected_sha256 )
    ? > ( string_len required ) 0 {
        ^ required
    } {}
    ( string_free required )
    ? == ( nurl_str_len expected_sha256 ) 0 {
        ^ ( string_new )
    } {}
    ? ! ( file_exists path ) {
        : String msg ( string_from `error: expected_sha256 was provided but target does not exist ` )
        ( string_push_str msg path )
        ^ msg
    } {}
    : !String IoErr rr ( read_file path )
    ?? rr {
        T contents → {
            : String stale ( patch_check_expected_sha256 path contents expected_sha256 )
            ( string_free contents )
            ^ stale
        }
        F e → {
            : IoErr ie # IoErr e
            : String msg2 ( string_from `error: expected_sha256 read_file failed for ` )
            ( string_push_str msg2 path )
            ( string_push_str msg2 `: ` )
            ( string_push_str msg2 ( io_err_msg ie ) )
            ^ msg2
        }
    }
}

@ patch_lf_to_crlf String input → String {
    ^ ( string_replace input `\n` `\r\n` )
}

: | PatchApply {
    PatchOk String
    PatchErr String
}

@ v4a_lines_match_trim_end ( Vec String ) current_lines i start ( Vec String ) search_lines → b {
    : i sn ( vec_len [String] search_lines )
    : ~ i k 0
    ~ < k sn {
        : ?String cur_o ( vec_get [String] current_lines + start k )
        : ?String search_o ( vec_get [String] search_lines k )
        ?? cur_o {
            T cur_line → {
                ?? search_o {
                    T search_line → {
                        : String cur_trimmed ( string_trim_end cur_line )
                        : String search_trimmed ( string_trim_end search_line )
                        : b same ? != ( nurl_str_eq ( string_data cur_trimmed ) ( string_data search_trimmed ) ) 0 T F
                        ( string_free cur_trimmed )
                        ( string_free search_trimmed )
                        ? ! same { ^ F } {}
                    }
                    F → { ^ F }
                }
            }
            F → { ^ F }
        }
        = k + k 1
    }
    ^ T
}

@ v4a_lines_match_trim ( Vec String ) current_lines i start ( Vec String ) search_lines → b {
    : i sn ( vec_len [String] search_lines )
    : ~ i k 0
    ~ < k sn {
        : ?String cur_o ( vec_get [String] current_lines + start k )
        : ?String search_o ( vec_get [String] search_lines k )
        ?? cur_o {
            T cur_line → {
                ?? search_o {
                    T search_line → {
                        : String cur_trimmed ( string_trim cur_line )
                        : String search_trimmed ( string_trim search_line )
                        : b same ? != ( nurl_str_eq ( string_data cur_trimmed ) ( string_data search_trimmed ) ) 0 T F
                        ( string_free cur_trimmed )
                        ( string_free search_trimmed )
                        ? ! same { ^ F } {}
                    }
                    F → { ^ F }
                }
            }
            F → { ^ F }
        }
        = k + k 1
    }
    ^ T
}

@ v4a_push_joined_line String out i emitted String line → i {
    ? > emitted 0 {
        ( string_push_str out `\n` )
    } {}
    ( string_push_str out ( string_data line ) )
    ^ + emitted 1
}

@ v4a_first_nonempty_line_index ( Vec String ) lines → i {
    : i n ( vec_len [String] lines )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                : String trimmed ( string_trim line )
                : i len ( string_len trimmed )
                ( string_free trimmed )
                ? > len 0 {
                    ^ k
                } {}
            }
            F → {}
        }
        = k + k 1
    }
    ^ 0
}

@ v4a_leading_ws String line → String {
    : i n ( string_len line )
    : ~ i k 0
    : ~ b going T
    ~ & going < k n {
        : String ch ( string_substr line k 1 )
        : b is_space ? | != ( nurl_str_eq ( string_data ch ) ` ` ) 0 != ( nurl_str_eq ( string_data ch ) `\t` ) 0 T F
        ( string_free ch )
        ? is_space {
            = k + k 1
        } {
            = going F
        }
    }
    ^ ( string_substr line 0 k )
}

@ v4a_structural_replacement_line String line String current_prefix String search_prefix → String {
    : String trimmed ( string_trim line )
    : i trimmed_len ( string_len trimmed )
    ( string_free trimmed )
    ? == trimmed_len 0 {
        ^ ( string_from ( string_data line ) )
    } {}
    ? != ( nurl_str_eq ( string_data current_prefix ) ( string_data search_prefix ) ) 0 {
        ^ ( string_from ( string_data line ) )
    } {}
    ? & > ( string_len current_prefix ) 0 ( string_starts_with line ( string_data current_prefix ) ) {
        ^ ( string_from ( string_data line ) )
    } {}

    : String out ( string_new )
    ? > ( string_len search_prefix ) 0 {
        ? ( string_starts_with line ( string_data search_prefix ) ) {
            : i n ( string_len line )
            : i plen ( string_len search_prefix )
            : String suffix ( string_substr line plen - n plen )
            ( string_push_str out ( string_data current_prefix ) )
            ( string_push_str out ( string_data suffix ) )
            ( string_free suffix )
            ^ out
        } {}
    } {}

    ? > ( string_len current_prefix ) 0 {
        ( string_push_str out ( string_data current_prefix ) )
        ( string_push_str out ( string_data line ) )
        ^ out
    } {}
    ( string_push_str out ( string_data line ) )
    ^ out
}
