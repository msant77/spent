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

# All four global+local prompts: parent_domain, cache, client, slug
all_answers() {
    printf '%s\n' \
        "example.com" \
        "$SPENT_CACHE_DIR_TEST" \
        "Pontosat" \
        "pontosat"
}

# Just the two per-folder prompts (when global is already configured)
local_answers() {
    printf '%s\n' "Pontosat" "pontosat"
}

# --- show ------------------------------------------------------------------

@test "config show without configs prints (not set) for both layers" {
    run "$SPENT_BIN" config show
    [ "$status" -eq 0 ]
    [[ "$output" == *"(not set)"* ]]
}

@test "config show after setup prints both layers" {
    all_answers | "$SPENT_BIN" config >/dev/null
    run "$SPENT_BIN" config show
    [ "$status" -eq 0 ]
    [[ "$output" == *'SPENT_PARENT_DOMAIN="example.com"'* ]]
    [[ "$output" == *'SPENT_CLIENT_NAME="Pontosat"'* ]]
    [[ "$output" == *'SPENT_SLUG="pontosat"'* ]]
}

# --- file lifecycle ---------------------------------------------------------

@test "config writes site.conf with mode 0600" {
    all_answers | "$SPENT_BIN" config >/dev/null
    [ -f "$SPENT_GLOBAL_CONFIG" ]
    perm=$(stat -f '%Lp' "$SPENT_GLOBAL_CONFIG")
    [ "$perm" = "600" ]
}

@test "config writes ./.spent-config with mode 0600" {
    all_answers | "$SPENT_BIN" config >/dev/null
    [ -f .spent-config ]
    perm=$(stat -f '%Lp' .spent-config)
    [ "$perm" = "600" ]
}

@test "config writes expected global keys" {
    all_answers | "$SPENT_BIN" config >/dev/null
    grep -q '^SPENT_PARENT_DOMAIN="example.com"$' "$SPENT_GLOBAL_CONFIG"
    grep -q "^SPENT_CACHE_DIR=\"$SPENT_CACHE_DIR_TEST\"\$" "$SPENT_GLOBAL_CONFIG"
}

@test "config writes expected local keys" {
    all_answers | "$SPENT_BIN" config >/dev/null
    grep -q '^SPENT_CLIENT_NAME="Pontosat"$' .spent-config
    grep -q '^SPENT_SLUG="pontosat"$' .spent-config
}

# --- prompt behavior --------------------------------------------------------

@test "second run skips global prompts" {
    all_answers | "$SPENT_BIN" config >/dev/null
    rm .spent-config
    run bash -c "echo -e 'Goapice\ngoapice' | '$SPENT_BIN' config"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Cloudflare Pages project name"* ]]
    [[ "$output" == *"Client display name"* ]]
}

@test "--reset-site re-asks all four prompts" {
    all_answers | "$SPENT_BIN" config >/dev/null
    run bash -c "printf '%s\n' '' '' 'NewClient' 'new-client' | '$SPENT_BIN' config --reset-site"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Parent domain"* ]]
    [[ "$output" == *"Cache directory"* ]]
    [[ "$output" == *"Client display name"* ]]
    [[ "$output" == *"Subdomain label"* ]]
}

@test "blank input keeps existing default on --reset-site" {
    all_answers | "$SPENT_BIN" config >/dev/null
    printf '%s\n' '' '' 'NewClient' 'new-client' | "$SPENT_BIN" config --reset-site >/dev/null
    grep -q '^SPENT_PARENT_DOMAIN="example.com"$' "$SPENT_GLOBAL_CONFIG"
    grep -q '^SPENT_CLIENT_NAME="NewClient"$' .spent-config
}

# --- defaults from folder name ---------------------------------------------

@test "default slug derives from folder basename, lowercased" {
    folder_name=$(basename "$TEST_TMPDIR")
    expected_slug=$(printf '%s' "$folder_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g')
    # Take the slug default by leaving the slug prompt blank
    printf '%s\n' "example.com" "$SPENT_CACHE_DIR_TEST" "Pontosat" "" \
        | "$SPENT_BIN" config >/dev/null
    grep -q "^SPENT_SLUG=\"$expected_slug\"\$" .spent-config
}

# --- initial deploy --------------------------------------------------------

@test "deploy creates slug subdir with index.html and months.json" {
    all_answers | "$SPENT_BIN" config >/dev/null
    [ -f "$SPENT_CACHE_DIR_TEST/pontosat/index.html" ]
    [ -f "$SPENT_CACHE_DIR_TEST/pontosat/months.json" ]
}

@test "deploy writes months.json with empty months array" {
    all_answers | "$SPENT_BIN" config >/dev/null
    grep -q '"client":"Pontosat"' "$SPENT_CACHE_DIR_TEST/pontosat/months.json"
    grep -q '"months":\[\]' "$SPENT_CACHE_DIR_TEST/pontosat/months.json"
}

@test "deploy invokes wrangler with slug as project name and slug subdir" {
    all_answers | "$SPENT_BIN" config >/dev/null
    [ -f "$WRANGLER_LOG" ]
    grep -q 'pages deploy' "$WRANGLER_LOG"
    grep -q -- '--project-name=pontosat' "$WRANGLER_LOG"
    grep -q "$SPENT_CACHE_DIR_TEST/pontosat" "$WRANGLER_LOG"
}

@test "config auto-creates the Pages project before deploying" {
    all_answers | "$SPENT_BIN" config >/dev/null
    [ -f "$WRANGLER_LOG" ]
    grep -q 'pages project create pontosat --production-branch=main' "$WRANGLER_LOG"
    # And the create call must come before the deploy call.
    create_line=$(grep -n 'pages project create pontosat' "$WRANGLER_LOG" | head -1 | cut -d: -f1)
    deploy_line=$(grep -n 'pages deploy' "$WRANGLER_LOG" | head -1 | cut -d: -f1)
    [ "$create_line" -lt "$deploy_line" ]
}

@test "config tolerates an already-existing Pages project" {
    # Replace the stub with one that fails "already exists" on create
    # but otherwise records args and exits 0.
    rm "$STUB_DIR/wrangler"
    cat > "$STUB_DIR/wrangler" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-} ${2:-} ${3:-}" == "pages project create" ]]; then
    printf 'Error: A project with the name "%s" already exists.\n' "${4:-}" >&2
    exit 1
fi
case "${1:-}" in
    whoami) printf 'stub@example.com\n'; exit 0 ;;
    *)      [[ -n "${WRANGLER_LOG:-}" ]] && printf '%s\n' "$*" >> "$WRANGLER_LOG"; exit 0 ;;
esac
STUB
    chmod +x "$STUB_DIR/wrangler"

    run bash -c "printf '%s\n' 'example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'pontosat' | '$SPENT_BIN' config"
    [ "$status" -eq 0 ]
    grep -q 'pages deploy' "$WRANGLER_LOG"
}

# --- wrangler missing -------------------------------------------------------

@test "config without wrangler still writes config files and exits 0" {
    rm "$STUB_DIR/wrangler"
    export PATH="/usr/bin:/bin"
    run bash -c "printf '%s\n' 'example.com' '$SPENT_CACHE_DIR_TEST' 'Pontosat' 'pontosat' | '$SPENT_BIN' config"
    [ "$status" -eq 0 ]
    [ -f "$SPENT_GLOBAL_CONFIG" ]
    [ -f .spent-config ]
    [[ "$output" == *"wrangler not installed"* ]]
}
