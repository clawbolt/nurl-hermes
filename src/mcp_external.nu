// External MCP stdio tool discovery and dispatch for Hermes NURL.
//
// This ports the first practical slice of tools/mcp_tool.py and
// hermes_cli/mcp_config.py: read `mcp_servers` from config.yaml, discover stdio
// server tools, expose them with `mcp__<server>__<tool>` names, and dispatch
// calls through NURL stdlib's MCP stdio client.

$ `stdlib/ext/anthropic.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/mcp_stdio.nu`
$ `stdlib/std/fs.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/config.nu`
$ `nurl/src/tools_local.nu`

: McpStdioServerConfig {
    String name
    String command
    ( Vec String ) args
    i timeout_ms
}

@ mcp_clone_args ( Vec String ) src → ( Vec String ) {
    : ( Vec String ) out ( vec_new [String] )
    : i n ( vec_len [String] src )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] src k )
        ?? e {
            T s → ( vec_push [String] out ( string_from ( string_data s ) ) )
            F → {}
        }
        = k + k 1
    }
    ^ out
}

@ mcp_config_free McpStdioServerConfig cfg → v {
    : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
    ( string_free . cfg name )
    ( string_free . cfg command )
    ( vec_free_with [String] . cfg args drop_str )
}

@ mcp_config_key_name String trimmed → String {
    : ?i colon ( string_index_of trimmed `:` )
    ?? colon {
        T idx → {
            : String raw_key ( string_substr trimmed 0 idx )
            : String key ( string_trim raw_key )
            ( string_free raw_key )
            ^ key
        }
        F → {}
    }
    ^ ( string_new )
}

@ mcp_config_line_has_value String trimmed → b {
    : ?i colon ( string_index_of trimmed `:` )
    ?? colon {
        T idx → {
            : i start + idx 1
            : i n ( string_len trimmed )
            : String raw_val ( string_substr trimmed start - n start )
            : String val ( string_trim raw_val )
            ( string_free raw_val )
            : b has ? > ( string_len val ) 0 T F
            ( string_free val )
            ^ has
        }
        F → {}
    }
    ^ F
}

@ mcp_parse_args_list String raw → ( Vec String ) {
    : ( Vec String ) out ( vec_new [String] )
    : String trimmed ( string_trim raw )
    : i n ( string_len trimmed )
    ? & >= n 2 == ( string_get trimmed 0 ) 91 {
        : i last ( string_get trimmed - n 1 )
        ? == last 93 {
            : String inner ( string_substr trimmed 1 - n 2 )
            : ( Vec String ) parts ( string_split inner `,` )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }
            : i count ( vec_len [String] parts )
            : ~ i k 0
            ~ < k count {
                : ?String e ( vec_get [String] parts k )
                ?? e {
                    T part → {
                        : String piece_trim ( string_trim part )
                        ? > ( string_len piece_trim ) 0 {
                            : String piece ( config_unquote piece_trim )
                            ( vec_push [String] out piece )
                        } {
                            ( string_free piece_trim )
                        }
                    }
                    F → {}
                }
                = k + k 1
            }
            ( vec_free_with [String] parts drop_str )
            ( string_free inner )
            ( string_free trimmed )
            ^ out
        } {}
    } {}

    ? > ( string_len trimmed ) 0 {
        : String value ( config_unquote trimmed )
        ( vec_push [String] out value )
    } {
        ( string_free trimmed )
    }
    ^ out
}

@ mcp_push_current ( Vec McpStdioServerConfig ) servers String name String command ( Vec String ) args i timeout_ms → v {
    ? & > ( string_len name ) 0 > ( string_len command ) 0 {
        : McpStdioServerConfig cfg @ McpStdioServerConfig {
            ( string_from ( string_data name ) )
            ( string_from ( string_data command ) )
            ( mcp_clone_args args )
            timeout_ms
        }
        ( vec_push [McpStdioServerConfig] servers cfg )
    } {}
}

