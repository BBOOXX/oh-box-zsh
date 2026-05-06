#!/usr/bin/env bash

# Bash 测试共享 helper
# 通用输出 捕获 断言函数

: "${PASS_COUNT:=0}"
: "${FAIL_COUNT:=0}"
: "${WARN_COUNT:=0}"

# 输出阶段标题
log() {
  printf '\n[%s] %s\n' "$1" "$2"
}

# 记录成功断言
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$*"
}

# 记录失败断言
fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*"
}

# 记录警告
warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$*"
}

# 执行命令并同时捕获标准输出和标准错误
# 第一个参数是变量名 用来接收输出内容
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

# 判断路径是否存在 包括坏掉的符号链接
assert_exists() {
  local path="$1"
  local msg="$2"

  if [ -e "$path" ] || [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (missing: $path)"
  fi
}

# 判断路径缺失且非符号链接
assert_not_exists() {
  local path="$1"
  local msg="$2"

  if [ -e "$path" ] || [ -L "$path" ]; then
    fail "$msg (unexpected path: $path)"
  else
    pass "$msg"
  fi
}

# 判断命令返回真值
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

# 判断命令返回假值
assert_false() {
  local msg="$1"
  shift

  if "$@"; then
    fail "$msg (unexpected success)"
  else
    pass "$msg"
  fi
}

# 断言返回码
assert_status() {
  local expected="$1"
  local msg="$2"
  shift 2

  "$@"
  local rc=$?

  if [ "$rc" -eq "$expected" ]; then
    pass "$msg"
  else
    fail "$msg (got rc=$rc | expected rc=$expected)"
  fi
}

# 判断路径是否是普通文件
assert_file() {
  local path="$1"
  local msg="$2"

  if [ -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a regular file: $path)"
  fi
}

# 判断路径是否是目录
assert_dir() {
  local path="$1"
  local msg="$2"

  if [ -d "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a directory: $path)"
  fi
}

# 判断路径是否是非符号链接的真实文件
assert_real_file() {
  local path="$1"
  local msg="$2"

  if [ -f "$path" ] && [ ! -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a regular file: $path)"
  fi
}

# 判断路径是否是非符号链接的真实目录
assert_real_dir() {
  local path="$1"
  local msg="$2"

  if [ -d "$path" ] && [ ! -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a real directory: $path)"
  fi
}

# 判断路径是否是符号链接
assert_symlink() {
  local path="$1"
  local msg="$2"

  if [ -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a symlink: $path)"
  fi
}

# 做字符串相等断言
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

# 判断一段文本是否包含某个子串
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

# 判断一段文本不包含某个子串
assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"

  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    fail "$msg (unexpected: $needle)"
  else
    pass "$msg"
  fi
}

# 打印一段输出块 方便排查失败原因
print_block() {
  local title="$1"
  local body="$2"

  printf '\n----- %s -----\n%s\n' "$title" "$body"
}

# 读取符号链接目标
get_symlink_target() {
  local path="$1"

  readlink "$path" 2>/dev/null || true
}
