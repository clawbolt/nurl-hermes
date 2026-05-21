// hermes-nurl-http — local browser/test HTTP adapter for Hermes NURL.
//
// This is intentionally a thin NURL-native wrapper around the existing
// hermes-nurl binary. It is for local browser testing, not a public-facing
// deployment surface.

$ `stdlib/ext/http_full.nu`
$ `stdlib/ext/env.nu`
$ `stdlib/ext/json.nu`
$ `stdlib/std/bytes.nu`
$ `stdlib/std/process.nu`
$ `stdlib/core/string.nu`
$ `stdlib/core/vec.nu`
$ `nurl/src/common.nu`

@ adapter_default_port → i { ^ 18081 }

@ parse_positive_int s raw i default_value → i {
    : String owned ( string_from raw )
    : String trimmed ( string_trim owned )
    ( string_free owned )
    : !i ParseErr parsed ( string_to_int trimmed )
    ( string_free trimmed )
    ?? parsed {
        T n → {
            ? > n 0 { ^ n } {}
        }
        F _ → {}
    }
    ^ default_value
}

@ adapter_host → String {
    : i argc ( env_args_count )
    ? > argc 1 {
        : s arg ( nurl_argv_get 1 )
        ? > ( nurl_str_len arg ) 0 { ^ ( string_from arg ) } {}
    } {}

    : ?String env_host ( env_get `HERMES_NURL_HTTP_HOST` )
    ?? env_host {
        T h → {
            ? > ( string_len h ) 0 { ^ h } {}
            ( string_free h )
        }
        F → {}
    }
    ^ ( string_from `127.0.0.1` )
}

@ adapter_port → i {
    : i argc ( env_args_count )
    ? > argc 2 {
        ^ ( parse_positive_int ( nurl_argv_get 2 ) ( adapter_default_port ) )
    } {}

    : ?String env_port ( env_get `HERMES_NURL_HTTP_PORT` )
    ?? env_port {
        T p → {
            : i parsed ( parse_positive_int ( string_data p ) ( adapter_default_port ) )
            ( string_free p )
            ^ parsed
        }
        F → {}
    }
    ^ ( adapter_default_port )
}

@ adapter_workers → i {
    : ?String env_workers ( env_get `HERMES_NURL_HTTP_WORKERS` )
    ?? env_workers {
        T w → {
            : i parsed ( parse_positive_int ( string_data w ) 4 )
            ( string_free w )
            ? > parsed 0 { ^ parsed } {}
        }
        F → {}
    }
    ^ 4
}

@ adapter_agent_bin → String {
    ^ ( env_var_or `HERMES_NURL_AGENT_BIN` `nurl/build/hermes-nurl` )
}

