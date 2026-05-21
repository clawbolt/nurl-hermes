// Hermes skill discovery and read-only skill tools for the NURL prototype.
//
// This ports the lightweight core of agent/skill_utils.py and
// tools/skills_tool.py: local/external skill discovery, frontmatter metadata,
// platform and disabled-skill filtering, progressive listing, and skill_view.

$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/std/path.nu`
$ `stdlib/std/process.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`
$ `nurl/src/harness.nu`

@ SKILL_MAX_DESCRIPTION → i { ^ 1024 }

@ skill_free_string_vec ( Vec String ) values → v {
    : i n ( vec_len [String] values )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] values k )
        ?? e {
            T s → { ( string_free s ) }
            F → {}
        }
        = k + k 1
    }
    ( vec_free [String] values )
}

@ skills_path → String {
    ^ ( hermes_path `skills` )
}

@ skill_is_excluded_dir s name → b {
    ? != ( nurl_str_eq name `.git` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `.github` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `.hub` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `.archive` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `__pycache__` ) 0 { ^ T } {}
    ^ F
}

@ skill_is_junk_entry s name → b {
    ? != ( nurl_str_eq name `.DS_Store` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `Thumbs.db` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `.pytest_cache` ) 0 { ^ T } {}
    ? != ( nurl_str_eq name `.mypy_cache` ) 0 { ^ T } {}
    ^ ( skill_is_excluded_dir name )
}

@ skill_trim_trailing_comma String raw → String {
    : i n ( string_len raw )
    ? > n 0 {
        ? == ( string_get raw - n 1 ) 44 {
            : String out ( string_substr raw 0 - n 1 )
            ( string_free raw )
            ^ out
        } {}
    } {}
    ^ raw
}

@ skill_clean_list_item String raw → String {
    : String trimmed0 ( string_trim raw )
    ( string_free raw )
    : i n0 ( string_len trimmed0 )
    : String without_dash ( string_from ( string_data trimmed0 ) )
    ? > n0 0 {
        ? == ( string_get trimmed0 0 ) 45 {
            ( string_free without_dash )
            = without_dash ( string_substr trimmed0 1 - n0 1 )
        } {}
    } {}
    ( string_free trimmed0 )
    : String trimmed1 ( string_trim without_dash )
    ( string_free without_dash )
    : String no_comma ( skill_trim_trailing_comma trimmed1 )
    : String trimmed2 ( string_trim no_comma )
    ( string_free no_comma )
    ^ ( config_unquote trimmed2 )
}

@ skill_push_list_value ( Vec String ) out String raw → v {
    : String trimmed ( string_trim raw )
    ( string_free raw )
    : i n ( string_len trimmed )
    ? == n 0 {
        ( string_free trimmed )
    } {
        : String inner ( string_from ( string_data trimmed ) )
        ? >= n 2 {
            ? == ( string_get trimmed 0 ) 91 {
                : i last ( string_get trimmed - n 1 )
                ? == last 93 {
                    ( string_free inner )
                    = inner ( string_substr trimmed 1 - n 2 )
                } {}
            } {}
        } {}
        ( string_free trimmed )

        : ( Vec String ) parts ( string_split inner `,` )
        ( string_free inner )
        : i count ( vec_len [String] parts )
        : ~ i k 0
        ~ < k count {
            : ?String e ( vec_get [String] parts k )
            ?? e {
                T part → {
                    : String clean ( skill_clean_list_item ( string_from ( string_data part ) ) )
                    ? > ( string_len clean ) 0 {
                        ( vec_push [String] out clean )
                    } {
                        ( string_free clean )
                    }
                }
                F → {}
            }
            = k + k 1
        }
        ( skill_free_string_vec parts )
    }
}

@ skill_config_list s wanted → ( Vec String ) {
    : ( Vec String ) out ( vec_new [String] )
    : String path ( hermes_config_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )

            : ~ b in_skills F
            : ~ b in_wanted_list F
            : i n ( vec_len [String] lines )
            : ~ i i 0
            ~ < i n {
                : ?String e ( vec_get [String] lines i )
                ?? e {
                    T line → {
                        : String trimmed ( string_trim line )
                        ? ( config_line_ignored trimmed ) {} {
                            : i indent ( config_line_indent line )
                            ? == indent 0 {
                                ? ( config_line_key_is trimmed `skills` ) {
                                    = in_skills T
                                    = in_wanted_list F
                                } {
                                    = in_skills F
                                    = in_wanted_list F
                                }
                            } {
                                ? in_skills {
                                    ? == indent 2 {
                                        = in_wanted_list F
                                        ? ( config_line_key_is trimmed wanted ) {
                                            : String value ( config_key_value trimmed wanted )
                                            ? > ( string_len value ) 0 {
                                                ( skill_push_list_value out value )
                                            } {
                                                ( string_free value )
                                                = in_wanted_list T
                                            }
                                        } {}
                                    } {
                                        ? in_wanted_list {
                                            ? >= indent 4 {
                                                ? ( string_starts_with trimmed `-` ) {
                                                    ( skill_push_list_value out ( string_from ( string_data trimmed ) ) )
                                                } {}
                                            } {}
                                        } {}
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
            ( skill_free_string_vec lines )
        }
        F _ → {}
    }
    ^ out
}

@ skill_expand_dir String raw → String {
    : String trimmed ( string_trim raw )
    ( string_free raw )
    : i n ( string_len trimmed )
    ? == n 0 {
        ^ trimmed
    } {}

    : ~ b home_relative F
    ? >= n 2 {
        ? == ( string_get trimmed 0 ) 126 {
            ? == ( string_get trimmed 1 ) 47 {
                = home_relative T
            } {}
        } {}
    } {}
    ? home_relative {
        : ?String home ( env_get `HOME` )
        ?? home {
            T h → {
                : String rest ( string_substr trimmed 2 - n 2 )
                : String joined ( path_join ( string_data h ) ( string_data rest ) )
                ( string_free h )
                ( string_free rest )
                ( string_free trimmed )
                ^ joined
            }
            F → {}
        }
    } {}

    ? == ( string_get trimmed 0 ) 47 {
        ^ trimmed
    } {}
    ? ( path_is_absolute ( string_data trimmed ) ) {
        ^ trimmed
    } {}

    : String home2 ( hermes_home )
    : String joined2 ( path_join ( string_data home2 ) ( string_data trimmed ) )
    ( string_free home2 )
    ( string_free trimmed )
    ^ joined2
}

@ skill_vec_contains ( Vec String ) values s needle → b {
    : i n ( vec_len [String] values )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] values k )
        ?? e {
            T value → {
                ? != ( nurl_str_eq ( string_data value ) needle ) 0 { ^ T } {}
            }
            F → {}
        }
        = k + k 1
    }
    ^ F
}

@ get_external_skills_dirs_nurl → ( Vec String ) {
    : ( Vec String ) out ( vec_new [String] )
    : ( Vec String ) raw_dirs ( skill_config_list `external_dirs` )
    : String local ( skills_path )
    : String local_norm ( string_from ( string_data local ) )
    ( string_free local )

    : i n ( vec_len [String] raw_dirs )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] raw_dirs k )
        ?? e {
            T raw → {
                : String expanded ( skill_expand_dir ( string_from ( string_data raw ) ) )
                ? > ( string_len expanded ) 0 {
                    ? == ( nurl_str_eq ( string_data expanded ) ( string_data local_norm ) ) 0 {
                        ? ( file_exists ( string_data expanded ) ) {
                            ? ( skill_vec_contains out ( string_data expanded ) ) {
                                ( string_free expanded )
                            } {
                                ( vec_push [String] out expanded )
                            }
                        } {
                            ( string_free expanded )
                        }
                    } {
                        ( string_free expanded )
                    }
                } {
                    ( string_free expanded )
                }
            }
            F → {}
        }
        = k + k 1
    }
    ( string_free local_norm )
    ( skill_free_string_vec raw_dirs )
    ^ out
}

@ skill_frontmatter_end String content → i {
    ? ( string_starts_with content `---` ) {
        : ?i end_o ( string_index_of content `\n---` )
        ?? end_o {
            T idx → { ^ idx }
            F → {}
        }
    } {}
    ^ -1
}

@ skill_frontmatter_value String content s wanted → String {
    : i end ( skill_frontmatter_end content )
    ? < end 0 { ^ ( string_new ) } {}
    : String fm ( string_substr content 3 - end 3 )
    : ( Vec String ) lines ( string_split fm `\n` )
    ( string_free fm )
    : String found ( string_new )
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
                        : String value ( config_key_value trimmed wanted )
                        ? > ( string_len value ) 0 {
                            ( string_free found )
                            = found value
                            = done T
                        } {
                            ( string_free value )
                        }
                    } {}
                }
                ( string_free trimmed )
            }
            F → {}
        }
        = i + i 1
    }
    ( skill_free_string_vec lines )
    ^ found
}

@ skill_body_text String content → String {
    : i end ( skill_frontmatter_end content )
    ? < end 0 {
        ^ ( string_from ( string_data content ) )
    } {}
    : i start + end 4
    : i n ( string_len content )
    ? < start n {
        ? == ( string_get content start ) 10 { = start + start 1 } {}
    } {}
    ^ ( string_substr content start - n start )
}

@ skill_first_body_line String content → String {
    : String body ( skill_body_text content )
    : ( Vec String ) lines ( string_split body `\n` )
    ( string_free body )
    : String found ( string_new )
    : ~ b done F
    : i n ( vec_len [String] lines )
    : ~ i i 0
    ~ & < i n ! done {
        : ?String e ( vec_get [String] lines i )
        ?? e {
            T line → {
                : String trimmed ( string_trim line )
                ? > ( string_len trimmed ) 0 {
                    ? != ( string_get trimmed 0 ) 35 {
                        ( string_free found )
                        = found ( string_from ( string_data trimmed ) )
                        = done T
                    } {}
                } {}
                ( string_free trimmed )
            }
            F → {}
        }
        = i + i 1
    }
    ( skill_free_string_vec lines )
    ^ found
}

@ skill_description String content → String {
    : String desc ( skill_frontmatter_value content `description` )
    ? == ( string_len desc ) 0 {
        ( string_free desc )
        = desc ( skill_first_body_line content )
    } {}
    : i n ( string_len desc )
    ? > n ( SKILL_MAX_DESCRIPTION ) {
        : String short ( string_substr desc 0 - ( SKILL_MAX_DESCRIPTION ) 3 )
        ( string_push_str short `...` )
        ( string_free desc )
        ^ short
    } {}
    ^ desc
}

@ skill_name_from_content String content s fallback → String {
    : String name ( skill_frontmatter_value content `name` )
    ? > ( string_len name ) 0 { ^ name } {}
    ( string_free name )
    ^ ( string_from fallback )
}

@ skill_current_platform → String {
    : ?String explicit ( env_get `HERMES_NURL_PLATFORM` )
    ?? explicit {
        T p → {
            ? > ( string_len p ) 0 { ^ p } {}
            ( string_free p )
        }
        F → {}
    }

    : !Output ProcessErr uname ( process_run1 `uname` `-s` )
    ?? uname {
        T out → {
            : String raw ( string_from ( output_stdout out ) )
            ( output_free out )
            : String lower ( string_to_lower raw )
            ( string_free raw )
            : String trimmed ( string_trim lower )
            ( string_free lower )
            ? ( string_contains trimmed `darwin` ) {
                ( string_free trimmed )
                ^ ( string_from `darwin` )
            } {}
            ? ( string_contains trimmed `linux` ) {
                ( string_free trimmed )
                ^ ( string_from `linux` )
            } {}
            : ~ b is_windows F
            ? ( string_contains trimmed `mingw` ) { = is_windows T } {}
            ? ( string_contains trimmed `msys` ) { = is_windows T } {}
            ? ( string_contains trimmed `windows` ) { = is_windows T } {}
            ? is_windows {
                ( string_free trimmed )
                ^ ( string_from `win32` )
            } {}
            ^ trimmed
        }
        F _ → {}
    }
    ^ ( string_from `linux` )
}

@ skill_matches_platform_nurl String content → b {
    : String platforms ( skill_frontmatter_value content `platforms` )
    ? == ( string_len platforms ) 0 {
        ( string_free platforms )
        ^ T
    } {}
    : String lower ( string_to_lower platforms )
    ( string_free platforms )
    : String current ( skill_current_platform )
    : ~ b ok F
    ? ( string_contains lower ( string_data current ) ) { = ok T } {}
    ? ! ok {
        ? != ( nurl_str_eq ( string_data current ) `darwin` ) 0 {
            ? ( string_contains lower `macos` ) { = ok T } {}
        } {}
    } {}
    ? ! ok {
        ? != ( nurl_str_eq ( string_data current ) `win32` ) 0 {
            ? ( string_contains lower `windows` ) { = ok T } {}
        } {}
    } {}
    ( string_free lower )
    ( string_free current )
    ^ ok
}

@ skill_content_warns String content → b {
    : String lower ( string_to_lower content )
    : ~ b found F
    ? ( string_contains lower `ignore previous instructions` ) { = found T } {}
    ? ( string_contains lower `ignore all previous` ) { = found T } {}
    ? ( string_contains lower `you are now` ) { = found T } {}
    ? ( string_contains lower `disregard your` ) { = found T } {}
    ? ( string_contains lower `forget your instructions` ) { = found T } {}
    ? ( string_contains lower `new instructions:` ) { = found T } {}
    ? ( string_contains lower `system prompt:` ) { = found T } {}
    ? ( string_contains lower `<system>` ) { = found T } {}
    ( string_free lower )
    ^ found
}

@ skill_dir_has_index s dir → b {
    : String path ( path_join dir `SKILL.md` )
    : b exists ( file_exists ( string_data path ) )
    ( string_free path )
    ^ exists
}

@ skill_add_category ( Vec String ) categories s category → v {
    ? > ( nurl_str_len category ) 0 {
        ? ( skill_vec_contains categories category ) {} {
            ( vec_push [String] categories ( string_from category ) )
        }
    } {}
}

@ skill_json_entry s name s desc s category s skill_dir → Json {
    : Json entry ( json_obj_new )
    ( json_obj_set entry `name` ( json_str_lit name ) )
    ( json_obj_set entry `description` ( json_str_lit desc ) )
    ? > ( nurl_str_len category ) 0 {
        ( json_obj_set entry `category` ( json_str_lit category ) )
    } {
        ( json_obj_set entry `category` ( json_null ) )
    }
    ( json_obj_set entry `skill_dir` ( json_str_lit skill_dir ) )
    ? ( harness_contract_exists skill_dir ) {
        ( json_obj_set entry `harness` ( harness_contract_summary_for_dir skill_dir ) )
    } {}
    ^ entry
}

@ skill_scan_dir s root s dir s category ( Vec String ) seen ( Vec String ) disabled ( Vec String ) categories Json skills_arr s category_filter → v {
    : b has_skill ( skill_dir_has_index dir )
    ? has_skill {
        : String index ( path_join dir `SKILL.md` )
        : !String IoErr rd ( read_file ( string_data index ) )
        ?? rd {
            T content → {
                ? ( skill_matches_platform_nurl content ) {
                    : String base ( path_basename dir )
                    : String name ( skill_name_from_content content ( string_data base ) )
                    ( string_free base )
                    : b already_seen ( skill_vec_contains seen ( string_data name ) )
                    : b is_disabled ( skill_vec_contains disabled ( string_data name ) )
                    ? | already_seen is_disabled {} {
                        : ~ b category_ok F
                        ? == ( nurl_str_len category_filter ) 0 { = category_ok T } {}
                        ? != ( nurl_str_eq category_filter category ) 0 { = category_ok T } {}
                        ? category_ok {
                            : String desc ( skill_description content )
                            ( vec_push [String] seen ( string_from ( string_data name ) ) )
                            ( skill_add_category categories category )
                            ( json_arr_push skills_arr
                            ( skill_json_entry ( string_data name ) ( string_data desc ) category dir ) )
                            ( string_free desc )
                        } {}
                    }
                    ( string_free name )
                } {}
                ( string_free content )
            }
            F _ → {}
        }
        ( string_free index )
    } {
        : !( Vec String ) IoErr listed ( dir_list dir )
        ?? listed {
            T entries → {
                : i n ( vec_len [String] entries )
                : ~ i k 0
                ~ < k n {
                    : ?String e ( vec_get [String] entries k )
                    ?? e {
                        T item → {
                            ? ( skill_is_excluded_dir ( string_data item ) ) {} {
                                : String child ( path_join dir ( string_data item ) )
                                : !( Vec String ) IoErr child_list ( dir_list ( string_data child ) )
                                ?? child_list {
                                    T child_entries → {
                                        ( skill_free_string_vec child_entries )
                                        : b child_has_skill ( skill_dir_has_index ( string_data child ) )
                                        : String next_category ( string_new )
                                        ? child_has_skill {
                                            ( string_free next_category )
                                            = next_category ( string_from category )
                                        } {
                                            ? == ( nurl_str_len category ) 0 {
                                                ( string_free next_category )
                                                = next_category ( string_from ( string_data item ) )
                                            } {
                                                ( string_free next_category )
                                                = next_category ( string_from category )
                                                ( string_push_str next_category `/` )
                                                ( string_push_str next_category ( string_data item ) )
                                            }
                                        }
                                        ( skill_scan_dir root ( string_data child ) ( string_data next_category ) seen disabled categories skills_arr category_filter )
                                        ( string_free next_category )
                                    }
                                    F _ → {}
                                }
                                ( string_free child )
                            }
                        }
                        F → {}
                    }
                    = k + k 1
                }
                ( skill_free_string_vec entries )
            }
            F _ → {}
        }
    }
}

@ skill_scan_all Json skills_arr ( Vec String ) categories s category_filter → v {
    : ( Vec String ) seen ( vec_new [String] )
    : ( Vec String ) disabled ( skill_config_list `disabled` )
    : String local ( skills_path )
    ? ( file_exists ( string_data local ) ) {
        ( skill_scan_dir ( string_data local ) ( string_data local ) `` seen disabled categories skills_arr category_filter )
    } {}
    ( string_free local )

    : ( Vec String ) externals ( get_external_skills_dirs_nurl )
    : i n ( vec_len [String] externals )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] externals k )
        ?? e {
            T root → {
                ( skill_scan_dir ( string_data root ) ( string_data root ) `` seen disabled categories skills_arr category_filter )
            }
            F → {}
        }
        = k + k 1
    }
    ( skill_free_string_vec externals )
    ( skill_free_string_vec disabled )
    ( skill_free_string_vec seen )
}

@ skills_list_json s category_filter → String {
    : Json skills_arr ( json_arr_new )
    : ( Vec String ) categories ( vec_new [String] )
    ( skill_scan_all skills_arr categories category_filter )
    : i count ( json_arr_len skills_arr )

    : Json cat_arr ( json_arr_new )
    : i cn ( vec_len [String] categories )
    : ~ i ck 0
    ~ < ck cn {
        : ?String ce ( vec_get [String] categories ck )
        ?? ce {
            T cat → ( json_arr_push cat_arr ( json_str_lit ( string_data cat ) ) )
            F → {}
        }
        = ck + ck 1
    }

    : Json result ( json_obj_new )
    ( json_obj_set result `success` ( json_bool T ) )
    ( json_obj_set result `skills` skills_arr )
    ( json_obj_set result `categories` cat_arr )
    ( json_obj_set result `count` ( json_int count ) )
    ( json_obj_set result `hint` ( json_str_lit `Use skill_view(name) to load full SKILL.md content or skill_view(name, file_path) for linked files.` ) )
    : String out ( json_stringify result )
    ( json_free result )
    ( skill_free_string_vec categories )
    ^ out
}

@ skills_dirs_json → String {
    : Json dirs ( json_arr_new )
    : String local ( skills_path )
    ( json_arr_push dirs ( json_str_lit ( string_data local ) ) )
    ( string_free local )

    : ( Vec String ) externals ( get_external_skills_dirs_nurl )
    : i n ( vec_len [String] externals )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] externals k )
        ?? e {
            T dir → ( json_arr_push dirs ( json_str_lit ( string_data dir ) ) )
            F → {}
        }
        = k + k 1
    }
    ( skill_free_string_vec externals )

    : Json result ( json_obj_new )
    ( json_obj_set result `success` ( json_bool T ) )
    ( json_obj_set result `dirs` dirs )
    : String out ( json_stringify result )
    ( json_free result )
    ^ out
}

@ skill_find_result b found s path s dir s root s category → Json {
    : Json result ( json_obj_new )
    ( json_obj_set result `found` ( json_bool found ) )
    ? found {
        ( json_obj_set result `path` ( json_str_lit path ) )
        ( json_obj_set result `dir` ( json_str_lit dir ) )
        ( json_obj_set result `root` ( json_str_lit root ) )
        ( json_obj_set result `category` ( json_str_lit category ) )
    } {}
    ^ result
}

@ skill_find_found Json result → b {
    : ?Json f ( json_obj_get result `found` )
    ?? f {
        T j → { ^ ( json_bool_val j ) }
        F → {}
    }
    ^ F
}

@ skill_find_path Json result s key → s {
    : ?Json v ( json_obj_get result key )
    ?? v {
        T j → { ^ ( json_str_data j ) }
        F → {}
    }
    ^ ``
}

@ skill_name_matches String content s dir s wanted → b {
    : String base ( path_basename dir )
    : String name ( skill_name_from_content content ( string_data base ) )
    : b ok F
    ? != ( nurl_str_eq ( string_data name ) wanted ) 0 { = ok T } {}
    ? != ( nurl_str_eq ( string_data base ) wanted ) 0 { = ok T } {}
    ( string_free base )
    ( string_free name )
    ^ ok
}

@ skill_find_in_dir s root s dir s category s wanted → Json {
    : b has_skill ( skill_dir_has_index dir )
    ? has_skill {
        : String index ( path_join dir `SKILL.md` )
        : !String IoErr rd ( read_file ( string_data index ) )
        ?? rd {
            T content → {
                : b ok ( skill_name_matches content dir wanted )
                ? ok {
                    ? ( skill_matches_platform_nurl content ) {
                        ( string_free content )
                        : Json found ( skill_find_result T ( string_data index ) dir root category )
                        ( string_free index )
                        ^ found
                    } {}
                } {}
                ( string_free content )
            }
            F _ → {}
        }
        ( string_free index )
        ^ ( skill_find_result F `` `` `` `` )
    } {}

    : !( Vec String ) IoErr listed ( dir_list dir )
    ?? listed {
        T entries → {
            : i n ( vec_len [String] entries )
            : ~ i k 0
            ~ < k n {
                : ?String e ( vec_get [String] entries k )
                ?? e {
                    T item → {
                        ? ( skill_is_excluded_dir ( string_data item ) ) {} {
                            : String child ( path_join dir ( string_data item ) )
                            : !( Vec String ) IoErr child_list ( dir_list ( string_data child ) )
                            ?? child_list {
                                T child_entries → {
                                    ( skill_free_string_vec child_entries )
                                    : b child_has_skill ( skill_dir_has_index ( string_data child ) )
                                    : String next_category ( string_new )
                                    ? child_has_skill {
                                        ( string_free next_category )
                                        = next_category ( string_from category )
                                    } {
                                        ? == ( nurl_str_len category ) 0 {
                                            ( string_free next_category )
                                            = next_category ( string_from ( string_data item ) )
                                        } {
                                            ( string_free next_category )
                                            = next_category ( string_from category )
                                            ( string_push_str next_category `/` )
                                            ( string_push_str next_category ( string_data item ) )
                                        }
                                    }
                                    : Json got ( skill_find_in_dir root ( string_data child ) ( string_data next_category ) wanted )
                                    ? ( skill_find_found got ) {
                                        ( string_free next_category )
                                        ( string_free child )
                                        ( skill_free_string_vec entries )
                                        ^ got
                                    } {}
                                    ( json_free got )
                                    ( string_free next_category )
                                }
                                F _ → {}
                            }
                            ( string_free child )
                        }
                    }
                    F → {}
                }
                = k + k 1
            }
            ( skill_free_string_vec entries )
        }
        F _ → {}
    }
    ^ ( skill_find_result F `` `` `` `` )
}

@ skill_normalized_name s raw → String {
    : String name ( string_from raw )
    : String normalized ( string_replace name `:` `/` )
    ( string_free name )
    ^ normalized
}

@ skill_direct_find s root s name → Json {
    : String normalized ( skill_normalized_name name )
    : String direct_dir ( path_join root ( string_data normalized ) )
    : String direct_index ( path_join ( string_data direct_dir ) `SKILL.md` )
    ? ( file_exists ( string_data direct_index ) ) {
        : String cat ( path_dirname ( string_data normalized ) )
        : String category ( string_from ( string_data cat ) )
        ? != ( nurl_str_eq ( string_data category ) `.` ) 0 {
            ( string_free category )
            = category ( string_new )
        } {}
        ( string_free cat )
        : Json found ( skill_find_result T ( string_data direct_index ) ( string_data direct_dir ) root ( string_data category ) )
        ( string_free category )
        ( string_free normalized )
        ( string_free direct_dir )
        ( string_free direct_index )
        ^ found
    } {}
    ( string_free normalized )
    ( string_free direct_dir )
    ( string_free direct_index )
    ^ ( skill_find_result F `` `` `` `` )
}

@ skill_find s name → Json {
    : String local ( skills_path )
    ? ( file_exists ( string_data local ) ) {
        : Json direct ( skill_direct_find ( string_data local ) name )
        ? ( skill_find_found direct ) {
            ( string_free local )
            ^ direct
        } {}
        ( json_free direct )
        : Json recursive ( skill_find_in_dir ( string_data local ) ( string_data local ) `` name )
        ? ( skill_find_found recursive ) {
            ( string_free local )
            ^ recursive
        } {}
        ( json_free recursive )
    } {}
    ( string_free local )

    : ( Vec String ) externals ( get_external_skills_dirs_nurl )
    : i n ( vec_len [String] externals )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] externals k )
        ?? e {
            T root → {
                : Json direct2 ( skill_direct_find ( string_data root ) name )
                ? ( skill_find_found direct2 ) {
                    ( skill_free_string_vec externals )
                    ^ direct2
                } {}
                ( json_free direct2 )
                : Json recursive2 ( skill_find_in_dir ( string_data root ) ( string_data root ) `` name )
                ? ( skill_find_found recursive2 ) {
                    ( skill_free_string_vec externals )
                    ^ recursive2
                } {}
                ( json_free recursive2 )
            }
            F → {}
        }
        = k + k 1
    }
    ( skill_free_string_vec externals )
    ^ ( skill_find_result F `` `` `` `` )
}

@ skill_file_path_safe s file_path → b {
    ? == ( nurl_str_len file_path ) 0 { ^ T } {}
    ? ( path_is_absolute file_path ) { ^ F } {}
    : String raw ( string_from file_path )
    : b bad F
    ? ( string_contains raw `..` ) { = bad T } {}
    ? ( string_contains raw `\\` ) { = bad T } {}
    ( string_free raw )
    ^ ! bad
}

@ skill_path_has_segment s rel s segment → b {
    : String raw ( string_from rel )
    : ( Vec String ) parts ( string_split raw `/` )
    ( string_free raw )
    : i n ( vec_len [String] parts )
    : ~ b found F
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] parts k )
        ?? e {
            T part → {
                ? != ( nurl_str_eq ( string_data part ) segment ) 0 {
                    = found T
                } {}
            }
            F → {}
        }
        = k + k 1
    }
    ( skill_free_string_vec parts )
    ^ found
}

@ skill_string_has_slash String value → b {
    : i n ( string_len value )
    : ~ i k 0
    ~ < k n {
        ? == ( string_get value k ) 47 { ^ T } {}
        = k + k 1
    }
    ^ F
}

@ skill_ignore_pattern_matches s rel s pattern → b {
    ? == ( nurl_str_len pattern ) 0 { ^ F } {}
    : String pat ( string_from pattern )
    : String clean ( string_trim pat )
    ( string_free pat )
    : i clean_len ( string_len clean )
    ? == clean_len 0 {
        ( string_free clean )
        ^ F
    } {}
    ? ( string_starts_with clean `#` ) {
        ( string_free clean )
        ^ F
    } {}

    : String normalized ( string_from ( string_data clean ) )
    ? ( string_starts_with normalized `/` ) {
        : i n0 ( string_len normalized )
        : String without_lead ( string_substr normalized 1 - n0 1 )
        ( string_free normalized )
        = normalized without_lead
    } {}

    : b matched F
    ? ( string_ends_with normalized `/` ) {
        : i n1 ( string_len normalized )
        : String dir_pat ( string_substr normalized 0 - n1 1 )
        ? ( skill_string_has_slash dir_pat ) {
            ? != ( nurl_str_eq rel ( string_data normalized ) ) 0 {
                = matched T
            } {}
        } {
            ? ( skill_path_has_segment rel ( string_data dir_pat ) ) {
                = matched T
            } {}
        }
        ( string_free dir_pat )
    } {
        ? ( string_contains normalized `/` ) {
            ? != ( nurl_str_eq rel ( string_data normalized ) ) 0 {
                = matched T
            } {}
        } {
            ? ( skill_path_has_segment rel ( string_data normalized ) ) {
                = matched T
            } {}
        }
    }
    ( string_free normalized )
    ( string_free clean )
    ^ matched
}

