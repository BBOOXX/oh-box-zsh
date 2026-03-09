#!/usr/bin/env bash
set -u
set -o pipefail
# ^ 测试脚本故意不开 -e.
#   原因是我们希望在某一步失败后, 继续跑完剩余检查, 最后一次性汇总失败项.
#   如果开了 -e, 脚本会在第一处失败时立即退出, 不利于一次性看全量问题.

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log() {
# ^ 统一输出阶段标题.
  printf '\n[%s] %s\n' "$1" "$2"
}

pass() {
# ^ 成功计数并输出成功信息.
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$*"
}

fail() {
# ^ 失败计数并输出失败信息.
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*"
}

warn() {
# ^ 警告计数并输出警告信息.
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$*"
}

run_capture() {
# ^ 执行命令并同时捕获标准输出和标准错误.
#   第一个参数是变量名, 用来接收输出内容.
#   返回码保持为被执行命令的返回码.
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
# ^ 判断路径是否存在, 包括坏掉的符号链接.
  local path="$1"
  local msg="$2"
  if [ -e "$path" ] || [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (missing: $path)"
  fi
}

assert_not_exists() {
# ^ 判断路径不存在, 包括不是坏掉的符号链接.
  local path="$1"
  local msg="$2"
  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$msg (unexpected path: $path)"
  else
    pass "$msg"
  fi
}

assert_file() {
# ^ 判断路径是否是普通文件.
  local path="$1"
  local msg="$2"
  if [ -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a regular file: $path)"
  fi
}

assert_dir() {
# ^ 判断路径是否是目录.
  local path="$1"
  local msg="$2"
  if [ -d "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a directory: $path)"
  fi
}

assert_symlink() {
# ^ 判断路径是否是符号链接.
  local path="$1"
  local msg="$2"
  if [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a symlink: $path)"
  fi
}

assert_eq() {
# ^ 做字符串相等断言.
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
# ^ 判断一段文本是否包含某个子串.
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (missing: $needle)"
  fi
}

assert_not_contains() {
# ^ 判断一段文本不包含某个子串.
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    fail "$msg (unexpected: $needle)"
  else
    pass "$msg"
  fi
}

print_block() {
# ^ 打印一段输出块, 方便排查失败原因.
  local title="$1"
  local body="$2"
  printf '\n----- %s -----\n%s\n' "$title" "$body"
}

get_symlink_target() {
# ^ 读取符号链接目标.
  local path="$1"
  readlink "$path" 2>/dev/null || true
}

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
# ^ 计算仓库根目录.
#   测试脚本位于 test/ 子目录, 所以上一层就是仓库根.

BASH_BIN="$(command -v bash 2>/dev/null || true)"
SHELLCHECK_BIN="$(command -v shellcheck 2>/dev/null || true)"
ZSH_BIN="$(command -v zsh 2>/dev/null || true)"

log INFO "repo root = $REPO_ROOT"

log STEP "基础前置检查"

if [ -z "$BASH_BIN" ]; then
  printf '[FATAL] bash not found\n' >&2
  exit 1
fi

printf 'bash = %s\n' "$BASH_BIN"
"$BASH_BIN" --version | head -n 1 || true

assert_file "$REPO_ROOT/install.sh" "install.sh 存在"
assert_file "$REPO_ROOT/zshenv" "zshenv 存在"
assert_dir  "$REPO_ROOT/zsh" "zsh 目录存在"
assert_file "$REPO_ROOT/zsh/init.zsh" "init.zsh 存在"
assert_file "$REPO_ROOT/zsh/conf/defaults.zsh" "conf/defaults.zsh 存在"
assert_file "$REPO_ROOT/zsh/conf/local.zsh.example" "conf/local.zsh.example 存在"
assert_file "$REPO_ROOT/zsh/user/config.zsh" "user/config.zsh 存在"
assert_file "$REPO_ROOT/zsh/features/env-path.zsh" "features/env-path.zsh 存在"
assert_file "$REPO_ROOT/zsh/features/pyenv.zsh" "features/pyenv.zsh 存在"
assert_file "$REPO_ROOT/zsh/features/z.zsh" "features/z.zsh 存在"
assert_dir  "$REPO_ROOT/zsh/features" "features 目录存在"
assert_dir  "$REPO_ROOT/test" "test 目录存在"
assert_file "$REPO_ROOT/test/test-core.zsh" "test/test-core.zsh 存在"
assert_file "$REPO_ROOT/test/test-install.sh" "test/test-install.sh 存在"

log STEP "结构边界检查"

if run_capture ENV_PATH_OUT sed -n '1,120p' "$REPO_ROOT/zsh/features/env-path.zsh"; then
  assert_not_contains "$ENV_PATH_OUT" '/opt/homebrew' "env-path 不硬编码 Homebrew 路径"
  assert_not_contains "$ENV_PATH_OUT" '/home/linuxbrew/.linuxbrew' "env-path 不硬编码 Linuxbrew 路径"
else
  print_block "env-path" "$ENV_PATH_OUT"
  fail "读取 env-path 失败"
fi

log STEP "bash 语法检查"

if run_capture BASH_N_OUT "$BASH_BIN" -n "$REPO_ROOT/install.sh"; then
  pass "bash -n install.sh 通过"
else
  print_block "bash syntax error" "$BASH_N_OUT"
  fail "bash -n install.sh 失败"
fi

log STEP "可选 shellcheck 检查"

if [ -z "$SHELLCHECK_BIN" ]; then
  warn "shellcheck 未安装, 跳过 bash 静态检查"
else
  printf 'shellcheck = %s\n' "$SHELLCHECK_BIN"
  if run_capture SHELLCHECK_OUT "$SHELLCHECK_BIN" "$REPO_ROOT/install.sh" "$REPO_ROOT/test/test-zsh.sh" "$REPO_ROOT/test/test-install.sh"
  then
    pass "shellcheck bash 脚本通过"
  else
    print_block "shellcheck" "$SHELLCHECK_OUT"
    fail "shellcheck bash 脚本失败"
  fi
fi

log STEP "install helper 单元测试"

if run_capture INSTALL_TEST_OUT env -i HOME="$PWD" PATH="$PATH" "$BASH_BIN" "$REPO_ROOT/test/test-install.sh"
then
  print_block "install helper unit test" "$INSTALL_TEST_OUT"
  pass "install helper 单元测试通过"
else
  print_block "install helper unit test" "$INSTALL_TEST_OUT"
  fail "install helper 单元测试失败"
fi

log STEP "隔离环境 link 安装"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-box-zsh-v2.XXXXXX")"
printf 'TMPROOT=%s\n' "$TMPROOT"

LINK_HOME="$TMPROOT/link-home"
LINK_XDG="$LINK_HOME/.config"
mkdir -p "$LINK_HOME"

if run_capture LINK_INSTALL_OUT env -i   HOME="$LINK_HOME"   XDG_CONFIG_HOME="$LINK_XDG"   PATH="$PATH"   "$BASH_BIN" "$REPO_ROOT/install.sh" --link --force
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
assert_eq "$LINK_ZSHDIR_TARGET" "$REPO_ROOT/zsh" "link 模式下 ~/.config/zsh 指向仓库 zsh/"

log STEP "隔离环境 copy 安装"

COPY_HOME="$TMPROOT/copy-home"
COPY_XDG="$COPY_HOME/.config"
mkdir -p "$COPY_HOME"

if run_capture COPY_INSTALL_OUT env -i   HOME="$COPY_HOME"   XDG_CONFIG_HOME="$COPY_XDG"   PATH="$PATH"   "$BASH_BIN" "$REPO_ROOT/install.sh" --copy --force
then
  print_block "install --copy --force" "$COPY_INSTALL_OUT"
  pass "copy 安装成功"
else
  print_block "install --copy --force" "$COPY_INSTALL_OUT"
  fail "copy 安装失败"
fi

assert_file "$COPY_HOME/.zshenv" "copy 模式下 ~/.zshenv 是普通文件"
assert_dir  "$COPY_XDG/zsh" "copy 模式下 ~/.config/zsh 是目录"
assert_file "$COPY_XDG/zsh/.oh-box-zsh-id" "copy 模式下项目标识文件存在"

log STEP "copy 模式源码更新刷新验证"

COPY_REFRESH_REPO="$TMPROOT/copy-refresh-repo"
COPY_REFRESH_HOME="$TMPROOT/copy-refresh-home"
COPY_REFRESH_XDG="$COPY_REFRESH_HOME/.config"

cp -R "$REPO_ROOT" "$COPY_REFRESH_REPO"
mkdir -p "$COPY_REFRESH_HOME"

if run_capture COPY_REFRESH_INSTALL_OUT env -i   HOME="$COPY_REFRESH_HOME"   XDG_CONFIG_HOME="$COPY_REFRESH_XDG"   PATH="$PATH"   "$BASH_BIN" "$COPY_REFRESH_REPO/install.sh" --copy --force
then
  print_block "copy refresh install" "$COPY_REFRESH_INSTALL_OUT"
  pass "copy 刷新测试的首次安装成功"
else
  print_block "copy refresh install" "$COPY_REFRESH_INSTALL_OUT"
  fail "copy 刷新测试的首次安装失败"
fi

printf '\n# copy-refresh-marker\n' >> "$COPY_REFRESH_REPO/zsh/init.zsh"

if run_capture COPY_REFRESH_RERUN_OUT env -i   HOME="$COPY_REFRESH_HOME"   XDG_CONFIG_HOME="$COPY_REFRESH_XDG"   PATH="$PATH"   "$BASH_BIN" "$COPY_REFRESH_REPO/install.sh" --copy --force
then
  print_block "copy refresh rerun" "$COPY_REFRESH_RERUN_OUT"
  pass "copy 刷新测试的第二次安装成功"
else
  print_block "copy refresh rerun" "$COPY_REFRESH_RERUN_OUT"
  fail "copy 刷新测试的第二次安装失败"
fi

if run_capture COPY_REFRESH_MARKER_OUT tail -n 1 "$COPY_REFRESH_XDG/zsh/init.zsh"; then
  assert_eq "$COPY_REFRESH_MARKER_OUT" "# copy-refresh-marker" "copy 模式在源码更新后会刷新目标目录"
else
  print_block "copy refresh target tail" "$COPY_REFRESH_MARKER_OUT"
  fail "读取 copy 刷新后的 init.zsh 失败"
fi

log STEP "可选 zsh 语法与运行验证"

if [ -z "$ZSH_BIN" ]; then
  warn "zsh 未安装, 跳过 zsh 语法与运行验证"
else
  printf 'zsh  = %s\n' "$ZSH_BIN"
  "$ZSH_BIN" --version

  # 构造需要做 zsh -n 语法检查的文件列表.
  SYNTAX_LIST_FILE="$TMPROOT/syntax-list.txt"
  : > "$SYNTAX_LIST_FILE"

  find "$REPO_ROOT/zsh" -type f     \( -name '*.zsh' -o -name '.zprofile' -o -name '.zshrc' \)     | sort >> "$SYNTAX_LIST_FILE"
  printf '%s\n' "$REPO_ROOT/zshenv" >> "$SYNTAX_LIST_FILE"

  while IFS= read -r file_path; do
    [ -n "$file_path" ] || continue

    if run_capture SYNTAX_OUT "$ZSH_BIN" -n "$file_path"; then
      pass "zsh -n 通过: ${file_path#"$REPO_ROOT"/}"
    else
      print_block "syntax error: ${file_path#"$REPO_ROOT"/}" "$SYNTAX_OUT"
      fail "zsh -n 失败: ${file_path#"$REPO_ROOT"/}"
    fi
  done < "$SYNTAX_LIST_FILE"

  if run_capture CORE_SYNTAX_OUT "$ZSH_BIN" -n "$REPO_ROOT/test/test-core.zsh"; then
    pass "zsh -n 通过: test/test-core.zsh"
  else
    print_block "syntax error: test/test-core.zsh" "$CORE_SYNTAX_OUT"
    fail "zsh -n 失败: test/test-core.zsh"
  fi

  if run_capture CORE_TEST_OUT env -i     HOME="$TMPROOT/core-home"     XDG_CACHE_HOME="$TMPROOT/core-home/.cache"     PATH="$PATH"     "$ZSH_BIN" "$REPO_ROOT/test/test-core.zsh" "$REPO_ROOT"
  then
    print_block "zsh core unit test" "$CORE_TEST_OUT"
    pass "core helper 单元测试通过"
  else
    print_block "zsh core unit test" "$CORE_TEST_OUT"
    fail "core helper 单元测试失败"
  fi

  # 为了验证 config 和 local 的加载时机, 我们创建一个临时仓库副本并往里注入测试 feature.
  TMPREPO="$TMPROOT/runtime-repo"
  cp -R "$REPO_ROOT" "$TMPREPO"

  cat > "$TMPREPO/zsh/user/config.zsh" <<'EOF'
# 这个临时 config 用于验证.
# 1. config 在 login feature 之前可见.
# 2. interactive 也能看到 config.
typeset -g TEST_CONFIG_MARK="loaded_from_config"
typeset -ga ZSH_LOGIN_FEATURES
ZSH_LOGIN_FEATURES=(env-path pyenv test-login-probe)
typeset -ga ZSH_INTERACTIVE_FEATURES
ZSH_INTERACTIVE_FEATURES=(history completion pyenv z keybinds prompt)
ZSH_THEME="avit"
ZSH_KEYMAP="vi"
EOF

  cat > "$TMPREPO/zsh/user/local.zsh" <<'EOF'
# 这个临时 local 用于验证 interactive 末尾加载.
typeset -g TEST_LOCAL_MARK="loaded_from_local"
EOF

  cat > "$TMPREPO/zsh/features/test-login-probe.zsh" <<'EOF'
# 这个临时 feature 用来验证 login feature 加载时, config 是否已经可见.
if [[ "${TEST_CONFIG_MARK:-}" == "loaded_from_config" ]]; then
  typeset -g TEST_LOGIN_PROBE="config_visible_before_login"
else
  typeset -g TEST_LOGIN_PROBE="config_missing_before_login"
fi
EOF

  RUNTIME_HOME="$TMPROOT/runtime-home"
  RUNTIME_XDG="$RUNTIME_HOME/.config"
  mkdir -p "$RUNTIME_HOME"

  if run_capture RUNTIME_INSTALL_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$BASH_BIN" "$TMPREPO/install.sh" --link --force
  then
    print_block "runtime install" "$RUNTIME_INSTALL_OUT"
    pass "runtime repo 安装成功"
  else
    print_block "runtime install" "$RUNTIME_INSTALL_OUT"
    fail "runtime repo 安装失败"
  fi

  RUNTIME_PYENV_ROOT="$RUNTIME_HOME/.pyenv"
  RUNTIME_PYENV_BIN="$RUNTIME_PYENV_ROOT/bin/pyenv"
  RUNTIME_PYENV_COMPLETION="$TMPROOT/runtime-pyenv-completion.zsh"
  RUNTIME_PYENV_PROJECT="$RUNTIME_HOME/work-python"
  RUNTIME_PYENV_SUBDIR="$RUNTIME_PYENV_PROJECT/app"
  mkdir -p "$RUNTIME_PYENV_ROOT/bin" "$RUNTIME_PYENV_ROOT/shims"
  mkdir -p "$RUNTIME_PYENV_SUBDIR"
  printf '%s\n' '3.11.9/envs/runtime' > "$RUNTIME_PYENV_PROJECT/.python-version"

  cat > "$RUNTIME_PYENV_COMPLETION" <<EOF
typeset -g TEST_RUNTIME_PYENV_COMPLETION=loaded_from_runtime_completion
EOF

  cat > "$RUNTIME_PYENV_BIN" <<EOF
#!/bin/sh
case "\$*" in
  'init --path --no-push-path --no-rehash')
    printf '%s\n' 'typeset -gx TEST_RUNTIME_PYENV_LOGIN=loaded_from_runtime_login'
    printf '%s\n' 'if [[ ":\$PATH:" != *":$RUNTIME_PYENV_ROOT/shims:"* ]]; then export PATH="$RUNTIME_PYENV_ROOT/shims:\${PATH}"; fi'
    exit 0
    ;;
  'init - --no-push-path --no-rehash zsh')
    printf '%s\n' 'typeset -gx TEST_RUNTIME_PYENV_INTERACTIVE=loaded_from_runtime_interactive'
    printf '%s\n' 'if [[ ":\$PATH:" != *":$RUNTIME_PYENV_ROOT/shims:"* ]]; then export PATH="$RUNTIME_PYENV_ROOT/shims:\${PATH}"; fi'
    printf '%s\n' 'export PYENV_SHELL=zsh'
    printf '%s\n' 'pyenv() { command "$RUNTIME_PYENV_BIN" "\$@"; }'
    printf '%s\n' "source '$RUNTIME_PYENV_COMPLETION'"
    exit 0
    ;;
  'virtualenv-init -')
    printf '%s\n' 'typeset -gx TEST_RUNTIME_PYENV_VIRTUALENV=loaded_from_runtime_virtualenv'
    printf '%s\n' 'export PYENV_VIRTUALENV_INIT=1'
    printf '%s\n' '_pyenv_virtualenv_hook() { typeset -gx TEST_RUNTIME_PYENV_VIRTUALENV_HOOK=triggered_from_runtime_virtualenv; return 0; }'
    printf '%s\n' 'typeset -g -a precmd_functions'
    printf '%s\n' 'if [[ -z \${precmd_functions[(r)_pyenv_virtualenv_hook]:-} ]]; then precmd_functions=(_pyenv_virtualenv_hook \$precmd_functions); fi'
    exit 0
    ;;
