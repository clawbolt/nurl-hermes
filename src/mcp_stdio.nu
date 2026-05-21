// hermes-nurl MCP stdio server prototype.
//
// This is the first protocol boundary for the NURL rewrite: small,
// deterministic, and compatible with any MCP client that can speak
// newline-delimited JSON-RPC over stdio.

$ `stdlib/ext/mcp.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/std/process.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`
$ `nurl/src/tools_local.nu`

@ empty_object_schema → Json {
    : Json schema ( json_obj_new )
    ( json_obj_set schema `type` ( json_str_lit `object` ) )
    ( json_obj_set schema `properties` ( json_obj_new ) )
    ^ schema
}

@ build_tools_list → ( Vec Json ) {
    : ( Vec Json ) tools ( vec_new [Json] )
    ( vec_push [Json] tools
    ( mcp_tool_descriptor `hermes_nurl_status`
    `Return status information for the Hermes NURL prototype.`
    ( empty_object_schema ) ) )

    ( vec_push [Json] tools
    ( mcp_tool_descriptor `echo`
    `Echo the supplied text. Used as a transport smoke test.`
    ( one_string_schema `text` `Text to echo` ) ) )

    ( vec_push [Json] tools
    ( mcp_tool_descriptor `hermes_nurl_chat`
    `Run the Hermes NURL agent binary for a single prompt.`
    ( one_string_schema `prompt` `Prompt to send to the Hermes NURL agent` ) ) )

    ( add_local_mcp_tools tools )
    ^ tools
}

@ run_status → Json {
    : String out ( string_from `hermes-nurl-mcp ` )
    ( string_push_str out ( VERSION ) )
    ( string_push_str out ` ready` )
    : Json result ( mcp_tool_result_text ( string_data out ) )
    ( string_free out )
    ^ result
}

@ run_echo Json args → Json {
    : ?Json text_j ( json_obj_get args `text` )
    ?? text_j {
        T tv → {
            : s text ( json_str_data tv )
            ^ ( mcp_tool_result_text text )
        }
        F → {
            ^ ( mcp_tool_result_error `missing required argument: text` )
        }
    }
    ^ ( mcp_tool_result_error `internal: invalid echo input` )
}

@ run_chat Json args → Json {
    : s prompt ( input_str args `prompt` )
    ? == ( nurl_str_len prompt ) 0 {
        ^ ( mcp_tool_result_error `missing required argument: prompt` )
    } {}

    : String bin ( env_var_or `HERMES_NURL_AGENT_BIN` `nurl/build/hermes-nurl` )
    : !Output ProcessErr r ( process_run2 ( string_data bin ) `chat` prompt )
    ( string_free bin )
    ?? r {
        T out → {
            : String body ( string_with_cap 256 )
            ( string_push_str body ( output_stdout out ) )
            : i errlen ( output_stderr_len out )
            ? > errlen 0 {
                ( string_push_str body `\n[stderr]\n` )
                ( string_push_str body ( output_stderr out ) )
            } {}
            : i ec ( output_exit_code out )
            ( output_free out )
            ? == ec 0 {
                : Json ok ( mcp_tool_result_text ( string_data body ) )
                ( string_free body )
                ^ ok
            } {
                : Json bad ( mcp_tool_result_error ( string_data body ) )
                ( string_free body )
                ^ bad
            }
        }
        F e → {
            : ProcessErr pe # ProcessErr e
            : String msg ( string_from `failed to run agent: ` )
            ( string_push_str msg ( process_err_name pe ) )
            : Json bad ( mcp_tool_result_error ( string_data msg ) )
            ( string_free msg )
            ^ bad
        }
    }
}

@ run_local_tool_subprocess s name Json args → Json {
    : String bin ( env_var_or `HERMES_NURL_AGENT_BIN` `nurl/build/hermes-nurl` )
    : String args_json ( json_stringify args )
    : ( Vec s ) argv ( vec_with_cap [s] 2 )
    ( vec_push [s] argv `mcp-call-stdin` )
    ( vec_push [s] argv name )
    : !Output ProcessErr r ( process_run ( string_data bin ) argv ( string_data args_json ) )
    ( vec_free [s] argv )
    ( string_free bin )
    ( string_free args_json )
    ?? r {
        T out → {
            : String body ( string_with_cap 256 )
            ( string_push_str body ( output_stdout out ) )
            : i errlen ( output_stderr_len out )
            ? > errlen 0 {
                ( string_push_str body `\n[stderr]\n` )
                ( string_push_str body ( output_stderr out ) )
            } {}
            : i ec ( output_exit_code out )
            ( output_free out )
            : b looks_err ( string_starts_with body `error:` )
            ? | != ec 0 looks_err {
                : Json bad ( mcp_tool_result_error ( string_data body ) )
                ( string_free body )
                ^ bad
            } {
                : Json ok ( mcp_tool_result_text ( string_data body ) )
                ( string_free body )
                ^ ok
            }
        }
        F e → {
            : ProcessErr pe # ProcessErr e
            : String msg ( string_from `failed to run local tool subprocess: ` )
            ( string_push_str msg ( process_err_name pe ) )
            : Json bad ( mcp_tool_result_error ( string_data msg ) )
            ( string_free msg )
            ^ bad
        }
    }
}