@ html_index → String {
    : String html ( string_with_cap 8192 )
    ( string_push_str html `<!doctype html>\n` )
    ( string_push_str html `<html lang="en"><head><meta charset="utf-8">` )
    ( string_push_str html `<meta name="viewport" content="width=device-width,initial-scale=1">` )
    ( string_push_str html `<title>Hermes NURL</title>` )
    ( string_push_str html `<style>` )
    ( string_push_str html `:root{color-scheme:light dark;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f7f7f4;color:#1c1d1b}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#f7f7f4;color:#1c1d1b}.shell{max-width:1120px;margin:0 auto;padding:28px 20px 40px}.top{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:18px}.brand{display:flex;flex-direction:column;gap:2px}.brand h1{font-size:24px;line-height:1.2;margin:0;font-weight:700}.brand span{font-size:13px;color:#676b5f}.status{font-size:13px;padding:6px 10px;border:1px solid #d5d7ce;border-radius:6px;background:#fff}.grid{display:grid;grid-template-columns:minmax(0,1fr) 360px;gap:14px}.panel{border:1px solid #d5d7ce;border-radius:8px;background:#fff;padding:14px}.panel h2{font-size:15px;margin:0 0 10px;font-weight:700}.field{display:flex;flex-direction:column;gap:6px;margin-bottom:10px}.field label{font-size:12px;color:#55594f}.field input,.field textarea{width:100%;border:1px solid #c9ccc2;border-radius:6px;background:#fff;color:#1c1d1b;font:inherit;padding:9px 10px}.field textarea{min-height:180px;resize:vertical;line-height:1.45}.row{display:flex;gap:8px;align-items:center}.row input{flex:1}.actions{display:flex;gap:8px;align-items:center}button{border:1px solid #1f5f5b;background:#24716b;color:white;border-radius:6px;padding:9px 12px;font:inherit;font-weight:650;cursor:pointer}button.secondary{background:#fff;color:#1f5f5b}button:disabled{opacity:.55;cursor:wait}pre{min-height:260px;max-height:520px;overflow:auto;margin:0;border:1px solid #d5d7ce;border-radius:6px;background:#101212;color:#e8ece5;padding:12px;font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;white-space:pre-wrap}.small pre{min-height:176px}.hint{font-size:12px;color:#676b5f;margin-top:8px}@media(max-width:880px){.grid{grid-template-columns:1fr}.top{align-items:flex-start;flex-direction:column}.status{width:100%}}` )
    ( string_push_str html `</style></head><body><main class="shell">` )
    ( string_push_str html `<div class="top"><div class="brand"><h1>Hermes NURL</h1><span>Local HTTP adapter</span></div><div id="status" class="status">checking</div></div>` )
    ( string_push_str html `<div class="grid"><section class="panel"><h2>Chat</h2><div class="field"><label for="prompt">Prompt</label><textarea id="prompt" spellcheck="false">Say hello in one short sentence.</textarea></div><div class="row"><div class="field" style="flex:1;margin-bottom:0"><label for="session">Session id</label><input id="session" placeholder="optional"></div><div class="actions" style="align-self:end"><button id="send">Run</button><button id="clear" class="secondary">Clear</button></div></div><div class="hint">POST /api/chat-stream</div></section>` )
    ( string_push_str html `<section class="panel small"><h2>Tool Call</h2><div class="field"><label for="tool">Tool</label><input id="tool" value="file_info"></div><div class="field"><label for="args">Arguments JSON</label><textarea id="args" spellcheck="false">{"path":"nurl/README.md"}</textarea></div><div class="actions"><button id="callTool">Call</button></div><div class="hint">POST /api/mcp-call/:tool</div></section></div>` )
    ( string_push_str html `<section class="panel" style="margin-top:14px"><h2>Output</h2><pre id="out"></pre></section>` )
    ( string_push_str html `</main><script>` )
    ( string_push_str html `const $=id=>document.getElementById(id);const out=$('out');function show(x){out.textContent=typeof x==='string'?x:JSON.stringify(x,null,2)}function append(x){out.textContent+=x;out.scrollTop=out.scrollHeight}async function health(){try{const r=await fetch('/api/health');const j=await r.json();$('status').textContent=j.ok?'ready '+j.version:'not ready'}catch(e){$('status').textContent='offline'}}async function postJson(url,body){const r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const text=await r.text();try{return JSON.parse(text)}catch(_){return {ok:false,status:r.status,stdout:text}}}function renderEvent(e){if(e.type==='final'){append(e.text||'');return}if(e.type==='turn'){append('[turn '+e.turn+']\\n');return}if(e.type==='tool'){append('[tool '+e.name+']\\n');return}if(e.type==='usage'){append('\\n[usage in='+e.input_tokens+' out='+e.output_tokens+' turns='+e.turns+']\\n');return}if(e.type==='error'){append('\\n[error '+(e.message||'unknown')+']\\n');return}if(e.type==='exit'){append('\\n[exit '+e.exit_code+']\\n');return}}async function streamChat(){const r=await fetch('/api/chat-stream',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({prompt:$('prompt').value,session_id:$('session').value})});if(!r.body){show(await r.text());return}const reader=r.body.getReader();const dec=new TextDecoder();let buf='';for(;;){const x=await reader.read();if(x.done)break;buf+=dec.decode(x.value,{stream:true});let p;while((p=buf.indexOf('\\n\\n'))>=0){const frame=buf.slice(0,p);buf=buf.slice(p+2);const data=frame.split('\\n').filter(l=>l.startsWith('data:')).map(l=>l.slice(5).trimStart()).join('\\n');if(!data)continue;try{renderEvent(JSON.parse(data))}catch(_){append(data+'\\n')}}}}$('send').onclick=async()=>{const b=$('send');b.disabled=true;show('');try{await streamChat()}catch(e){show(String(e))}b.disabled=false};$('callTool').onclick=async()=>{const b=$('callTool');b.disabled=true;show('calling...');try{const args=JSON.parse($('args').value||'{}');show(await postJson('/api/mcp-call/'+encodeURIComponent($('tool').value),args))}catch(e){show(String(e))}b.disabled=false};$('clear').onclick=()=>{out.textContent=''};health();` )
    ( string_push_str html `</script></body></html>\n` )
    ^ html
}

