#!/usr/bin/env zsh
emulate -R zsh

PASS_COUNT=0
FAIL_COUNT=0

log() {
  print -r -- ""
  print -r -- "[$1] $2"
}

pass() {
  (( PASS_COUNT += 1 ))
  print -r -- "[PASS] $*"
}

fail() {
  (( FAIL_COUNT += 1 ))
  print -r -- "[FAIL] $*"
}

assert_eq() {
  local got="$1"
  local expected="$2"
  local msg="$3"

  if [[ "$got" == "$expected" ]]; then
    pass "$msg"
  else
    fail "$msg (got: $got | expected: $expected)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$msg"
  else
    fail "$msg (missing: $needle)"
  fi
}

assert_true() {
  local msg="$1"
  shift

  if "$@"; then
    pass "$msg"
  else
    local rc=$?
    fail "$msg (rc=$rc)"
  fi
}

assert_false() {
  local msg="$1"
  shift

  if "$@"; then
    fail "$msg (unexpected success)"
  else
    pass "$msg"
  fi
}

assert_status() {
  local expected="$1"
  local msg="$2"
  shift 2

  "$@"
  local rc=$?

  if [[ "$rc" == "$expected" ]]; then
    pass "$msg"
  else
    fail "$msg (got rc=$rc | expected rc=$expected)"
  fi
}

assert_file_readable() {
  local file="$1"
  local msg="$2"

  if [[ -r "$file" ]]; then
    pass "$msg"
  else
    fail "$msg (not readable: $file)"
  fi
}

restore_var() {
  local name="$1"
  local had_value="$2"
  local old_value="$3"

  if [[ "$had_value" == "1" ]]; then
    typeset -g "$name=$old_value"
  else
    unset "$name"
  fi
}

REPO_ROOT="${1:-}"
if [[ -z "$REPO_ROOT" || ! -d "$REPO_ROOT/zsh" ]]; then
  print -r -- "[FATAL] usage: test-core.zsh <repo-root>" >&2
  exit 1
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-box-zsh-core.XXXXXX")" || exit 1
trap 'rm -rf "$TMPROOT"' EXIT

typeset -g ZDOTDIR="$REPO_ROOT/zsh"
typeset -g ZSH_ROOT="$ZDOTDIR"
typeset -g ZSH_CONF_DIR="$ZSH_ROOT/conf"
typeset -g ZSH_CORE_DIR="$ZSH_ROOT/core"
typeset -g ZSH_FEATURE_DIR="$ZSH_ROOT/features"
typeset -g ZSH_STAGE_DIR="$ZSH_ROOT/stage"
typeset -g ZSH_THEME_DIR="$ZSH_ROOT/themes"
typeset -g ZSH_USER_DIR="$ZSH_ROOT/user"
typeset -g ZSH_CACHE_DIR="$TMPROOT/cache"
typeset -g ZSH_CACHE_SNIPPET_DIR="$ZSH_CACHE_DIR/snippets"

mkdir -p "$ZSH_CACHE_SNIPPET_DIR"

source "$ZSH_CORE_DIR/00-core.zsh" || exit 1
source "$ZSH_CORE_DIR/10-path.zsh" || exit 1
source "$ZSH_CORE_DIR/20-detect.zsh" || exit 1
source "$ZSH_CORE_DIR/30-cache.zsh" || exit 1
source "$ZSH_CORE_DIR/40-lazy.zsh" || exit 1

typeset -ga ORIGINAL_PATH=("${path[@]}")

log STEP "00-core.zsh"

print -r -- 'typeset -g TEST_OPTIONAL_SOURCE=loaded_optional' >| "$TMPROOT/optional-source.zsh"
unset TEST_OPTIONAL_SOURCE
assert_status 0 "zsh_source_optional skips missing file" zsh_source_optional "$TMPROOT/missing.zsh"
assert_status 0 "zsh_source_optional loads readable file" zsh_source_optional "$TMPROOT/optional-source.zsh"
assert_eq "${TEST_OPTIONAL_SOURCE:-unset}" "loaded_optional" "zsh_source_optional updates current shell"

print -r -- 'typeset -g TEST_REQUIRED_SOURCE=loaded_required' >| "$TMPROOT/required-source.zsh"
unset TEST_REQUIRED_SOURCE
assert_status 0 "zsh_source_required loads readable file" zsh_source_required "$TMPROOT/required-source.zsh"
assert_eq "${TEST_REQUIRED_SOURCE:-unset}" "loaded_required" "zsh_source_required updates current shell"
assert_status 1 "zsh_source_required rejects missing file" zsh_source_required "$TMPROOT/required-missing.zsh"