esac
exit 1
EOF
  chmod +x "$RUNTIME_PYENV_BIN"

  log STEP "stage guard 验证"

  # shellcheck disable=SC2016
  run_capture INVALID_STAGE_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     ZDOTDIR="$RUNTIME_XDG/zsh"     ZSH_INIT_STAGE="bad"     "$ZSH_BIN" -fc 'source "$ZDOTDIR/init.zsh"'
  INVALID_STAGE_RC=$?

  if [ "$INVALID_STAGE_RC" -ne 0 ]; then
    pass "非法 ZSH_INIT_STAGE 会返回非零"
  else
    print_block "invalid stage" "$INVALID_STAGE_OUT"
    fail "非法 ZSH_INIT_STAGE 不应静默成功"
  fi

  assert_contains "$INVALID_STAGE_OUT" '[zsh-init] unknown stage: bad' "非法阶段会输出明确错误"

  # shellcheck disable=SC2016
  if run_capture LOGIN_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -lc 'print -r -- "zdotdir=$ZDOTDIR cfg=${TEST_CONFIG_MARK:-none} login=${TEST_LOGIN_PROBE:-none} local=${TEST_LOCAL_MARK:-none} pyenv_root=${PYENV_ROOT:-none} pyenv_login=${TEST_RUNTIME_PYENV_LOGIN:-none}"; print -r -- "path0=${path[1]:-none}"'
  then
    print_block "zsh -lc" "$LOGIN_OUT"
    assert_contains "$LOGIN_OUT" "zdotdir=$RUNTIME_XDG/zsh" "login 阶段的 ZDOTDIR 正确指向 XDG 配置目录"
    assert_contains "$LOGIN_OUT" 'cfg=loaded_from_config' "login 阶段能看到 config.zsh"
    assert_contains "$LOGIN_OUT" 'login=config_visible_before_login' "login feature 能看到更早加载的 config.zsh"
    assert_contains "$LOGIN_OUT" 'local=none' "login 阶段不加载 local.zsh"
    assert_contains "$LOGIN_OUT" "pyenv_root=$RUNTIME_PYENV_ROOT" "login 阶段会导出 PYENV_ROOT"
    assert_contains "$LOGIN_OUT" 'pyenv_login=loaded_from_runtime_login' "login 阶段会加载 pyenv path 初始化"
    assert_contains "$LOGIN_OUT" "path0=$RUNTIME_PYENV_ROOT/shims" "login 阶段会把 pyenv shims 放到 PATH 前面"
  else
    print_block "zsh -lc" "$LOGIN_OUT"
    fail "zsh -lc 执行失败"
  fi

  # shellcheck disable=SC2016
  if run_capture INTERACTIVE_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic 'print -r -- "zdotdir=$ZDOTDIR cfg=${TEST_CONFIG_MARK:-none} login=${TEST_LOGIN_PROBE:-none} local=${TEST_LOCAL_MARK:-none} theme=${ZSH_THEME:-none} keymap=${ZSH_KEYMAP:-none} pyenv_root=${PYENV_ROOT:-none} pyenv_shell=${PYENV_SHELL:-none} pyenv_interactive=${TEST_RUNTIME_PYENV_INTERACTIVE:-none} pyenv_completion=${TEST_RUNTIME_PYENV_COMPLETION:-none} pyenv_virtualenv=${TEST_RUNTIME_PYENV_VIRTUALENV:-none} pyenv_virtualenv_init=${PYENV_VIRTUALENV_INIT:-none}"; print -r -- "prompt=$PROMPT"; print -r -- "rprompt=$RPROMPT"; typeset -f __zsh_avit_precmd >/dev/null 2>&1 && print -r -- "avit_func=yes"; typeset -f pyenv >/dev/null 2>&1 && print -r -- "pyenv_func=yes"; typeset -f _pyenv_virtualenv_hook >/dev/null 2>&1 && print -r -- "pyenv_virtualenv_func=yes"; print -r -- "path0=${path[1]:-none}"'
  then
    print_block "zsh -ic" "$INTERACTIVE_OUT"
    assert_contains "$INTERACTIVE_OUT" "zdotdir=$RUNTIME_XDG/zsh" "interactive 阶段的 ZDOTDIR 正确指向 XDG 配置目录"
    assert_contains "$INTERACTIVE_OUT" 'cfg=loaded_from_config' "interactive 阶段能看到 config.zsh"
    assert_contains "$INTERACTIVE_OUT" 'local=loaded_from_local' "interactive 阶段加载 local.zsh"
    assert_contains "$INTERACTIVE_OUT" 'theme=avit' "interactive 阶段会加载声明的 avit 主题"
    assert_contains "$INTERACTIVE_OUT" 'keymap=vi' "interactive 阶段会保留声明的 vi 编辑模式"
    assert_contains "$INTERACTIVE_OUT" "pyenv_root=$RUNTIME_PYENV_ROOT" "interactive 阶段也会导出 PYENV_ROOT"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_shell=zsh' "interactive 阶段会导出 PYENV_SHELL"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_interactive=loaded_from_runtime_interactive' "interactive 阶段会加载 pyenv shell 初始化"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_completion=loaded_from_runtime_completion' "interactive 阶段会 source pyenv completion"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_virtualenv=none' "interactive 启动时不会立刻加载 pyenv virtualenv init"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_virtualenv_init=none' "interactive 启动时不会立刻导出 PYENV_VIRTUALENV_INIT"
    assert_contains "$INTERACTIVE_OUT" 'pyenv_func=yes' "interactive 阶段会定义 pyenv shell function"
    assert_contains "$INTERACTIVE_OUT" "path0=$RUNTIME_PYENV_ROOT/shims" "interactive 阶段会把 pyenv shims 放到 PATH 前面"
    assert_contains "$INTERACTIVE_OUT" '__zsh_avit_git_left_segment' "avit 主题会接管左侧 prompt"
    assert_contains "$INTERACTIVE_OUT" '__zsh_avit_rprompt_segment' "avit 主题会接管右侧 prompt"
    assert_contains "$INTERACTIVE_OUT" 'avit_func=yes' "avit 主题的 precmd 钩子函数已加载"

    # 再做一组默认 UX 验证.
    # 这里只验证最关键的几个默认行为是否真的被打开.
    # shellcheck disable=SC2016
    if run_capture UX_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic 'print -r -- "case=${ZSH_COMPLETION_CASE_INSENSITIVE:-0} opt_complete_in_word=${options[completeinword]:-off} opt_auto_menu=${options[automenu]:-off} opt_share_history=${options[sharehistory]:-off} opt_hist_verify=${options[histverify]:-off}"'
  then
    print_block "zsh default ux" "$UX_OUT"
    assert_contains "$UX_OUT" 'case=1' "默认开启大小写无关补全配置"
    assert_contains "$UX_OUT" 'opt_complete_in_word=on' "默认开启 complete_in_word"
    assert_contains "$UX_OUT" 'opt_auto_menu=on' "默认开启 auto_menu"
    assert_contains "$UX_OUT" 'opt_share_history=on' "默认开启 share_history"
    assert_contains "$UX_OUT" 'opt_hist_verify=on' "默认开启 hist_verify"
  else
    print_block "zsh default ux" "$UX_OUT"
    fail "默认 UX 验证失败"
  fi
  else
    print_block "zsh -ic" "$INTERACTIVE_OUT"
    fail "zsh -ic 执行失败"
  fi

  assert_not_exists "$RUNTIME_HOME/.cache/zsh/z/data" "interactive 启动不会预写 z 索引"

  if run_capture PYENV_VIRTUALENV_LAZY_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "cd '$RUNTIME_PYENV_SUBDIR'; print -r -- \"pyenv_virtualenv=\${TEST_RUNTIME_PYENV_VIRTUALENV:-none} pyenv_virtualenv_init=\${PYENV_VIRTUALENV_INIT:-none} pyenv_virtualenv_hook=\${TEST_RUNTIME_PYENV_VIRTUALENV_HOOK:-none}\"; typeset -f _pyenv_virtualenv_hook >/dev/null 2>&1 && print -r -- \"pyenv_virtualenv_func=yes\""
  then
    print_block "pyenv virtualenv lazy" "$PYENV_VIRTUALENV_LAZY_OUT"
    assert_contains "$PYENV_VIRTUALENV_LAZY_OUT" 'pyenv_virtualenv=loaded_from_runtime_virtualenv' "进入带 .python-version 的目录后才加载 pyenv virtualenv init"
    assert_contains "$PYENV_VIRTUALENV_LAZY_OUT" 'pyenv_virtualenv_init=1' "命中目录后会导出 PYENV_VIRTUALENV_INIT"
    assert_contains "$PYENV_VIRTUALENV_LAZY_OUT" 'pyenv_virtualenv_hook=triggered_from_runtime_virtualenv' "lazy virtualenv init 会立刻运行一次 hook"
    assert_contains "$PYENV_VIRTUALENV_LAZY_OUT" 'pyenv_virtualenv_func=yes' "lazy virtualenv init 会定义 virtualenv hook 函数"
  else
    print_block "pyenv virtualenv lazy" "$PYENV_VIRTUALENV_LAZY_OUT"
    fail "pyenv virtualenv lazy 验证失败"
  fi

  log STEP "z 目录跳转验证"

  TRACK_ALPHA="$RUNTIME_HOME/work-alpha"
  TRACK_BETA="$RUNTIME_HOME/work-beta"
  TRACK_DOWN="$RUNTIME_HOME/Downloads"
  TRACK_GAMMA="$RUNTIME_HOME/work-gamma"
  mkdir -p "$TRACK_ALPHA" "$TRACK_BETA" "$TRACK_DOWN" "$TRACK_GAMMA"
  TRACK_ALPHA_REAL="$(CDPATH='' cd -- "$TRACK_ALPHA" && pwd)"
  TRACK_DOWN_REAL="$(CDPATH='' cd -- "$TRACK_DOWN" && pwd)"
  TRACK_GAMMA_REAL="$(CDPATH='' cd -- "$TRACK_GAMMA" && pwd)"

  if run_capture Z_TRACK_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "cd '$TRACK_ALPHA'; cd '$TRACK_BETA'; cd '$TRACK_ALPHA'; cd '$TRACK_DOWN'; print -r -- tracked"
  then
    print_block "z track" "$Z_TRACK_OUT"
    pass "z 目录轨迹建立成功"
  else
    print_block "z track" "$Z_TRACK_OUT"
    fail "z 目录轨迹建立失败"
  fi

  assert_file "$RUNTIME_HOME/.cache/zsh/z/data" "z feature 会把目录索引写入缓存"

  if run_capture Z_LIST_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "z -l alpha"
  then
    print_block "z list" "$Z_LIST_OUT"
    assert_contains "$Z_LIST_OUT" "$TRACK_ALPHA_REAL" "z -l 会列出命中的目录"
    assert_not_contains "$Z_LIST_OUT" $'\t' "z -l 不泄漏内部 record 字段"
  else
    print_block "z list" "$Z_LIST_OUT"
    fail "z -l 执行失败"
  fi

  if run_capture Z_JUMP_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "cd '$RUNTIME_HOME'; z alpha && print -r -- \$PWD"
  then
    print_block "z jump" "$Z_JUMP_OUT"
    assert_contains "$Z_JUMP_OUT" "$TRACK_ALPHA_REAL" "z 能跳到访问过的路径"
  else
    print_block "z jump" "$Z_JUMP_OUT"
    fail "z 跳转执行失败"
  fi

  if run_capture Z_COMPLETE_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "print -r -- comp=\${_comps[z]:-none}; __zsh_z_completion_candidates alpha; print -l -- \${reply[@]}"
  then
    print_block "z completion" "$Z_COMPLETE_OUT"
    assert_contains "$Z_COMPLETE_OUT" 'comp=_z' "z completion 已注册到 compdef"
    assert_contains "$Z_COMPLETE_OUT" "$TRACK_ALPHA_REAL" "z completion 能产出目录候选"
    assert_not_contains "$Z_COMPLETE_OUT" $'\t' "z completion 不泄漏内部 record 字段"
    assert_not_contains "$Z_COMPLETE_OUT" 'visits' "z completion 不展示内部计数字段"
  else
    print_block "z completion" "$Z_COMPLETE_OUT"
    fail "z completion 验证失败"
  fi

  if run_capture Z_COMPLETE_CASE_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "__zsh_z_completion_candidates down; print -l -- \${reply[@]}"
  then
    print_block "z completion case-insensitive" "$Z_COMPLETE_CASE_OUT"
    assert_contains "$Z_COMPLETE_CASE_OUT" "$TRACK_DOWN_REAL" "z completion 支持大小写无关的子串匹配"
  else
    print_block "z completion case-insensitive" "$Z_COMPLETE_CASE_OUT"
    fail "z completion 大小写无关验证失败"
  fi

  if run_capture Z_RELOAD_OUT env -i     HOME="$RUNTIME_HOME"     XDG_CONFIG_HOME="$RUNTIME_XDG"     PATH="$PATH"     "$ZSH_BIN" -ic "__zsh_z_completion_candidates alpha >/dev/null; sleep 1; printf '%s\t%s\t%s\n' 7 9999999999 '$TRACK_GAMMA_REAL' >> '$RUNTIME_HOME/.cache/zsh/z/data'; __zsh_z_completion_candidates gamma; print -l -- \${reply[@]}"
  then
    print_block "z completion reload" "$Z_RELOAD_OUT"
    assert_contains "$Z_RELOAD_OUT" "$TRACK_GAMMA_REAL" "z completion 会在数据文件变更后按需重载"
  else
    print_block "z completion reload" "$Z_RELOAD_OUT"
    fail "z completion 按需重载验证失败"
  fi
fi

log RESULT "PASS=$PASS_COUNT FAIL=$FAIL_COUNT WARN=$WARN_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