@ response_html String html → HttpResponse {
    : HttpResponse r ( response_text 200 ( string_data html ) )
    ( response_set_header r `Content-Type` `text/html; charset=utf-8` )
    ( response_set_header r `Cache-Control` `no-store` )
    ^ r
}

@ json_error i status s message → HttpResponse {
    : Json body ( json_obj_new )
    ( json_obj_set body `ok` ( json_bool F ) )
    ( json_obj_set body `error` ( json_str_lit message ) )
    : HttpResponse r ( response_json status body )
    ( json_free body )
    ^ r
}

@ request_json HttpRequest req → !Json ParseErr {
    : String body ( bytes_to_str . req body )
    : !Json ParseErr parsed ( json_parse ( string_data body ) )
    ( string_free body )
    ^ parsed
}

@ process_response ! Output ProcessErr result → HttpResponse {
    ?? result {
        T out → {
            : i code ( output_exit_code out )
            : Json body ( json_obj_new )
            : b ok ? == code 0 T F
            ( json_obj_set body `ok` ( json_bool ok ) )
            ( json_obj_set body `exit_code` ( json_int code ) )
            ( json_obj_set body `stdout` ( json_str_lit ( output_stdout out ) ) )
            ( json_obj_set body `stderr` ( json_str_lit ( output_stderr out ) ) )
            : i status ? == code 0 200 502
            : HttpResponse r ( response_json status body )
            ( json_free body )
            ( output_free out )
            ^ r
        }
        F e → {
            : String msg ( string_from `failed to run hermes-nurl: ` )
            ( string_push_str msg ( process_err_name e ) )
            : HttpResponse r ( json_error 500 ( string_data msg ) )
            ( string_free msg )
            ^ r
        }
    }
}

@ adapter_write_response_close TcpConn conn HttpResponse r → v {
    ( response_set_header r `Connection` `close` )
    : ( Vec u ) wire ( response_serialize r )
    : !v NetErr wr ( tcp_write_all conn wire )
    ?? wr { T _ → {} F _ → {} }
    ( vec_free [u] wire )
    ( http_response_free r )
}

@ stream_write_line TcpConn conn s line → b {
    : String payload ( string_with_cap + ( nurl_str_len line ) 16 )
    ( string_push_str payload `data: ` )
    ( string_push_str payload line )
    ( string_push_str payload `\n\n` )
    : ( Vec u ) bytes ( vec_with_cap [u] ( string_len payload ) )
    ( bytes_extend_str bytes ( string_data payload ) )
    : !v NetErr wr ( response_write_chunk conn bytes )
    ( vec_free [u] bytes )
    ( string_free payload )
    ?? wr {
        T _ → { ^ T }
        F _ → { ^ F }
    }
}

@ stream_write_json TcpConn conn Json evt → b {
    : String line ( json_stringify evt )
    : b ok ( stream_write_line conn ( string_data line ) )
    ( string_free line )
    ^ ok
}

@ stream_write_status TcpConn conn s state → b {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `type` ( json_str_lit `status` ) )
    ( json_obj_set evt `state` ( json_str_lit state ) )
    : b ok ( stream_write_json conn evt )
    ( json_free evt )
    ^ ok
}

@ stream_write_error TcpConn conn s message → b {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `type` ( json_str_lit `error` ) )
    ( json_obj_set evt `message` ( json_str_lit message ) )
    : b ok ( stream_write_json conn evt )
    ( json_free evt )
    ^ ok
}

@ stream_write_exit TcpConn conn i code → b {
    : Json evt ( json_obj_new )
    ( json_obj_set evt `type` ( json_str_lit `exit` ) )
    ( json_obj_set evt `exit_code` ( json_int code ) )
    : b ok ( stream_write_json conn evt )
    ( json_free evt )
    ^ ok
}