assert_true "zsh_has_cmd finds zsh" zsh_has_cmd zsh
assert_false "zsh_has_cmd rejects missing command" zsh_has_cmd __oh_box_missing_cmd__
assert_false "zsh_is_interactive is false in unit test shell" zsh_is_interactive
assert_false "zsh_is_login is false in unit test shell" zsh_is_login

DEBUG_OUT="$({ ZSH_DEBUG=1; zsh_log_debug "hello"; } 2>&1)"
assert_contains "$DEBUG_OUT" "[zsh-debug] hello" "zsh_log_debug emits prefixed output"
DEBUG_OFF_OUT="$({ ZSH_DEBUG=0; zsh_log_debug "hello"; } 2>&1)"
assert_eq "$DEBUG_OFF_OUT" "" "zsh_log_debug stays quiet when disabled"
WARN_OUT="$({ zsh_warn "watch out"; } 2>&1)"
assert_contains "$WARN_OUT" "[zsh] watch out" "zsh_warn emits prefixed output"

rm -rf "$TMPROOT/ensure-dir"
assert_status 0 "zsh_ensure_dir creates missing directory" zsh_ensure_dir "$TMPROOT/ensure-dir"
assert_true "zsh_ensure_dir result exists" test -d "$TMPROOT/ensure-dir"

assert_true "zsh_feature_is_valid_name accepts env-path" zsh_feature_is_valid_name env-path
assert_false "zsh_feature_is_valid_name rejects path traversal" zsh_feature_is_valid_name ../bad

mkdir -p "$TMPROOT/features"
typeset -g ZSH_FEATURE_DIR="$TMPROOT/features"
print -r -- 'typeset -ga TEST_FEATURE_ORDER; TEST_FEATURE_ORDER+=(one)' >| "$ZSH_FEATURE_DIR/one.zsh"
print -r -- 'typeset -ga TEST_FEATURE_ORDER; TEST_FEATURE_ORDER+=(two)' >| "$ZSH_FEATURE_DIR/two.zsh"

typeset -ga TEST_FEATURE_ORDER=()
assert_status 0 "zsh_load_feature loads existing feature" zsh_load_feature one
assert_eq "${(j.:.)TEST_FEATURE_ORDER}" "one" "zsh_load_feature executes sourced file"
assert_status 1 "zsh_load_feature rejects invalid feature name" zsh_load_feature ../bad
assert_status 1 "zsh_load_feature rejects missing feature" zsh_load_feature missing

TEST_FEATURE_ORDER=()
assert_status 1 "zsh_load_feature_list keeps failure status for missing feature" zsh_load_feature_list one missing two
assert_eq "${(j.:.)TEST_FEATURE_ORDER}" "one:two" "zsh_load_feature_list keeps loading remaining features"

log STEP "10-path.zsh"

mkdir -p "$TMPROOT/bin-a" "$TMPROOT/bin-b"
path=("$TMPROOT/bin-a")
assert_true "path_contains finds existing directory" path_contains "$TMPROOT/bin-a"
assert_false "path_contains rejects missing directory" path_contains "$TMPROOT/bin-b"

path=("$TMPROOT/bin-a")
path_prepend "$TMPROOT/bin-b"
assert_eq "${(j.:.)path}" "$TMPROOT/bin-b:$TMPROOT/bin-a" "path_prepend moves directory to the front"

path=("$TMPROOT/bin-b")
path_append "$TMPROOT/bin-a"
assert_eq "${(j.:.)path}" "$TMPROOT/bin-b:$TMPROOT/bin-a" "path_append adds directory to the end"

path=("$TMPROOT/bin-a" "$TMPROOT/bin-b")
path_remove "$TMPROOT/bin-a"
assert_eq "${(j.:.)path}" "$TMPROOT/bin-b" "path_remove drops matching directory"

typeset +U path PATH
path=("$TMPROOT/bin-a" "$TMPROOT/bin-a" "$TMPROOT/bin-b")
typeset -U path PATH
path_dedup
assert_eq "${(j.:.)path}" "$TMPROOT/bin-a:$TMPROOT/bin-b" "path_dedup removes duplicates"

typeset -U path PATH
path=("${ORIGINAL_PATH[@]}")

log STEP "20-detect.zsh"

