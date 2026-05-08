#!/usr/bin/env bats

setup() {
    SPENT_BIN="$BATS_TEST_DIRNAME/../spent"
    TEMPLATE="$BATS_TEST_DIRNAME/../template/index.html"
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

# Drive the five global+local prompts with given client name and slug
configure_with() {
    local client="$1" slug="$2"
    printf '%s\n' \
        "spent-reports" \
        "https://reports.example.com" \
        "$SPENT_CACHE_DIR_TEST" \
        "$client" \
        "$slug"
}

# --- slug validation -------------------------------------------------------

@test "slug with slash is rejected" {
    run bash -c "$(configure_with 'Pontosat' 'foo/bar' | sed 's/^/echo /' | tr '\n' '\n')true | '$SPENT_BIN' config"
    # simpler reformulation:
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'foo/bar' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with dot-dot is rejected" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' '../etc' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with space is rejected" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'foo bar' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with leading hyphen is rejected" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' '-foo' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with trailing hyphen is rejected" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'foo-' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with uppercase is rejected" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'Pontosat' | '$SPENT_BIN' config"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid slug"* ]]
}

@test "slug with hyphen between alphanumerics is accepted" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'pontosat-a3f9d2' | '$SPENT_BIN' config"
    [ "$status" -eq 0 ]
}

@test "slug single character is accepted" {
    run bash -c "printf '%s\n' 'spent-reports' 'https://reports.example.com' '$SPENT_CACHE_DIR_TEST' 'P' 'p' | '$SPENT_BIN' config"
    [ "$status" -eq 0 ]
}

# --- bash quote-escape round-trip -----------------------------------------

source_local_config_value() {
    local key="$1"
    bash -c "
        unset $key
        # shellcheck disable=SC1091
        source ./.spent-config
        printf '%s' \"\${$key}\"
    "
}

@test "client name with double quote round-trips" {
    configure_with 'Foo "Bar"' 'foo-bar' | "$SPENT_BIN" config >/dev/null
    val=$(source_local_config_value SPENT_CLIENT_NAME)
    [ "$val" = 'Foo "Bar"' ]
}

@test "client name with backslash round-trips" {
    configure_with 'A\B' 'a-b' | "$SPENT_BIN" config >/dev/null
    val=$(source_local_config_value SPENT_CLIENT_NAME)
    [ "$val" = 'A\B' ]
}

@test "client name with dollar sign does not expand on source" {
    configure_with '$HOME-Inc' 'h-inc' | "$SPENT_BIN" config >/dev/null
    val=$(source_local_config_value SPENT_CLIENT_NAME)
    [ "$val" = '$HOME-Inc' ]
}

@test "client name with backtick does not execute on source" {
    configure_with 'A`whoami`B' 'a-b' | "$SPENT_BIN" config >/dev/null
    val=$(source_local_config_value SPENT_CLIENT_NAME)
    [ "$val" = 'A`whoami`B' ]
}

@test "client name with all four sharp characters round-trips" {
    configure_with 'Foo "Bar" \X $HOME `id`' 'foo-bar' | "$SPENT_BIN" config >/dev/null
    val=$(source_local_config_value SPENT_CLIENT_NAME)
    [ "$val" = 'Foo "Bar" \X $HOME `id`' ]
}

# --- CSP on the customer page ---------------------------------------------

@test "template includes Content-Security-Policy meta" {
    grep -q '<meta http-equiv="Content-Security-Policy"' "$TEMPLATE"
}

@test "CSP forbids external default sources" {
    grep -q "default-src 'self'" "$TEMPLATE"
}

@test "CSP disables form-action and frame-ancestors" {
    grep -q "form-action 'none'" "$TEMPLATE"
    grep -q "frame-ancestors 'none'" "$TEMPLATE"
}

@test "template sets referrer to no-referrer" {
    grep -q '<meta name="referrer" content="no-referrer">' "$TEMPLATE"
}
