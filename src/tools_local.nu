// Shared local tool registry and dispatch for Hermes NURL.

$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/mcp.nu`
$ `stdlib/std/process.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/hash.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/harness.nu`
$ `nurl/src/skills.nu`
$ `nurl/src/tools_http.nu`

@ path_content_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json path_prop ( json_obj_new )
    ( json_obj_set path_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set path_prop `description` ( json_str_lit `Filesystem path to write` ) )

    : Json content_prop ( json_obj_new )
    ( json_obj_set content_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set content_prop `description` ( json_str_lit `UTF-8 content` ) )

    : Json expected_prop ( json_obj_new )
    ( json_obj_set expected_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set expected_prop `description` ( json_str_lit `Optional current file SHA-256 hex digest. When set, the write is rejected if the existing file content has changed since it was read.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `path` path_prop )
    ( json_obj_set props `content` content_prop )
    ( json_obj_set props `expected_sha256` expected_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `path` ) )
    ( json_arr_push req ( json_str_lit `content` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ read_file_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json path_prop ( json_obj_new )
    ( json_obj_set path_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set path_prop `description` ( json_str_lit `Filesystem path of a UTF-8 text file to read. Binary media such as images, PDFs, archives, and audio/video files are refused; use file_info or a workflow-specific vision/export helper instead.` ) )

    : Json offset_prop ( json_obj_new )
    ( json_obj_set offset_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set offset_prop `description` ( json_str_lit `Number of lines to skip before returning content. Defaults to 0.` ) )

    : Json limit_prop ( json_obj_new )
    ( json_obj_set limit_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set limit_prop `description` ( json_str_lit `Maximum lines to return. Omit or set <= 0 to return all remaining lines.` ) )

    : Json line_numbers_prop ( json_obj_new )
    ( json_obj_set line_numbers_prop `type` ( json_str_lit `boolean` ) )
    ( json_obj_set line_numbers_prop `description` ( json_str_lit `When true, prefix each returned line with its 1-based line number.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `path` path_prop )
    ( json_obj_set props `offset` offset_prop )
    ( json_obj_set props `limit` limit_prop )
    ( json_obj_set props `line_numbers` line_numbers_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `path` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ search_files_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json pattern_prop ( json_obj_new )
    ( json_obj_set pattern_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set pattern_prop `description` ( json_str_lit `Text or regex pattern to search for` ) )

    : Json path_prop ( json_obj_new )
    ( json_obj_set path_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set path_prop `description` ( json_str_lit `File or directory path to search. Defaults to current directory.` ) )

    : Json target_prop ( json_obj_new )
    ( json_obj_set target_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set target_prop `description` ( json_str_lit `content searches inside files; files searches file paths by glob. Defaults to content.` ) )

    : Json limit_prop ( json_obj_new )
    ( json_obj_set limit_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set limit_prop `description` ( json_str_lit `Maximum lines to return. Defaults to 50.` ) )

    : Json offset_prop ( json_obj_new )
    ( json_obj_set offset_prop `type` ( json_str_lit `integer` ) )
    ( json_obj_set offset_prop `description` ( json_str_lit `Number of result lines to skip. Defaults to 0.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `pattern` pattern_prop )
    ( json_obj_set props `path` path_prop )
    ( json_obj_set props `target` target_prop )
    ( json_obj_set props `limit` limit_prop )
    ( json_obj_set props `offset` offset_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `pattern` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ file_info_schema → Json {
    ^ ( one_string_schema `path` `File or directory path to inspect` )
}

@ patch_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json mode_prop ( json_obj_new )
    ( json_obj_set mode_prop `type` ( json_str_lit `string` ) )
    : Json mode_enum ( json_arr_new )
    ( json_arr_push mode_enum ( json_str_lit `replace` ) )
    ( json_arr_push mode_enum ( json_str_lit `patch` ) )
    ( json_obj_set mode_prop `enum` mode_enum )
    ( json_obj_set mode_prop `description` ( json_str_lit `Edit mode. 'replace' edits one file by exact text replacement. 'patch' applies V4A Add/Update/Delete/Move multi-file patches.` ) )
    ( json_obj_set mode_prop `default` ( json_str_lit `replace` ) )

    : Json path_prop ( json_obj_new )
    ( json_obj_set path_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set path_prop `description` ( json_str_lit `File path to edit` ) )

    : Json old_prop ( json_obj_new )
    ( json_obj_set old_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set old_prop `description` ( json_str_lit `Exact text to find` ) )

    : Json new_prop ( json_obj_new )
    ( json_obj_set new_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set new_prop `description` ( json_str_lit `Replacement text` ) )

    : Json all_prop ( json_obj_new )
    ( json_obj_set all_prop `type` ( json_str_lit `boolean` ) )
    ( json_obj_set all_prop `description` ( json_str_lit `Replace all occurrences instead of requiring a unique match` ) )

    : Json dry_prop ( json_obj_new )
    ( json_obj_set dry_prop `type` ( json_str_lit `boolean` ) )
    ( json_obj_set dry_prop `description` ( json_str_lit `Validate the edit and report what would change without writing or deleting files.` ) )

    : Json expected_prop ( json_obj_new )
    ( json_obj_set expected_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set expected_prop `description` ( json_str_lit `Optional current file SHA-256 hex digest. When set, the patch is rejected if the file content has changed since it was read.` ) )

    : Json patch_prop ( json_obj_new )
    ( json_obj_set patch_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set patch_prop `description` ( json_str_lit `Required when mode='patch'. V4A patch content using *** Begin Patch, *** Update/Add/Delete File, optional *** Move to: and *** Expected SHA256: directives, hunks with context/-/+ lines, and *** End Patch.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `mode` mode_prop )
    ( json_obj_set props `path` path_prop )
    ( json_obj_set props `old_string` old_prop )
    ( json_obj_set props `new_string` new_prop )
    ( json_obj_set props `replace_all` all_prop )
    ( json_obj_set props `dry_run` dry_prop )
    ( json_obj_set props `expected_sha256` expected_prop )
    ( json_obj_set props `patch` patch_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `mode` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ harness_record_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )

    : Json action_prop ( json_obj_new )
    ( json_obj_set action_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set action_prop `description` ( json_str_lit `Harness lifecycle action: start, evidence, handoff, gate, preflight, report, allow_read, or complete.` ) )

    : Json name_prop ( json_obj_new )
    ( json_obj_set name_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set name_prop `description` ( json_str_lit `Contract id, evidence kind, dependent skill name, gate name, or report status depending on action. Use report status blocked/no-go when prerequisites fail and the correct outcome is to tell the user the workflow cannot proceed.` ) )

    : Json value_prop ( json_obj_new )
    ( json_obj_set value_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set value_prop `description` ( json_str_lit `Evidence value, handoff artifact, gate status, or report detail depending on action.` ) )

    : Json detail_prop ( json_obj_new )
    ( json_obj_set detail_prop `type` ( json_str_lit `string` ) )
    ( json_obj_set detail_prop `description` ( json_str_lit `Optional additional gate/report detail.` ) )

    : Json props ( json_obj_new )
    ( json_obj_set props `action` action_prop )
    ( json_obj_set props `name` name_prop )
    ( json_obj_set props `value` value_prop )
    ( json_obj_set props `detail` detail_prop )
    ( json_obj_set schema `properties` props )

    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `action` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ input_bool Json input s field b default → b {
    : ?Json v ( json_obj_get input field )
    ?? v {
        T j → { ^ ( json_bool_val j ) }
        F → { ^ default }
    }
    ^ default
}

@ input_int Json input s field i default → i {
    : ?Json v ( json_obj_get input field )
    ?? v {
        T j → {
            : ?i n ( json_num_as_i j )
            ?? n {
                T got → { ^ got }
                F → {}
            }
        }
        F → {}
    }
    ^ default
}

@ page_lines String body i offset i limit → String {
    : ( Vec String ) lines ( string_split body `\n` )
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    : i n ( vec_len [String] lines )
    : i off offset
    ? < off 0 { = off 0 } {}
    : i lim limit
    ? <= lim 0 { = lim 50 } {}

    : String out ( string_with_cap 256 )
    : ~ i seen 0
    : ~ i emitted 0
    : ~ i k 0
    ~ & < k n < emitted lim {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                ? > ( string_len line ) 0 {
                    ? >= seen off {
                        ( string_push_str out ( string_data line ) )
                        ( string_push_str out `\n` )
                        = emitted + emitted 1
                    } {}
                    = seen + seen 1
                } {}
            }
            F → {}
        }
        = k + k 1
    }
    ( vec_free_with [String] lines drop_str )
    ( string_free body )
    ? == ( string_len out ) 0 {
        ( string_push_str out `(no matches)\n` )
    } {}
    ^ out
}

@ slice_lines String body i offset i limit → String {
    ? & <= offset 0 <= limit 0 { ^ body } {}
    : ( Vec String ) lines ( string_split body `\n` )
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    : i n ( vec_len [String] lines )
    : i off offset
    ? < off 0 { = off 0 } {}
    : i lim limit
    ? <= lim 0 { = lim n } {}

    : String out ( string_with_cap 256 )
    : ~ i emitted 0
    : ~ i k off
    ~ & < k n < emitted lim {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                ( string_push_str out ( string_data line ) )
                ? < + k 1 n { ( string_push_str out `\n` ) } {}
                = emitted + emitted 1
            }
            F → {}
        }
        = k + k 1
    }
    ( vec_free_with [String] lines drop_str )
    ( string_free body )
    ^ out
}

@ slice_lines_numbered String body i offset i limit → String {
    : ( Vec String ) lines ( string_split body `\n` )
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    : i n ( vec_len [String] lines )
    : i off offset
    ? < off 0 { = off 0 } {}
    : i lim limit
    ? <= lim 0 { = lim n } {}

    : String out ( string_with_cap 256 )
    : ~ i emitted 0
    : ~ i k off
    ~ & < k n < emitted lim {
        : ?String e ( vec_get [String] lines k )
        ?? e {
            T line → {
                ( string_push_int out + k 1 )
                ( string_push_str out `| ` )
                ( string_push_str out ( string_data line ) )
                ? < + k 1 n { ( string_push_str out `\n` ) } {}
                = emitted + emitted 1
            }
            F → {}
        }
        = k + k 1
    }
    ( vec_free_with [String] lines drop_str )
    ( string_free body )
    ^ out
}

@ string_count_occurrences String text s needle → i {
    : i flen ( nurl_str_len needle )
    ? == flen 0 { ^ 0 } {}
    : ~ i count 0
    : ~ i start 0
    : ~ b going T
    ~ going {
        : s cur # s + # i ( string_data text ) start
        : i found ( nurl_str_find cur needle )
        ? < found 0 {
            = going F
        } {
            = count + count 1
            = start + start + found flen
        }
    }
    ^ count
}

@ patch_error s msg → String {
    : String out ( string_from `error: patch ` )
    ( string_push_str out msg )
    ^ out
}

@ mutation_path_guard_error s path s reason → String {
    : String msg ( string_from `error: production path guard rejected ` )
    ( string_push_str msg path )
    ( string_push_str msg `: ` )
    ( string_push_str msg reason )
    ( trace_event `tool_blocked` ( string_data msg ) )
    ^ msg
}

@ mutation_path_guard s path → String {
    ? ! ( hermes_nurl_production_mode ) {
        ^ ( string_new )
    } {}
    ? == ( nurl_str_len path ) 0 {
        ^ ( string_new )
    } {}
    : String raw ( string_from path )
    ? ( string_starts_with raw `/` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `absolute paths are not allowed in production mutation tools; use a relative workspace path` )
    } {}
    ? ( string_starts_with raw `~` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `home-relative paths are not allowed in production mutation tools` )
    } {}
    ? ( string_contains raw `..` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `parent-directory components are not allowed in production mutation tools` )
    } {}
    ? ( string_contains raw `.git` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `VCS metadata paths are not allowed in production mutation tools` )
    } {}
    ? ( string_contains raw `.hg` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `VCS metadata paths are not allowed in production mutation tools` )
    } {}
    ? ( string_contains raw `.svn` ) {
        ( string_free raw )
        ^ ( mutation_path_guard_error path `VCS metadata paths are not allowed in production mutation tools` )
    } {}
    ( string_free raw )
    ^ ( string_new )
}

@ read_file_binary_media_guard s path → String {
    : String raw ( string_from path )
    : String lower ( string_to_lower raw )
    ( string_free raw )
    : ~ b blocked F
    ? ( string_ends_with lower `.png` ) { = blocked T } {}
    ? ( string_ends_with lower `.jpg` ) { = blocked T } {}
    ? ( string_ends_with lower `.jpeg` ) { = blocked T } {}
    ? ( string_ends_with lower `.webp` ) { = blocked T } {}
    ? ( string_ends_with lower `.gif` ) { = blocked T } {}
    ? ( string_ends_with lower `.avif` ) { = blocked T } {}
    ? ( string_ends_with lower `.pdf` ) { = blocked T } {}
    ? ( string_ends_with lower `.zip` ) { = blocked T } {}
    ? ( string_ends_with lower `.tar` ) { = blocked T } {}
    ? ( string_ends_with lower `.gz` ) { = blocked T } {}
    ? ( string_ends_with lower `.mp3` ) { = blocked T } {}
    ? ( string_ends_with lower `.mp4` ) { = blocked T } {}
    ? ( string_ends_with lower `.mov` ) { = blocked T } {}
    ( string_free lower )
    ? blocked {
        ( trace_event `tool_blocked` `read_file_binary_media` )
        : String msg ( string_from `error: read_file only supports UTF-8 text files. Refused binary/media path ` )
        ( string_push_str msg path )
        ( string_push_str msg `. Use file_info for metadata or the relevant vision/image workflow helper for visual inspection.` )
        ^ msg
    } {}
    ^ ( string_new )
}

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

@ edit_check_strict_enabled → b {
    ^ ( env_truthy `HERMES_NURL_EDIT_CHECK_STRICT` )
}

@ edit_check_strict_result String summary s label → String {
    ? ( edit_check_strict_enabled ) {
        : String out ( string_from `error: ` )
        ( string_push_str out label )
        ( string_push_str out ` after edit\n` )
        ( string_push_str out ( string_data summary ) )
        ( string_free summary )
        ^ ( truncate_for_model out )
    } {}
    ^ summary
}

@ append_edit_check_result String summary → String {
    : String cmd ( hermes_nurl_edit_check_command )
    ? == ( string_len cmd ) 0 {
        ( string_free cmd )
        ^ summary
    } {}
    ? ! ( hermes_nurl_shell_allowed ) {
        ( trace_event `edit_check_skipped` `shell_disabled` )
        ( string_push_str summary `\n[edit check skipped]\nHERMES_NURL_EDIT_CHECK_COMMAND is set, but shell execution is disabled. Set HERMES_NURL_ALLOW_SHELL=1 in production mode to run it.` )
        ( string_free cmd )
        ^ ( edit_check_strict_result summary `edit check skipped` )
    } {}
    ? ( shell_command_blocked ( string_data cmd ) ) {
        ? ( env_truthy `HERMES_NURL_ALLOW_DESTRUCTIVE` ) {} {
            ( trace_event `edit_check_blocked` `shell_guard` )
            ( string_push_str summary `\n[edit check blocked]\nConfigured command was refused by the shell guard: ` )
            ( string_push_str summary ( string_data cmd ) )
            ( string_free cmd )
            ^ ( edit_check_strict_result summary `edit check blocked` )
        }
    } {}
    ( trace_event `edit_check_start` ( string_data cmd ) )
    : !Output ProcessErr r ( process_run_shell ( string_data cmd ) )
    ?? r {
        T out → {
            : i ec ( output_exit_code out )
            ? == ec 0 {
                ( trace_event `edit_check_passed` ( string_data cmd ) )
                ( string_push_str summary `\n[edit check passed]\ncommand: ` )
            } {
                : String detail ( string_from ( string_data cmd ) )
                ( string_push_str detail ` exit=` )
                ( string_push_int detail ec )
                ( trace_event `edit_check_failed` ( string_data detail ) )
                ( string_free detail )
                ( string_push_str summary `\n[edit check failed: exit ` )
                ( string_push_int summary ec )
                ( string_push_str summary `]\ncommand: ` )
            }
            ( string_push_str summary ( string_data cmd ) )
            : s stdout ( output_stdout out )
            ? > ( nurl_str_len stdout ) 0 {
                ( string_push_str summary `\n[stdout]\n` )
                ( string_push_str summary stdout )
            } {}
            : i errlen ( output_stderr_len out )
            ? > errlen 0 {
                ( string_push_str summary `\n[stderr]\n` )
                ( string_push_str summary ( output_stderr out ) )
            } {}
            ( output_free out )
            ( string_free cmd )
            ? != ec 0 {
                ^ ( edit_check_strict_result summary `edit check failed` )
            } {}
            ^ ( truncate_for_model summary )
        }
        F e → {
            : ProcessErr pe # ProcessErr e
            ( trace_event `edit_check_error` ( process_err_name pe ) )
            ( string_push_str summary `\n[edit check error]\n` )
            ( string_push_str summary ( process_err_name pe ) )
            ( string_free cmd )
            ^ ( edit_check_strict_result summary `edit check error` )
        }
    }
}

@ local_tool_count → i { ^ 12 }

@ local_tool_name i idx → s {
    ? == idx 0 { ^ `run_shell` } {}
    ? == idx 1 { ^ `file_info` } {}
    ? == idx 2 { ^ `read_file` } {}
    ? == idx 3 { ^ `list_dir` } {}
    ? == idx 4 { ^ `write_file` } {}
    ? == idx 5 { ^ `append_file` } {}
    ? == idx 6 { ^ `search_files` } {}
    ? == idx 7 { ^ `patch` } {}
    ? == idx 8 { ^ `skills_list` } {}
    ? == idx 9 { ^ `skill_view` } {}
    ? == idx 10 { ^ `http_request` } {}
    ? == idx 11 { ^ `harness_record` } {}
    ^ ``
}

@ local_tool_is_mutating s name → b {
    ? != ( nurl_str_eq name `write_file` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `append_file` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `patch` ) 0 { ^ T } {}
    ^ F
}

@ local_tool_enabled s name → b {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ ( hermes_nurl_shell_allowed )
    } {}
    ? ( local_tool_is_mutating name ) {
        ^ ( hermes_nurl_mutations_allowed )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( hermes_nurl_network_allowed )
    } {}
    ^ T
}

@ local_tool_blocked_message s name → String {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ( trace_event `tool_blocked` `production_mode:run_shell` )
        ^ ( string_from `error: run_shell is disabled in HERMES_NURL_PRODUCTION_MODE. Set HERMES_NURL_ALLOW_SHELL=1 to expose it.` )
    } {}
    ? ( local_tool_is_mutating name ) {
        : String detail ( string_from `production_mode:` )
        ( string_push_str detail name )
        ( trace_event `tool_blocked` ( string_data detail ) )
        ( string_free detail )
        ^ ( string_from `error: mutating tools are disabled in HERMES_NURL_PRODUCTION_MODE. Set HERMES_NURL_ALLOW_MUTATIONS=1 to expose write_file, append_file, and patch.` )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ( trace_event `tool_blocked` `production_mode:http_request` )
        ^ ( string_from `error: http_request is disabled. In production set HERMES_NURL_ALLOW_NETWORK=1 and configure HERMES_NURL_NETWORK_ALLOW_HOSTS or HERMES_NURL_NETWORK_ALLOW_BASE_URLS.` )
    } {}
    ^ ( string_from `` )
}

@ local_tool_description s name → s {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ `Run a shell command and return stdout plus stderr. Use sparingly.`
    } {}
    ? != ( nurl_str_eq name `file_info` ) 0 {
        ^ `Return basic path metadata such as existence, kind, and file size.`
    } {}
    ? != ( nurl_str_eq name `read_file` ) 0 {
        ^ `Read a UTF-8 text file, optionally by line offset and limit.`
    } {}
    ? != ( nurl_str_eq name `list_dir` ) 0 {
        ^ `List entries in a directory.`
    } {}
    ? != ( nurl_str_eq name `write_file` ) 0 {
        ^ `Write UTF-8 content to a file, replacing existing contents.`
    } {}
    ? != ( nurl_str_eq name `append_file` ) 0 {
        ^ `Append UTF-8 content to a file.`
    } {}
    ? != ( nurl_str_eq name `search_files` ) 0 {
        ^ `Search file contents or file paths with ripgrep.`
    } {}
    ? != ( nurl_str_eq name `patch` ) 0 {
        ^ `Targeted exact string replacement or V4A Add/Update/Delete/Move multi-file patches in UTF-8 files.`
    } {}
    ? != ( nurl_str_eq name `skills_list` ) 0 {
        ^ `List available Hermes skills with compact metadata. Use skill_view to load full instructions.`
    } {}
    ? != ( nurl_str_eq name `skill_view` ) 0 {
        ^ `Load a Hermes skill's SKILL.md content or one linked file from references, templates, assets, scripts, commands, or brand bundles.`
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ `Make a controlled HTTP GET or POST request with production policy checks, response caps, and secret redaction. Prefer skill helpers for workflow-specific APIs.`
    } {}
    ? != ( nurl_str_eq name `harness_record` ) 0 {
        ^ `Record harness lifecycle evidence, gate status, and final report state for contract-backed workflows.`
    } {}
    ^ `Local Hermes NURL tool`
}

@ local_tool_schema s name → Json {
    ? != ( nurl_str_eq name `run_shell` ) 0 {
        ^ ( one_string_schema `command` `Shell command to execute via /bin/sh -c` )
    } {}
    ? != ( nurl_str_eq name `file_info` ) 0 {
        ^ ( file_info_schema )
    } {}
    ? != ( nurl_str_eq name `read_file` ) 0 {
        ^ ( read_file_schema )
    } {}
    ? != ( nurl_str_eq name `list_dir` ) 0 {
        ^ ( one_string_schema `path` `Directory path to list` )
    } {}
    ? != ( nurl_str_eq name `write_file` ) 0 {
        ^ ( path_content_schema )
    } {}
    ? != ( nurl_str_eq name `append_file` ) 0 {
        ^ ( path_content_schema )
    } {}
    ? != ( nurl_str_eq name `search_files` ) 0 {
        ^ ( search_files_schema )
    } {}
    ? != ( nurl_str_eq name `patch` ) 0 {
        ^ ( patch_schema )
    } {}
    ? != ( nurl_str_eq name `skills_list` ) 0 {
        ^ ( skills_list_schema )
    } {}
    ? != ( nurl_str_eq name `skill_view` ) 0 {
        ^ ( skill_view_schema )
    } {}
    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( http_request_schema )
    } {}
    ? != ( nurl_str_eq name `harness_record` ) 0 {
        ^ ( harness_record_schema )
    } {}
    : Json empty ( json_obj_new )
    ( json_obj_set empty `type` ( json_str_lit `object` ) )
    ^ empty
}

@ build_local_claude_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( vec_new [Json] )
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( claude_tool_def name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
    ^ tools
}

@ openai_compat_tool_def s name s description Json parameters → Json {
    : Json fn ( json_obj_new )
    ( json_obj_set fn `name` ( json_str_lit name ) )
    ( json_obj_set fn `description` ( json_str_lit description ) )
    ( json_obj_set fn `parameters` parameters )

    : Json t ( json_obj_new )
    ( json_obj_set t `type` ( json_str_lit `function` ) )
    ( json_obj_set t `function` fn )
    ^ t
}

@ build_local_openai_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( vec_new [Json] )
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( openai_compat_tool_def name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
    ^ tools
}

@ add_local_mcp_tools ( Vec Json ) tools → v {
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        : s name ( local_tool_name k )
        ? ( local_tool_enabled name ) {
            ( vec_push [Json] tools
            ( mcp_tool_descriptor name
            ( local_tool_description name )
            ( local_tool_schema name ) ) )
        } {}
        = k + k 1
    }
}

@ run_local_tool_input s name Json input → String {
    ? ! ( local_tool_enabled name ) {
        ? != ( nurl_str_eq name `patch` ) 0 {
            : b dry_run_allowed ( input_bool input `dry_run` F )
            ? dry_run_allowed {} {
                ^ ( local_tool_blocked_message name )
            }
        } {
            ^ ( local_tool_blocked_message name )
        }
    } {}

    ? != ( nurl_str_eq name `run_shell` ) 0 {
        : s cmd ( input_str input `command` )
        ? == ( nurl_str_len cmd ) 0 {
            ^ ( string_from `error: tool 'run_shell' requires non-empty 'command' field` )
        } {}
        ? ( shell_prompt_file_write_blocked cmd ) {
            ( trace_event `tool_blocked` `prompt_file_shell_write` )
            ^ ( string_from `error: run_shell refused shell redirection into prompt_*.txt. Use write_file with a relative path so long prompts are not corrupted by shell quoting or printf formatting.` )
        } {}
        ? ( shell_command_blocked cmd ) {
            ? ( env_truthy `HERMES_NURL_ALLOW_DESTRUCTIVE` ) {} {
                ( trace_event `tool_blocked` `shell_guard` )
                ^ ( string_from `error: run_shell refused a dangerous command. Set HERMES_NURL_ALLOW_DESTRUCTIVE=1 to override.` )
            }
        } {}
        ( trace_event `tool_run_shell` cmd )
        : !Output ProcessErr r ( process_run_shell cmd )
        ?? r {
            T out → {
                : i ec ( output_exit_code out )
                : String body ( string_with_cap 256 )
                ? != ec 0 {
                    ( string_push_str body `[exit ` )
                    ( string_push_int body ec )
                    ( string_push_str body `]\n` )
                } {}
                ( string_push_str body ( output_stdout out ) )
                : i errlen ( output_stderr_len out )
                ? > errlen 0 {
                    ( string_push_str body `\n[stderr]\n` )
                    ( string_push_str body ( output_stderr out ) )
                } {}
                ( output_free out )
                ^ ( truncate_for_model body )
            }
            F e → {
                : ProcessErr pe # ProcessErr e
                : String msg ( string_from `error: process_run failed: ` )
                ( string_push_str msg ( process_err_name pe ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `http_request` ) 0 {
        ^ ( run_http_request_tool input )
    } {}

    ? != ( nurl_str_eq name `file_info` ) 0 {
        : s path ( input_str input `path` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'file_info' requires non-empty 'path' field` )
        } {}
        : String read_guard ( skill_active_read_guard_error path )
        ? > ( string_len read_guard ) 0 {
            : String msg ( string_from `error: ` )
            ( string_push_str msg ( string_data read_guard ) )
            ( string_free read_guard )
            ^ msg
        } {}
        ( string_free read_guard )
        ( trace_event `tool_file_info` path )
        : String out ( string_with_cap 128 )
        ( string_push_str out `path: ` )
        ( string_push_str out path )
        ( string_push_str out `\n` )
        ? ( file_exists path ) {
            ( string_push_str out `exists: true\n` )
            : !i IoErr sz ( file_size path )
            ?? sz {
                T bytes → {
                    ( string_push_str out `kind: file\nbytes: ` )
                    ( string_push_int out bytes )
                    ( string_push_str out `\n` )
                    : !String IoErr fr ( read_file path )
                    ?? fr {
                        T contents → {
                            : String digest ( sha256_hex ( string_data contents ) )
                            ( string_push_str out `sha256: ` )
                            ( string_push_str out ( string_data digest ) )
                            ( string_push_str out `\n` )
                            ( string_free digest )
                            ( string_free contents )
                        }
                        F _ → {}
                    }
                }
                F _ → {
                    : !( Vec String ) IoErr dl ( dir_list path )
                    ?? dl {
                        T entries → {
                            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
                            ( string_push_str out `kind: directory\nentries: ` )
                            ( string_push_int out ( vec_len [String] entries ) )
                            ( string_push_str out `\n` )
                            ( vec_free_with [String] entries drop_str )
                        }
                        F e → {
                            : IoErr ie # IoErr e
                            ( string_push_str out `kind: unknown\nerror: ` )
                            ( string_push_str out ( io_err_msg ie ) )
                            ( string_push_str out `\n` )
                        }
                    }
                }
            }
        } {
            ( string_push_str out `exists: false\n` )
        }
        ^ out
    } {}

    ? != ( nurl_str_eq name `read_file` ) 0 {
        : s path ( input_str input `path` )
        : i offset ( input_int input `offset` 0 )
        : i limit ( input_int input `limit` 0 )
        : b line_numbers ( input_bool input `line_numbers` F )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'read_file' requires non-empty 'path' field` )
        } {}
        : String read_guard ( skill_active_read_guard_error path )
        ? > ( string_len read_guard ) 0 {
            : String msg ( string_from `error: ` )
            ( string_push_str msg ( string_data read_guard ) )
            ( string_free read_guard )
            ^ msg
        } {}
        ( string_free read_guard )
        : String binary_guard ( read_file_binary_media_guard path )
        ? > ( string_len binary_guard ) 0 {
            ^ binary_guard
        } {}
        ( string_free binary_guard )
        ( trace_event `tool_read_file` path )
        : !String IoErr r ( read_file path )
        ?? r {
            T contents → {
                ? line_numbers {
                    ^ ( truncate_for_model ( slice_lines_numbered contents offset limit ) )
                } {
                    ^ ( truncate_for_model ( slice_lines contents offset limit ) )
                }
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: read_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `list_dir` ) 0 {
        : s path ( input_str input `path` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'list_dir' requires non-empty 'path' field` )
        } {}
        ( trace_event `tool_list_dir` path )
        : !( Vec String ) IoErr r ( dir_list path )
        ?? r {
            T entries → {
                : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
                : i n ( vec_len [String] entries )
                : String out ( string_with_cap 256 )
                ? == n 0 {
                    ( string_push_str out `(empty)\n` )
                } {}
                : ~ i k 0
                ~ < k n {
                    : ?String e ( vec_get [String] entries k )
                    ?? e {
                        T item → {
                            ( string_push_str out ( string_data item ) )
                            ( string_push_str out `\n` )
                        }
                        F → {}
                    }
                    = k + k 1
                }
                ( vec_free_with [String] entries drop_str )
                ^ ( truncate_for_model out )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: list_dir: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `write_file` ) 0 {
        : s path ( input_str input `path` )
        : s content ( input_str input `content` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'write_file' requires non-empty 'path' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String stale ( mutation_check_expected_sha path expected_sha256 )
        ? > ( string_len stale ) 0 {
            ^ stale
        } {}
        ( string_free stale )
        ( trace_event `tool_write_file` path )
        : !v IoErr r ( write_file path content )
        ?? r {
            T _ → {
                : String msg ( string_from `wrote ` )
                ( string_push_int msg ( nurl_str_len content ) )
                ( string_push_str msg ` bytes to ` )
                ( string_push_str msg path )
                ^ ( append_edit_check_result msg )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: write_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `append_file` ) 0 {
        : s path ( input_str input `path` )
        : s content ( input_str input `content` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'append_file' requires non-empty 'path' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String stale ( mutation_check_expected_sha path expected_sha256 )
        ? > ( string_len stale ) 0 {
            ^ stale
        } {}
        ( string_free stale )
        ( trace_event `tool_append_file` path )
        : !v IoErr r ( append_file path content )
        ?? r {
            T _ → {
                : String msg ( string_from `appended ` )
                ( string_push_int msg ( nurl_str_len content ) )
                ( string_push_str msg ` bytes to ` )
                ( string_push_str msg path )
                ^ ( append_edit_check_result msg )
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: append_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `search_files` ) 0 {
        : s pattern ( input_str input `pattern` )
        : s path_raw ( input_str input `path` )
        : s target ( input_str input `target` )
        : i limit ( input_int input `limit` 50 )
        : i offset ( input_int input `offset` 0 )
        ? == ( nurl_str_len pattern ) 0 {
            ^ ( string_from `error: tool 'search_files' requires non-empty 'pattern' field` )
        } {}
        : s path ? == ( nurl_str_len path_raw ) 0 `.` path_raw
        ( trace_event `tool_search_files` pattern )

        : ( Vec s ) args ( vec_with_cap [s] 8 )
        ? != ( nurl_str_eq target `files` ) 0 {
            ( vec_push [s] args `--files` )
            ( vec_push [s] args `-g` )
            ( vec_push [s] args pattern )
            ( vec_push [s] args path )
        } {
            ? | == ( nurl_str_len target ) 0 != ( nurl_str_eq target `content` ) 0 {
                ( vec_push [s] args `--line-number` )
                ( vec_push [s] args `--no-heading` )
                ( vec_push [s] args `--with-filename` )
                ( vec_push [s] args `--color` )
                ( vec_push [s] args `never` )
                ( vec_push [s] args pattern )
                ( vec_push [s] args path )
            } {
                ( vec_free [s] args )
                ^ ( string_from `error: search_files target must be 'content' or 'files'` )
            }
        }
        : !Output ProcessErr r ( process_run `rg` args `` )
        ( vec_free [s] args )
        ?? r {
            T out → {
                : String body ( string_with_cap 256 )
                ( string_push_str body ( output_stdout out ) )
                : i errlen ( output_stderr_len out )
                ? > errlen 0 {
                    ( string_push_str body `\n[stderr]\n` )
                    ( string_push_str body ( output_stderr out ) )
                } {}
                ( output_free out )
                ^ ( truncate_for_model ( page_lines body offset limit ) )
            }
            F e → {
                : ProcessErr pe # ProcessErr e
                : String msg ( string_from `error: search_files requires rg: ` )
                ( string_push_str msg ( process_err_name pe ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `patch` ) 0 {
        : s mode ( input_str input `mode` )
        : b dry_run ( input_bool input `dry_run` F )
        ? != ( nurl_str_eq mode `patch` ) 0 {
            : s patch_text ( input_str input `patch` )
            ? == ( nurl_str_len patch_text ) 0 {
                ^ ( string_from `error: tool 'patch' requires non-empty 'patch' field when mode='patch'` )
            } {}
            ? dry_run {
                ( trace_event `tool_patch_v4a_dry_run` `multi-file` )
            } {
                ( trace_event `tool_patch_v4a` `multi-file` )
            }
            : String result ( apply_v4a_patch patch_text dry_run )
            ? | dry_run ( string_starts_with result `error:` ) {
                ^ result
            } {}
            ^ ( append_edit_check_result result )
        } {}
        ? & > ( nurl_str_len mode ) 0 == ( nurl_str_eq mode `replace` ) 0 {
            ^ ( string_from `error: patch mode must be 'replace' or 'patch'` )
        } {}

        : s path ( input_str input `path` )
        : s old_string ( input_str input `old_string` )
        : s new_string ( input_str input `new_string` )
        : s expected_sha256 ( input_str input `expected_sha256` )
        : b replace_all ( input_bool input `replace_all` F )
        ? == ( nurl_str_len path ) 0 {
            ^ ( string_from `error: tool 'patch' requires non-empty 'path' field` )
        } {}
        ? == ( nurl_str_len old_string ) 0 {
            ^ ( string_from `error: tool 'patch' requires non-empty 'old_string' field` )
        } {}
        : String guard ( mutation_path_guard path )
        ? > ( string_len guard ) 0 {
            ^ guard
        } {}
        ( string_free guard )
        : String required ( mutation_expected_sha_guard path expected_sha256 )
        ? > ( string_len required ) 0 {
            ^ required
        } {}
        ( string_free required )
        ? dry_run {
            ( trace_event `tool_patch_dry_run` path )
        } {
            ( trace_event `tool_patch` path )
        }

        : !String IoErr rr ( read_file path )
        ?? rr {
            T contents → {
                : String stale ( patch_check_expected_sha256 path contents expected_sha256 )
                ? > ( string_len stale ) 0 {
                    ( string_free contents )
                    ^ stale
                } {}
                ( string_free stale )
                : i count ( string_count_occurrences contents old_string )
                ? == count 0 {
                    ( string_free contents )
                    ^ ( string_from `error: patch old_string not found` )
                } {}
                ? & ! replace_all > count 1 {
                    : String msg ( string_from `error: patch old_string occurs ` )
                    ( string_push_int msg count )
                    ( string_push_str msg ` times; set replace_all=true or include more context` )
                    ( string_free contents )
                    ^ msg
                } {}
                ? dry_run {
                    : String msg ( string_from `validated replace patch (dry run): would patch ` )
                    ( string_push_int msg count )
                    ( string_push_str msg ` occurrence` )
                    ? != count 1 { ( string_push_str msg `s` ) } {}
                    ( string_push_str msg ` in ` )
                    ( string_push_str msg path )
                    ( string_free contents )
                    ^ msg
                } {}
                : String patched ( string_replace contents old_string new_string )
                : !v IoErr wr ( write_file path ( string_data patched ) )
                ?? wr {
                    T _ → {
                        : String msg ( string_from `patched ` )
                        ( string_push_int msg count )
                        ( string_push_str msg ` occurrence` )
                        ? != count 1 { ( string_push_str msg `s` ) } {}
                        ( string_push_str msg ` in ` )
                        ( string_push_str msg path )
                        ( string_free contents )
                        ( string_free patched )
                        ^ ( append_edit_check_result msg )
                    }
                    F e → {
                        : IoErr ie # IoErr e
                        : String msg ( string_from `error: patch write_file: ` )
                        ( string_push_str msg ( io_err_msg ie ) )
                        ( string_free contents )
                        ( string_free patched )
                        ^ msg
                    }
                }
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `error: patch read_file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                ^ msg
            }
        }
    } {}

    ? != ( nurl_str_eq name `skills_list` ) 0 {
        : s category ( input_str input `category` )
        ( trace_event `tool_skills_list` category )
        ^ ( skills_list_json category )
    } {}

    ? != ( nurl_str_eq name `skill_view` ) 0 {
        : s skill_name ( input_str input `name` )
        : s file_path ( input_str input `file_path` )
        ? == ( nurl_str_len skill_name ) 0 {
            ^ ( string_from `error: tool 'skill_view' requires non-empty 'name' field` )
        } {}
        : String detail ( string_from skill_name )
        ? > ( nurl_str_len file_path ) 0 {
            ( string_push_str detail `:` )
            ( string_push_str detail file_path )
        } {}
        ( trace_event `tool_skill_view` ( string_data detail ) )
        ( string_free detail )
        ^ ( skill_view_json skill_name file_path )
    } {}

    ? != ( nurl_str_eq name `harness_record` ) 0 {
        : s action ( input_str input `action` )
        : s hname ( input_str input `name` )
        : s value ( input_str input `value` )
        : s detail ( input_str input `detail` )
        ( trace_event `tool_harness_record` action )
        ? != ( nurl_str_eq action `start` ) 0 {
            ? == ( nurl_str_len hname ) 0 {
                ^ ( string_from `error: harness_record start requires name=<contract-id>` )
            } {}
            ^ ( harness_start_run hname )
        } {}
        ? != ( nurl_str_eq action `evidence` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record evidence requires name=<kind> and value=<evidence>` )
            } {}
            ^ ( harness_record_evidence hname value )
        } {}
        ? != ( nurl_str_eq action `handoff` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record handoff requires name=<dependent-skill> and value=<artifact>` )
            } {}
            ^ ( harness_record_handoff hname value detail )
        } {}
        ? != ( nurl_str_eq action `gate` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record gate requires name=<gate> and value=<status>` )
            } {}
            ^ ( harness_record_gate hname value detail )
        } {}
        ? != ( nurl_str_eq action `preflight` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record preflight requires name=<preflight> and value=<status>` )
            } {}
            ^ ( harness_record_preflight hname value detail )
        } {}
        ? != ( nurl_str_eq action `report` ) 0 {
            ? == ( nurl_str_len hname ) 0 {
                ^ ( string_from `error: harness_record report requires name=<status>` )
            } {}
            ^ ( harness_write_report hname value )
        } {}
        ? != ( nurl_str_eq action `allow_read` ) 0 {
            ? | == ( nurl_str_len hname ) 0 == ( nurl_str_len value ) 0 {
                ^ ( string_from `error: harness_record allow_read requires name=<skill> and value=<relative-path>` )
            } {}
            ^ ( harness_unlock_read hname value detail )
        } {}
        ? != ( nurl_str_eq action `complete` ) 0 {
            ^ ( harness_completion_check_json )
        } {}
        ^ ( string_from `error: harness_record action must be start, evidence, handoff, gate, preflight, report, allow_read, or complete` )
    } {}

    : String unknown ( string_from `error: unknown tool '` )
    ( string_push_str unknown name )
    ( string_push_str unknown `'` )
    ^ unknown
}

@ run_local_claude_tool Json tu → String {
    : s name ( claude_tool_use_name tu )
    : ?Json input_o ( claude_tool_use_input tu )

    : Json input ?? input_o {
        T j → j
        F → @ Json { JNull }
    }

    ^ ( run_local_tool_input name input )
}

@ is_local_tool s name → b {
    : i n ( local_tool_count )
    : ~ i k 0
    ~ < k n {
        ? != ( nurl_str_eq name ( local_tool_name k ) ) 0 { ^ T } {}
        = k + k 1
    }
    ^ F
}
