// Model metadata and context-length fallbacks for Hermes NURL.
//
// This is the offline, deterministic subset of agent/model_metadata.py. Live
// provider catalog probes can layer on later; for now the agent gets the same
// broad family defaults and explicit config override hook needed by future
// context compression/preflight work.

$ `stdlib/core/string.nu`
$ `nurl/src/config.nu`

@ CONTEXT_PROBE_TIER_0 → i { ^ 256000 }

@ DEFAULT_FALLBACK_CONTEXT → i { ^ ( CONTEXT_PROBE_TIER_0 ) }

@ MINIMUM_CONTEXT_LENGTH → i { ^ 64000 }

@ model_name_without_provider_prefix s model → String {
    : String raw ( string_from model )
    : String lower ( string_to_lower raw )
    : ?i colon ( string_index_of lower `:` )
    ?? colon {
        T idx → {
            : String prefix ( string_substr lower 0 idx )
            : ~ b strip F
            ? != ( nurl_str_eq ( string_data prefix ) `openrouter` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `nous` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `anthropic` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `claude` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `openai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `openai-codex` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `gemini` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `google` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `custom` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `local` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `glm` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `zai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `z-ai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `z.ai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `zhipu` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `kimi` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `moonshot` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `deepseek` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `xai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `x-ai` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `grok` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `qwen` ) 0 { = strip T } {}
            ? != ( nurl_str_eq ( string_data prefix ) `alibaba` ) 0 { = strip T } {}
            ( string_free prefix )
            ? strip {
                : i start + idx 1
                : i n ( string_len raw )
                : String suffix ( string_substr raw start - n start )
                ( string_free raw )
                ( string_free lower )
                ^ suffix
            } {}
        }
        F → {}
    }
    ( string_free lower )
    ^ raw
}

@ model_context_length_fallback s model → i {
    : String stripped ( model_name_without_provider_prefix model )
    : String lower ( string_to_lower stripped )
    ( string_free stripped )
    : ~ i ctx ( DEFAULT_FALLBACK_CONTEXT )

    // Longest/specific matches first, mirroring Hermes' Python fallback table.
    ? ( string_contains lower `claude-opus-4-7` ) { = ctx 1000000 } {}
    ? ( string_contains lower `claude-opus-4.7` ) { = ctx 1000000 } {}
    ? ( string_contains lower `claude-opus-4-6` ) { = ctx 1000000 } {}
    ? ( string_contains lower `claude-sonnet-4-6` ) { = ctx 1000000 } {}
    ? ( string_contains lower `claude-opus-4.6` ) { = ctx 1000000 } {}
    ? ( string_contains lower `claude-sonnet-4.6` ) { = ctx 1000000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `claude` ) { = ctx 200000 } {}

    ? ( string_contains lower `gpt-5.5` ) { = ctx 1050000 } {}
    ? ( string_contains lower `gpt-5.4-nano` ) { = ctx 400000 } {}
    ? ( string_contains lower `gpt-5.4-mini` ) { = ctx 400000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `gpt-5.4` ) { = ctx 1050000 } {}
    ? ( string_contains lower `gpt-5.3-codex-spark` ) { = ctx 128000 } {}
    ? ( string_contains lower `gpt-5.1-chat` ) { = ctx 128000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `gpt-5` ) { = ctx 400000 } {}
    ? ( string_contains lower `gpt-4.1` ) { = ctx 1047576 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `gpt-4` ) { = ctx 128000 } {}

    ? ( string_contains lower `gemini` ) { = ctx 1048576 } {}
    ? ( string_contains lower `gemma-4` ) { = ctx 256000 } {}
    ? ( string_contains lower `gemma4` ) { = ctx 256000 } {}
    ? ( string_contains lower `gemma-3` ) { = ctx 131072 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `gemma` ) { = ctx 8192 } {}

    ? ( string_contains lower `deepseek-v4-pro` ) { = ctx 1000000 } {}
    ? ( string_contains lower `deepseek-v4-flash` ) { = ctx 1000000 } {}
    ? ( string_contains lower `deepseek-chat` ) { = ctx 1000000 } {}
    ? ( string_contains lower `deepseek-reasoner` ) { = ctx 1000000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `deepseek` ) { = ctx 128000 } {}

    ? ( string_contains lower `qwen3.6-plus` ) { = ctx 1048576 } {}
    ? ( string_contains lower `qwen3-coder-plus` ) { = ctx 1000000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `qwen3-coder` ) { = ctx 262144 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `qwen` ) { = ctx 131072 } {}

    ? ( string_contains lower `minimax` ) { = ctx 204800 } {}
    ? ( string_contains lower `glm` ) { = ctx 202752 } {}
    ? ( string_contains lower `kimi` ) { = ctx 262144 } {}
    ? ( string_contains lower `hy3-preview` ) { = ctx 262144 } {}
    ? ( string_contains lower `nemotron` ) { = ctx 131072 } {}
    ? ( string_contains lower `trinity` ) { = ctx 262144 } {}
    ? ( string_contains lower `elephant` ) { = ctx 262144 } {}
    ? ( string_contains lower `llama` ) { = ctx 131072 } {}

    ? ( string_contains lower `grok-code-fast` ) { = ctx 256000 } {}
    ? ( string_contains lower `grok-4-1-fast` ) { = ctx 2000000 } {}
    ? ( string_contains lower `grok-2-vision` ) { = ctx 8192 } {}
    ? ( string_contains lower `grok-4-fast` ) { = ctx 2000000 } {}
    ? ( string_contains lower `grok-4.20` ) { = ctx 2000000 } {}
    ? ( string_contains lower `grok-4.3` ) { = ctx 1000000 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `grok-4` ) { = ctx 256000 } {}
    ? ( string_contains lower `grok-3` ) { = ctx 131072 } {}
    ? ( string_contains lower `grok-2` ) { = ctx 131072 } {}
    ? & == ctx ( DEFAULT_FALLBACK_CONTEXT ) ( string_contains lower `grok` ) { = ctx 131072 } {}

    ? ( string_contains lower `mimo-v2-pro` ) { = ctx 1048576 } {}
    ? ( string_contains lower `mimo-v2.5-pro` ) { = ctx 1048576 } {}
    ? ( string_contains lower `mimo-v2.5` ) { = ctx 1048576 } {}
    ? ( string_contains lower `mimo-v2-omni` ) { = ctx 262144 } {}
    ? ( string_contains lower `mimo-v2-flash` ) { = ctx 262144 } {}

    ( string_free lower )
    ^ ctx
}

@ model_context_length s model → i {
    : i configured ( hermes_config_model_context_length )
    ? > configured 0 { ^ configured } {}
    ^ ( model_context_length_fallback model )
}

@ model_context_is_supported s model → b {
    ^ >= ( model_context_length model ) ( MINIMUM_CONTEXT_LENGTH )
}