@ dispatch_tool s name Json args → Json {
    ? != ( nurl_str_eq name `hermes_nurl_status` ) 0 {
        ^ ( run_status )
    } {}
    ? != ( nurl_str_eq name `echo` ) 0 {
        ^ ( run_echo args )
    } {}
    ? != ( nurl_str_eq name `hermes_nurl_chat` ) 0 {
        ^ ( run_chat args )
    } {}
    ? ( is_local_tool name ) {
        ? ( hermes_nurl_production_mode ) {
            ? ( hermes_nurl_mutations_allowed ) {
                ? ( local_tool_is_mutating name ) {
                    ^ ( run_local_tool_subprocess name args )
                } {}
            } {}
        } {}
        : String out ( run_local_tool_input name args )
        : b looks_err ( string_starts_with out `error:` )
        ? looks_err {
            : Json bad ( mcp_tool_result_error ( string_data out ) )
            ( string_free out )
            ^ bad
        } {
            : Json ok ( mcp_tool_result_text ( string_data out ) )
            ( string_free out )
            ^ ok
        }
    } {}
    ^ ( mcp_tool_result_error `unknown tool` )
}

@ handle_initialize Json id → v {
    : Json result ( mcp_initialize_result `hermes-nurl-mcp` ( VERSION ) )
    ( mcp_send_message ( mcp_response_result id result ) )
}

@ handle_ping Json id → v {
    : Json empty ( json_obj_new )
    ( mcp_send_message ( mcp_response_result id empty ) )
}

@ handle_tools_list Json id → v {
    : ( Vec Json ) tools ( build_tools_list )
    : Json result ( mcp_tools_list_result tools )
    ( mcp_send_message ( mcp_response_result id result ) )
}

@ handle_tools_call Json id Json params → v {
    : ?Json name_j ( json_obj_get params `name` )
    ?? name_j {
        T nv → {
            : s name ( json_str_data nv )
            : ?Json args_j ( json_obj_get params `arguments` )
            : Json args ?? args_j {
                T av → ( json_clone av )
                F → ( json_obj_new )
            }
            : Json result ( dispatch_tool name args )
            ( json_free args )
            ( mcp_send_message ( mcp_response_result id result ) )
        }
        F → {
            ( mcp_send_message
            ( mcp_response_error id mcp_err_invalid_params
            `tools/call requires a "name" parameter` ) )
        }
    }
}

@ handle_unknown_method Json id s method → v {
    : i mlen ( nurl_str_len method )
    : String msg ( string_with_cap + 32 mlen )
    ( string_push_str msg `unknown method: ` )
    ( string_push_str msg method )
    ( mcp_send_message
    ( mcp_response_error id mcp_err_method_not_found ( string_data msg ) ) )
    ( string_free msg )
}

@ handle Json req → v {
    : ?Json method_j ( json_obj_get req `method` )
    ?? method_j {
        T mv → {
            : s method ( json_str_data mv )
            : ?Json id_opt ( json_obj_get req `id` )
            ?? id_opt {
                T id → {
                    ? != ( nurl_str_eq method `initialize` ) 0 {
                        ( handle_initialize id )
                    } {
                        ? != ( nurl_str_eq method `ping` ) 0 {
                            ( handle_ping id )
                        } {
                            ? != ( nurl_str_eq method `tools/list` ) 0 {
                                ( handle_tools_list id )
                            } {
                                ? != ( nurl_str_eq method `tools/call` ) 0 {
                                    : ?Json params_j ( json_obj_get req `params` )
                                    : Json params ?? params_j {
                                        T pv → ( json_clone pv )
                                        F → ( json_obj_new )
                                    }
                                    ( handle_tools_call id params )
                                    ( json_free params )
                                } {
                                    ( handle_unknown_method id method )
                                } } } }
                }
                F → {
                    ? != ( nurl_str_eq method `notifications/initialized` ) 0 {
                        ( mcp_log `client initialized` )
                    } {}
                }
            }
        }
        F → {
            ( mcp_log `request without method, ignoring` )
        }
    }
}

@ main → i {
    ( mcp_log `hermes-nurl-mcp ready` )
    : ~ b running T
    ~ running {
        : ?Json msg ( mcp_read_request )
        ?? msg {
            T req → {
                ( handle req )
                ( json_free req )
            }
            F _ → {
                = running F
            }
        }
    }
    ( mcp_log `bye` )
    ^ 0
}
