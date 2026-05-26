// Tool JSON schemas and utility helpers for Hermes NURL.
// Extracted from tools_local.nu for maintainability.

$ `stdlib/ext/json.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `stdlib/core/errors.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/hash.nu`
$ `nurl/src/common.nu`

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