@ skill_path_ignored s skill_dir s rel → b {
    ? == ( nurl_str_len rel ) 0 {
        ^ F
    } {}
    : String ignore_path ( path_join skill_dir `.skillignore` )
    : !String IoErr rd ( read_file ( string_data ignore_path ) )
    ( string_free ignore_path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ~ b ignored F
            : i n ( vec_len [String] lines )
            : ~ i k 0
            ~ < k n {
                : ?String e ( vec_get [String] lines k )
                ?? e {
                    T line → {
                        : String trimmed ( string_trim line )
                        ? ( skill_ignore_pattern_matches rel ( string_data trimmed ) ) {
                            = ignored T
                        } {}
                        ( string_free trimmed )
                    }
                    F → {}
                }
                = k + k 1
            }
            ( skill_free_string_vec lines )
            ^ ignored
        }
        F _ → {}
    }
    ^ F
}

@ skill_collect_files s base s cur s rel Json arr → v {
    : !( Vec String ) IoErr listed ( dir_list cur )
    ?? listed {
        T entries → {
            : i n ( vec_len [String] entries )
            : ~ i k 0
            ~ < k n {
                : ?String e ( vec_get [String] entries k )
                ?? e {
                    T item → {
                        ? ( skill_is_junk_entry ( string_data item ) ) {} {
                            : String child ( path_join cur ( string_data item ) )
                            : String child_rel ( string_new )
                            ? == ( nurl_str_len rel ) 0 {
                                ( string_free child_rel )
                                = child_rel ( string_from ( string_data item ) )
                            } {
                                ( string_free child_rel )
                                = child_rel ( string_from rel )
                                ( string_push_str child_rel `/` )
                                ( string_push_str child_rel ( string_data item ) )
                            }
                            ? ( skill_path_ignored base ( string_data child_rel ) ) {} {
                                : !( Vec String ) IoErr child_list ( dir_list ( string_data child ) )
                                ?? child_list {
                                    T child_entries → {
                                        ( skill_free_string_vec child_entries )
                                        ( skill_collect_files base ( string_data child ) ( string_data child_rel ) arr )
                                    }
                                    F _ → {
                                        ? != ( nurl_str_eq ( string_data child_rel ) `SKILL.md` ) 0 {} {
                                            ( json_arr_push arr ( json_str_lit ( string_data child_rel ) ) )
                                        }
                                    }
                                }
                            }
                            ( string_free child )
                            ( string_free child_rel )
                        }
                    }
                    F → {}
                }
                = k + k 1
            }
            ( skill_free_string_vec entries )
        }
        F _ → {}
    }
}

