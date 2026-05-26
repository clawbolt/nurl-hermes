// V4A patch staging, conflict detection, commit, and preview for Hermes NURL.
// Extracted from tools_local.nu for maintainability.

$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/hash.nu`
$ `nurl/src/common.nu`

@ v4a_stage_push ( Vec Json ) staged i kind s path String content s move_to i applied → v {
    : Json op ( json_obj_new )
    ( json_obj_set op `kind` ( json_int kind ) )
    ( json_obj_set op `path` ( json_str_lit path ) )
    ( json_obj_set op `content` ( json_str_lit ( string_data content ) ) )
    ( json_obj_set op `applied` ( json_int applied ) )
    ? > ( nurl_str_len move_to ) 0 {
        ( json_obj_set op `move_to` ( json_str_lit move_to ) )
    } {}
    ( vec_push [Json] staged op )
}

@ v4a_stage_add_file ( Vec Json ) staged s path s body → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Add File path is empty` )
    } {}
    : String guard ( mutation_path_guard path )
    ? > ( string_len guard ) 0 {
        ^ guard
    } {}
    ( string_free guard )
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
    ( v4a_stage_push staged 1 path content `` 0 )
    ( string_free content )
    ^ ( string_new )
}

@ v4a_stage_update_file ( Vec Json ) staged s path s body s move_to s expected_sha256 → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Update File path is empty` )
    } {}
    : String guard ( mutation_path_guard path )
    ? > ( string_len guard ) 0 {
        ^ guard
    } {}
    ( string_free guard )
    ? > ( nurl_str_len move_to ) 0 {
        : String move_guard ( mutation_path_guard move_to )
        ? > ( string_len move_guard ) 0 {
            ^ move_guard
        } {}
        ( string_free move_guard )
    } {}
    : String sha_guard ( mutation_expected_sha_guard path expected_sha256 )
    ? > ( string_len sha_guard ) 0 {
        ^ sha_guard
    } {}
    ( string_free sha_guard )
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
            ( v4a_stage_push staged 2 path current move_to applied )
            ( string_free current )
            ^ ( string_new )
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

@ v4a_stage_delete_file ( Vec Json ) staged s path s expected_sha256 → String {
    ? == ( nurl_str_len path ) 0 {
        ^ ( patch_error `Delete File path is empty` )
    } {}
    : String guard ( mutation_path_guard path )
    ? > ( string_len guard ) 0 {
        ^ guard
    } {}
    ( string_free guard )
    : String sha_guard ( mutation_expected_sha_guard path expected_sha256 )
    ? > ( string_len sha_guard ) 0 {
        ^ sha_guard
    } {}
    ( string_free sha_guard )
    ? ! ( file_exists path ) {
        : String msg ( patch_error `Delete File target not found: ` )
        ( string_push_str msg path )
        ^ msg
    } {}
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
    : String empty ( string_new )
    ( v4a_stage_push staged 3 path empty `` 0 )
    ( string_free empty )
    ^ ( string_new )
}

@ v4a_stage_ops ( Vec Json ) ops ( Vec Json ) staged → String {
    : i n ( vec_len [Json] ops )
    : ~ i k 0
    ~ < k n {
        : ?Json e ( vec_get [Json] ops k )
        ?? e {
            T op → {
                : ?Json kind_j ( json_obj_get op `kind` )
                : ?Json path_j ( json_obj_get op `path` )
                : ?Json body_j ( json_obj_get op `body` )
                : ?Json move_j ( json_obj_get op `move_to` )
                : ?Json expected_j ( json_obj_get op `expected_sha256` )
                : i kind ?? kind_j {
                    T kj → {
                        : ?i got ( json_num_as_i kj )
                        ?? got { T v → v F → 0 }
                    }
                    F → 0
                }
                : s path ?? path_j { T pj → ( json_str_data pj ) F → `` }
                : s body ?? body_j { T bj → ( json_str_data bj ) F → `` }
                : s move_to ?? move_j { T mj → ( json_str_data mj ) F → `` }
                : s expected_sha256 ?? expected_j { T ej → ( json_str_data ej ) F → `` }
                : String result ? == kind 1 {
                    ( v4a_stage_add_file staged path body )
                } {
                    ? == kind 2 {
                        ( v4a_stage_update_file staged path body move_to expected_sha256 )
                    } {
                        ? == kind 3 {
                            ( v4a_stage_delete_file staged path expected_sha256 )
                        } {
                            ( patch_error `unknown V4A operation kind` )
                        }
                    }
                }
                ? ( string_starts_with result `error:` ) {
                    ^ result
                } {}
                ( string_free result )
            }
            F → {}
        }
        = k + k 1
    }
    ^ ( string_new )
}

@ v4a_staged_kind Json op → i {
    : ?Json kind_j ( json_obj_get op `kind` )
    ?? kind_j {
        T kj → {
            : ?i got ( json_num_as_i kj )
            ?? got {
                T v → { ^ v }
                F → {}
            }
        }
        F → {}
    }
    ^ 0
}

@ v4a_staged_path Json op → s {
    : ?Json path_j ( json_obj_get op `path` )
    ?? path_j {
        T pj → { ^ ( json_str_data pj ) }
        F → {}
    }
    ^ ``
}

@ v4a_staged_move_to Json op → s {
    : ?Json move_j ( json_obj_get op `move_to` )
    ?? move_j {
        T mj → { ^ ( json_str_data mj ) }
        F → {}
    }
    ^ ``
}

@ v4a_staged_write_path Json op → s {
    : i kind ( v4a_staged_kind op )
    : s move_to ( v4a_staged_move_to op )
    ? & == kind 2 > ( nurl_str_len move_to ) 0 {
        ^ move_to
    } {}
    ^ ( v4a_staged_path op )
}

@ v4a_nonempty_path_eq s left s right → b {
    ? == ( nurl_str_len left ) 0 { ^ F } {}
    ? == ( nurl_str_len right ) 0 { ^ F } {}
    ^ ? != ( nurl_str_eq left right ) 0 T F
}

@ v4a_conflict_message s path → String {
    : String msg ( patch_error `conflicting V4A operations touch ` )
    ( string_push_str msg path )
    ^ msg
}

@ v4a_validate_staged_conflicts ( Vec Json ) staged → String {
    : i n ( vec_len [Json] staged )
    : ~ i i 0
    ~ < i n {
        : ?Json current_o ( vec_get [Json] staged i )
        ?? current_o {
            T current → {
                : s cur_source ( v4a_staged_path current )
                : s cur_write ( v4a_staged_write_path current )
                : ~ i j 0
                ~ < j i {
                    : ?Json prior_o ( vec_get [Json] staged j )
                    ?? prior_o {
                        T prior → {
                            : s prior_source ( v4a_staged_path prior )
                            : s prior_write ( v4a_staged_write_path prior )
                            ? ( v4a_nonempty_path_eq cur_source prior_source ) { ^ ( v4a_conflict_message cur_source ) } {}
                            ? ( v4a_nonempty_path_eq cur_source prior_write ) { ^ ( v4a_conflict_message cur_source ) } {}
                            ? ( v4a_nonempty_path_eq cur_write prior_source ) { ^ ( v4a_conflict_message cur_write ) } {}
                            ? ( v4a_nonempty_path_eq cur_write prior_write ) { ^ ( v4a_conflict_message cur_write ) } {}
                        }
                        F → {}
                    }
                    = j + j 1
                }
            }
            F → {}
        }
        = i + i 1
    }
    ^ ( string_new )
}

@ v4a_commit_staged_patch ( Vec Json ) staged → String {
    : String summary ( string_from `applied V4A patch:\n` )
    : i n ( vec_len [Json] staged )
    : ~ i k 0
    ~ < k n {
        : ?Json e ( vec_get [Json] staged k )
        ?? e {
            T op → {
                : ?Json kind_j ( json_obj_get op `kind` )
                : ?Json path_j ( json_obj_get op `path` )
                : ?Json content_j ( json_obj_get op `content` )
                : ?Json move_j ( json_obj_get op `move_to` )
                : ?Json applied_j ( json_obj_get op `applied` )
                : i kind ?? kind_j {
                    T kj → {
                        : ?i got ( json_num_as_i kj )
                        ?? got { T v → v F → 0 }
                    }
                    F → 0
                }
                : s path ?? path_j { T pj → ( json_str_data pj ) F → `` }
                : s content ?? content_j { T cj → ( json_str_data cj ) F → `` }
                : s move_to ?? move_j { T mj → ( json_str_data mj ) F → `` }
                : i applied ?? applied_j {
                    T aj → {
                        : ?i got2 ( json_num_as_i aj )
                        ?? got2 { T v2 → v2 F → 0 }
                    }
                    F → 0
                }
                ? == kind 1 {
                    : !v IoErr wr ( write_file path content )
                    ?? wr {
                        T _ → {
                            ( string_push_str summary `- added ` )
                            ( string_push_str summary path )
                            ( string_push_str summary `\n` )
                        }
                        F err → {
                            : IoErr ie # IoErr err
                            : String msg ( patch_error `write_file failed for ` )
                            ( string_push_str msg path )
                            ( string_push_str msg `: ` )
                            ( string_push_str msg ( io_err_msg ie ) )
                            ^ msg
                        }
                    }
                } {
                    ? == kind 2 {
                        : s write_path ? > ( nurl_str_len move_to ) 0 move_to path
                        : !v IoErr wr2 ( write_file write_path content )
                        ?? wr2 {
                            T _ → {
                                ? > ( nurl_str_len move_to ) 0 {
                                    : !v IoErr dr ( file_delete path )
                                    ?? dr {
                                        T _ → {}
                                        F derr → {
                                            : IoErr die # IoErr derr
                                            : String dmsg ( patch_error `move wrote target but could not delete source ` )
                                            ( string_push_str dmsg path )
                                            ( string_push_str dmsg `: ` )
                                            ( string_push_str dmsg ( io_err_msg die ) )
                                            ^ dmsg
                                        }
                                    }
                                    ( string_push_str summary `- moved ` )
                                    ( string_push_str summary path )
                                    ( string_push_str summary ` to ` )
                                    ( string_push_str summary move_to )
                                } {
                                    ( string_push_str summary `- updated ` )
                                    ( string_push_str summary path )
                                }
                                ( string_push_str summary ` (` )
                                ( string_push_int summary applied )
                                ( string_push_str summary ` hunk` )
                                ? != applied 1 { ( string_push_str summary `s` ) } {}
                                ( string_push_str summary `)\n` )
                            }
                            F err2 → {
                                : IoErr ie2 # IoErr err2
                                : String msg2 ( patch_error `write_file failed for ` )
                                ( string_push_str msg2 write_path )
                                ( string_push_str msg2 `: ` )
                                ( string_push_str msg2 ( io_err_msg ie2 ) )
                                ^ msg2
                            }
                        }
                    } {
                        ? == kind 3 {
                            : !v IoErr dr2 ( file_delete path )
                            ?? dr2 {
                                T _ → {
                                    ( string_push_str summary `- deleted ` )
                                    ( string_push_str summary path )
                                    ( string_push_str summary `\n` )
                                }
                                F derr2 → {
                                    : IoErr die2 # IoErr derr2
                                    : String msg3 ( patch_error `delete failed for ` )
                                    ( string_push_str msg3 path )
                                    ( string_push_str msg3 `: ` )
                                    ( string_push_str msg3 ( io_err_msg die2 ) )
                                    ^ msg3
                                }
                            }
                        } {
                            ^ ( patch_error `unknown staged V4A operation kind` )
                        }
                    }
                }
            }
            F → {}
        }
        = k + k 1
    }
    ^ summary
}

@ v4a_preview_staged_patch ( Vec Json ) staged → String {
    : String summary ( string_from `validated V4A patch (dry run):\n` )
    : i n ( vec_len [Json] staged )
    : ~ i k 0
    ~ < k n {
        : ?Json e ( vec_get [Json] staged k )
        ?? e {
            T op → {
                : ?Json kind_j ( json_obj_get op `kind` )
                : ?Json path_j ( json_obj_get op `path` )
                : ?Json move_j ( json_obj_get op `move_to` )
                : ?Json applied_j ( json_obj_get op `applied` )
                : i kind ?? kind_j {
                    T kj → {
                        : ?i got ( json_num_as_i kj )
                        ?? got { T v → v F → 0 }
                    }
                    F → 0
                }
                : s path ?? path_j { T pj → ( json_str_data pj ) F → `` }
                : s move_to ?? move_j { T mj → ( json_str_data mj ) F → `` }
                : i applied ?? applied_j {
                    T aj → {
                        : ?i got2 ( json_num_as_i aj )
                        ?? got2 { T v2 → v2 F → 0 }
                    }
                    F → 0
                }
                ? == kind 1 {
                    ( string_push_str summary `- would add ` )
                    ( string_push_str summary path )
                    ( string_push_str summary `\n` )
                } {
                    ? == kind 2 {
                        ? > ( nurl_str_len move_to ) 0 {
                            ( string_push_str summary `- would move ` )
                            ( string_push_str summary path )
                            ( string_push_str summary ` to ` )
                            ( string_push_str summary move_to )
                        } {
                            ( string_push_str summary `- would update ` )
                            ( string_push_str summary path )
                        }
                        ( string_push_str summary ` (` )
                        ( string_push_int summary applied )
                        ( string_push_str summary ` hunk` )
                        ? != applied 1 { ( string_push_str summary `s` ) } {}
                        ( string_push_str summary `)\n` )
                    } {
                        ? == kind 3 {
                            ( string_push_str summary `- would delete ` )
                            ( string_push_str summary path )
                            ( string_push_str summary `\n` )
                        } {
                            ^ ( patch_error `unknown staged V4A operation kind` )
                        }
                    }
                }
            }
            F → {}
        }
        = k + k 1
    }
    ^ summary
}

@ apply_v4a_patch s patch_text b dry_run → String {
    : ( Vec Json ) ops ( vec_new [Json] )
    : String parse_err ( v4a_parse_into ops patch_text )
    ? > ( string_len parse_err ) 0 {
        ^ parse_err
    } {}
    : i n ( vec_len [Json] ops )
    ? <= n 0 {
        ^ ( patch_error `did not contain any operations` )
    } {}
    : ( Vec Json ) staged ( vec_new [Json] )
    : String stage_err ( v4a_stage_ops ops staged )
    ? > ( string_len stage_err ) 0 {
        ^ stage_err
    } {}
    : String conflict_err ( v4a_validate_staged_conflicts staged )
    ? > ( string_len conflict_err ) 0 {
        ^ conflict_err
    } {}
    : String summary ? dry_run {
        ( v4a_preview_staged_patch staged )
    } {
        ( v4a_commit_staged_patch staged )
    }
    : ( @ v Json ) drop_json \ Json j → v { ( json_free j ) }
    ( vec_free_with [Json] ops drop_json )
    ( vec_free_with [Json] staged drop_json )
    ^ summary
}