@ hermes_mcp_stdio_servers → ( Vec McpStdioServerConfig ) {
    : ( Vec McpStdioServerConfig ) servers ( vec_new [McpStdioServerConfig] )
    : String path ( hermes_config_path )
    : !String IoErr rd ( read_file ( string_data path ) )
    ( string_free path )
    ?? rd {
        T body → {
            : ( Vec String ) lines ( string_split body `\n` )
            ( string_free body )
            : ( @ v String ) drop_str \ String s → v { ( string_free s ) }

            : ~ b in_mcp F
            : ~ b in_server F
            : ~ String cur_name ( string_new )
            : ~ String cur_command ( string_new )
            : ~ ( Vec String ) cur_args ( vec_new [String] )
            : ~ i cur_timeout 120000

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
                                ? ( config_line_key_is trimmed `mcp_servers` ) {
                                    = in_mcp T
                                } {
                                    ? in_server {
                                        ( mcp_push_current servers cur_name cur_command cur_args cur_timeout )
                                        : ( @ v String ) drop_arg \ String s → v { ( string_free s ) }
                                        ( vec_free_with [String] cur_args drop_arg )
                                        ( string_free cur_name )
                                        ( string_free cur_command )
                                        = cur_name ( string_new )
                                        = cur_command ( string_new )
                                        = cur_args ( vec_new [String] )
                                        = cur_timeout 120000
                                        = in_server F
                                    } {}
                                    = in_mcp F
                                }
                            } {
                                ? & in_mcp == indent 2 {
                                    ? in_server {
                                        ( mcp_push_current servers cur_name cur_command cur_args cur_timeout )
                                        : ( @ v String ) drop_arg2 \ String s → v { ( string_free s ) }
                                        ( vec_free_with [String] cur_args drop_arg2 )
                                        ( string_free cur_name )
                                        ( string_free cur_command )
                                        = cur_args ( vec_new [String] )
                                        = cur_timeout 120000
                                    } {}
                                    ( string_free cur_name )
                                    = cur_name ( mcp_config_key_name trimmed )
                                    ( string_free cur_command )
                                    = cur_command ( string_new )
                                    = in_server T
                                } {
                                    ? & in_mcp in_server {
                                        : String cmd_value ( config_key_value trimmed `command` )
                                        ? > ( string_len cmd_value ) 0 {
                                            ( string_free cur_command )
                                            = cur_command cmd_value
                                        } {
                                            ( string_free cmd_value )
                                            : String args_value ( config_key_value trimmed `args` )
                                            ? > ( string_len args_value ) 0 {
                                                : ( @ v String ) drop_arg3 \ String s → v { ( string_free s ) }
                                                ( vec_free_with [String] cur_args drop_arg3 )
                                                = cur_args ( mcp_parse_args_list args_value )
                                            } {
                                                ( string_free args_value )
                                                : String timeout_value ( config_key_value trimmed `timeout` )
                                                ? > ( string_len timeout_value ) 0 {
                                                    : !i ParseErr parsed_timeout ( string_to_int timeout_value )
                                                    ?? parsed_timeout {
                                                        T seconds → {
                                                            ? > seconds 0 { = cur_timeout * seconds 1000 } {}
                                                        }
                                                        F _ → {}
                                                    }
                                                } {}
                                                ( string_free timeout_value )
                                            }
                                        }
                                    } {}
                                }
                            }
                        }
                        ( string_free trimmed )
                    }
                    F → {}
                }
                = i + i 1
            }
            ? in_server {
                ( mcp_push_current servers cur_name cur_command cur_args cur_timeout )
            } {}
            : ( @ v String ) drop_last_arg \ String s → v { ( string_free s ) }
            ( vec_free_with [String] cur_args drop_last_arg )
            ( string_free cur_name )
            ( string_free cur_command )
            ( vec_free_with [String] lines drop_str )
        }
        F _ → {}
    }
    ^ servers
}

@ mcp_args_to_raw ( Vec String ) args → ( Vec s ) {
    : ( Vec s ) out ( vec_new [s] )
    : i n ( vec_len [String] args )
    : ~ i k 0
    ~ < k n {
        : ?String e ( vec_get [String] args k )
        ?? e {
            T s → ( vec_push [s] out ( string_data s ) )
            F → {}
        }
        = k + k 1
    }
    ^ out
}

@ mcp_prefixed_name s server s tool → String {
    : String out ( string_with_cap + + ( nurl_str_len server ) ( nurl_str_len tool ) 8 )
    ( string_push_str out `mcp__` )
    ( string_push_str out server )
    ( string_push_str out `__` )
    ( string_push_str out tool )
    ^ out
}

@ mcp_tool_name_matches s prefixed s server → b {
    : String prefix ( string_from `mcp__` )
    ( string_push_str prefix server )
    ( string_push_str prefix `__` )
    : String name ( string_from prefixed )
    : b ok ( string_starts_with name ( string_data prefix ) )
    ( string_free prefix )
    ( string_free name )
    ^ ok
}

