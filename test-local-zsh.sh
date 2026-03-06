#!/usr/bin/env bash
set -u
set -o pipefail

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log() {
  printf '\n[%s] %s\n' "$1" "$2"
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$*"
}

run_capture() {
  local __var_name="$1"
  shift

  local __out
  local __rc

  __out="$("$@" 2>&1)"
  __rc=$?

  printf -v "$__var_name" '%s' "$__out"
  return "$__rc"
}

assert_exists() {
  local path="$1"
  local msg="$2"
  if [ -e "$path" ] || [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (missing: $path)"
  fi
}

assert_file() {
  local path="$1"
  local msg="$2"
  if [ -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a regular file: $path)"
  fi
}

assert_dir() {
  local path="$1"
  local msg="$2"
  if [ -d "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a directory: $path)"
  fi
}

assert_symlink() {
  local path="$1"
  local msg="$2"
  if [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a symlink: $path)"
  fi
}

assert_not_symlink() {
  local path="$1"
  local msg="$2"
  if [ ! -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (should not be a symlink: $path)"
  fi
}

assert_eq() {
  local got="$1"
  local expected="$2"
  local msg="$3"
  if [ "$got" = "$expected" ]; then
    pass "$msg"
  else
    fail "$msg (got: $got | expected: $expected)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (missing: $needle)"
  fi
}

print_block() {
  local title="$1"
  local body="$2"
  printf '\n----- %s -----\n%s\n' "$title" "$body"
}

get_symlink_target() {
  local path="$1"
  readlink "$path" 2>/dev/null || true
}

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BASH_BIN="$(command -v bash 2>/dev/null || true)"
ZSH_BIN="$(command -v zsh 2>/dev/null || true)"

log INFO "repo root = $REPO_ROOT"

log STEP "基础前置检查"

if [ -z "$BASH_BIN" ]; then
  printf '[FATAL] bash not found\n' >&2
  exit 1
fi

if [ -z "$ZSH_BIN" ]; then
  printf '[FATAL] zsh not found in PATH\n' >&2
  exit 1
fi

printf 'bash = %s\n' "$BASH_BIN"
printf 'zsh  = %s\n' "$ZSH_BIN"
"$BASH_BIN" --version | head -n 1
"$ZSH_BIN" --version

assert_file "$REPO_ROOT/install.sh" "install.sh 存在"
assert_file "$REPO_ROOT/zshenv" "zshenv 存在"
assert_dir  "$REPO_ROOT/zsh" "zsh 目录存在"
assert_file "$REPO_ROOT/zsh/init.zsh" "init.zsh 存在"
assert_file "$REPO_ROOT/zsh/conf/defaults.zsh" "conf/defaults.zsh 存在"
assert_file "$REPO_ROOT/zsh/config.zsh" "config.zsh 存在"

log STEP "可选 shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  if run_capture SHELLCHECK_OUT shellcheck "$REPO_ROOT/install.sh"; then
    print_block "shellcheck install.sh" "${SHELLCHECK_OUT:-<empty>}"
    pass "shellcheck install.sh 通过"
  else
    print_block "shellcheck install.sh" "$SHELLCHECK_OUT"
    fail "shellcheck install.sh 未通过"
  fi
else
  warn "shellcheck 未安装，跳过"
fi

log STEP "zsh -n 语法检查"

SYNTAX_LIST_FILE="${TMPDIR:-/tmp}/oh_box_zsh_syntax_list.$$"
: > "$SYNTAX_LIST_FILE"

find "$REPO_ROOT/zsh" -type f \
  \( -name '*.zsh' -o -name '.zprofile' -o -name '.zshrc' \) \
  | sort >> "$SYNTAX_LIST_FILE"
printf '%s\n' "$REPO_ROOT/zshenv" >> "$SYNTAX_LIST_FILE"

while IFS= read -r file_path; do
  if [ -z "$file_path" ]; then
    continue
  fi

  if run_capture SYNTAX_OUT "$ZSH_BIN" -n "$file_path"; then
    pass "zsh -n 通过: ${file_path#$REPO_ROOT/}"
  else
    print_block "syntax error: ${file_path#$REPO_ROOT/}" "$SYNTAX_OUT"
    fail "zsh -n 失败: ${file_path#$REPO_ROOT/}"
  fi
done < "$SYNTAX_LIST_FILE"

rm -f "$SYNTAX_LIST_FILE"

log STEP "隔离环境 link 安装"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-box-zsh-test.XXXXXX")"
printf 'TMPROOT=%s\n' "$TMPROOT"

LINK_HOME="$TMPROOT/link-home"
LINK_XDG="$LINK_HOME/.config"
mkdir -p "$LINK_HOME"

if run_capture LINK_INSTALL_OUT env -i \
  HOME="$LINK_HOME" \
  XDG_CONFIG_HOME="$LINK_XDG" \
  PATH="$PATH" \
  "$BASH_BIN" "$REPO_ROOT/install.sh" --link --force
then
  print_block "install --link --force" "$LINK_INSTALL_OUT"
  pass "link 安装成功"
else
  print_block "install --link --force" "$LINK_INSTALL_OUT"
  fail "link 安装失败"
fi

assert_symlink "$LINK_HOME/.zshenv" "link 模式下 ~/.zshenv 是符号链接"
assert_symlink "$LINK_XDG/zsh" "link 模式下 ~/.config/zsh 是符号链接"

LINK_ZSHENV_TARGET="$(get_symlink_target "$LINK_HOME/.zshenv")"
LINK_ZSHDIR_TARGET="$(get_symlink_target "$LINK_XDG/zsh")"

assert_eq "$LINK_ZSHENV_TARGET" "$REPO_ROOT/zshenv" "link 模式下 ~/.zshenv 指向仓库 zshenv"
assert_eq "$LINK_ZSHDIR_TARGET" "$REPO_ROOT/zsh" "link 模式下 ~/.config/zsh 指向仓库 zsh 目录"

log STEP "link 模式下 zsh -lic / zsh -ic 冒烟测试"

SMOKE_LINK_LI_SCRIPT='
print -r -- "ZDOTDIR=$ZDOTDIR"
print -r -- "BOOT=${__zsh_framework_bootstrapped:-0}"
print -r -- "LOGIN_STAGE=${__zsh_stage_loaded[login]:-0}"
print -r -- "INT_STAGE=${__zsh_stage_loaded[interactive]:-0}"
print -r -- "IS_INTERACTIVE=$([[ $- == *i* ]] && print 1 || print 0)"
print -r -- "IS_LOGIN=$([[ -o login ]] && print 1 || print 0)"
print -r -- "HISTFILE=${HISTFILE:-}"
print -r -- "ZSH_OS=${ZSH_OS:-}"
print -r -- "ZSH_ARCH=${ZSH_ARCH:-}"
print -r -- "FEATURES=${ZSH_ENABLE_HISTORY:-}/${ZSH_ENABLE_COMPLETION:-}/${ZSH_ENABLE_KEYBINDS:-}/${ZSH_ENABLE_PROMPT:-}"
print -r -- "KEYMAP=${ZSH_KEYMAP:-}"
print -r -- "THEME=${ZSH_THEME:-}"
whence -w zsh_source_optional >/dev/null 2>&1 && print -r -- "CORE_FN=1" || print -r -- "CORE_FN=0"
'

if run_capture LINK_LI_OUT env -i \
  HOME="$LINK_HOME" \
  XDG_CONFIG_HOME="$LINK_XDG" \
  PATH="$PATH" \
  TERM="${TERM:-xterm-256color}" \
  "$ZSH_BIN" -lic "$SMOKE_LINK_LI_SCRIPT"
then
  print_block "zsh -lic (link)" "$LINK_LI_OUT"
  pass "zsh -lic 启动成功"
else
  print_block "zsh -lic (link)" "$LINK_LI_OUT"
  fail "zsh -lic 启动失败"
fi

assert_contains "$LINK_LI_OUT" "ZDOTDIR=$LINK_XDG/zsh" "zsh -lic 使用正确的 ZDOTDIR"
assert_contains "$LINK_LI_OUT" "BOOT=1" "框架 bootstrap 完成"
assert_contains "$LINK_LI_OUT" "LOGIN_STAGE=1" "login 阶段已执行"
assert_contains "$LINK_LI_OUT" "INT_STAGE=1" "interactive 阶段已执行"
assert_contains "$LINK_LI_OUT" "IS_INTERACTIVE=1" "zsh -lic 为 interactive"
assert_contains "$LINK_LI_OUT" "IS_LOGIN=1" "zsh -lic 为 login"
assert_contains "$LINK_LI_OUT" "HISTFILE=$LINK_HOME/.cache/zsh/history" "history 文件路径正确"
assert_contains "$LINK_LI_OUT" "FEATURES=1/0/1/1" "默认功能开关值正确"
assert_contains "$LINK_LI_OUT" "KEYMAP=emacs" "默认 keymap 正确"
assert_contains "$LINK_LI_OUT" "THEME=basic" "默认 theme 正确"
assert_contains "$LINK_LI_OUT" "CORE_FN=1" "核心函数已加载"

SMOKE_LINK_I_SCRIPT='
print -r -- "LOGIN_STAGE=${__zsh_stage_loaded[login]:-0}"
print -r -- "INT_STAGE=${__zsh_stage_loaded[interactive]:-0}"
print -r -- "IS_LOGIN=$([[ -o login ]] && print 1 || print 0)"
print -r -- "IS_INTERACTIVE=$([[ $- == *i* ]] && print 1 || print 0)"
'

if run_capture LINK_I_OUT env -i \
  HOME="$LINK_HOME" \
  XDG_CONFIG_HOME="$LINK_XDG" \
  PATH="$PATH" \
  TERM="${TERM:-xterm-256color}" \
  "$ZSH_BIN" -ic "$SMOKE_LINK_I_SCRIPT"
then
  print_block "zsh -ic (link)" "$LINK_I_OUT"
  pass "zsh -ic 启动成功"
else
  print_block "zsh -ic (link)" "$LINK_I_OUT"
  fail "zsh -ic 启动失败"
fi

assert_contains "$LINK_I_OUT" "LOGIN_STAGE=0" "zsh -ic 不应执行 login 阶段"
assert_contains "$LINK_I_OUT" "INT_STAGE=1" "zsh -ic 应执行 interactive 阶段"
assert_contains "$LINK_I_OUT" "IS_LOGIN=0" "zsh -ic 不是 login shell"
assert_contains "$LINK_I_OUT" "IS_INTERACTIVE=1" "zsh -ic 是 interactive shell"

log STEP "不加 --force 的幂等安装检查"

if run_capture IDEMPOTENT_OUT env -i \
  HOME="$LINK_HOME" \
  XDG_CONFIG_HOME="$LINK_XDG" \
  PATH="$PATH" \
  "$BASH_BIN" "$REPO_ROOT/install.sh" --link
then
  print_block "install --link (idempotent expected success)" "$IDEMPOTENT_OUT"
  assert_contains "$IDEMPOTENT_OUT" "Already linked:" "已正确安装时输出 Already linked"
  pass "已有正确目标时，不加 --force 幂等成功"
else
  print_block "install --link (idempotent expected success)" "$IDEMPOTENT_OUT"
  fail "已有正确目标时，不加 --force 不应失败"
fi

log STEP "不加 --force 的冲突目标检查"

BROKEN_HOME="$TMPROOT/broken-home"
BROKEN_XDG="$BROKEN_HOME/.config"
mkdir -p "$BROKEN_XDG/zsh"
printf 'broken\n' > "$BROKEN_HOME/.zshenv"
printf 'not-a-repo-copy\n' > "$BROKEN_XDG/zsh/README.fake"

if run_capture CONFLICT_OUT env -i \
  HOME="$BROKEN_HOME" \
  XDG_CONFIG_HOME="$BROKEN_XDG" \
  PATH="$PATH" \
  "$BASH_BIN" "$REPO_ROOT/install.sh" --link
then
  print_block "install --link (conflict expected fail)" "$CONFLICT_OUT"
  fail "冲突目标时，不加 --force 居然成功"
else
  print_block "install --link (conflict expected fail)" "$CONFLICT_OUT"
  assert_contains "$CONFLICT_OUT" "Target exists:" "冲突目标时提示 Target exists"
  pass "冲突目标时，不加 --force 正确失败"
fi

log STEP "隔离环境 copy 安装"

COPY_HOME="$TMPROOT/copy-home"
COPY_XDG="$COPY_HOME/.config"
mkdir -p "$COPY_HOME"

if run_capture COPY_INSTALL_OUT env -i \
  HOME="$COPY_HOME" \
  XDG_CONFIG_HOME="$COPY_XDG" \
  PATH="$PATH" \
  "$BASH_BIN" "$REPO_ROOT/install.sh" --copy --force
then
  print_block "install --copy --force" "$COPY_INSTALL_OUT"
  pass "copy 安装成功"
else
  print_block "install --copy --force" "$COPY_INSTALL_OUT"
  fail "copy 安装失败"
fi

assert_exists "$COPY_HOME/.zshenv" "copy 模式下 ~/.zshenv 存在"
assert_exists "$COPY_XDG/zsh" "copy 模式下 ~/.config/zsh 存在"
assert_not_symlink "$COPY_HOME/.zshenv" "copy 模式下 ~/.zshenv 不是符号链接"
assert_not_symlink "$COPY_XDG/zsh" "copy 模式下 ~/.config/zsh 不是符号链接"
assert_file "$COPY_XDG/zsh/init.zsh" "copy 模式下 init.zsh 已复制"

log STEP "copy 模式下本地覆盖测试"

cat > "$COPY_XDG/zsh/config.local.zsh" <<'EOCONFIGLOCAL'
typeset -gi ZSH_ENABLE_HISTORY=0
typeset -gi ZSH_ENABLE_COMPLETION=0
typeset -gi ZSH_ENABLE_KEYBINDS=0
typeset -gi ZSH_ENABLE_PROMPT=0
typeset -g ZSH_KEYMAP=vi
typeset -g ZSH_THEME=basic
EOCONFIGLOCAL

cat > "$COPY_XDG/zsh/local.zsh" <<'EOLOCAL'
typeset -g LOCAL_MARK="loaded_from_local"
EOLOCAL

SMOKE_COPY_I_SCRIPT='
print -r -- "LOCAL_MARK=${LOCAL_MARK:-}"
print -r -- "FEATURES=${ZSH_ENABLE_HISTORY:-}/${ZSH_ENABLE_COMPLETION:-}/${ZSH_ENABLE_KEYBINDS:-}/${ZSH_ENABLE_PROMPT:-}"
print -r -- "KEYMAP=${ZSH_KEYMAP:-}"
print -r -- "THEME=${ZSH_THEME:-}"
print -r -- "INT_STAGE=${__zsh_stage_loaded[interactive]:-0}"
'

if run_capture COPY_I_OUT env -i \
  HOME="$COPY_HOME" \
  XDG_CONFIG_HOME="$COPY_XDG" \
  PATH="$PATH" \
  TERM="${TERM:-xterm-256color}" \
  "$ZSH_BIN" -ic "$SMOKE_COPY_I_SCRIPT"
then
  print_block "zsh -ic (copy + local override)" "$COPY_I_OUT"
  pass "copy 模式下本地覆盖测试启动成功"
else
  print_block "zsh -ic (copy + local override)" "$COPY_I_OUT"
  fail "copy 模式下本地覆盖测试启动失败"
fi

assert_contains "$COPY_I_OUT" "LOCAL_MARK=loaded_from_local" "local.zsh 已被加载"
assert_contains "$COPY_I_OUT" "FEATURES=0/0/0/0" "config.local.zsh 覆盖开关成功"
assert_contains "$COPY_I_OUT" "KEYMAP=vi" "config.local.zsh 覆盖 keymap 成功"
assert_contains "$COPY_I_OUT" "THEME=basic" "config.local.zsh 覆盖 theme 成功"
assert_contains "$COPY_I_OUT" "INT_STAGE=1" "copy 模式 interactive 阶段执行成功"

log STEP "XDG 路径契约探测（这一步不判定对错，只输出当前行为）"

CONTRACT_HOME="$TMPROOT/contract-home"
CONTRACT_XDG="$TMPROOT/contract-xdg"
mkdir -p "$CONTRACT_HOME" "$CONTRACT_XDG"

if run_capture CONTRACT_OUT env -i \
  HOME="$CONTRACT_HOME" \
  XDG_CONFIG_HOME="$CONTRACT_XDG" \
  PATH="$PATH" \
  "$BASH_BIN" "$REPO_ROOT/install.sh" --link --force
then
  print_block "contract install" "$CONTRACT_OUT"
else
  print_block "contract install" "$CONTRACT_OUT"
  fail "XDG 契约探测安装失败"
fi

if [ -L "$CONTRACT_XDG/zsh" ] || [ -d "$CONTRACT_XDG/zsh" ]; then
  pass "当前安装契约：优先使用 XDG_CONFIG_HOME"
  printf 'CONTRACT_RESULT=XDG_CONFIG_HOME_PRIORITY\n'
else
  warn "当前安装契约：没有落在 XDG_CONFIG_HOME，需人工看输出"
  printf 'CONTRACT_RESULT=UNKNOWN\n'
fi

if [ -e "$CONTRACT_HOME/.config/zsh" ] || [ -L "$CONTRACT_HOME/.config/zsh" ]; then
  printf 'HOME_CONFIG_ZSH_PRESENT=1\n'
else
  printf 'HOME_CONFIG_ZSH_PRESENT=0\n'
fi

log SUMMARY "测试完成"
printf 'PASS=%s\n' "$PASS_COUNT"
printf 'FAIL=%s\n' "$FAIL_COUNT"
printf 'WARN=%s\n' "$WARN_COUNT"
printf 'TMPROOT=%s\n' "$TMPROOT"

if [ "$FAIL_COUNT" -ne 0 ]; then
  printf '\nRESULT=FAILED\n'
  exit 1
fi

printf '\nRESULT=PASSED\n'
exit 0