@ stream_begin TcpConn conn → b {
    : ( Vec Header ) hs ( vec_new [Header] )
    ( vec_push [Header] hs ( header_new `Content-Type` `text/event-stream; charset=utf-8` ) )
    ( vec_push [Header] hs ( header_new `Cache-Control` `no-cache, no-transform` ) )
    ( vec_push [Header] hs ( header_new `Connection` `close` ) )
    ( vec_push [Header] hs ( header_new `Access-Control-Allow-Origin` `*` ) )
    ( vec_push [Header] hs ( header_new `Access-Control-Allow-Headers` `Content-Type, Authorization` ) )
    ( vec_push [Header] hs ( header_new `X-Accel-Buffering` `no` ) )
    : !v NetErr beg ( response_begin_chunked conn 200 hs )
    ( vec_free_with [Header] hs \ Header h → v { ( header_free h ) } )
    ?? beg {
        T _ → { ^ T }
        F _ → { ^ F }
    }
}

@ h_chat_stream_conn TcpConn conn HttpRequest req → v {
    : !Json ParseErr parsed ( request_json req )
    ?? parsed {
        T input → {
            : s prompt ( input_str input `prompt` )
            ? <= ( nurl_str_len prompt ) 0 {
                ( json_free input )
                ( adapter_write_response_close conn ( json_error 400 `missing required field: prompt` ) )
            } {
                ? ! ( stream_begin conn ) {
                    ( json_free input )
                } {
                    : ~ b open T
                    : s session_id ( input_str input `session_id` )
                    : String bin ( adapter_agent_bin )
                    : ( Vec s ) args ( vec_with_cap [s] 2 )
                    ? > ( nurl_str_len session_id ) 0 {
                        ( vec_push [s] args `resume-events` )
                        ( vec_push [s] args session_id )
                    } {
                        ( vec_push [s] args `chat-events` )
                    }

                    : !ProcChild ProcessErr spawned ( process_spawn ( string_data bin ) args )
                    ( vec_free [s] args )
                    ( string_free bin )
                    ?? spawned {
                        T child → {
                            ? open {
                                : i wrote ( proc_write_str child prompt )
                                ? < wrote 0 {
                                    = open ( stream_write_error conn `failed to write prompt to child stdin` )
                                } {}
                            } {}
                            ( proc_close_stdin child )
                            ( json_free input )

                            : ~ b done F
                            ~ & open ! done {
                                : ?String got ( proc_read_line child 250 )
                                ?? got {
                                    T line → {
                                        = open ( stream_write_line conn ( string_data line ) )
                                        ( string_free line )
                                    }
                                    F _ → {
                                        ? ( proc_eof child ) { = done T } {}
                                    }
                                }
                            }

                            : i code ( proc_wait child )
                            ? < code 0 {
                                = open ( stream_write_error conn `failed to wait for child process` )
                            } {}
                            ? open {
                                : !v NetErr endr ( response_end_chunked conn )
                                ?? endr { T _ → {} F _ → {} }
                            } {}
                            ( proc_free child )
                        }
                        F e → {
                            ( json_free input )
                            ? open {
                                = open ( stream_write_error conn ( process_err_name e ) )
                                ? open {
                                    : !v NetErr endr ( response_end_chunked conn )
                                    ?? endr { T _ → {} F _ → {} }
                                } {}
                            } {}
                        }
                    }
                }
            }
        }
        F _ → {
            ( adapter_write_response_close conn ( json_error 400 `request body must be valid JSON` ) )
        }
    }
}

@ adapter_request_is_chat_stream HttpRequest req → b {
    : s method ( string_data . req method )
    : s path ( string_data . req path )
    ? & != 0 ( nurl_str_eq method `POST` ) != 0 ( nurl_str_eq path `/api/chat-stream` ) {
        ^ T
    } {}
    ^ F
}

@ adapter_serve_once TcpListener listener ( @ HttpResponse HttpRequest ) handler → !v NetErr {
    : !TcpConn NetErr ar ( tcp_accept listener )
    ?? ar {
        T conn → {
            ( tcp_set_timeout conn 30000 )
            : ( Vec u ) carry ( vec_with_cap [u] 4096 )
            : HttpLimits lim ( http_default_limits )
            : !ParsedHeadOk HttpReqErr ph ( __read_request_head conn carry lim )
            ?? ph {
                T pho → {
                    : HttpRequest req . pho head
                    : b body_ok ( __finish_body conn req carry . lim body_default_max )
                    ? body_ok {
                        ? ( adapter_request_is_chat_stream req ) {
                            ( h_chat_stream_conn conn req )
                        } {
                            : HttpResponse resp ( handler req )
                            ( adapter_write_response_close conn resp )
                        }
                    } {
                        ( adapter_write_response_close conn ( response_text 400 `malformed body\n` ) )
                    }
                    ( request_free req )
                }
                F e → {
                    : s nm ( http_req_err_name e )
                    ? != 0 ( nurl_str_eq nm `HttpReqIo` ) {} {
                        ( adapter_write_response_close conn ( __parse_err_response e ) )
                    }
                }
            }
            ( vec_free [u] carry )
            ( tcp_close_conn conn )
            ^ @ !v NetErr { T 0 }
        }
        F e → ^ @ !v NetErr { F e }
    }
}