@ mcp_unprefix_tool_name s prefixed s server → String {
    : String prefix ( string_from `mcp__` )
    ( string_push_str prefix server )
    ( string_push_str prefix `__` )
    : i start ( string_len prefix )
    : i n ( nurl_str_len prefixed )
    : String raw ( string_from prefixed )
    : String out ( string_substr raw start - n start )
    ( string_free prefix )
    ( string_free raw )
    ^ out
}

@ mcp_schema_or_empty Json tool → Json {
    : ?Json schema ( json_obj_get tool `inputSchema` )
    ?? schema {
        T j → { ^ ( json_clone j ) }
        F → {}
    }
    : Json empty ( json_obj_new )
    ( json_obj_set empty `type` ( json_str_lit `object` ) )
    ^ empty
}

@ mcp_tool_description Json tool → s {
    : ?Json desc ( json_obj_get tool `description` )
    ?? desc {
        T j → { ^ ( json_str_data j ) }
        F → {}
    }
    ^ `External MCP tool`
}

@ add_external_mcp_claude_tools ( Vec Json ) tools → v {
    : ( Vec McpStdioServerConfig ) servers ( hermes_mcp_stdio_servers )
    : ( @ v McpStdioServerConfig ) drop_cfg \ McpStdioServerConfig cfg → v { ( mcp_config_free cfg ) }
    : i sn ( vec_len [McpStdioServerConfig] servers )
    : ~ i si 0
    ~ < si sn {
        : ?McpStdioServerConfig c ( vec_get [McpStdioServerConfig] servers si )
        ?? c {
            T cfg → {
                : ( Vec s ) raw_args ( mcp_args_to_raw . cfg args )
                : !McpStdioClient McpStdioErr spawned ( mcp_stdio_spawn ( string_data . cfg command ) raw_args )
                ( vec_free [s] raw_args )
                ?? spawned {
                    T client → {
                        : !Json McpStdioErr init ( mcp_stdio_initialize client `hermes-nurl` ( VERSION ) )
                        ?? init { T r → ( json_free r ) F _ → {} }
                        : !( Vec Json ) McpStdioErr listed ( mcp_stdio_tools_list client )
                        ?? listed {
                            T remote_tools → {
                                : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
                                : i tn ( vec_len [Json] remote_tools )
                                : ~ i ti 0
                                ~ < ti tn {
                                    : ?Json te ( vec_get [Json] remote_tools ti )
                                    ?? te {
                                        T tool → {
                                            : ?Json name_j ( json_obj_get tool `name` )
                                            ?? name_j {
                                                T nj → {
                                                    : String pname ( mcp_prefixed_name ( string_data . cfg name ) ( json_str_data nj ) )
                                                    ( vec_push [Json] tools
                                                    ( claude_tool_def ( string_data pname )
                                                    ( mcp_tool_description tool )
                                                    ( mcp_schema_or_empty tool ) ) )
                                                    ( string_free pname )
                                                }
                                                F → {}
                                            }
                                        }
                                        F → {}
                                    }
                                    = ti + ti 1
                                }
                                ( vec_free_with [Json] remote_tools drop_json )
                            }
                            F _ → {}
                        }
                        ( mcp_stdio_free client )
                    }
                    F _ → {}
                }
            }
            F → {}
        }
        = si + si 1
    }
    ( vec_free_with [McpStdioServerConfig] servers drop_cfg )
}

@ add_external_mcp_openai_tools ( Vec Json ) tools → v {
    : ( Vec McpStdioServerConfig ) servers ( hermes_mcp_stdio_servers )
    : ( @ v McpStdioServerConfig ) drop_cfg \ McpStdioServerConfig cfg → v { ( mcp_config_free cfg ) }
    : i sn ( vec_len [McpStdioServerConfig] servers )
    : ~ i si 0
    ~ < si sn {
        : ?McpStdioServerConfig c ( vec_get [McpStdioServerConfig] servers si )
        ?? c {
            T cfg → {
                : ( Vec s ) raw_args ( mcp_args_to_raw . cfg args )
                : !McpStdioClient McpStdioErr spawned ( mcp_stdio_spawn ( string_data . cfg command ) raw_args )
                ( vec_free [s] raw_args )
                ?? spawned {
                    T client → {
                        : !Json McpStdioErr init ( mcp_stdio_initialize client `hermes-nurl` ( VERSION ) )
                        ?? init { T r → ( json_free r ) F _ → {} }
                        : !( Vec Json ) McpStdioErr listed ( mcp_stdio_tools_list client )
                        ?? listed {
                            T remote_tools → {
                                : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
                                : i tn ( vec_len [Json] remote_tools )
                                : ~ i ti 0
                                ~ < ti tn {
                                    : ?Json te ( vec_get [Json] remote_tools ti )
                                    ?? te {
                                        T tool → {
                                            : ?Json name_j ( json_obj_get tool `name` )
                                            ?? name_j {
                                                T nj → {
                                                    : String pname ( mcp_prefixed_name ( string_data . cfg name ) ( json_str_data nj ) )
                                                    ( vec_push [Json] tools
                                                    ( openai_compat_tool_def ( string_data pname )
                                                    ( mcp_tool_description tool )
                                                    ( mcp_schema_or_empty tool ) ) )
                                                    ( string_free pname )
                                                }
                                                F → {}
                                            }
                                        }
                                        F → {}
                                    }
                                    = ti + ti 1
                                }
                                ( vec_free_with [Json] remote_tools drop_json )
                            }
                            F _ → {}
                        }
                        ( mcp_stdio_free client )
                    }
                    F _ → {}
                }
            }
            F → {}
        }
        = si + si 1
    }
    ( vec_free_with [McpStdioServerConfig] servers drop_cfg )
}