case "$(uname -s 2>/dev/null)" in
  Darwin) EXPECTED_OS="macos" ;;
  Linux) EXPECTED_OS="linux" ;;
  *) EXPECTED_OS="unknown" ;;
esac
zsh_detect_os
assert_eq "$REPLY" "$EXPECTED_OS" "zsh_detect_os normalizes uname -s"

RAW_ARCH="$(uname -m 2>/dev/null)"
case "$RAW_ARCH" in
  arm64|aarch64) EXPECTED_ARCH="arm64" ;;
  x86_64|amd64) EXPECTED_ARCH="x86_64" ;;
  *) EXPECTED_ARCH="${RAW_ARCH:-unknown}" ;;
esac
zsh_detect_arch
assert_eq "$REPLY" "$EXPECTED_ARCH" "zsh_detect_arch normalizes uname -m"

HAD_TERMUX_VERSION="${+TERMUX_VERSION}"
OLD_TERMUX_VERSION="${TERMUX_VERSION-}"
TERMUX_VERSION="1"
assert_true "zsh_detect_termux respects TERMUX_VERSION" zsh_detect_termux
restore_var TERMUX_VERSION "$HAD_TERMUX_VERSION" "$OLD_TERMUX_VERSION"

HAD_WSL_INTEROP="${+WSL_INTEROP}"
OLD_WSL_INTEROP="${WSL_INTEROP-}"
WSL_INTEROP="1"
assert_true "zsh_detect_wsl respects WSL_INTEROP" zsh_detect_wsl
restore_var WSL_INTEROP "$HAD_WSL_INTEROP" "$OLD_WSL_INTEROP"

HAD_SSH_CONNECTION="${+SSH_CONNECTION}"
OLD_SSH_CONNECTION="${SSH_CONNECTION-}"
SSH_CONNECTION="client host"
assert_true "zsh_detect_ssh respects SSH_CONNECTION" zsh_detect_ssh
restore_var SSH_CONNECTION "$HAD_SSH_CONNECTION" "$OLD_SSH_CONNECTION"

HAD_HOST="${+HOST}"
OLD_HOST="${HOST-}"
HAD_TERMUX_VERSION="${+TERMUX_VERSION}"
OLD_TERMUX_VERSION="${TERMUX_VERSION-}"
HAD_WSL_INTEROP="${+WSL_INTEROP}"
OLD_WSL_INTEROP="${WSL_INTEROP-}"
HAD_SSH_CONNECTION="${+SSH_CONNECTION}"
OLD_SSH_CONNECTION="${SSH_CONNECTION-}"

HOST="unit-host"
TERMUX_VERSION="1"
WSL_INTEROP="1"
SSH_CONNECTION="client host"
zsh_detect_env
assert_eq "$ZSH_HOSTNAME" "unit-host" "zsh_detect_env prefers HOST when present"
assert_eq "$ZSH_IS_TERMUX" "1" "zsh_detect_env exports Termux flag"
assert_eq "$ZSH_IS_WSL" "1" "zsh_detect_env exports WSL flag"
assert_eq "$ZSH_IS_SSH" "1" "zsh_detect_env exports SSH flag"
restore_var HOST "$HAD_HOST" "$OLD_HOST"
restore_var TERMUX_VERSION "$HAD_TERMUX_VERSION" "$OLD_TERMUX_VERSION"
restore_var WSL_INTEROP "$HAD_WSL_INTEROP" "$OLD_WSL_INTEROP"
restore_var SSH_CONNECTION "$HAD_SSH_CONNECTION" "$OLD_SSH_CONNECTION"

log STEP "30-cache.zsh"

typeset -g ZSH_CACHE_DIR="$TMPROOT/cache-unit"
typeset -g ZSH_CACHE_SNIPPET_DIR="$ZSH_CACHE_DIR/snippets"
zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

zcache_sanitize_key ""
assert_eq "$REPLY" "default" "zcache_sanitize_key uses default fallback for empty key"
zcache_sanitize_key "tool/shellenv zsh"
assert_eq "$REPLY" "tool_shellenv_zsh" "zcache_sanitize_key normalizes unsafe characters"

zcache_path "tool/shellenv zsh"
CACHE_FILE="$REPLY"
assert_eq "$CACHE_FILE" "$ZSH_CACHE_SNIPPET_DIR/tool_shellenv_zsh.zsh" "zcache_path builds cache file path"

