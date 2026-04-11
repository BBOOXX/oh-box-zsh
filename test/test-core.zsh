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
INFO_OUT="$(zsh_msg info demo "heads up")"
assert_eq "$INFO_OUT" "[demo] heads up" "zsh_msg emits scoped info on stdout"
WARN_OUT="$({ zsh_warn "watch out"; } 2>&1)"
assert_contains "$WARN_OUT" "[zsh] watch out" "zsh_warn emits prefixed output"
ERROR_OUT="$({ zsh_msg error demo "broken"; } 2>&1)"
assert_contains "$ERROR_OUT" "[demo] broken" "zsh_msg emits scoped errors on stderr"

rm -rf "$TMPROOT/ensure-dir"
assert_status 0 "zsh_ensure_dir creates missing directory" zsh_ensure_dir "$TMPROOT/ensure-dir"
assert_true "zsh_ensure_dir result exists" test -d "$TMPROOT/ensure-dir"

assert_status 0 "zsh_now_seconds returns current timestamp" zsh_now_seconds
if [[ "$REPLY" == <-> ]]; then
  pass "zsh_now_seconds returns numeric timestamp"
else
  fail "zsh_now_seconds returns numeric timestamp (got: $REPLY)"
fi

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

LONG_CACHE_KEY=""
while (( ${#LONG_CACHE_KEY} < 260 )); do
  LONG_CACHE_KEY+="pyenv-init:"
done
zcache_path "$LONG_CACHE_KEY"
LONG_CACHE_FILE="$REPLY"
LONG_CACHE_BASE="${LONG_CACHE_FILE:t}"
assert_true "zcache_path compacts overlong cache filenames" test "${#LONG_CACHE_BASE}" -lt 128
assert_contains "$LONG_CACHE_BASE" "pyenv-init_pyenv-init" "zcache_path keeps a readable prefix for long keys"

print -r -- "cached" >| "$CACHE_FILE"
assert_status 0 "zsh_file_mtime reads cache file mtime" zsh_file_mtime "$CACHE_FILE"
if [[ "$REPLY" == <-> ]]; then
  pass "zsh_file_mtime returns numeric timestamp"
else
  fail "zsh_file_mtime returns numeric timestamp (got: $REPLY)"
fi
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
ZCACHE_MISS_DEBUG_OUT="$({ ZSH_DEBUG=1; zcache_ensure_cmd "debug-cache" 60 -- print -r -- 'typeset -g TEST_DEBUG_CACHE=ready'; } 2>&1)"
assert_contains "$ZCACHE_MISS_DEBUG_OUT" "zcache: ensure cache-miss key=debug-cache" "zcache debug 输出 cache miss"
assert_contains "$ZCACHE_MISS_DEBUG_OUT" "zcache: ensure refresh-done key=debug-cache" "zcache debug 输出 refresh 完成"
ZCACHE_HIT_DEBUG_OUT="$({ ZSH_DEBUG=1; zcache_ensure_cmd "debug-cache" 60 -- print -r -- 'typeset -g TEST_DEBUG_CACHE=changed'; } 2>&1)"
assert_contains "$ZCACHE_HIT_DEBUG_OUT" "zcache: ensure cache-hit key=debug-cache" "zcache debug 输出 cache hit"

unset TEST_CACHE_VALUE
assert_status 0 "zcache_source_cmd sources trusted cache file" zcache_source_cmd "unit-cache-source" 60 -- print -r -- 'typeset -g TEST_CACHE_VALUE=from_cache'
assert_eq "${TEST_CACHE_VALUE:-unset}" "from_cache" "zcache_source_cmd updates current shell"
ZCACHE_SOURCE_DEBUG_OUT="$({ ZSH_DEBUG=1; zcache_source_cmd "debug-cache" 60 -- print -r -- 'typeset -g TEST_DEBUG_CACHE=changed_again'; } 2>&1)"
assert_contains "$ZCACHE_SOURCE_DEBUG_OUT" "zcache: source file=" "zcache debug 输出 source 文件路径"
zcache_path "unit-cache-source"
SOURCE_CACHE_FILE="$REPLY"
assert_status 0 "zcache_invalidate removes cache file" zcache_invalidate "unit-cache-source"
assert_false "zcache_invalidate removes target from disk" test -e "$SOURCE_CACHE_FILE"

log STEP "features/brew.zsh"

HAD_ZSH_OS="${+ZSH_OS}"
OLD_ZSH_OS="${ZSH_OS-}"
HAD_ZSH_ARCH="${+ZSH_ARCH}"
OLD_ZSH_ARCH="${ZSH_ARCH-}"
typeset -ga TEST_BREW_SAVED_PATH=("${path[@]}")
mkdir -p "$TMPROOT/no-brew-bin"
path=("$TMPROOT/no-brew-bin")
rehash
ZSH_OS="unknown"
ZSH_ARCH="unknown"
source "$REPO_ROOT/zsh/features/brew.zsh" || exit 1
path=("${TEST_BREW_SAVED_PATH[@]}")
rehash

ZSH_OS="macos"
ZSH_ARCH="arm64"
assert_status 0 "zsh_brew_default_bin supports macOS Apple Silicon" zsh_brew_default_bin
assert_eq "$REPLY" "/opt/homebrew/bin/brew" "Apple Silicon 默认 brew 路径正确"

ZSH_OS="macos"
ZSH_ARCH="x86_64"
assert_status 0 "zsh_brew_default_bin supports macOS Intel" zsh_brew_default_bin
assert_eq "$REPLY" "/usr/local/bin/brew" "Intel macOS 默认 brew 路径正确"

ZSH_OS="linux"
ZSH_ARCH="x86_64"
assert_status 0 "zsh_brew_default_bin supports Linux" zsh_brew_default_bin
assert_eq "$REPLY" "/home/linuxbrew/.linuxbrew/bin/brew" "Linux 默认 brew 路径正确"

ZSH_OS="unknown"
ZSH_ARCH="unknown"
assert_status 1 "zsh_brew_default_bin skips unsupported platform" zsh_brew_default_bin

BREW_DEFAULT_DEBUG_OUT="$({ ZSH_DEBUG=1; ZSH_OS="macos"; ZSH_ARCH="arm64"; zsh_brew_default_bin >/dev/null; } 2>&1)"
assert_contains "$BREW_DEFAULT_DEBUG_OUT" "brew: default-bin return=0 brew=/opt/homebrew/bin/brew" "brew default-bin debug 输出结果路径"

restore_var ZSH_OS "$HAD_ZSH_OS" "$OLD_ZSH_OS"
restore_var ZSH_ARCH "$HAD_ZSH_ARCH" "$OLD_ZSH_ARCH"

typeset -g ZSH_CACHE_DIR="$TMPROOT/brew-cache"
typeset -g ZSH_CACHE_SNIPPET_DIR="$ZSH_CACHE_DIR/snippets"
zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

typeset -g TEST_BREW_ROOT="$TMPROOT/fake-brew"
typeset -g TEST_BREW_BIN="$TEST_BREW_ROOT/bin/brew"
typeset -g TEST_BREW_COUNT_FILE="$TMPROOT/fake-brew.count"
typeset -g TEST_BREW_PATH_FILE="$TMPROOT/fake-brew.path"
mkdir -p "$TEST_BREW_ROOT/bin"

{
  print -r -- '#!/bin/sh'
  print -r -- 'count=0'
  print -r -- "[ -f \"$TEST_BREW_COUNT_FILE\" ] && count=\$(cat \"$TEST_BREW_COUNT_FILE\")"
  print -r -- 'count=$((count + 1))'
  print -r -- "printf '%s\n' \"\$count\" > \"$TEST_BREW_COUNT_FILE\""
  print -r -- "printf '%s\n' \"\$PATH\" > \"$TEST_BREW_PATH_FILE\""
  print -r -- 'if [ "$1" = "shellenv" ] && [ "$2" = "zsh" ]; then'
  print -r -- "  case \":\$PATH:\" in"
  print -r -- "    *\":$TEST_BREW_ROOT/bin:\"*) exit 0 ;;"
  print -r -- '  esac'
  print -r -- '  printf "%s\n" "typeset -gx TEST_BREW_ENV=loaded_from_fake_brew"'
  print -r -- '  printf "%s\n" "typeset -gx TEST_BREW_LOAD_COUNT=${count}"'
  print -r -- '  exit 0'
  print -r -- 'fi'
  print -r -- 'exit 1'
} >| "$TEST_BREW_BIN"
chmod +x "$TEST_BREW_BIN"

typeset -g ZSH_BREW_SHELLENV_TTL=3600
typeset -ga TEST_BREW_PATH_BEFORE=("${path[@]}")
path=("$TEST_BREW_ROOT/bin" "${TEST_BREW_PATH_BEFORE[@]}")
rehash
unset TEST_BREW_ENV TEST_BREW_LOAD_COUNT

assert_status 0 "zsh_brew_init sources cached brew shellenv output" zsh_brew_init
assert_eq "${TEST_BREW_ENV:-unset}" "loaded_from_fake_brew" "brew feature updates current shell from shellenv"
assert_eq "${TEST_BREW_LOAD_COUNT:-unset}" "1" "brew feature sources first shellenv output"

TEST_BREW_INVOKE_COUNT="$(<"$TEST_BREW_COUNT_FILE")"
assert_eq "$TEST_BREW_INVOKE_COUNT" "1" "brew feature invokes brew once on cold cache"
TEST_BREW_CALLED_PATH="$(<"$TEST_BREW_PATH_FILE")"
if [[ "$TEST_BREW_CALLED_PATH" == *"$TEST_BREW_ROOT/bin"* ]]; then
  fail "brew feature should call brew shellenv with sanitized PATH"
else
  pass "brew feature calls brew shellenv with sanitized PATH"
fi

zsh_brew_cache_key "$TEST_BREW_BIN"
zcache_path "$REPLY"
TEST_BREW_CACHE_FILE="$REPLY"
assert_file_readable "$TEST_BREW_CACHE_FILE" "brew feature creates readable shellenv cache"

unset TEST_BREW_ENV TEST_BREW_LOAD_COUNT
assert_status 0 "zsh_brew_init reuses fresh cache" zsh_brew_init
assert_eq "${TEST_BREW_ENV:-unset}" "loaded_from_fake_brew" "brew feature can re-source cached shellenv"
assert_eq "${TEST_BREW_LOAD_COUNT:-unset}" "1" "cached shellenv keeps original content"
TEST_BREW_INVOKE_COUNT="$(<"$TEST_BREW_COUNT_FILE")"
assert_eq "$TEST_BREW_INVOKE_COUNT" "1" "brew feature avoids re-running brew while cache is fresh"
BREW_INIT_DEBUG_OUT="$({ ZSH_DEBUG=1; zsh_brew_init >/dev/null; } 2>&1)"
assert_contains "$BREW_INIT_DEBUG_OUT" "brew: init brew=$TEST_BREW_BIN" "brew init debug 输出找到的 brew 路径"
assert_contains "$BREW_INIT_DEBUG_OUT" "brew: load-shellenv return=0 brew=$TEST_BREW_BIN" "brew init debug 输出 shellenv 加载结果"

path=("${ORIGINAL_PATH[@]}")
rehash
unset ZSH_BREW_SHELLENV_TTL TEST_BREW_ENV TEST_BREW_LOAD_COUNT

log STEP "features/pyenv.zsh"

HAD_ZSH_PYENV_ROOT="${+ZSH_PYENV_ROOT}"
OLD_ZSH_PYENV_ROOT="${ZSH_PYENV_ROOT-}"
HAD_ZSH_PYENV_INIT_TTL="${+ZSH_PYENV_INIT_TTL}"
OLD_ZSH_PYENV_INIT_TTL="${ZSH_PYENV_INIT_TTL-}"
HAD_ZSH_PYENV_REHASH_ON_INIT="${+ZSH_PYENV_REHASH_ON_INIT}"
OLD_ZSH_PYENV_REHASH_ON_INIT="${ZSH_PYENV_REHASH_ON_INIT-}"
HAD_ZSH_PYENV_ENABLE_VIRTUALENV_LAZY="${+ZSH_PYENV_ENABLE_VIRTUALENV_LAZY}"
OLD_ZSH_PYENV_ENABLE_VIRTUALENV_LAZY="${ZSH_PYENV_ENABLE_VIRTUALENV_LAZY-}"
HAD_ZSH_PYENV_VIRTUALENV_HOOK_MODE="${+ZSH_PYENV_VIRTUALENV_HOOK_MODE}"
OLD_ZSH_PYENV_VIRTUALENV_HOOK_MODE="${ZSH_PYENV_VIRTUALENV_HOOK_MODE-}"
HAD_ZSH_PYENV_VIRTUALENV_TRIGGER_FILE="${+ZSH_PYENV_VIRTUALENV_TRIGGER_FILE}"
OLD_ZSH_PYENV_VIRTUALENV_TRIGGER_FILE="${ZSH_PYENV_VIRTUALENV_TRIGGER_FILE-}"
HAD_ZSH_CURRENT_STAGE="${+ZSH_CURRENT_STAGE}"
OLD_ZSH_CURRENT_STAGE="${ZSH_CURRENT_STAGE-}"
HAD_PYENV_ROOT="${+PYENV_ROOT}"
OLD_PYENV_ROOT="${PYENV_ROOT-}"
HAD_PYENV_SHELL="${+PYENV_SHELL}"
OLD_PYENV_SHELL="${PYENV_SHELL-}"
HAD_PYENV_VIRTUALENV_INIT="${+PYENV_VIRTUALENV_INIT}"
OLD_PYENV_VIRTUALENV_INIT="${PYENV_VIRTUALENV_INIT-}"
HAD_PRECMD_FUNCTIONS="${+precmd_functions}"
typeset -ga TEST_PYENV_SAVED_PRECMD_FUNCTIONS=("${precmd_functions[@]}")
HAD_CHPWD_FUNCTIONS="${+chpwd_functions}"
typeset -ga TEST_PYENV_SAVED_CHPWD_FUNCTIONS=("${chpwd_functions[@]}")
typeset -g TEST_PYENV_SAVED_PWD="$PWD"

typeset -g TEST_PYENV_ROOT="$TMPROOT/fake-pyenv-root"
typeset -g TEST_PYENV_BIN="$TEST_PYENV_ROOT/bin/pyenv"
typeset -g TEST_PYENV_SHIMS="$TEST_PYENV_ROOT/shims"
typeset -g TEST_PYENV_COUNT_FILE="$TMPROOT/fake-pyenv.count"
typeset -g TEST_PYENV_ARGS_FILE="$TMPROOT/fake-pyenv.args"
typeset -g TEST_PYENV_REHASH_FILE="$TMPROOT/fake-pyenv.rehash"
typeset -g TEST_PYENV_COMPLETION_FILE="$TMPROOT/fake-pyenv-completion.zsh"
typeset -g TEST_PYENV_LINK="$TMPROOT/fake-pyenv-link"
typeset -g TEST_PYENV_PROJECT="$TMPROOT/fake-pyenv-project"
typeset -g TEST_PYENV_PROJECT_SUBDIR="$TEST_PYENV_PROJECT/app"

mkdir -p "$TEST_PYENV_ROOT/bin" "$TEST_PYENV_SHIMS"
mkdir -p "$TEST_PYENV_PROJECT_SUBDIR"
ln -sf "$TEST_PYENV_BIN" "$TEST_PYENV_LINK"
print -r -- 'typeset -g TEST_PYENV_COMPLETION_MARK=loaded_from_completion' >| "$TEST_PYENV_COMPLETION_FILE"
print -r -- "3.11.9/envs/unit" >| "$TEST_PYENV_PROJECT/.python-version"

{
  print -r -- '#!/bin/sh'
  print -r -- 'count=0'
  print -r -- "[ -f \"$TEST_PYENV_COUNT_FILE\" ] && count=\$(cat \"$TEST_PYENV_COUNT_FILE\")"
  print -r -- 'count=$((count + 1))'
  print -r -- "printf '%s\n' \"\$count\" > \"$TEST_PYENV_COUNT_FILE\""
  print -r -- "printf '%s\n' \"\$*\" > \"$TEST_PYENV_ARGS_FILE\""
  print -r -- 'case "$*" in'
  print -r -- "  'init --path --no-push-path --no-rehash')"
  print -r -- "    printf '%s\n' 'typeset -gx TEST_PYENV_LOGIN_MARK=loaded_from_login'"
  print -r -- "    printf '%s\n' 'if [[ \":\$PATH:\" != *\":$TEST_PYENV_SHIMS:\"* ]]; then export PATH=\"$TEST_PYENV_SHIMS:\${PATH}\"; fi'"
  print -r -- '    exit 0'
  print -r -- '    ;;'
  print -r -- "  'init --path --no-push-path')"
  print -r -- "    printf '%s\n' 'typeset -gx TEST_PYENV_LOGIN_MARK=loaded_from_login'"
  print -r -- "    printf '%s\n' 'if [[ \":\$PATH:\" != *\":$TEST_PYENV_SHIMS:\"* ]]; then export PATH=\"$TEST_PYENV_SHIMS:\${PATH}\"; fi'"
  print -r -- "    printf '%s\n' 'command pyenv rehash'"
  print -r -- '    exit 0'
  print -r -- '    ;;'
  print -r -- "  'init - --no-push-path --no-rehash zsh')"
  print -r -- "    printf '%s\n' 'typeset -gx TEST_PYENV_INTERACTIVE_MARK=loaded_from_interactive'"
  print -r -- "    printf '%s\n' 'if [[ \":\$PATH:\" != *\":$TEST_PYENV_SHIMS:\"* ]]; then export PATH=\"$TEST_PYENV_SHIMS:\${PATH}\"; fi'"
  print -r -- "    printf '%s\n' 'export PYENV_SHELL=zsh'"
  print -r -- "    printf '%s\n' \"source '$TEST_PYENV_COMPLETION_FILE'\""
  print -r -- "    printf '%s\n' 'pyenv() { command \"$TEST_PYENV_BIN\" \"\$@\"; }'"
  print -r -- '    exit 0'
  print -r -- '    ;;'
  print -r -- "  'virtualenv-init -')"
  print -r -- "    printf '%s\n' 'typeset -gx TEST_PYENV_VIRTUALENV_INIT_MARK=loaded_from_virtualenv_init'"
  print -r -- "    printf '%s\n' 'export PYENV_VIRTUALENV_INIT=1'"
  print -r -- "    printf '%s\n' '_pyenv_virtualenv_hook() { typeset -gx TEST_PYENV_VIRTUALENV_HOOK=triggered_from_virtualenv_hook; return 0; }'"
  print -r -- "    printf '%s\n' 'typeset -g -a precmd_functions'"
  print -r -- "    printf '%s\n' 'if [[ -z \${precmd_functions[(r)_pyenv_virtualenv_hook]:-} ]]; then precmd_functions=(_pyenv_virtualenv_hook \$precmd_functions); fi'"
  print -r -- '    exit 0'
  print -r -- '    ;;'
  print -r -- "  'rehash')"
  print -r -- "    printf '%s\n' 1 > \"$TEST_PYENV_REHASH_FILE\""
  print -r -- '    exit 0'
  print -r -- '    ;;'
  print -r -- 'esac'
  print -r -- 'exit 1'
} >| "$TEST_PYENV_BIN"
chmod +x "$TEST_PYENV_BIN"

mkdir -p "$TMPROOT/no-pyenv-bin"
path=("$TMPROOT/no-pyenv-bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin")
rehash

unset PYENV_ROOT PYENV_SHELL TEST_PYENV_LOGIN_MARK TEST_PYENV_INTERACTIVE_MARK TEST_PYENV_COMPLETION_MARK __zsh_feature_pyenv_loaded
unfunction pyenv 2>/dev/null || true
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
source "$REPO_ROOT/zsh/features/pyenv.zsh" || exit 1

typeset -g ZSH_PYENV_ROOT="$TEST_PYENV_ROOT"
typeset -g ZSH_PYENV_INIT_TTL=3600
typeset -gi ZSH_PYENV_REHASH_ON_INIT=0
typeset -gi ZSH_PYENV_ENABLE_VIRTUALENV_LAZY=1
typeset -g ZSH_PYENV_VIRTUALENV_HOOK_MODE="chpwd"
typeset -g ZSH_PYENV_VIRTUALENV_TRIGGER_FILE=".python-version"
typeset -ga precmd_functions=()
typeset -ga chpwd_functions=()

assert_status 0 "zsh_pyenv_prepare_env exports PYENV_ROOT and adds root/bin" zsh_pyenv_prepare_env
assert_eq "${PYENV_ROOT:-unset}" "$TEST_PYENV_ROOT" "pyenv feature exports configured PYENV_ROOT"
assert_eq "${path[1]:-unset}" "$TEST_PYENV_ROOT/bin" "pyenv feature prepends PYENV_ROOT/bin"

assert_status 0 "zsh_pyenv_find_bin finds pyenv in configured root" zsh_pyenv_find_bin
assert_eq "$REPLY" "${TEST_PYENV_BIN:A}" "pyenv feature resolves configured pyenv binary"

assert_status 0 "zsh_pyenv_cache_key accepts symlink path" zsh_pyenv_cache_key "$TEST_PYENV_LINK" login 0
assert_contains "$REPLY" "${TEST_PYENV_BIN:A}" "pyenv cache key uses canonical pyenv path"

/bin/rm -f "$TEST_PYENV_COUNT_FILE" "$TEST_PYENV_ARGS_FILE" "$TEST_PYENV_REHASH_FILE"
unset TEST_PYENV_LOGIN_MARK
assert_status 0 "zsh_pyenv_load_init sources cached login init" zsh_pyenv_load_init "$TEST_PYENV_BIN" login
assert_eq "${TEST_PYENV_LOGIN_MARK:-unset}" "loaded_from_login" "pyenv login init updates current shell"
assert_eq "${path[1]:-unset}" "$TEST_PYENV_SHIMS" "pyenv login init prepends shims path"
TEST_PYENV_INVOKE_COUNT="$(<"$TEST_PYENV_COUNT_FILE")"
assert_eq "$TEST_PYENV_INVOKE_COUNT" "1" "pyenv login init invokes pyenv once on cold cache"

unset TEST_PYENV_LOGIN_MARK
assert_status 0 "zsh_pyenv_load_init reuses fresh login cache" zsh_pyenv_load_init "$TEST_PYENV_BIN" login
assert_eq "${TEST_PYENV_LOGIN_MARK:-unset}" "loaded_from_login" "pyenv login init can re-source cached output"
TEST_PYENV_INVOKE_COUNT="$(<"$TEST_PYENV_COUNT_FILE")"
assert_eq "$TEST_PYENV_INVOKE_COUNT" "1" "pyenv login init avoids re-running pyenv while cache is fresh"

unset TEST_PYENV_INTERACTIVE_MARK TEST_PYENV_COMPLETION_MARK PYENV_SHELL
unfunction pyenv 2>/dev/null || true
assert_status 0 "zsh_pyenv_load_init sources cached interactive init" zsh_pyenv_load_init "$TEST_PYENV_BIN" interactive
assert_eq "${TEST_PYENV_INTERACTIVE_MARK:-unset}" "loaded_from_interactive" "pyenv interactive init updates current shell"
assert_eq "${PYENV_SHELL:-unset}" "zsh" "pyenv interactive init exports PYENV_SHELL"
assert_eq "${TEST_PYENV_COMPLETION_MARK:-unset}" "loaded_from_completion" "pyenv interactive init sources completion script"
assert_true "pyenv interactive init defines pyenv wrapper function" test -n "$(typeset -f pyenv 2>/dev/null)"

/bin/rm -f "$TEST_PYENV_REHASH_FILE"
typeset -gi ZSH_PYENV_REHASH_ON_INIT=1
assert_status 0 "zsh_pyenv_load_init can include rehash when enabled" zsh_pyenv_load_init "$TEST_PYENV_BIN" login
assert_true "pyenv login init runs rehash when enabled" test -f "$TEST_PYENV_REHASH_FILE"

unset TEST_PYENV_VIRTUALENV_INIT_MARK TEST_PYENV_VIRTUALENV_HOOK PYENV_VIRTUALENV_INIT __zsh_feature_pyenv_virtualenv_loaded __zsh_feature_pyenv_bin __zsh_pyenv_virtualenv_lazy_registered
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
typeset -ga precmd_functions=()
typeset -ga chpwd_functions=()

builtin cd -- "$TMPROOT"
assert_status 1 "zsh_pyenv_find_trigger_file skips unrelated directory" zsh_pyenv_find_trigger_file
assert_status 0 "zsh_pyenv_enable_virtualenv_lazy only registers watcher" zsh_pyenv_enable_virtualenv_lazy "$TEST_PYENV_BIN"
assert_eq "${TEST_PYENV_VIRTUALENV_INIT_MARK:-unset}" "unset" "pyenv virtualenv lazy init does not load immediately"
assert_false "pyenv virtualenv lazy watcher does not register precmd" test "${precmd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0
assert_true "pyenv virtualenv lazy watcher is registered in chpwd" test "${chpwd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0

builtin cd -- "$TEST_PYENV_PROJECT_SUBDIR"
assert_status 0 "zsh_pyenv_find_trigger_file walks parent directories" zsh_pyenv_find_trigger_file
assert_eq "${REPLY:A}" "${TEST_PYENV_PROJECT:A}/.python-version" "pyenv virtualenv lazy trigger follows parent chain"
assert_status 0 "pyenv virtualenv lazy watcher loads on matching directory" __zsh_pyenv_virtualenv_maybe_load
assert_eq "${TEST_PYENV_VIRTUALENV_INIT_MARK:-unset}" "loaded_from_virtualenv_init" "pyenv virtualenv init loads after matching trigger file"
assert_eq "${PYENV_VIRTUALENV_INIT:-unset}" "1" "pyenv virtualenv lazy init exports PYENV_VIRTUALENV_INIT"
assert_eq "${TEST_PYENV_VIRTUALENV_HOOK:-unset}" "triggered_from_virtualenv_hook" "pyenv virtualenv lazy init runs virtualenv hook immediately after load"
assert_true "pyenv virtualenv hook function is defined after lazy load" test -n "$(typeset -f _pyenv_virtualenv_hook 2>/dev/null)"
assert_false "pyenv virtualenv lazy watcher removes precmd hook after load" test "${precmd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0
assert_false "pyenv virtualenv lazy watcher removes chpwd hook after load" test "${chpwd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0
assert_false "pyenv virtualenv hook is not kept on precmd in chpwd mode" test "${precmd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0
assert_true "pyenv virtualenv hook is moved to chpwd in chpwd mode" test "${chpwd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0

unset TEST_PYENV_VIRTUALENV_INIT_MARK TEST_PYENV_VIRTUALENV_HOOK __zsh_feature_pyenv_virtualenv_loaded __zsh_feature_pyenv_bin __zsh_pyenv_virtualenv_lazy_registered
typeset -gx PYENV_VIRTUALENV_INIT=1
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
typeset -ga precmd_functions=()
typeset -ga chpwd_functions=()

builtin cd -- "$TMPROOT"
assert_status 0 "zsh_pyenv_enable_virtualenv_lazy ignores inherited env-only marker" zsh_pyenv_enable_virtualenv_lazy "$TEST_PYENV_BIN"
assert_eq "${TEST_PYENV_VIRTUALENV_INIT_MARK:-unset}" "unset" "env-only marker does not pretend virtualenv init already loaded"
assert_eq "${__zsh_feature_pyenv_virtualenv_loaded:-unset}" "unset" "env-only marker does not flip loaded guard early"
assert_false "env-only marker still has no virtualenv hook function" test -n "$(typeset -f _pyenv_virtualenv_hook 2>/dev/null)"
assert_true "env-only marker still registers chpwd watcher" test "${chpwd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0

builtin cd -- "$TEST_PYENV_PROJECT_SUBDIR"
assert_status 0 "env-only marker is repaired after entering matching directory" __zsh_pyenv_virtualenv_maybe_load
assert_eq "${TEST_PYENV_VIRTUALENV_INIT_MARK:-unset}" "loaded_from_virtualenv_init" "env-only marker still reloads virtualenv init script"
assert_eq "${TEST_PYENV_VIRTUALENV_HOOK:-unset}" "triggered_from_virtualenv_hook" "env-only marker repair also runs virtualenv hook"
assert_true "env-only marker repair restores virtualenv hook function" test -n "$(typeset -f _pyenv_virtualenv_hook 2>/dev/null)"
assert_true "env-only marker repair moves hook back to chpwd" test "${chpwd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0

unset TEST_PYENV_VIRTUALENV_INIT_MARK TEST_PYENV_VIRTUALENV_HOOK PYENV_VIRTUALENV_INIT __zsh_feature_pyenv_virtualenv_loaded __zsh_feature_pyenv_bin __zsh_pyenv_virtualenv_lazy_registered
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
typeset -ga precmd_functions=()
typeset -ga chpwd_functions=()

builtin cd -- "$TEST_PYENV_PROJECT_SUBDIR"
assert_status 0 "zsh_pyenv_enable_virtualenv_lazy loads immediately when current directory already matches" zsh_pyenv_enable_virtualenv_lazy "$TEST_PYENV_BIN"
assert_eq "${TEST_PYENV_VIRTUALENV_INIT_MARK:-unset}" "loaded_from_virtualenv_init" "pyenv virtualenv lazy init covers matching startup directory"
assert_eq "${PYENV_VIRTUALENV_INIT:-unset}" "1" "matching startup directory still exports PYENV_VIRTUALENV_INIT"
assert_eq "${TEST_PYENV_VIRTUALENV_HOOK:-unset}" "triggered_from_virtualenv_hook" "matching startup directory still runs virtualenv hook"
assert_false "matching startup directory does not leave precmd watcher behind" test "${precmd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0
assert_false "matching startup directory does not leave chpwd watcher behind" test "${chpwd_functions[(Ie)__zsh_pyenv_virtualenv_maybe_load]}" -gt 0
assert_false "matching startup directory also avoids precmd virtualenv hook" test "${precmd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0
assert_true "matching startup directory keeps virtualenv hook on chpwd" test "${chpwd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0

unset TEST_PYENV_VIRTUALENV_INIT_MARK TEST_PYENV_VIRTUALENV_HOOK PYENV_VIRTUALENV_INIT __zsh_feature_pyenv_virtualenv_loaded __zsh_feature_pyenv_bin __zsh_pyenv_virtualenv_lazy_registered
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
typeset -ga precmd_functions=()
typeset -ga chpwd_functions=()
typeset -g ZSH_PYENV_VIRTUALENV_HOOK_MODE="precmd"

builtin cd -- "$TEST_PYENV_PROJECT_SUBDIR"
assert_status 0 "zsh_pyenv_enable_virtualenv_lazy can preserve precmd virtualenv hook when requested" zsh_pyenv_enable_virtualenv_lazy "$TEST_PYENV_BIN"
assert_true "precmd hook mode keeps pyenv virtualenv hook on precmd" test "${precmd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0
assert_false "precmd hook mode does not add pyenv virtualenv hook to chpwd" test "${chpwd_functions[(Ie)_pyenv_virtualenv_hook]}" -gt 0

builtin cd -- "$TEST_PYENV_SAVED_PWD"
path=("${ORIGINAL_PATH[@]}")
rehash
unfunction pyenv 2>/dev/null || true
unfunction _pyenv_virtualenv_hook 2>/dev/null || true
unset TEST_PYENV_LOGIN_MARK TEST_PYENV_INTERACTIVE_MARK TEST_PYENV_COMPLETION_MARK TEST_PYENV_VIRTUALENV_INIT_MARK TEST_PYENV_VIRTUALENV_HOOK __zsh_feature_pyenv_loaded __zsh_feature_pyenv_virtualenv_loaded __zsh_feature_pyenv_bin __zsh_pyenv_virtualenv_lazy_registered
restore_var ZSH_PYENV_ROOT "$HAD_ZSH_PYENV_ROOT" "$OLD_ZSH_PYENV_ROOT"
restore_var ZSH_PYENV_INIT_TTL "$HAD_ZSH_PYENV_INIT_TTL" "$OLD_ZSH_PYENV_INIT_TTL"
restore_var ZSH_PYENV_REHASH_ON_INIT "$HAD_ZSH_PYENV_REHASH_ON_INIT" "$OLD_ZSH_PYENV_REHASH_ON_INIT"
restore_var ZSH_PYENV_ENABLE_VIRTUALENV_LAZY "$HAD_ZSH_PYENV_ENABLE_VIRTUALENV_LAZY" "$OLD_ZSH_PYENV_ENABLE_VIRTUALENV_LAZY"
restore_var ZSH_PYENV_VIRTUALENV_HOOK_MODE "$HAD_ZSH_PYENV_VIRTUALENV_HOOK_MODE" "$OLD_ZSH_PYENV_VIRTUALENV_HOOK_MODE"
restore_var ZSH_PYENV_VIRTUALENV_TRIGGER_FILE "$HAD_ZSH_PYENV_VIRTUALENV_TRIGGER_FILE" "$OLD_ZSH_PYENV_VIRTUALENV_TRIGGER_FILE"
restore_var ZSH_CURRENT_STAGE "$HAD_ZSH_CURRENT_STAGE" "$OLD_ZSH_CURRENT_STAGE"
restore_var PYENV_ROOT "$HAD_PYENV_ROOT" "$OLD_PYENV_ROOT"
restore_var PYENV_SHELL "$HAD_PYENV_SHELL" "$OLD_PYENV_SHELL"
restore_var PYENV_VIRTUALENV_INIT "$HAD_PYENV_VIRTUALENV_INIT" "$OLD_PYENV_VIRTUALENV_INIT"
if [[ "$HAD_PRECMD_FUNCTIONS" == "1" ]]; then
  typeset -ga precmd_functions=("${TEST_PYENV_SAVED_PRECMD_FUNCTIONS[@]}")
else
  unset precmd_functions
fi
if [[ "$HAD_CHPWD_FUNCTIONS" == "1" ]]; then
  typeset -ga chpwd_functions=("${TEST_PYENV_SAVED_CHPWD_FUNCTIONS[@]}")
else
  unset chpwd_functions
fi

log STEP "features/tmux.zsh"

HAD_ZSH_TMUX_AUTO_ATTACH="${+ZSH_TMUX_AUTO_ATTACH}"
OLD_ZSH_TMUX_AUTO_ATTACH="${ZSH_TMUX_AUTO_ATTACH-}"
HAD_TMUX="${+TMUX}"
OLD_TMUX="${TMUX-}"
HAD_TMUX_GUARD="${+__zsh_feature_tmux_loaded}"
OLD_TMUX_GUARD="${__zsh_feature_tmux_loaded-}"
typeset -ga TEST_TMUX_SAVED_PATH=("${path[@]}")
typeset -g TEST_TMUX_ROOT="$TMPROOT/fake-tmux"
typeset -g TEST_TMUX_BIN="$TEST_TMUX_ROOT/bin/tmux"
typeset -g TEST_TMUX_LOG="$TMPROOT/fake-tmux.log"
typeset -g TEST_TMUX_HAS_SESSION_FILE="$TMPROOT/fake-tmux.has-session"

mkdir -p "$TEST_TMUX_ROOT/bin"

{
  print -r -- '#!/bin/sh'
  print -r -- "printf '%s\n' \"\$*\" >> \"$TEST_TMUX_LOG\""
  print -r -- 'if [ "$1" = "list-sessions" ]; then'
  print -r -- "  [ -f \"$TEST_TMUX_HAS_SESSION_FILE\" ] && exit 0"
  print -r -- '  exit 1'
  print -r -- 'fi'
  print -r -- 'exit 0'
} >| "$TEST_TMUX_BIN"
chmod +x "$TEST_TMUX_BIN"

path=("$TEST_TMUX_ROOT/bin" "${TEST_TMUX_SAVED_PATH[@]}")
rehash

typeset -gi ZSH_TMUX_AUTO_ATTACH=1
unset TMUX __zsh_feature_tmux_loaded
unfunction tmux 2>/dev/null || true
source "$REPO_ROOT/zsh/features/tmux.zsh" || exit 1

assert_true "tmux feature defines tmux wrapper function" test -n "$(typeset -f tmux 2>/dev/null)"
assert_status 0 "zsh_tmux_should_auto_attach is enabled by default" zsh_tmux_should_auto_attach

/bin/rm -f "$TEST_TMUX_LOG" "$TEST_TMUX_HAS_SESSION_FILE"
assert_status 0 "tmux feature starts new session when server has no session" tmux
TEST_TMUX_LOG_OUT="$(<"$TEST_TMUX_LOG")"
assert_eq "$TEST_TMUX_LOG_OUT" $'list-sessions\nnew-session' "tmux feature checks session list before new-session"

: >| "$TEST_TMUX_HAS_SESSION_FILE"
/bin/rm -f "$TEST_TMUX_LOG"
assert_status 0 "tmux feature attaches when server already has session" tmux
TEST_TMUX_LOG_OUT="$(<"$TEST_TMUX_LOG")"
assert_eq "$TEST_TMUX_LOG_OUT" $'list-sessions\nattach-session' "tmux feature prefers attach-session when session exists"

/bin/rm -f "$TEST_TMUX_LOG"
assert_status 0 "tmux feature passes explicit subcommands through unchanged" tmux ls
TEST_TMUX_LOG_OUT="$(<"$TEST_TMUX_LOG")"
assert_eq "$TEST_TMUX_LOG_OUT" "ls" "tmux feature does not rewrite explicit subcommands"

TMUX="unit-pane"
assert_status 1 "zsh_tmux_should_auto_attach skips nested tmux shells" zsh_tmux_should_auto_attach
/bin/rm -f "$TEST_TMUX_LOG"
assert_status 0 "tmux feature keeps native no-arg behavior inside tmux" tmux
TEST_TMUX_LOG_OUT="$(<"$TEST_TMUX_LOG")"
assert_eq "$TEST_TMUX_LOG_OUT" "" "nested tmux shells bypass smart attach/new logic"

unset TMUX
typeset -gi ZSH_TMUX_AUTO_ATTACH=0
assert_status 1 "zsh_tmux_should_auto_attach respects disable switch" zsh_tmux_should_auto_attach
/bin/rm -f "$TEST_TMUX_LOG"
assert_status 0 "tmux feature can be disabled declaratively" tmux
TEST_TMUX_LOG_OUT="$(<"$TEST_TMUX_LOG")"
assert_eq "$TEST_TMUX_LOG_OUT" "" "disabled tmux feature keeps native no-arg behavior"

restore_var ZSH_TMUX_AUTO_ATTACH "$HAD_ZSH_TMUX_AUTO_ATTACH" "$OLD_ZSH_TMUX_AUTO_ATTACH"
restore_var TMUX "$HAD_TMUX" "$OLD_TMUX"
restore_var __zsh_feature_tmux_loaded "$HAD_TMUX_GUARD" "$OLD_TMUX_GUARD"
path=("${TEST_TMUX_SAVED_PATH[@]}")
rehash
unfunction tmux 2>/dev/null || true

log STEP "features/keybinds.zsh"

HAD_ZSH_KEYMAP="${+ZSH_KEYMAP}"
OLD_ZSH_KEYMAP="${ZSH_KEYMAP-}"
HAD_WORDCHARS="${+WORDCHARS}"
OLD_WORDCHARS="${WORDCHARS-}"

typeset -g ZSH_KEYMAP="emacs"
WORDCHARS='*?_-.[]~=/&;!#$%^(){}<>'
source "$REPO_ROOT/zsh/features/keybinds.zsh" || exit 1
assert_eq "$WORDCHARS" "" "keybinds feature restores oh-my-zsh style word boundaries"

fc -p "$TMPROOT/keybinds-history" 100 100
print -sr -- "echo alpha"
print -sr -- "echo beta"
print -sr -- "echo alpha"
print -sr -- "echo gamma"

BUFFER=""
CURSOR=${#BUFFER}
LASTWIDGET="self-insert"
assert_status 0 "keybinds empty buffer falls back to plain history" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo gamma" "空行上箭头先取最近一条历史"

LASTWIDGET="_zsh_autosuggest_widget_modify"
assert_status 0 "keybinds plain history can continue through autosuggestions wrappers" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo alpha" "空行连续上箭头会继续向前翻历史"

assert_status 0 "keybinds plain history skips duplicate commands" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo beta" "普通历史会跳过已经出现过的重复命令"

assert_status 0 "keybinds plain history stays on the oldest unique command" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo beta" "到达最旧唯一历史后继续上箭头不会跳走"

assert_status 0 "keybinds plain history can move forward again" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo alpha" "空行下箭头会回到较新的唯一历史"

assert_status 0 "keybinds plain history can move forward across unique results" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo gamma" "普通历史继续下箭头会回到更新的唯一历史"

assert_status 0 "keybinds plain history restores the original empty buffer" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "" "继续下箭头会回到最初的空输入"

assert_status 0 "keybinds plain history stays on the original empty buffer" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "" "回到原始输入后继续下箭头不会跳走"

assert_status 0 "zle-line-finish resets sticky history state after accepting a line" zle-line-finish
BUFFER=""
CURSOR=${#BUFFER}
LASTWIDGET="self-insert"
assert_status 0 "after finishing a line empty buffer restarts from latest history" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo gamma" "回车结束当前行后, 新一轮上箭头会重新从最新历史开始"

BUFFER="echo "
CURSOR=${#BUFFER}
LASTWIDGET="self-insert"
assert_status 0 "keybinds prefix search finds the latest matching history entry" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo gamma" "第一次上箭头会命中最近的前缀匹配"

LASTWIDGET="_zsh_autosuggest_widget_modify"
assert_status 0 "keybinds prefix search can continue through autosuggestions wrappers" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo alpha" "第二次上箭头会继续向前命中更早的前缀匹配"

assert_status 0 "keybinds prefix search skips duplicate commands" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo beta" "前缀搜索也会跳过已经出现过的重复命令"

assert_status 0 "keybinds prefix search stays on the oldest unique match" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo beta" "到达最旧唯一前缀匹配后继续上箭头不会跳走"

assert_status 0 "keybinds prefix search can move forward again" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo alpha" "第一次下箭头会回到较新的唯一前缀匹配"

assert_status 0 "keybinds prefix search can move forward across unique results" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo gamma" "前缀搜索继续下箭头会回到更新的唯一前缀匹配"

assert_status 0 "keybinds prefix search restores the original query buffer" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo " "继续下箭头会回到最初输入的前缀"

assert_status 0 "keybinds prefix search stays on the original query buffer" zsh_keybinds_history_search_down
assert_eq "$BUFFER" "echo " "回到原始前缀后继续下箭头不会跳走"

BUFFER="echo beta --"
CURSOR=${#BUFFER}
LASTWIDGET="self-insert"
assert_status 0 "editing a recalled line starts a new prefix search" zsh_keybinds_history_search_up
assert_eq "$BUFFER" "echo beta --" "没有匹配时会保留用户修改后的当前行"
fc -P

restore_var ZSH_KEYMAP "$HAD_ZSH_KEYMAP" "$OLD_ZSH_KEYMAP"
restore_var WORDCHARS "$HAD_WORDCHARS" "$OLD_WORDCHARS"

log STEP "features/autosuggestions.zsh"

typeset -g TEST_AUTOSUGGESTIONS_ROOT="$TMPROOT/fake-autosuggestions"
typeset -g TEST_AUTOSUGGESTIONS_FILE="$TEST_AUTOSUGGESTIONS_ROOT/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
mkdir -p "${TEST_AUTOSUGGESTIONS_FILE:h}"

{
  print -r -- 'typeset TEST_AUTOSUGGESTIONS_MARK=loaded_from_autosuggestions'
} >| "$TEST_AUTOSUGGESTIONS_FILE"

unset TEST_AUTOSUGGESTIONS_MARK ZSH_AUTOSUGGESTIONS_FILE HOMEBREW_PREFIX __zsh_feature_autosuggestions_loaded
source "$REPO_ROOT/zsh/features/autosuggestions.zsh" || exit 1

assert_status 0 "zsh_autosuggestions_candidate_from_brew derives plugin path from brew bin" zsh_autosuggestions_candidate_from_brew "$TEST_BREW_ROOT/bin/brew"
assert_eq "$REPLY" "$TEST_BREW_ROOT/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "autosuggestions candidate path matches brew prefix"

assert_status 0 "zsh_autosuggestions_candidate_from_prefix derives plugin path from prefix" zsh_autosuggestions_candidate_from_prefix "$TEST_AUTOSUGGESTIONS_ROOT"
assert_eq "$REPLY" "$TEST_AUTOSUGGESTIONS_FILE" "autosuggestions candidate path matches explicit prefix"

HAD_ZSH_OS="${+ZSH_OS}"
OLD_ZSH_OS="${ZSH_OS-}"
HAD_ZSH_ARCH="${+ZSH_ARCH}"
OLD_ZSH_ARCH="${ZSH_ARCH-}"

ZSH_OS="macos"
ZSH_ARCH="arm64"
assert_status 0 "zsh_autosuggestions_default_candidates supports macOS Apple Silicon" zsh_autosuggestions_default_candidates
assert_eq "${(j.:.)reply}" "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Apple Silicon autosuggestions 候选路径正确"
assert_status 0 "zsh_autosuggestions_default_file supports macOS Apple Silicon" zsh_autosuggestions_default_file
assert_eq "$REPLY" "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Apple Silicon 默认 autosuggestions 路径正确"

ZSH_OS="macos"
ZSH_ARCH="x86_64"
assert_status 0 "zsh_autosuggestions_default_candidates supports macOS Intel" zsh_autosuggestions_default_candidates
assert_eq "${(j.:.)reply}" "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Intel autosuggestions 候选路径正确"
assert_status 0 "zsh_autosuggestions_default_file supports macOS Intel" zsh_autosuggestions_default_file
assert_eq "$REPLY" "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Intel macOS 默认 autosuggestions 路径正确"

ZSH_OS="linux"
ZSH_ARCH="x86_64"
assert_status 0 "zsh_autosuggestions_default_candidates supports Linux" zsh_autosuggestions_default_candidates
assert_eq "${(j.:.)reply}" "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh:/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh:/home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Linux autosuggestions 候选路径按优先级排列"
assert_status 0 "zsh_autosuggestions_default_file supports Linux" zsh_autosuggestions_default_file
assert_eq "$REPLY" "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "Linux 默认 autosuggestions 首选系统包路径"

ZSH_OS="unknown"
ZSH_ARCH="unknown"
assert_status 1 "zsh_autosuggestions_default_candidates skips unsupported platform" zsh_autosuggestions_default_candidates
assert_status 1 "zsh_autosuggestions_default_file skips unsupported platform" zsh_autosuggestions_default_file

restore_var ZSH_OS "$HAD_ZSH_OS" "$OLD_ZSH_OS"
restore_var ZSH_ARCH "$HAD_ZSH_ARCH" "$OLD_ZSH_ARCH"

ZSH_AUTOSUGGESTIONS_FILE="$TEST_AUTOSUGGESTIONS_FILE"
assert_status 0 "zsh_autosuggestions_find_file accepts override file" zsh_autosuggestions_find_file
assert_eq "$REPLY" "$TEST_AUTOSUGGESTIONS_FILE" "autosuggestions override file is returned as-is"

unset TEST_AUTOSUGGESTIONS_MARK __zsh_feature_autosuggestions_loaded
source "$REPO_ROOT/zsh/features/autosuggestions.zsh" || exit 1
assert_eq "${TEST_AUTOSUGGESTIONS_MARK:-unset}" "loaded_from_autosuggestions" "autosuggestions feature sources override file at top level"

unset ZSH_AUTOSUGGESTIONS_FILE
HOMEBREW_PREFIX="$TEST_AUTOSUGGESTIONS_ROOT"
assert_status 0 "zsh_autosuggestions_find_file prefers HOMEBREW_PREFIX when available" zsh_autosuggestions_find_file
assert_eq "$REPLY" "$TEST_AUTOSUGGESTIONS_FILE" "autosuggestions feature prefers HOMEBREW_PREFIX path"

unset HOMEBREW_PREFIX
typeset -ga TEST_AUTOSUGGESTIONS_PATH_BEFORE=("${path[@]}")
mkdir -p "$TEST_AUTOSUGGESTIONS_ROOT/bin"
print -r -- '#!/bin/sh' >| "$TEST_AUTOSUGGESTIONS_ROOT/bin/brew"
chmod +x "$TEST_AUTOSUGGESTIONS_ROOT/bin/brew"
path=("$TEST_AUTOSUGGESTIONS_ROOT/bin" "${TEST_AUTOSUGGESTIONS_PATH_BEFORE[@]}")
rehash
assert_status 0 "zsh_autosuggestions_find_file derives file from brew in PATH" zsh_autosuggestions_find_file
assert_eq "$REPLY" "$TEST_AUTOSUGGESTIONS_FILE" "autosuggestions feature prefers brew prefix in PATH"

path=("${ORIGINAL_PATH[@]}")
rehash

typeset -g TEST_AUTOSUGGESTIONS_FALLBACK_FILE="$TMPROOT/fallback-autosuggestions.zsh"
{
  print -r -- 'typeset TEST_AUTOSUGGESTIONS_FALLBACK_MARK=loaded_from_default_candidates'
} >| "$TEST_AUTOSUGGESTIONS_FALLBACK_FILE"

zsh_autosuggestions_default_candidates() {
  emulate -L zsh
  reply=("$TMPROOT/missing-autosuggestions.zsh" "$TEST_AUTOSUGGESTIONS_FALLBACK_FILE")
}

typeset -ga TEST_AUTOSUGGESTIONS_PATH_NO_BREW=("${ORIGINAL_PATH[@]}")
if (( $+commands[brew] )); then
  path=("${TEST_AUTOSUGGESTIONS_PATH_NO_BREW[@]}")
  path_remove "${commands[brew]:h}"
  TEST_AUTOSUGGESTIONS_PATH_NO_BREW=("${path[@]}")
fi

path=("${TEST_AUTOSUGGESTIONS_PATH_NO_BREW[@]}")
rehash

unset HOMEBREW_PREFIX ZSH_AUTOSUGGESTIONS_FILE
assert_status 0 "zsh_autosuggestions_find_file falls back across default candidates" zsh_autosuggestions_find_file
assert_eq "$REPLY" "$TEST_AUTOSUGGESTIONS_FALLBACK_FILE" "autosuggestions feature skips unreadable default candidates"

path=("${ORIGINAL_PATH[@]}")
rehash

unset __zsh_feature_autosuggestions_loaded
source "$REPO_ROOT/zsh/features/autosuggestions.zsh" || exit 1

log STEP "features/prompt and themes/avit.zsh"

HAD_ZSH_THEME="${+ZSH_THEME}"
OLD_ZSH_THEME="${ZSH_THEME-}"
HAD_ZSH_KEYMAP="${+ZSH_KEYMAP}"
OLD_ZSH_KEYMAP="${ZSH_KEYMAP-}"
HAD_ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT="${+ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT}"
OLD_ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT="${ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT-}"
HAD_VIRTUAL_ENV_DISABLE_PROMPT="${+VIRTUAL_ENV_DISABLE_PROMPT}"
OLD_VIRTUAL_ENV_DISABLE_PROMPT="${VIRTUAL_ENV_DISABLE_PROMPT-}"
HAD_PYENV_VIRTUALENV_DISABLE_PROMPT="${+PYENV_VIRTUALENV_DISABLE_PROMPT}"
OLD_PYENV_VIRTUALENV_DISABLE_PROMPT="${PYENV_VIRTUALENV_DISABLE_PROMPT-}"
HAD_CONDA_CHANGEPS1="${+CONDA_CHANGEPS1}"
OLD_CONDA_CHANGEPS1="${CONDA_CHANGEPS1-}"
HAD_VIRTUAL_ENV="${+VIRTUAL_ENV}"
OLD_VIRTUAL_ENV="${VIRTUAL_ENV-}"
HAD_VIRTUAL_ENV_PROMPT="${+VIRTUAL_ENV_PROMPT}"
OLD_VIRTUAL_ENV_PROMPT="${VIRTUAL_ENV_PROMPT-}"
HAD_PIPENV_ACTIVE="${+PIPENV_ACTIVE}"
OLD_PIPENV_ACTIVE="${PIPENV_ACTIVE-}"
HAD_PIPENV_PIPFILE="${+PIPENV_PIPFILE}"
OLD_PIPENV_PIPFILE="${PIPENV_PIPFILE-}"
HAD_PIPENV_PROMPT="${+PIPENV_PROMPT}"
OLD_PIPENV_PROMPT="${PIPENV_PROMPT-}"
HAD_CONDA_DEFAULT_ENV="${+CONDA_DEFAULT_ENV}"
OLD_CONDA_DEFAULT_ENV="${CONDA_DEFAULT_ENV-}"
HAD_THEME_GUARD="${+__zsh_theme_avit_loaded}"
OLD_THEME_GUARD="${__zsh_theme_avit_loaded-}"

unset __zsh_theme_avit_loaded
unset VIRTUAL_ENV_DISABLE_PROMPT PYENV_VIRTUALENV_DISABLE_PROMPT CONDA_CHANGEPS1
unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT PIPENV_ACTIVE PIPENV_PIPFILE PIPENV_PROMPT CONDA_DEFAULT_ENV
typeset -g ZSH_THEME="avit"
typeset -g ZSH_KEYMAP="emacs"
typeset -gi ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT=1

source "$REPO_ROOT/zsh/features/prompt.zsh" || exit 1

assert_eq "${VIRTUAL_ENV_DISABLE_PROMPT:-unset}" "1" "avit 默认关闭 virtualenv prompt 注入"
assert_eq "${PYENV_VIRTUALENV_DISABLE_PROMPT:-unset}" "1" "avit 默认关闭 pyenv-virtualenv prompt 注入"
assert_eq "${CONDA_CHANGEPS1:-unset}" "no" "avit 默认关闭 conda prompt 注入"

VIRTUAL_ENV_PROMPT='(excel_lab) '
VIRTUAL_ENV="$TMPROOT/excel_lab-cvFsw0f3"
__zsh_avit_build_virtualenv_segment
assert_eq "$REPLY" "%F{magenta}(excel_lab)%f " "avit 优先使用工具提供的环境展示名"

unset VIRTUAL_ENV_PROMPT VIRTUAL_ENV
PIPENV_ACTIVE=1
PIPENV_PIPFILE="$TMPROOT/pipenv-demo/Pipfile"
mkdir -p "${PIPENV_PIPFILE:h}"
print -r -- "[packages]" >| "$PIPENV_PIPFILE"
__zsh_avit_build_virtualenv_segment
assert_eq "$REPLY" "%F{magenta}(pipenv-demo)%f " "avit 在 pipenv 下回退到项目目录名"

unset PIPENV_ACTIVE PIPENV_PIPFILE
VIRTUAL_ENV="$TMPROOT/plain-venv"
__zsh_avit_build_virtualenv_segment
assert_eq "$REPLY" "%F{magenta}(plain-venv)%f " "avit 在普通 virtualenv 下回退到环境目录名"

unset VIRTUAL_ENV
CONDA_DEFAULT_ENV="ml"
__zsh_avit_build_virtualenv_segment
assert_eq "$REPLY" "%F{magenta}(ml)%f " "avit 支持 conda 环境名"

PROMPT_MANAGE_OFF_OUT="$(
  unset __zsh_theme_avit_loaded
  unset VIRTUAL_ENV_DISABLE_PROMPT PYENV_VIRTUALENV_DISABLE_PROMPT CONDA_CHANGEPS1
  typeset -g ZSH_KEYMAP="emacs"
  typeset -gi ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT=0
  source "$REPO_ROOT/zsh/themes/avit.zsh" || exit 1
  print -r -- "${VIRTUAL_ENV_DISABLE_PROMPT-unset}:${PYENV_VIRTUALENV_DISABLE_PROMPT-unset}:${CONDA_CHANGEPS1-unset}"
)"
assert_eq "$PROMPT_MANAGE_OFF_OUT" "unset:unset:unset" "avit 允许通过声明式配置放弃接管 Python prompt"

restore_var ZSH_THEME "$HAD_ZSH_THEME" "$OLD_ZSH_THEME"
restore_var ZSH_KEYMAP "$HAD_ZSH_KEYMAP" "$OLD_ZSH_KEYMAP"
restore_var ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT "$HAD_ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT" "$OLD_ZSH_THEME_AVIT_MANAGE_PYTHON_PROMPT"
restore_var VIRTUAL_ENV_DISABLE_PROMPT "$HAD_VIRTUAL_ENV_DISABLE_PROMPT" "$OLD_VIRTUAL_ENV_DISABLE_PROMPT"
restore_var PYENV_VIRTUALENV_DISABLE_PROMPT "$HAD_PYENV_VIRTUALENV_DISABLE_PROMPT" "$OLD_PYENV_VIRTUALENV_DISABLE_PROMPT"
restore_var CONDA_CHANGEPS1 "$HAD_CONDA_CHANGEPS1" "$OLD_CONDA_CHANGEPS1"
restore_var VIRTUAL_ENV "$HAD_VIRTUAL_ENV" "$OLD_VIRTUAL_ENV"
restore_var VIRTUAL_ENV_PROMPT "$HAD_VIRTUAL_ENV_PROMPT" "$OLD_VIRTUAL_ENV_PROMPT"
restore_var PIPENV_ACTIVE "$HAD_PIPENV_ACTIVE" "$OLD_PIPENV_ACTIVE"
restore_var PIPENV_PIPFILE "$HAD_PIPENV_PIPFILE" "$OLD_PIPENV_PIPFILE"
restore_var PIPENV_PROMPT "$HAD_PIPENV_PROMPT" "$OLD_PIPENV_PROMPT"
restore_var CONDA_DEFAULT_ENV "$HAD_CONDA_DEFAULT_ENV" "$OLD_CONDA_DEFAULT_ENV"
restore_var __zsh_theme_avit_loaded "$HAD_THEME_GUARD" "$OLD_THEME_GUARD"

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