@ adapter_serve_run TcpListener listener ( @ HttpResponse HttpRequest ) handler → !v NetErr {
    : ~ b done F
    : ~ b had_err F
    : ~ NetErr last_err NetClosed
    ~ ! done {
        : !v NetErr r ( adapter_serve_once listener handler )
        ?? r {
            T _ → {}
            F e → {
                : s nm ( net_err_name e )
                ? | != 0 ( nurl_str_eq nm `NetClosed` ) != 0 ( nurl_str_eq nm `NetAccept` ) {
                    = done T
                } {
                    = last_err e
                    = had_err T
                    = done T
                }
            }
        }
    }
    ? had_err { ^ @ !v NetErr { F last_err } } {}
    ^ @ !v NetErr { T 0 }
}

@ adapter_serve_run_pool TcpListener listener ( @ HttpResponse HttpRequest ) handler i n_workers → !v NetErr {
    ? <= n_workers 1 { ^ ( adapter_serve_run listener handler ) } {}

    : s thandles ( nurl_alloc * n_workers 8 )
    : ( @ v ) worker \ → v {
        : ~ b done F
        ~ ! done {
            : !v NetErr r ( adapter_serve_once listener handler )
            ?? r {
                T _ → {}
                F e → {
                    : s nm ( net_err_name e )
                    ? | != 0 ( nurl_str_eq nm `NetClosed` ) != 0 ( nurl_str_eq nm `NetAccept` ) {
                        = done T
                    } {
                        = done T
                    }
                }
            }
        }
    }

    : ~ i j 0
    ~ < j n_workers {
        : !Thread ThreadErr tr ( thread_spawn worker )
        ?? tr {
            T t → {
                : s tp . t raw
                : i traw # i tp
                ( nurl_poke thandles * j 8 traw )
            }
            F _ → {
                ( nurl_poke thandles * j 8 0 )
            }
        }
        = j + j 1
    }

    = j 0
    ~ < j n_workers {
        : i traw ( nurl_peek thandles * j 8 )
        ? != traw 0 {
            : s tp # s traw
            : Thread t @ Thread { tp }
            ( thread_join t )
        } {}
        = j + j 1
    }
    ( nurl_free thandles )
    ^ @ !v NetErr { T 0 }
}

@ h_index HttpRequest req Params params → HttpResponse {
    : String html ( html_index )
    : HttpResponse r ( response_html html )
    ( string_free html )
    ^ r
}

@ h_health HttpRequest req Params params → HttpResponse {
    : String bin ( adapter_agent_bin )
    : Json body ( json_obj_new )
    ( json_obj_set body `ok` ( json_bool T ) )
    ( json_obj_set body `version` ( json_str_lit ( VERSION ) ) )
    ( json_obj_set body `agent_bin` ( json_str_lit ( string_data bin ) ) )
    ( json_obj_set body `production_mode` ( json_bool ( hermes_nurl_production_mode ) ) )
    : HttpResponse r ( response_json 200 body )
    ( json_free body )
    ( string_free bin )
    ^ r
}

@ h_chat HttpRequest req Params params → HttpResponse {
    : !Json ParseErr parsed ( request_json req )
    ?? parsed {
        T input → {
            : s prompt ( input_str input `prompt` )
            ? <= ( nurl_str_len prompt ) 0 {
                ( json_free input )
                ^ ( json_error 400 `missing required field: prompt` )
            } {}

            : s session_id ( input_str input `session_id` )
            : String bin ( adapter_agent_bin )
            : ( Vec s ) args ( vec_with_cap [s] 2 )
            ? > ( nurl_str_len session_id ) 0 {
                ( vec_push [s] args `resume` )
                ( vec_push [s] args session_id )
            } {
                ( vec_push [s] args `chat` )
            }
            : !Output ProcessErr ran ( process_run ( string_data bin ) args prompt )
            ( vec_free [s] args )
            ( string_free bin )
            ( json_free input )
            ^ ( process_response ran )
        }
        F _ → {
            ^ ( json_error 400 `request body must be valid JSON` )
        }
    }
}

