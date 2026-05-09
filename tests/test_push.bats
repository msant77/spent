#!/usr/bin/env bats

setup() {
    SPENT_BIN="$BATS_TEST_DIRNAME/../spent"
    TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR" || exit 1

    export SPENT_GLOBAL_CONFIG="$TEST_TMPDIR/site.conf"
    export SPENT_CACHE_DIR_TEST="$TEST_TMPDIR/cache"
    export WRANGLER_LOG="$TEST_TMPDIR/wrangler.log"

    STUB_DIR="$TEST_TMPDIR/bin"
    mkdir -p "$STUB_DIR"
    ln -s "$BATS_TEST_DIRNAME/fixtures/wrangler-stub" "$STUB_DIR/wrangler"
    export PATH="$STUB_DIR:$PATH"
}

teardown() {
    cd / || return
    rm -rf "$TEST_TMPDIR"
}

configure() {
    printf '%s\n' \
        "example.com" \
        "$SPENT_CACHE_DIR_TEST" \
        "Pontosat" \
        "pontosat" \
        | "$SPENT_BIN" config >/dev/null
}

write_log() {
    local file="$1"; shift
    {
        printf '%s\n' 'duration,type,ref,message,start,end'
        for row in "$@"; do printf '%s\n' "$row"; done
    } > "$file"
}

slug_file() {
    printf '%s/pontosat/%s' "$SPENT_CACHE_DIR_TEST" "$1"
}

# --- error paths -----------------------------------------------------------

@test "push without global config errors" {
    run "$SPENT_BIN" push
    [ "$status" -ne 0 ]
    [[ "$output" == *"run \"spent config\""* ]]
}

@test "push without local config errors" {
    configure
    rm -f .spent-config
    run "$SPENT_BIN" push
    [ "$status" -ne 0 ]
    [[ "$output" == *".spent-config"* ]]
}

@test "push with no logs errors" {
    configure
    run "$SPENT_BIN" push
    [ "$status" -ne 0 ]
    [[ "$output" == *"no .spent-*.log"* ]]
}

@test "push without wrangler exits non-zero" {
    configure
    write_log .spent-05-2026.log '"1h","dev","","","04-05-26 09:00","04-05-26 10:00"'
    rm "$STUB_DIR/wrangler"
    export PATH="/usr/bin:/bin"
    run "$SPENT_BIN" push
    [ "$status" -ne 0 ]
}

# --- happy path -----------------------------------------------------------

@test "push converts log to year-first .json" {
    configure
    write_log .spent-05-2026.log '"1h","dev","#1","first","04-05-26 09:00","04-05-26 10:00"'
    "$SPENT_BIN" push >/dev/null
    [ -f "$(slug_file 2026-05.json)" ]
}

@test "push builds months.json sorted descending" {
    configure
    write_log .spent-03-2026.log '"1h","dev","","mar","04-03-26 09:00","04-03-26 10:00"'
    write_log .spent-05-2026.log '"1h","dev","","mai","04-05-26 09:00","04-05-26 10:00"'
    write_log .spent-04-2026.log '"1h","dev","","abr","04-04-26 09:00","04-04-26 10:00"'
    "$SPENT_BIN" push >/dev/null
    months=$(cat "$(slug_file months.json)")
    [[ "$months" == *'"months":[{"period":"2026-05",'* ]]
    # 2026-04 comes before 2026-03
    pos_04=$(printf '%s' "$months" | grep -bo '"period":"2026-04"' | head -1 | cut -d: -f1)
    pos_03=$(printf '%s' "$months" | grep -bo '"period":"2026-03"' | head -1 | cut -d: -f1)
    [ "$pos_04" -lt "$pos_03" ]
}

@test "push uses Portuguese month labels with diacritics" {
    configure
    write_log .spent-03-2026.log '"1h","dev","","mar","04-03-26 09:00","04-03-26 10:00"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"label":"Março 2026"' "$(slug_file months.json)"
}

@test "push includes client name in months.json" {
    configure
    write_log .spent-05-2026.log '"1h","dev","","x","04-05-26 09:00","04-05-26 10:00"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"client":"Pontosat"' "$(slug_file months.json)"
}

@test "push invokes wrangler with slug as project and slug subdir" {
    configure
    write_log .spent-05-2026.log '"1h","dev","","x","04-05-26 09:00","04-05-26 10:00"'
    "$SPENT_BIN" push >/dev/null
    [ -f "$WRANGLER_LOG" ]
    grep -q 'pages deploy' "$WRANGLER_LOG"
    grep -q -- '--project-name=pontosat' "$WRANGLER_LOG"
    grep -q "$SPENT_CACHE_DIR_TEST/pontosat" "$WRANGLER_LOG"
}