@ skill_linked_group_for_rel s rel → String {
    : String raw ( string_from rel )
    : ?i slash ( string_index_of raw `/` )
    ?? slash {
        T idx → {
            ? > idx 0 {
                : String group ( string_substr raw 0 idx )
                ( string_free raw )
                ^ group
            } {}
        }
        F → {}
    }
    ( string_free raw )
    ^ ( string_from `root` )
}

@ skill_linked_add_rel s skill_dir s rel Json linked → b {
    ? == ( nurl_str_len rel ) 0 { ^ F } {}
    ? != ( nurl_str_eq rel `SKILL.md` ) 0 { ^ F } {}
    ? ! ( skill_file_path_safe rel ) { ^ F } {}
    ? ( skill_path_ignored skill_dir rel ) { ^ F } {}
    : String base_name ( path_basename rel )
    ? ( skill_is_junk_entry ( string_data base_name ) ) {
        ( string_free base_name )
        ^ F
    } {}
    ( string_free base_name )

    : String target ( path_join skill_dir rel )
    ? ! ( file_exists ( string_data target ) ) {
        ( string_free target )
        ^ F
    } {}

    : !( Vec String ) IoErr maybe_dir ( dir_list ( string_data target ) )
    ?? maybe_dir {
        T children → {
            ( skill_free_string_vec children )
            ( string_free target )
            ^ F
        }
        F _ → {}
    }
    ( string_free target )

    : String group ( skill_linked_group_for_rel rel )
    : ?Json existing ( json_obj_get linked ( string_data group ) )
    ?? existing {
        T arr → {
            ( json_arr_push arr ( json_str_lit rel ) )
        }
        F → {
            : Json arr2 ( json_arr_new )
            ( json_arr_push arr2 ( json_str_lit rel ) )
            ( json_obj_set linked ( string_data group ) arr2 )
        }
    }
    ( string_free group )
    ^ T
}