@ h_mcp_call HttpRequest req Params params → HttpResponse {
    : ?String tool_opt ( params_get params `tool` )
    ?? tool_opt {
        T tool → {
            : HttpResponse resp ( h_mcp_call_tool req ( string_data tool ) )
            ( string_free tool )
            ^ resp
        }
        F empty → {
            ( string_free empty )
            ^ ( json_error 400 `missing tool name` )
        }
    }
}

@ h_mcp_call_tool HttpRequest req s tool → HttpResponse {
    ? <= ( nurl_str_len tool ) 0 {
        ^ ( json_error 400 `missing tool name` )
    } {}

    : String body ( bytes_to_str . req body )
    : String bin ( adapter_agent_bin )
    : ( Vec s ) args ( vec_with_cap [s] 2 )
    ( vec_push [s] args `mcp-call-stdin` )
    ( vec_push [s] args tool )
    : !Output ProcessErr ran ( process_run ( string_data bin ) args ( string_data body ) )
    ( vec_free [s] args )
    ( string_free bin )
    ( string_free body )
    ^ ( process_response ran )
}

@ build_handler Router r → ( @ HttpResponse HttpRequest ) {
    : ( @ HttpResponse HttpRequest ) base
    \ HttpRequest req → HttpResponse {
        ? & != 0 ( nurl_str_eq ( string_data . req method ) `POST` ) ( string_starts_with . req path `/api/mcp-call/` ) {
            : i prefix_n ( nurl_str_len `/api/mcp-call/` )
            : i path_n ( string_len . req path )
            ? <= path_n prefix_n {
                ^ ( json_error 400 `missing tool name` )
            } {}

            : String tool ( string_substr . req path prefix_n - path_n prefix_n )
            : HttpResponse resp ( h_mcp_call_tool req ( string_data tool ) )
            ( string_free tool )
            ^ resp
        } {}

        ^ ( router_handle r req )
    }
    ^ ( with_cors_default base )
}

@ main → i {
    ( hermes_load_dotenv )
    : String host ( adapter_host )
    : i port ( adapter_port )
    : i workers ( adapter_workers )
    : !TcpListener NetErr lr ( tcp_listen ( string_data host ) port )
    ?? lr {
        T listener → {
            : Router r ( router_new )
            ( router_get r `/` \ HttpRequest req Params params → HttpResponse { ^ ( h_index req params ) } )
            ( router_get r `/api/health` \ HttpRequest req Params params → HttpResponse { ^ ( h_health req params ) } )
            ( router_post r `/api/chat` \ HttpRequest req Params params → HttpResponse { ^ ( h_chat req params ) } )
            ( router_post r `/api/mcp-call/:tool` \ HttpRequest req Params params → HttpResponse { ^ ( h_mcp_call req params ) } )
            : ( @ HttpResponse HttpRequest ) handler ( build_handler r )

            ( signal_install_shutdown listener )
            ( nurl_print `hermes-nurl-http listening on http://` )
            ( nurl_print ( string_data host ) )
            ( nurl_print `:` )
            ( nurl_print ( nurl_str_int port ) )
            ( nurl_print `/\n` )

            : !v NetErr rr ? > workers 1 {
                ( adapter_serve_run_pool listener handler workers )
            } {
                ( adapter_serve_run listener handler )
            }

            ( signal_clear_shutdown )
            ( tcp_close_listener listener )
            ( router_free r )
            ( string_free host )
            ?? rr {
                T _ → { ^ 0 }
                F e → {
                    ( nurl_eprint `[http] server error: ` )
                    ( nurl_eprint ( net_err_name e ) )
                    ( nurl_eprint `\n` )
                    ^ 1
                }
            }
        }
        F e → {
            ( nurl_eprint `[http] could not bind: ` )
            ( nurl_eprint ( net_err_name e ) )
            ( nurl_eprint `\n` )
            ( string_free host )
            ^ 1
        }
    }
}