@test "push prints subdomain URL on success" {
    configure
    write_log .spent-05-2026.log '"1h","dev","","x","04-05-26 09:00","04-05-26 10:00"'
    run "$SPENT_BIN" push
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://pontosat.example.com/"* ]]
}

# --- csv-to-json edge cases -----------------------------------------------

@test "csv-to-json: empty optional fields" {
    configure
    write_log .spent-05-2026.log '"5m","","","","04-05-26 09:00","04-05-26 09:05"'
    "$SPENT_BIN" push >/dev/null
    json=$(cat "$(slug_file 2026-05.json)")
    [[ "$json" == *'"type": ""'* ]]
    [[ "$json" == *'"ref": ""'* ]]
    [[ "$json" == *'"message": ""'* ]]
}

@test "csv-to-json: comma in message" {
    configure
    write_log .spent-05-2026.log '"5m","","","with a, comma","04-05-26 09:00","04-05-26 09:05"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"message": "with a, comma"' "$(slug_file 2026-05.json)"
}

@test "csv-to-json: doubled-quote escapes correctly" {
    configure
    write_log .spent-05-2026.log '"5m","","","with ""quote"" inside","04-05-26 09:00","04-05-26 09:05"'
    "$SPENT_BIN" push >/dev/null
    json=$(cat "$(slug_file 2026-05.json)")
    expected='"message": "with \"quote\" inside"'
    [[ "$json" == *"$expected"* ]]
}

@test "csv-to-json: literal comma-quote sequence in message" {
    configure
    # Message content is the 3 chars: " , "  (quote, comma, quote)
    # Encoded by csv_field as ""","""
    write_log .spent-05-2026.log '"5m","","",""",""","04-05-26 09:00","04-05-26 09:05"'
    "$SPENT_BIN" push >/dev/null
    json=$(cat "$(slug_file 2026-05.json)")
    expected='"message": "\",\""'
    [[ "$json" == *"$expected"* ]]
}

@test "csv-to-json: UTF-8 Portuguese diacritics" {
    configure
    write_log .spent-05-2026.log '"5m","","","apresentação e correção","04-05-26 09:00","04-05-26 09:05"'
    "$SPENT_BIN" push >/dev/null
    grep -q 'apresentação e correção' "$(slug_file 2026-05.json)"
}

@test "csv-to-json: duration_minutes for 4h30m" {
    configure
    write_log .spent-05-2026.log '"4h30m","dev","","","04-05-26 09:00","04-05-26 13:30"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"duration_minutes": 270' "$(slug_file 2026-05.json)"
}

@test "csv-to-json: duration_minutes for 90m" {
    configure
    write_log .spent-05-2026.log '"90m","dev","","","04-05-26 09:00","04-05-26 10:30"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"duration_minutes": 90' "$(slug_file 2026-05.json)"
}

@test "csv-to-json: ISO-8601 date conversion" {
    configure
    write_log .spent-05-2026.log '"1h","dev","","","04-05-26 09:30","04-05-26 10:30"'
    "$SPENT_BIN" push >/dev/null
    json=$(cat "$(slug_file 2026-05.json)")
    [[ "$json" == *'"start": "2026-05-04T09:30:00"'* ]]
    [[ "$json" == *'"end": "2026-05-04T10:30:00"'* ]]
}

@test "csv-to-json: total_minutes sums all entries" {
    configure
    write_log .spent-05-2026.log \
        '"2h","dev","","","04-05-26 09:00","04-05-26 11:00"' \
        '"30m","plan","","","04-05-26 11:00","04-05-26 11:30"' \
        '"45m","call","","","04-05-26 14:00","04-05-26 14:45"'
    "$SPENT_BIN" push >/dev/null
    grep -q '"total_minutes": 195' "$(slug_file 2026-05.json)"
}

@test "csv-to-json: ref preserved verbatim with sigil" {
    configure
    write_log .spent-05-2026.log \
        '"1h","dev","#42","x","04-05-26 09:00","04-05-26 10:00"' \
        '"1h","dev","!100","y","04-05-26 10:00","04-05-26 11:00"'
    "$SPENT_BIN" push >/dev/null
    json=$(cat "$(slug_file 2026-05.json)")
    [[ "$json" == *'"ref": "#42"'* ]]
    [[ "$json" == *'"ref": "!100"'* ]]
}