@ skill_linked_files_from_source_index s skill_dir Json source_index → Json {
    : Json linked ( json_obj_new )
    : ~ b any F
    : ?Json exposed ( json_obj_get source_index `default_expose` )
    ?? exposed {
        T arr → {
            : i n ( json_arr_len arr )
            : ~ i k 0
            ~ < k n {
                : ?Json item ( json_arr_get arr k )
                ?? item {
                    T rel_j → {
                        ? ( skill_linked_add_rel skill_dir ( json_str_data rel_j ) linked ) {
                            = any T
                        } {}
                    }
                    F → {}
                }
                = k + k 1
            }
        }
        F → {}
    }
    ? any { ^ linked } {}
    ( json_free linked )
    ^ ( json_null )
}

@ skill_glob_matches s rel s pattern → b {
    ? != ( nurl_str_eq rel pattern ) 0 { ^ T } {}
    : String pat ( string_from pattern )
    ? ! ( string_contains pat `*` ) {
        ( string_free pat )
        ^ F
    } {}
    : ( Vec String ) parts ( string_split pat `*` )
    ( string_free pat )
    : i n ( vec_len [String] parts )
    ? == n 2 {
        : ?String first_o ( vec_get [String] parts 0 )
        : ?String last_o ( vec_get [String] parts 1 )
        ?? first_o {
            T first → {
                ?? last_o {
                    T last → {
                        : b ok T
                        ? > ( string_len first ) 0 {
                            : String rel_s0 ( string_from rel )
                            ? ! ( string_starts_with rel_s0 ( string_data first ) ) {
                                = ok F
                            } {}
                            ( string_free rel_s0 )
                        } {}
                        ? > ( string_len last ) 0 {
                            : String rel_s ( string_from rel )
                            ? ! ( string_ends_with rel_s ( string_data last ) ) {
                                = ok F
                            } {}
                            ( string_free rel_s )
                        } {}
                        ( skill_free_string_vec parts )
                        ^ ok
                    }
                    F → {}
                }
            }
            F → {}
        }
    } {}
    ( skill_free_string_vec parts )
    ^ F
}

