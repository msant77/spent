#!/usr/bin/env bats

setup() {
    SPENT_BIN="$BATS_TEST_DIRNAME/../spent"
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR" || exit 1
}

teardown() {
    cd / || return
    rm -rf "$TEST_TMPDIR"
}

# --- duration parsing -------------------------------------------------------

@test "rejects no args" {
    run "$SPENT_BIN"
    [ "$status" -eq 2 ]
}

@test "accepts 2h" {
    run "$SPENT_BIN" 2h -m "test"
    [ "$status" -eq 0 ]
}

@test "accepts 30m" {
    run "$SPENT_BIN" 30m -m "test"
    [ "$status" -eq 0 ]
}

@test "accepts 5m" {
    run "$SPENT_BIN" 5m -m "test"
    [ "$status" -eq 0 ]
}

@test "accepts 4h30m" {
    run "$SPENT_BIN" 4h30m -m "test"
    [ "$status" -eq 0 ]
}

@test "accepts 90m" {
    run "$SPENT_BIN" 90m -m "test"
    [ "$status" -eq 0 ]
}

@test "rejects bare number duration" {
    run "$SPENT_BIN" 2 -m "test"
    [ "$status" -eq 2 ]
}

@test "rejects 2x duration" {
    run "$SPENT_BIN" 2x
    [ "$status" -eq 2 ]
}

@test "rejects h30m duration" {
    run "$SPENT_BIN" h30m
    [ "$status" -eq 2 ]
}

# --- ref parsing ------------------------------------------------------------

@test "accepts #42 ref" {
    "$SPENT_BIN" 1h "#42" -m "issue"
    log=$(ls .spent-*.log)
    grep -q '"#42"' "$log"
}

@test "accepts !100 ref" {
    "$SPENT_BIN" 1h "!100" -m "mr"
    log=$(ls .spent-*.log)
    grep -q '"!100"' "$log"
}

@test "rejects bare ref number" {
    run "$SPENT_BIN" 1h 42
    [ "$status" -eq 2 ]
}

@test "rejects malformed #ref" {
    run "$SPENT_BIN" 1h "#foo"
    [ "$status" -eq 2 ]
}

# --- type validation --------------------------------------------------------

@test "accepts every allowed type" {
    for t in dev test plan call prompt message other; do
        run "$SPENT_BIN" 5m -t "$t"
        [ "$status" -eq 0 ]
    done
}

@test "rejects bogus type" {
    run "$SPENT_BIN" 5m -t bogus
    [ "$status" -eq 2 ]
}

# --- CSV format -------------------------------------------------------------

@test "writes header on first append only" {
    "$SPENT_BIN" 5m -m "first"
    "$SPENT_BIN" 10m -m "second"
    "$SPENT_BIN" 15m -m "third"
    log=$(ls .spent-*.log)
    header_count=$(grep -c '^duration,type,ref,message,start,end$' "$log")
    [ "$header_count" -eq 1 ]
    line_count=$(wc -l < "$log" | tr -d ' ')
    [ "$line_count" -eq 4 ]
}

@test "csv escapes commas in message" {
    "$SPENT_BIN" 5m -m "with a, comma"
    log=$(ls .spent-*.log)
    grep -q '"with a, comma"' "$log"
}

@test "csv escapes double quotes in message" {
    "$SPENT_BIN" 5m -m 'with "quote"'
    log=$(ls .spent-*.log)
    grep -q '"with ""quote"""' "$log"
}

@test "all fields appear correctly in row" {
    "$SPENT_BIN" 1h -t dev "#42" -m "test" -st "29-04-26 09:00" -et "29-04-26 10:00"
    last=$(tail -1 .spent-04-2026.log)
    [ "$last" = '"1h","dev","#42","test","29-04-26 09:00","29-04-26 10:00"' ]
}

@test "empty optional fields produce empty quoted strings" {
    "$SPENT_BIN" 5m
    log=$(ls .spent-*.log)
    last=$(tail -1 "$log")
    [[ "$last" == '"5m","","","",'* ]]
}

# --- time defaults ----------------------------------------------------------

@test "neither st nor et: row has 6 quoted fields" {
    "$SPENT_BIN" 1h -m "now"
    log=$(ls .spent-*.log)
    last=$(tail -1 "$log")
    field_count=$(echo "$last" | awk -F'","' '{print NF}')
    [ "$field_count" -eq 6 ]
}

@test "et computed from st + duration" {
    "$SPENT_BIN" 2h -st "29-04-26 09:00" -m "morning"
    last=$(tail -1 .spent-04-2026.log)
    [[ "$last" == *'"29-04-26 09:00","29-04-26 11:00"' ]]
}

@test "st computed from et - duration" {
    "$SPENT_BIN" 30m -et "29-04-26 17:30" -m "wrap up"
    last=$(tail -1 .spent-04-2026.log)
    [[ "$last" == *'"29-04-26 17:00","29-04-26 17:30"' ]]
}

@test "both st and et used as-is" {
    "$SPENT_BIN" 99h -st "29-04-26 09:00" -et "29-04-26 10:30" -m "label only"
    last=$(tail -1 .spent-04-2026.log)
    [[ "$last" == *'"29-04-26 09:00","29-04-26 10:30"' ]]
}

# --- file targeting ---------------------------------------------------------

@test "filename uses MM-YYYY from start time" {
    "$SPENT_BIN" 1h -st "15-01-26 09:00" -m "jan entry"
    [ -f .spent-01-2026.log ]
}

@test "different months write to different files" {
    "$SPENT_BIN" 1h -st "15-01-26 09:00" -m "jan"
    "$SPENT_BIN" 1h -st "15-02-26 09:00" -m "feb"
    [ -f .spent-01-2026.log ]
    [ -f .spent-02-2026.log ]
}

# --- error paths ------------------------------------------------------------

@test "rejects garbage start time" {
    run "$SPENT_BIN" 1h -st "garbage"
    [ "$status" -eq 2 ]
}

@test "rejects garbage end time" {
    run "$SPENT_BIN" 1h -et "garbage"
    [ "$status" -eq 2 ]
}

@test "rejects unknown long flag" {
    run "$SPENT_BIN" 1h --foo
    [ "$status" -eq 2 ]
}

@test "rejects -t without value" {
    run "$SPENT_BIN" 1h -t
    [ "$status" -eq 2 ]
}

@test "help flag exits 0" {
    run "$SPENT_BIN" -h
    [ "$status" -eq 0 ]
}