@ build_agent_claude_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( build_local_claude_tools )
    ( add_external_mcp_claude_tools tools )
    ^ tools
}

@ build_agent_openai_tools → ( Vec Json ) {
    : ( Vec Json ) tools ( build_local_openai_tools )
    ( add_external_mcp_openai_tools tools )
    ^ tools
}

@ mcp_response_to_text Json resp → String {
    ? ( mcp_stdio_response_is_error resp ) {
        : String err ( string_from `error: external MCP call failed: ` )
        ( string_push_str err ( mcp_stdio_response_error_message resp ) )
        ^ err
    } {}

    : ?Json result ( json_obj_get resp `result` )
    ?? result {
        T res → {
            : ~ b is_error F
            : ?Json ie ( json_obj_get res `isError` )
            ?? ie { T j → { = is_error ( json_bool_val j ) } F → {} }
            : String out ( string_with_cap 256 )
            ? is_error { ( string_push_str out `error: ` ) } {}
            : ?Json content ( json_obj_get res `content` )
            ?? content {
                T arr → {
                    : i n ( json_arr_len arr )
                    : ~ i k 0
                    ~ < k n {
                        : ?Json e ( json_arr_get arr k )
                        ?? e {
                            T item → {
                                : ?Json text_j ( json_obj_get item `text` )
                                ?? text_j {
                                    T tj → {
                                        ? > ( string_len out ) 0 { ( string_push_str out `\n` ) } {}
                                        ( string_push_str out ( json_str_data tj ) )
                                    }
                                    F → {}
                                }
                            }
                            F → {}
                        }
                        = k + k 1
                    }
                    ? > ( string_len out ) 0 { ^ out } {}
                }
                F → {}
            }
            : String fallback ( json_stringify res )
            ? is_error {
                ( string_push_str out ( string_data fallback ) )
                ( string_free fallback )
                ^ out
            } {}
            ( string_free out )
            ^ fallback
        }
        F → {}
    }
    ^ ( string_from `error: external MCP call returned no result` )
}

@ run_external_mcp_tool s prefixed Json input → String {
    : ( Vec McpStdioServerConfig ) servers ( hermes_mcp_stdio_servers )
    : ( @ v McpStdioServerConfig ) drop_cfg \ McpStdioServerConfig cfg → v { ( mcp_config_free cfg ) }
    : String out ( string_from `error: external MCP tool not found: ` )
    ( string_push_str out prefixed )
    : i sn ( vec_len [McpStdioServerConfig] servers )
    : ~ i si 0
    : ~ b done F
    ~ & < si sn ! done {
        : ?McpStdioServerConfig c ( vec_get [McpStdioServerConfig] servers si )
        ?? c {
            T cfg → {
                ? ( mcp_tool_name_matches prefixed ( string_data . cfg name ) ) {
                    ( string_free out )
                    : String remote_name ( mcp_unprefix_tool_name prefixed ( string_data . cfg name ) )
                    : ( Vec s ) raw_args ( mcp_args_to_raw . cfg args )
                    : !McpStdioClient McpStdioErr spawned ( mcp_stdio_spawn ( string_data . cfg command ) raw_args )
                    ( vec_free [s] raw_args )
                    ?? spawned {
                        T client → {
                            : !Json McpStdioErr init ( mcp_stdio_initialize client `hermes-nurl` ( VERSION ) )
                            ?? init { T r → ( json_free r ) F _ → {} }
                            : !Json McpStdioErr called ( mcp_stdio_tools_call client ( string_data remote_name ) ( json_clone input ) )
                            ?? called {
                                T resp → {
                                    = out ( mcp_response_to_text resp )
                                    ( json_free resp )
                                }
                                F e → {
                                    = out ( string_from `error: external MCP transport failed: ` )
                                    ( string_push_str out ( mcp_stdio_err_name e ) )
                                }
                            }
                            ( mcp_stdio_free client )
                        }
                        F e → {
                            = out ( string_from `error: external MCP spawn failed: ` )
                            ( string_push_str out ( mcp_stdio_err_name e ) )
                        }
                    }
                    ( string_free remote_name )
                    = done T
                } {}
            }
            F → {}
        }
        = si + si 1
    }
    ( vec_free_with [McpStdioServerConfig] servers drop_cfg )
    ^ out
}