print -r -- "cached" >| "$CACHE_FILE"
assert_status 0 "zcache_get_mtime reads cache file mtime" zcache_get_mtime "$CACHE_FILE"
if [[ "$REPLY" == <-> ]]; then
  pass "zcache_get_mtime returns numeric timestamp"
else
  fail "zcache_get_mtime returns numeric timestamp (got: $REPLY)"
fi

assert_true "zcache_is_fresh accepts fresh cache with positive TTL" zcache_is_fresh "$CACHE_FILE" 60
assert_true "zcache_is_fresh treats ttl=0 as always fresh" zcache_is_fresh "$CACHE_FILE" 0
touch -t 200001010000 "$CACHE_FILE"
assert_false "zcache_is_fresh rejects stale cache" zcache_is_fresh "$CACHE_FILE" 1

assert_status 2 "zcache_ensure_cmd validates usage" zcache_ensure_cmd "bad"
assert_status 0 "zcache_ensure_cmd rebuilds missing cache" zcache_ensure_cmd "unit-cache" 60 -- print -r -- 'typeset -g TEST_CACHE_FILE=ready'
assert_file_readable "$REPLY" "zcache_ensure_cmd returns readable cache file"

unset TEST_CACHE_VALUE
assert_status 0 "zcache_source_cmd sources trusted cache file" zcache_source_cmd "unit-cache-source" 60 -- print -r -- 'typeset -g TEST_CACHE_VALUE=from_cache'
assert_eq "${TEST_CACHE_VALUE:-unset}" "from_cache" "zcache_source_cmd updates current shell"
zcache_path "unit-cache-source"
SOURCE_CACHE_FILE="$REPLY"
assert_status 0 "zcache_invalidate removes cache file" zcache_invalidate "unit-cache-source"
assert_false "zcache_invalidate removes target from disk" test -e "$SOURCE_CACHE_FILE"

log STEP "40-lazy.zsh"

__zlazy_loader_by_cmd=()
__zlazy_loader_done=()
__zlazy_loader_active=()

assert_true "zlazy_is_valid_name accepts foo_bar" zlazy_is_valid_name foo_bar
assert_false "zlazy_is_valid_name rejects foo-bar" zlazy_is_valid_name foo-bar
assert_status 1 "__zlazy_define_wrapper rejects invalid command name" __zlazy_define_wrapper foo-bar
assert_status 2 "__zlazy_run_loader rejects empty loader name" __zlazy_run_loader ""
assert_status 127 "__zlazy_run_loader rejects missing loader" __zlazy_run_loader __missing_loader__
assert_status 127 "__zlazy_dispatch rejects unregistered command" __zlazy_dispatch __missing_lazy_cmd__
assert_status 2 "zlazy_register requires loader and commands" zlazy_register

typeset -gi TEST_LAZY_RUNS=0
lazy_loader() {
  (( TEST_LAZY_RUNS += 1 ))
  lazycmd() {
    print -r -- "lazy:$*:$TEST_LAZY_RUNS"
  }
}

assert_status 0 "zlazy_register installs wrapper for command" zlazy_register lazy_loader lazycmd
LAZY_OUT_FILE="$TMPROOT/lazy-first.out"
lazycmd hello world >| "$LAZY_OUT_FILE"
LAZY_OUT="$(<"$LAZY_OUT_FILE")"
assert_eq "$LAZY_OUT" "lazy:hello world:1" "zlazy_register dispatches first call through loader"
LAZY_OUT_FILE="$TMPROOT/lazy-second.out"
lazycmd again >| "$LAZY_OUT_FILE"
LAZY_OUT="$(<"$LAZY_OUT_FILE")"
assert_eq "$LAZY_OUT" "lazy:again:1" "lazy loader runs only once"
assert_eq "$TEST_LAZY_RUNS" "1" "lazy loader state tracks successful initialization"

zlazy_mark_loaded manual_loader
assert_eq "${__zlazy_loader_done[manual_loader]:-}" "1" "zlazy_mark_loaded marks loader as complete"
__zlazy_loader_active[manual_loader]=1
zlazy_reset_loader manual_loader
assert_eq "${__zlazy_loader_done[manual_loader]:-}${__zlazy_loader_active[manual_loader]:-}" "" "zlazy_reset_loader clears loader state"

print -r -- ""
print -r -- "[RESULT] PASS=$PASS_COUNT FAIL=$FAIL_COUNT"

if (( FAIL_COUNT != 0 )); then
  exit 1
fi