@ skill_contract_rule_path Json rule → String {
    : ?Json path_j ( json_obj_get rule `path` )
    ?? path_j {
        T p → { ^ ( string_from ( json_str_data p ) ) }
        F → {}
    }
    ^ ( string_new )
}

@ skill_contract_rule_reason Json rule s fallback → String {
    : ?Json reason_j ( json_obj_get rule `reason` )
    ?? reason_j {
        T r → { ^ ( string_from ( json_str_data r ) ) }
        F → {}
    }
    : ?Json allowed_j ( json_obj_get rule `allowed_when` )
    ?? allowed_j {
        T a → {
            : String out ( string_from `allowed_when=` )
            ( string_push_str out ( json_str_data a ) )
            ^ out
        }
        F → {}
    }
    ^ ( string_from fallback )
}

@ skill_contract_rule_array_error s skill_name s rel Json arr s rule_kind → String {
    : i n ( json_arr_len arr )
    : ~ i k 0
    ~ < k n {
        : ?Json item ( json_arr_get arr k )
        ?? item {
            T rule → {
                : String pattern ( skill_contract_rule_path rule )
                ? > ( string_len pattern ) 0 {
                    ? ( skill_glob_matches rel ( string_data pattern ) ) {
                        : String reason ( skill_contract_rule_reason rule rule_kind )
                        : b allowed F
                        ? != ( nurl_str_eq rule_kind `conditional_read` ) 0 {
                            ? ( harness_read_unlocked skill_name rel ) {
                                = allowed T
                            } {}
                        } {}
                        ? ! allowed {
                            : String ignored ( harness_record_read_violation skill_name rel rule_kind ( string_data reason ) )
                            ( string_free ignored )
                            : String msg ( string_from `Path violates harness contract ` )
                            ( string_push_str msg rule_kind )
                            ( string_push_str msg ` rule for ` )
                            ( string_push_str msg rel )
                            ? > ( string_len reason ) 0 {
                                ( string_push_str msg `: ` )
                                ( string_push_str msg ( string_data reason ) )
                            } {}
                            ( string_free pattern )
                            ( string_free reason )
                            ^ msg
                        } {}
                        ( string_free reason )
                    } {}
                } {}
                ( string_free pattern )
            }
            F → {}
        }
        = k + k 1
    }
    ^ ( string_new )
}