@ is_agent_tool s name → b {
    ? ( is_local_tool name ) { ^ T } {}
    : String raw ( string_from name )
    : b external ( string_starts_with raw `mcp__` )
    ( string_free raw )
    ^ external
}

@ run_agent_tool_input s name Json input → String {
    ? ( is_local_tool name ) {
        ^ ( run_local_tool_input name input )
    } {}
    ? ( is_agent_tool name ) {
        ^ ( run_external_mcp_tool name input )
    } {}
    : String unknown ( string_from `error: unknown tool '` )
    ( string_push_str unknown name )
    ( string_push_str unknown `'` )
    ^ unknown
}

@ run_agent_claude_tool Json tu → String {
    : s name ( claude_tool_use_name tu )
    : ?Json input_o ( claude_tool_use_input tu )
    : Json input ?? input_o {
        T j → j
        F → @ Json { JNull }
    }
    ^ ( run_agent_tool_input name input )
}

@ print_configured_mcp_tools → i {
    : ( Vec McpStdioServerConfig ) servers ( hermes_mcp_stdio_servers )
    : ( @ v McpStdioServerConfig ) drop_cfg \ McpStdioServerConfig cfg → v { ( mcp_config_free cfg ) }
    : i sn ( vec_len [McpStdioServerConfig] servers )
    : ~ i si 0
    ~ < si sn {
        : ?McpStdioServerConfig c ( vec_get [McpStdioServerConfig] servers si )
        ?? c {
            T cfg → {
                : ( Vec s ) raw_args ( mcp_args_to_raw . cfg args )
                : !McpStdioClient McpStdioErr spawned ( mcp_stdio_spawn ( string_data . cfg command ) raw_args )
                ( vec_free [s] raw_args )
                ?? spawned {
                    T client → {
                        : !Json McpStdioErr init ( mcp_stdio_initialize client `hermes-nurl` ( VERSION ) )
                        ?? init { T r → ( json_free r ) F _ → {} }
                        : !( Vec Json ) McpStdioErr listed ( mcp_stdio_tools_list client )
                        ?? listed {
                            T remote_tools → {
                                : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
                                : i tn ( vec_len [Json] remote_tools )
                                : ~ i ti 0
                                ~ < ti tn {
                                    : ?Json te ( vec_get [Json] remote_tools ti )
                                    ?? te {
                                        T tool → {
                                            : ?Json name_j ( json_obj_get tool `name` )
                                            ?? name_j {
                                                T nj → {
                                                    : String pname ( mcp_prefixed_name ( string_data . cfg name ) ( json_str_data nj ) )
                                                    ( nurl_print ( string_data pname ) )
                                                    ( nurl_print `\n` )
                                                    ( string_free pname )
                                                }
                                                F → {}
                                            }
                                        }
                                        F → {}
                                    }
                                    = ti + ti 1
                                }
                                ( vec_free_with [Json] remote_tools drop_json )
                            }
                            F e → {
                                ( nurl_eprint `mcp tools/list failed: ` )
                                ( nurl_eprint ( mcp_stdio_err_name e ) )
                                ( nurl_eprint `\n` )
                            }
                        }
                        ( mcp_stdio_free client )
                    }
                    F e → {
                        ( nurl_eprint `mcp spawn failed: ` )
                        ( nurl_eprint ( mcp_stdio_err_name e ) )
                        ( nurl_eprint `\n` )
                    }
                }
            }
            F → {}
        }
        = si + si 1
    }
    ( vec_free_with [McpStdioServerConfig] servers drop_cfg )
    ^ 0
}
