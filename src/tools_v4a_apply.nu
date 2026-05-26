// V4A hunk matching and file apply operations for Hermes NURL.
// Extracted from tools_local.nu for maintainability.

$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/hash.nu`
$ `nurl/src/common.nu`

@ v4a_apply_update_hunk_trim_end_fuzzy String current String search String replacement s path → PatchApply {
    : ( Vec String ) current_lines ( string_split current `\n` )
    : ( Vec String ) search_lines ( string_split search `\n` )
    : ( Vec String ) replacement_lines ( string_split replacement `\n` )
    : i cn ( vec_len [String] current_lines )
    : i sn ( vec_len [String] search_lines )
    ? | <= sn 0 < cn sn {
        : String msg0 ( patch_error `trimmed hunk not found in ` )
        ( string_push_str msg0 path )
        ^ @ PatchApply { PatchErr msg0 }
    } {}

    : ~ i count 0
    : ~ i found 0
    : ~ i start 0
    ~ <= + start sn cn {
        ? ( v4a_lines_match_trim_end current_lines start search_lines ) {
            = count + count 1
            = found start
        } {}
        = start + start 1
    }

    ? == count 0 {
        : String msg ( patch_error `trimmed hunk not found in ` )
        ( string_push_str msg path )
        ^ @ PatchApply { PatchErr msg }
    } {}
    ? > count 1 {
        : String msg2 ( patch_error `trimmed hunk is ambiguous in ` )
        ( string_push_str msg2 path )
        ( string_push_str msg2 ` (` )
        ( string_push_int msg2 count )
        ( string_push_str msg2 ` matches)` )
        ^ @ PatchApply { PatchErr msg2 }
    } {}

    : String out ( string_with_cap ( string_len current ) )
    : ~ i emitted 0
    : ~ i k 0
    ~ < k found {
        : ?String e ( vec_get [String] current_lines k )
        ?? e {
            T line → { = emitted ( v4a_push_joined_line out emitted line ) }
            F → {}
        }
        = k + k 1
    }
    : i rn ( vec_len [String] replacement_lines )
    : ~ i r 0
    ~ < r rn {
        : ?String e2 ( vec_get [String] replacement_lines r )
        ?? e2 {
            T line2 → { = emitted ( v4a_push_joined_line out emitted line2 ) }
            F → {}
        }
        = r + r 1
    }
    = k + found sn
    ~ < k cn {
        : ?String e3 ( vec_get [String] current_lines k )
        ?? e3 {
            T line3 → { = emitted ( v4a_push_joined_line out emitted line3 ) }
            F → {}
        }
        = k + k 1
    }
    ^ @ PatchApply { PatchOk out }
}

@ v4a_apply_update_hunk_structural_fuzzy String current String search String replacement s path → PatchApply {
    : ( Vec String ) current_lines ( string_split current `\n` )
    : ( Vec String ) search_lines ( string_split search `\n` )
    : ( Vec String ) replacement_lines ( string_split replacement `\n` )
    : i cn ( vec_len [String] current_lines )
    : i sn ( vec_len [String] search_lines )
    ? | <= sn 0 < cn sn {
        : String msg0 ( patch_error `structural hunk not found in ` )
        ( string_push_str msg0 path )
        ^ @ PatchApply { PatchErr msg0 }
    } {}

    : ~ i count 0
    : ~ i found 0
    : ~ i start 0
    ~ <= + start sn cn {
        ? ( v4a_lines_match_trim current_lines start search_lines ) {
            = count + count 1
            = found start
        } {}
        = start + start 1
    }

    ? == count 0 {
        : String msg ( patch_error `structural hunk not found in ` )
        ( string_push_str msg path )
        ^ @ PatchApply { PatchErr msg }
    } {}
    ? > count 1 {
        : String msg2 ( patch_error `structural hunk is ambiguous in ` )
        ( string_push_str msg2 path )
        ( string_push_str msg2 ` (` )
        ( string_push_int msg2 count )
        ( string_push_str msg2 ` matches)` )
        ^ @ PatchApply { PatchErr msg2 }
    } {}

    : i base_idx ( v4a_first_nonempty_line_index search_lines )
    : String current_prefix ( string_new )
    : String search_prefix ( string_new )
    : ?String cur_base_o ( vec_get [String] current_lines + found base_idx )
    ?? cur_base_o {
        T cur_base → {
            : String p ( v4a_leading_ws cur_base )
            ( string_push_str current_prefix ( string_data p ) )
            ( string_free p )
        }
        F → {}
    }
    : ?String search_base_o ( vec_get [String] search_lines base_idx )
    ?? search_base_o {
        T search_base → {
            : String p2 ( v4a_leading_ws search_base )
            ( string_push_str search_prefix ( string_data p2 ) )
            ( string_free p2 )
        }
        F → {}
    }

    : String out ( string_with_cap ( string_len current ) )
    : ~ i emitted 0
    : ~ i k 0
    ~ < k found {
        : ?String e ( vec_get [String] current_lines k )
        ?? e {
            T line → { = emitted ( v4a_push_joined_line out emitted line ) }
            F → {}
        }
        = k + k 1
    }
    : i rn ( vec_len [String] replacement_lines )
    : ~ i r 0
    ~ < r rn {
        : ?String e2 ( vec_get [String] replacement_lines r )
        ?? e2 {
            T line2 → {
                : String line_current_prefix ( string_from ( string_data current_prefix ) )
                : String line_search_prefix ( string_from ( string_data search_prefix ) )
                ? < r sn {
                    ( string_clear line_current_prefix )
                    ( string_clear line_search_prefix )
                    : ?String cur_line_o ( vec_get [String] current_lines + found r )
                    ?? cur_line_o {
                        T cur_line → {
                            : String cp ( v4a_leading_ws cur_line )
                            ( string_push_str line_current_prefix ( string_data cp ) )
                            ( string_free cp )
                        }
                        F → {}
                    }
                    : ?String search_line_o ( vec_get [String] search_lines r )
                    ?? search_line_o {
                        T search_line → {
                            : String sp ( v4a_leading_ws search_line )
                            ( string_push_str line_search_prefix ( string_data sp ) )
                            ( string_free sp )
                        }
                        F → {}
                    }
                } {}
                : String fixed ( v4a_structural_replacement_line line2 line_current_prefix line_search_prefix )
                = emitted ( v4a_push_joined_line out emitted fixed )
                ( string_free fixed )
                ( string_free line_current_prefix )
                ( string_free line_search_prefix )
            }
            F → {}
        }
        = r + r 1
    }
    = k + found sn
    ~ < k cn {
        : ?String e3 ( vec_get [String] current_lines k )
        ?? e3 {
            T line3 → { = emitted ( v4a_push_joined_line out emitted line3 ) }
            F → {}
        }
        = k + k 1
    }
    ( string_free current_prefix )
    ( string_free search_prefix )
    ^ @ PatchApply { PatchOk out }
}

@ v4a_apply_update_hunk String current String search String replacement s path → PatchApply {
    ? == ( string_len search ) 0 {
        : String msg ( patch_error `addition-only update hunks need surrounding context in this NURL core port` )
        ^ @ PatchApply { PatchErr msg }
    } {}
    : i count ( string_count_occurrences current ( string_data search ) )
    ? == count 0 {
        : String crlf_search ( patch_lf_to_crlf search )
        : i crlf_count ( string_count_occurrences current ( string_data crlf_search ) )
        ? == crlf_count 1 {
            : String crlf_replacement ( patch_lf_to_crlf replacement )
            : String patched_crlf ( string_replace current ( string_data crlf_search ) ( string_data crlf_replacement ) )
            ( string_free crlf_search )
            ( string_free crlf_replacement )
            ^ @ PatchApply { PatchOk patched_crlf }
        } {}
        ? > crlf_count 1 {
            : String msg2 ( patch_error `update hunk is ambiguous in ` )
            ( string_push_str msg2 path )
            ( string_push_str msg2 ` (` )
            ( string_push_int msg2 crlf_count )
            ( string_push_str msg2 ` CRLF-normalized matches)` )
            ( string_free crlf_search )
            ^ @ PatchApply { PatchErr msg2 }
        } {}
        ( string_free crlf_search )
        : PatchApply fuzzy ( v4a_apply_update_hunk_trim_end_fuzzy current search replacement path )
        ?? fuzzy {
            PatchOk patched_fuzzy → {
                ^ @ PatchApply { PatchOk patched_fuzzy }
            }
            PatchErr fuzzy_err → {
                ? ( string_contains fuzzy_err `ambiguous` ) {
                    ^ @ PatchApply { PatchErr fuzzy_err }
                } {}
            }
        }
        : PatchApply structural ( v4a_apply_update_hunk_structural_fuzzy current search replacement path )
        ?? structural {
            PatchOk patched_structural → {
                ^ @ PatchApply { PatchOk patched_structural }
            }
            PatchErr structural_err → {
                ? ( string_contains structural_err `ambiguous` ) {
                    ^ @ PatchApply { PatchErr structural_err }
                } {}
            }
        }
        : String msg ( patch_error `update hunk not found in ` )
        ( string_push_str msg path )
        ^ @ PatchApply { PatchErr msg }
    } {}
    ? > count 1 {
        : String msg ( patch_error `update hunk is ambiguous in ` )
        ( string_push_str msg path )
        ( string_push_str msg ` (` )
        ( string_push_int msg count )
        ( string_push_str msg ` matches)` )
        ^ @ PatchApply { PatchErr msg }
    } {}
    : String patched ( string_replace current ( string_data search ) ( string_data replacement ) )
    ^ @ PatchApply { PatchOk patched }
}

@ v4a_apply_update_file s path s body s move_to s expected_sha256 → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Update File path is empty` )
    } {}
    ? & > ( nurl_str_len move_to ) 0 ( file_exists move_to ) {
        : String msg0 ( patch_error `Move target already exists: ` )
        ( string_push_str msg0 move_to )
        ^ msg0
    } {}
    : !String IoErr rr ( read_file path )
    ?? rr {
        T original → {
            : String stale ( patch_check_expected_sha256 path original expected_sha256 )
            ? > ( string_len stale ) 0 {
                ( string_free original )
                ^ stale
            } {}
            ( string_free stale )
            : ~ String current ( string_from ( string_data original ) )
            ( string_free original )
            : String body_s ( string_from body )
            : ( Vec String ) lines ( string_split body_s `\n` )
            ( string_free body_s )
            : ~ String search ( string_new )
            : ~ String replacement ( string_new )
            : ~ b hunk_changed F
            : ~ i applied 0
            : i n ( vec_len [String] lines )
            : ~ i k 0
            ~ < k n {
                : ?String e ( vec_get [String] lines k )
                ?? e {
                    T line → {
                        ? ( string_starts_with line `@@` ) {
                            ? | > ( string_len search ) 0 > ( string_len replacement ) 0 {
                                ? hunk_changed {
                                    : PatchApply hr ( v4a_apply_update_hunk current search replacement path )
                                    ?? hr {
                                        PatchOk patched → {
                                            = current patched
                                            = applied + applied 1
                                        }
                                        PatchErr err → {
                                            ^ err
                                        }
                                    }
                                } {}
                            } {}
                            ( string_clear search )
                            ( string_clear replacement )
                            = hunk_changed F
                        } {
                            ? ( string_starts_with line `\` ) {
                            } {
                                ? ( string_starts_with line `+` ) {
                                    ( v4a_append_payload_line replacement line 1 )
                                    = hunk_changed T
                                } {
                                    ? ( string_starts_with line `-` ) {
                                        ( v4a_append_payload_line search line 1 )
                                        = hunk_changed T
                                    } {
                                        ? ( string_starts_with line ` ` ) {
                                            ( v4a_append_payload_line search line 1 )
                                            ( v4a_append_payload_line replacement line 1 )
                                        } {
                                            ( v4a_append_payload_line search line 0 )
                                            ( v4a_append_payload_line replacement line 0 )
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
            ? | > ( string_len search ) 0 > ( string_len replacement ) 0 {
                ? hunk_changed {
                    : PatchApply hr2 ( v4a_apply_update_hunk current search replacement path )
                    ?? hr2 {
                        PatchOk patched2 → {
                            = current patched2
                            = applied + applied 1
                        }
                        PatchErr err2 → {
                            ^ err2
                        }
                    }
                } {}
            } {}
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            ( vec_free_with [String] lines drop_str )
            ? & <= applied 0 == ( nurl_str_len move_to ) 0 {
                ^ ( patch_error `Update File had no changed hunks` )
            } {}
            : s write_path ? > ( nurl_str_len move_to ) 0 move_to path
            : !v IoErr wr ( write_file write_path ( string_data current ) )
            ?? wr {
                T _ → {
                    ? > ( nurl_str_len move_to ) 0 {
                        : !v IoErr dr ( file_delete path )
                        ?? dr {
                            T _ → {}
                            F e → {
                                : IoErr ie # IoErr e
                                : String dmsg ( patch_error `move wrote target but could not delete source ` )
                                ( string_push_str dmsg path )
                                ( string_push_str dmsg `: ` )
                                ( string_push_str dmsg ( io_err_msg ie ) )
                                ^ dmsg
                            }
                        }
                    } {}
                    : String msg ? > ( nurl_str_len move_to ) 0 ( string_from `moved ` ) ( string_from `updated ` )
                    ( string_push_str msg path )
                    ? > ( nurl_str_len move_to ) 0 {
                        ( string_push_str msg ` to ` )
                        ( string_push_str msg move_to )
                    } {}
                    ( string_push_str msg ` (` )
                    ( string_push_int msg applied )
                    ( string_push_str msg ` hunk` )
                    ? != applied 1 { ( string_push_str msg `s` ) } {}
                    ( string_push_str msg `)` )
                    ^ msg
                }
                F e → {
                    : IoErr ie # IoErr e
                    : String msg ( patch_error `write_file failed for ` )
                    ( string_push_str msg write_path )
                    ( string_push_str msg `: ` )
                    ( string_push_str msg ( io_err_msg ie ) )
                    ^ msg
                }
            }
        }
        F e → {
            : IoErr ie # IoErr e
            : String msg ( patch_error `read_file failed for ` )
            ( string_push_str msg path )
            ( string_push_str msg `: ` )
            ( string_push_str msg ( io_err_msg ie ) )
            ^ msg
        }
    }
}

@ v4a_apply_add_file s path s body → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Add File path is empty` )
    } {}
    ? ( file_exists path ) {
        : String msg ( patch_error `Add File target already exists: ` )
        ( string_push_str msg path )
        ^ msg
    } {}
    : String body_s ( string_from body )
    : ( Vec String ) lines ( string_split body_s `\n` )
    ( string_free body_s )
    : String content ( string_new )
    : ~ i added 0
    : i n ( vec_len [String] lines )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                ? ( string_starts_with line `\` ) {
                } {
                    ? ( string_starts_with line `+` ) {
                        ? > added 0 { ( string_push_str content `\n` ) } {}
                        : i ln ( string_len line )
                        : String piece ( string_substr line 1 - ln 1 )
                        ( string_push_str content ( string_data piece ) )
                        ( string_free piece )
                        = added + added 1
                    } {
                        ? > ( string_len line ) 0 {
                            ^ ( patch_error `Add File content lines must start with '+'` )
                        } {}
                    }
                }
            }
            F → {}
        }
        = k + k 1
    }
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    ( vec_free_with [String] lines drop_str )
    : !v IoErr wr ( write_file path ( string_data content ) )
    ?? wr {
        T _ → {
            : String msg ( string_from `added ` )
            ( string_push_str msg path )
            ^ msg
        }
        F e → {
            : IoErr ie # IoErr e
            : String msg ( patch_error `write_file failed for ` )
            ( string_push_str msg path )
            ( string_push_str msg `: ` )
            ( string_push_str msg ( io_err_msg ie ) )
            ^ msg
        }
    }
}

@ v4a_apply_delete_file s path s expected_sha256 → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Delete File path is empty` )
    } {}
    ? ! ( file_exists path ) {
        : String msg ( patch_error `Delete File target not found: ` )
        ( string_push_str msg path )
        ^ msg
    } {}
    ? > ( nurl_str_len expected_sha256 ) 0 {
        : !String IoErr rr ( read_file path )
        ?? rr {
            T contents → {
                : String stale ( patch_check_expected_sha256 path contents expected_sha256 )
                ( string_free contents )
                ? > ( string_len stale ) 0 {
                    ^ stale
                } {}
                ( string_free stale )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg0 ( patch_error `read_file failed for ` )
                ( string_push_str msg0 path )
                ( string_push_str msg0 `: ` )
                ( string_push_str msg0 ( io_err_msg ie ) )
                ^ msg0
            }
        }
    } {}
    : !v IoErr dr ( file_delete path )
    ?? dr {
        T _ → {
            : String msg ( string_from `deleted ` )
            ( string_push_str msg path )
            ^ msg
        }
        F e → {
            : IoErr ie # IoErr e
            : String msg ( patch_error `delete failed for ` )
            ( string_push_str msg path )
            ( string_push_str msg `: ` )
            ( string_push_str msg ( io_err_msg ie ) )
            ^ msg
        }
    }
}