@ skill_contract_read_error s skill_name s skill_dir s rel → String {
    ? ! ( harness_contract_exists skill_dir ) {
        ^ ( string_new )
    } {}
    : String path ( harness_contract_path skill_dir )
    ? == ( string_len path ) 0 {
        ( string_free path )
        ^ ( string_new )
    } {}
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : !Json ParseErr parsed ( json_parse ( string_data body ) )
            ( string_free body )
            ?? parsed {
                T contract → {
                    : ?Json forbidden ( json_obj_get contract `forbidden_reads` )
                    ?? forbidden {
                        T arr → {
                            : String err ( skill_contract_rule_array_error skill_name rel arr `forbidden_read` )
                            ? > ( string_len err ) 0 {
                                ( json_free contract )
                                ^ err
                            } {}
                            ( string_free err )
                        }
                        F → {}
                    }
                    : ?Json conditional ( json_obj_get contract `conditional_reads` )
                    ?? conditional {
                        T arr2 → {
                            : String err2 ( skill_contract_rule_array_error skill_name rel arr2 `conditional_read` )
                            ? > ( string_len err2 ) 0 {
                                ( json_free contract )
                                ^ err2
                            } {}
                            ( string_free err2 )
                        }
                        F → {}
                    }
                    ( json_free contract )
                }
                F _ → {}
            }
        }
        F _ → {}
    }
    ^ ( string_new )
}

@ skill_mark_active_harness_skill s name s skill_dir → v {
    ? ( harness_contract_exists skill_dir ) {
        : !v IoErr set_name ( env_set `HERMES_NURL_ACTIVE_HARNESS_SKILL_NAME` name )
        ?? set_name { T _ → {} F _ → {} }
        : !v IoErr set_dir ( env_set `HERMES_NURL_ACTIVE_HARNESS_SKILL_DIR` skill_dir )
        ?? set_dir { T _ → {} F _ → {} }
        : Json summary ( harness_contract_summary_for_dir skill_dir )
        : ?Json preflights ( json_obj_get summary `preflight_gates` )
        ?? preflights {
            T arr → {
                ? > ( json_arr_len arr ) 0 {
                    : String names ( harness_string_array_join summary `preflight_gates` )
                    : !v IoErr set_preflights ( env_set `HERMES_NURL_HARNESS_PREFLIGHT_NAMES` ( string_data names ) )
                    ?? set_preflights { T _ → {} F _ → {} }
                    ( string_free names )
                    ( harness_require_preflight `contract declares preflight_gates` )
                } {}
            }
            F → {}
        }
        ( json_free summary )
    } {}
}

@ skill_abs_path s path → String {
    ? ( path_is_absolute path ) {
        ^ ( path_normalize path )
    } {}
    : !String IoErr cwd ( env_cwd )
    ?? cwd {
        T cur → {
            : String joined ( path_join ( string_data cur ) path )
            ( string_free cur )
            : String norm ( path_normalize ( string_data joined ) )
            ( string_free joined )
            ^ norm
        }
        F _ → {}
    }
    ^ ( path_normalize path )
}

@ skill_active_read_guard_error s path → String {
    : ?String dir_o ( env_get `HERMES_NURL_ACTIVE_HARNESS_SKILL_DIR` )
    ?? dir_o {
        T dir_raw → {
            : ?String name_o ( env_get `HERMES_NURL_ACTIVE_HARNESS_SKILL_NAME` )
            ?? name_o {
                T skill_name → {
                    : String skill_dir ( path_normalize ( string_data dir_raw ) )
                    : String got_path ( skill_abs_path path )
                    : String prefix ( string_from ( string_data skill_dir ) )
                    ( string_push_str prefix `/` )
                    ? ( string_starts_with got_path ( string_data prefix ) ) {
                        : i got_n ( string_len got_path )
                        : i prefix_n ( string_len prefix )
                        : String rel ( string_substr got_path prefix_n - got_n prefix_n )
                        : String err ( skill_contract_read_error ( string_data skill_name ) ( string_data skill_dir ) ( string_data rel ) )
                        ( string_free rel )
                        ( string_free prefix )
                        ( string_free got_path )
                        ( string_free skill_dir )
                        ( string_free skill_name )
                        ( string_free dir_raw )
                        ^ err
                    } {}
                    ( string_free prefix )
                    ( string_free got_path )
                    ( string_free skill_dir )
                    ( string_free skill_name )
                }
                F → {}
            }
            ( string_free dir_raw )
        }
        F → {}
    }
    ^ ( string_new )
}

