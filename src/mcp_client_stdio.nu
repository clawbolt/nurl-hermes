// Minimal MCP stdio client smoke test for Hermes NURL.
//
// This is intentionally tiny: it proves the NURL runtime can spawn a long-lived
// MCP server, write JSON-RPC requests over stdin, and read newline-delimited
// JSON responses from stdout. The agent loop can grow external MCP tool
// discovery/calls on top of this boundary.

$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/mcp_stdio.nu`
$ `stdlib/core/io.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`

@ argv_args i start → ( Vec s ) {
    : i argc ( env_args_count )
    : ( Vec s ) args ( vec_new [s] )
    : ~ i i start
    ~ < i argc {
        ( vec_push [s] args ( nurl_argv_get i ) )
        = i + i 1
    }
    ^ args
}

@ print_json_line Json j → v {
    : String line ( json_stringify j )
    ( nurl_print ( string_data line ) )
    ( nurl_print `\n` )
    ( string_free line )
}

@ print_tools ( Vec Json ) tools → v {
    : i n ( vec_len [Json] tools )
    : ~ i i 0
    ~ < i n {
        : ?Json e ( vec_get [Json] tools i )
        ?? e {
            T t → { ( print_json_line t ) }
            F → {}
        }
        = i + i 1
    }
}

@ main → i {
    : i argc ( env_args_count )
    ? < argc 2 {
        ( nurl_eprint `usage: hermes-nurl-mcp-client <server-command> [args...]\n` )
        ^ 2
    } {}

    : s cmd ( nurl_argv_get 1 )
    : ( Vec s ) args ( argv_args 2 )
    : !McpStdioClient McpStdioErr spawned ( mcp_stdio_spawn cmd args )
    ( vec_free [s] args )

    ?? spawned {
        T client → {
            : !Json McpStdioErr init ( mcp_stdio_initialize client `hermes-nurl-mcp-client` ( VERSION ) )
            ?? init {
                T resp → {
                    ( print_json_line resp )
                    ( json_free resp )
                }
                F e → {
                    ( nurl_eprint `error: MCP initialize failed: ` )
                    ( nurl_eprint ( mcp_stdio_err_name e ) )
                    ( nurl_eprint `\n` )
                    ( mcp_stdio_free client )
                    ^ 1
                }
            }

            : !( Vec Json ) McpStdioErr listed ( mcp_stdio_tools_list client )
            ?? listed {
                T tools → {
                    ( print_tools tools )
                    : ( @ v Json ) drop_json \ Json e → v { ( json_free e ) }
                    ( vec_free_with [Json] tools drop_json )
                }
                F e → {
                    ( nurl_eprint `error: MCP tools/list failed: ` )
                    ( nurl_eprint ( mcp_stdio_err_name e ) )
                    ( nurl_eprint `\n` )
                    ( mcp_stdio_free client )
                    ^ 1
                }
            }

            : Json echo_args ( json_obj_new )
            ( json_obj_set echo_args `text` ( json_str_lit `nurl-mcp-client-ok` ) )
            : !Json McpStdioErr called ( mcp_stdio_tools_call client `echo` echo_args )
            ?? called {
                T resp → {
                    ( print_json_line resp )
                    ( json_free resp )
                }
                F e → {
                    ( nurl_eprint `error: MCP tools/call failed: ` )
                    ( nurl_eprint ( mcp_stdio_err_name e ) )
                    ( nurl_eprint `\n` )
                    ( mcp_stdio_free client )
                    ^ 1
                }
            }

            ( mcp_stdio_free client )
            ^ 0
        }
        F e → {
            ( nurl_eprint `error: failed to spawn MCP server: ` )
            ( nurl_eprint ( mcp_stdio_err_name e ) )
            ( nurl_eprint `\n` )
            ^ 1
        }
    }
}
