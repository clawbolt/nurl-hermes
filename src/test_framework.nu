// Minimal in-process test runner for Hermes NURL.
//
// Convention: each test case is a function that returns 0 on pass, 1 on fail.
// The selftest command calls each test by name and reports results.
// Output format: one line per test, "PASS <name>" or "FAIL <name>: <detail>".

$ `stdlib/core/string.nu`
$ `stdlib/ext/env.nu`

: TestState {
    i passed
    i failed
    i total
}

@ test_state_new → TestState {
    ^ @ TestState { 0 0 0 }
}

@ test_state_free TestState s → v {
    // Integers need no freeing; mark the struct as consumed.
}

@ test_report_pass TestState s name → v {
    = . s passed + . s passed 1
    = . s total + . s total 1
    ( nurl_print `PASS ` )
    ( nurl_print name )
    ( nurl_print `\n` )
}

@ test_report_fail TestState s name s detail → v {
    = . s failed + . s failed 1
    = . s total + . s total 1
    ( nurl_print `FAIL ` )
    ( nurl_print name )
    ( nurl_print `: ` )
    ( nurl_print detail )
    ( nurl_print `\n` )
}

// Run a single test case: call the test function, report result.
@ test_run TestState s name i result → v {
    ? == result 0 {
        ( test_report_pass s name )
    } {
        ( test_report_fail s name `returned 1` )
    }
}

// Run a single test case with an explicit detail on failure.
@ test_run_detail TestState s name i result s detail → v {
    ? == result 0 {
        ( test_report_pass s name )
    } {
        ( test_report_fail s name detail )
    }
}

// Print a summary line: "X passed, Y failed, Z total".
@ test_summary TestState s → i {
    ( nurl_print `\n` )
    ( nurl_print ( nurl_str_int . s passed ) )
    ( nurl_print ` passed, ` )
    ( nurl_print ( nurl_str_int . s failed ) )
    ( nurl_print ` failed, ` )
    ( nurl_print ( nurl_str_int . s total ) )
    ( nurl_print ` total\n` )
    ? == . s failed 0 { ^ 0 } {}
    ^ 1
}