@ skill_linked_files_json s skill_dir → Json {
    ? ( harness_contract_exists skill_dir ) {
        : Json summary ( harness_contract_summary_for_dir skill_dir )
        : ?Json source_index ( json_obj_get summary `source_index` )
        ?? source_index {
            T si → {
                : Json contract_linked ( skill_linked_files_from_source_index skill_dir si )
                ( json_free summary )
                ^ contract_linked
            }
            F → {}
        }
        ( json_free summary )
    } {}

    : Json linked ( json_obj_new )
    : ~ b any F

    : Json refs ( json_arr_new )
    : String refs_dir ( path_join skill_dir `references` )
    ? ( file_exists ( string_data refs_dir ) ) {
        ( skill_collect_files skill_dir ( string_data refs_dir ) `references` refs )
    } {}
    ? > ( json_arr_len refs ) 0 {
        ( json_obj_set linked `references` refs )
        = any T
    } {
        ( json_free refs )
    }
    ( string_free refs_dir )

    : Json templates ( json_arr_new )
    : String templates_dir ( path_join skill_dir `templates` )
    ? ( file_exists ( string_data templates_dir ) ) {
        ( skill_collect_files skill_dir ( string_data templates_dir ) `templates` templates )
    } {}
    ? > ( json_arr_len templates ) 0 {
        ( json_obj_set linked `templates` templates )
        = any T
    } {
        ( json_free templates )
    }
    ( string_free templates_dir )

    : Json assets ( json_arr_new )
    : String assets_dir ( path_join skill_dir `assets` )
    ? ( file_exists ( string_data assets_dir ) ) {
        ( skill_collect_files skill_dir ( string_data assets_dir ) `assets` assets )
    } {}
    ? > ( json_arr_len assets ) 0 {
        ( json_obj_set linked `assets` assets )
        = any T
    } {
        ( json_free assets )
    }
    ( string_free assets_dir )

    : Json scripts ( json_arr_new )
    : String scripts_dir ( path_join skill_dir `scripts` )
    ? ( file_exists ( string_data scripts_dir ) ) {
        ( skill_collect_files skill_dir ( string_data scripts_dir ) `scripts` scripts )
    } {}
    ? > ( json_arr_len scripts ) 0 {
        ( json_obj_set linked `scripts` scripts )
        = any T
    } {
        ( json_free scripts )
    }
    ( string_free scripts_dir )

    : Json commands ( json_arr_new )
    : String commands_dir ( path_join skill_dir `commands` )
    ? ( file_exists ( string_data commands_dir ) ) {
        ( skill_collect_files skill_dir ( string_data commands_dir ) `commands` commands )
    } {}
    ? > ( json_arr_len commands ) 0 {
        ( json_obj_set linked `commands` commands )
        = any T
    } {
        ( json_free commands )
    }
    ( string_free commands_dir )

    : Json brands ( json_arr_new )
    : String brands_dir ( path_join skill_dir `brands` )
    ? ( file_exists ( string_data brands_dir ) ) {
        ( skill_collect_files skill_dir ( string_data brands_dir ) `brands` brands )
    } {}
    ? > ( json_arr_len brands ) 0 {
        ( json_obj_set linked `brands` brands )
        = any T
    } {
        ( json_free brands )
    }
    ( string_free brands_dir )

    ? any { ^ linked } {}
    ( json_free linked )
    ^ ( json_null )
}

@ skill_error_json s msg → String {
    : Json result ( json_obj_new )
    ( json_obj_set result `success` ( json_bool F ) )
    ( json_obj_set result `error` ( json_str_lit msg ) )
    : String out ( json_stringify result )
    ( json_free result )
    ^ out
}

@ skill_view_json s name s file_path → String {
    ? == ( nurl_str_len name ) 0 {
        ^ ( skill_error_json `skill_view requires non-empty name` )
    } {}
    : Json found ( skill_find name )
    ? ! ( skill_find_found found ) {
        ( json_free found )
        ^ ( skill_error_json `Skill not found. Use skills_list to inspect available skills.` )
    } {}

    : s skill_md ( skill_find_path found `path` )
    : s skill_dir ( skill_find_path found `dir` )
    : s category ( skill_find_path found `category` )
    ( skill_mark_active_harness_skill name skill_dir )

    ? ! ( skill_file_path_safe file_path ) {
        ( json_free found )
        ^ ( skill_error_json `Path traversal is not allowed. Use a relative file path inside the skill directory.` )
    } {}
    ? ( skill_path_ignored skill_dir file_path ) {
        ( json_free found )
        ^ ( skill_error_json `Path is ignored by this skill's .skillignore.` )
    } {}

    ? > ( nurl_str_len file_path ) 0 {
        : String read_err ( skill_contract_read_error name skill_dir file_path )
        ? > ( string_len read_err ) 0 {
            : String out_err ( skill_error_json ( string_data read_err ) )
            ( string_free read_err )
            ( json_free found )
            ^ out_err
        } {}
        ( string_free read_err )
        : String target ( path_join skill_dir file_path )
        : !String IoErr rd_linked ( read_file ( string_data target ) )
        ?? rd_linked {
            T linked_content → {
                : Json result ( json_obj_new )
                ( json_obj_set result `success` ( json_bool T ) )
                ( json_obj_set result `name` ( json_str_lit name ) )
                ( json_obj_set result `file` ( json_str_lit file_path ) )
                ( json_obj_set result `content` ( json_str_lit ( string_data linked_content ) ) )
                ( json_obj_set result `skill_dir` ( json_str_lit skill_dir ) )
                : String out ( json_stringify result )
                ( json_free result )
                ( string_free linked_content )
                ( string_free target )
                ( json_free found )
                ^ out
            }
            F e → {
                : IoErr ie # IoErr e
                : String msg ( string_from `Failed to read skill linked file: ` )
                ( string_push_str msg ( io_err_msg ie ) )
                : String out ( skill_error_json ( string_data msg ) )
                ( string_free msg )
                ( string_free target )
                ( json_free found )
                ^ out
            }
        }
    } {}

    : !String IoErr rd ( read_file skill_md )
    ?? rd {
        T content → {
            ? ! ( skill_matches_platform_nurl content ) {
                ( string_free content )
                ( json_free found )
                ^ ( skill_error_json `Skill is not supported on this platform.` )
            } {}
            : ( Vec String ) disabled ( skill_config_list `disabled` )
            : String resolved_name ( skill_name_from_content content name )
            ? ( skill_vec_contains disabled ( string_data resolved_name ) ) {
                ( skill_free_string_vec disabled )
                ( string_free content )
                ( string_free resolved_name )
                ( json_free found )
                ^ ( skill_error_json `Skill is disabled in config.yaml skills.disabled.` )
            } {}
            ( skill_free_string_vec disabled )

            : String desc ( skill_description content )
            : Json result ( json_obj_new )
            ( json_obj_set result `success` ( json_bool T ) )
            ( json_obj_set result `name` ( json_str_lit ( string_data resolved_name ) ) )
            ( json_obj_set result `description` ( json_str_lit ( string_data desc ) ) )
            ( json_obj_set result `content` ( json_str_lit ( string_data content ) ) )
            ( json_obj_set result `path` ( json_str_lit skill_md ) )
            ( json_obj_set result `skill_dir` ( json_str_lit skill_dir ) )
            ? > ( nurl_str_len category ) 0 {
                ( json_obj_set result `category` ( json_str_lit category ) )
            } {
                ( json_obj_set result `category` ( json_null ) )
            }
            ( json_obj_set result `linked_files` ( skill_linked_files_json skill_dir ) )
            ? ( harness_contract_exists skill_dir ) {
                ( json_obj_set result `harness` ( harness_contract_summary_for_dir skill_dir ) )
            } {}
            ( json_obj_set result `usage_hint` ( json_str_lit `To view linked files, call skill_view with the same name and a file_path such as references/api.md, templates/example.md, assets/data.json, scripts/run.sh, commands/mint.md, or brands/example/prompts.md.` ) )
            ? ( skill_content_warns content ) {
                : Json warnings ( json_arr_new )
                ( json_arr_push warnings ( json_str_lit `skill content contains patterns that may indicate prompt injection; load with care` ) )
                ( json_obj_set result `warnings` warnings )
            } {}
            : String out ( json_stringify result )
            ( json_free result )
            ( string_free resolved_name )
            ( string_free desc )
            ( string_free content )
            ( json_free found )
            ^ out
        }
        F e → {
            : IoErr ie # IoErr e
            : String msg ( string_from `Failed to read skill: ` )
            ( string_push_str msg ( io_err_msg ie ) )
            : String out ( skill_error_json ( string_data msg ) )
            ( string_free msg )
            ( json_free found )
            ^ out
        }
    }
}

@ skills_list_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )
    : Json props ( json_obj_new )
    : Json category ( json_obj_new )
    ( json_obj_set category `type` ( json_str_lit `string` ) )
    ( json_obj_set category `description` ( json_str_lit `Optional category filter, such as mlops or writing.` ) )
    ( json_obj_set props `category` category )
    ( json_obj_set schema `properties` props )
    ( json_obj_set schema `required` ( json_arr_new ) )
    ^ schema
}

@ skill_view_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )
    : Json props ( json_obj_new )
    : Json name ( json_obj_new )
    ( json_obj_set name `type` ( json_str_lit `string` ) )
    ( json_obj_set name `description` ( json_str_lit `Skill name from skills_list, or a categorized path such as mlops/axolotl.` ) )
    : Json file_path ( json_obj_new )
    ( json_obj_set file_path `type` ( json_str_lit `string` ) )
    ( json_obj_set file_path `description` ( json_str_lit `Optional linked file path inside the skill directory, such as references/api.md.` ) )
    ( json_obj_set props `name` name )
    ( json_obj_set props `file_path` file_path )
    ( json_obj_set schema `properties` props )
    : Json req ( json_arr_new )
    ( json_arr_push req ( json_str_lit `name` ) )
    ( json_obj_set schema `required` req )
    ^ schema
}

@ skills_prompt_scan_dir s root s dir s category ( Vec String ) seen ( Vec String ) disabled String out → v {
    : b has_skill ( skill_dir_has_index dir )
    ? has_skill {
        : String index ( path_join dir `SKILL.md` )
        : !String IoErr rd ( read_file ( string_data index ) )
        ?? rd {
            T content → {
                ? ( skill_matches_platform_nurl content ) {
                    : String base ( path_basename dir )
                    : String name ( skill_name_from_content content ( string_data base ) )
                    ( string_free base )
                    : b already_seen ( skill_vec_contains seen ( string_data name ) )
                    : b is_disabled ( skill_vec_contains disabled ( string_data name ) )
                    ? | already_seen is_disabled {} {
                        : String desc ( skill_description content )
                        ( vec_push [String] seen ( string_from ( string_data name ) ) )
                        ( string_push_str out `- ` )
                        ? > ( nurl_str_len category ) 0 {
                            ( string_push_str out category )
                            ( string_push_str out `/` )
                        } {}
                        ( string_push_str out ( string_data name ) )
                        ? > ( string_len desc ) 0 {
                            ( string_push_str out `: ` )
                            ( string_push_str out ( string_data desc ) )
                        } {}
                        : String harness_fragment ( harness_contract_prompt_fragment dir )
                        ? > ( string_len harness_fragment ) 0 {
                            ( string_push_str out ( string_data harness_fragment ) )
                        } {}
                        ( string_free harness_fragment )
                        ( string_push_str out `\n` )
                        ( string_free desc )
                    }
                    ( string_free name )
                } {}
                ( string_free content )
            }
            F _ → {}
        }
        ( string_free index )
    } {
        : !( Vec String ) IoErr listed ( dir_list dir )
        ?? listed {
            T entries → {
                : i n ( vec_len [String] entries )
                : ~ i k 0
                ~ < k n {
                    : ?String e ( vec_get [String] entries k )
                    ?? e {
                        T item → {
                            ? ( skill_is_excluded_dir ( string_data item ) ) {} {
                                : String child ( path_join dir ( string_data item ) )
                                : !( Vec String ) IoErr child_list ( dir_list ( string_data child ) )
                                ?? child_list {
                                    T child_entries → {
                                        ( skill_free_string_vec child_entries )
                                        : b child_has_skill ( skill_dir_has_index ( string_data child ) )
                                        : String next_category ( string_new )
                                        ? child_has_skill {
                                            ( string_free next_category )
                                            = next_category ( string_from category )
                                        } {
                                            ? == ( nurl_str_len category ) 0 {
                                                ( string_free next_category )
                                                = next_category ( string_from ( string_data item ) )
                                            } {
                                                ( string_free next_category )
                                                = next_category ( string_from category )
                                                ( string_push_str next_category `/` )
                                                ( string_push_str next_category ( string_data item ) )
                                            }
                                        }
                                        ( skills_prompt_scan_dir root ( string_data child ) ( string_data next_category ) seen disabled out )
                                        ( string_free next_category )
                                    }
                                    F _ → {}
                                }
                                ( string_free child )
                            }
                        }
                        F → {}
                    }
                    = k + k 1
                }
                ( skill_free_string_vec entries )
            }
            F _ → {}
        }
    }
}

@ skills_prompt_index → String {
    : String out ( string_new )
    : ( Vec String ) seen ( vec_new [String] )
    : ( Vec String ) disabled ( skill_config_list `disabled` )

    : String local ( skills_path )
    ? ( file_exists ( string_data local ) ) {
        ( skills_prompt_scan_dir ( string_data local ) ( string_data local ) `` seen disabled out )
    } {}
    ( string_free local )

    : ( Vec String ) externals ( get_external_skills_dirs_nurl )
    : i n ( vec_len [String] externals )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] externals k )
        ?? e {
            T root → {
                ( skills_prompt_scan_dir ( string_data root ) ( string_data root ) `` seen disabled out )
            }
            F → {}
        }
        = k + k 1
    }
    ( skill_free_string_vec externals )
    ( skill_free_string_vec disabled )
    ( skill_free_string_vec seen )
    ^ out
}

@ build_skills_system_prompt → String {
    : String index ( skills_prompt_index )
    ? == ( string_len index ) 0 {
        ( string_free index )
        ^ ( string_new )
    } {}
    : String out ( string_with_cap + ( string_len index ) 1024 )
    ( string_push_str out `## Skills (mandatory)\nBefore replying, scan the skills below. If a skill matches or is even partially relevant to the task, load it with skill_view(name) and follow its instructions. Skills contain specialized knowledge, scripts, templates, and workflow conventions. If a loaded workflow needs a capability provided by another available skill, load and use that skill instead of inventing an ad hoc substitute. If a loaded skill exposes a scripts/ helper for an API or export step, use that helper instead of hand-writing curl, Python urllib, or token-bearing shell commands. Skills marked with [harness ...] have contract-backed evidence, dependent skill, and gate expectations; do not report completion until the relevant contract evidence and gates are satisfied. Only proceed without loading a skill if genuinely none are relevant.\n\n<available_skills>\n` )
    ( string_push_str out ( string_data index ) )
    ( string_push_str out `</available_skills>` )
    ( string_free index )
    ^ out
}
