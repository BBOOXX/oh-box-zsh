#!/usr/bin/env bash
set -u
set -o pipefail
shopt -s nullglob

PASS_COUNT=0
FAIL_COUNT=0

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

assert_file() {
  local path="$1"
  local msg="$2"

  if [ -f "$path" ] && [ ! -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a regular file: $path)"
  fi
}

assert_dir() {
  local path="$1"
  local msg="$2"

  if [ -d "$path" ] && [ ! -L "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not a real directory: $path)"
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

REPO_ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oh-box-zsh-install.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

source "$REPO_ROOT/install.sh"
# install.sh 在顶层开启了 -e.
# 这里恢复测试脚本自己的策略, 允许继续收集后续断言结果.
set +e

log STEP "helper functions"

ensure_parent_dir "$TMPROOT/parent/a/b/file"
assert_dir "$TMPROOT/parent/a/b" "ensure_parent_dir creates parent directories"

printf 'backup-source\n' > "$TMPROOT/original"
backup_path "$TMPROOT/original"
assert_false "backup_path removes original path" test -e "$TMPROOT/original"
BACKUP_GLOB=("$TMPROOT"/original.backup.*)
assert_eq "${#BACKUP_GLOB[@]}" "1" "backup_path creates exactly one backup target"
assert_file "${BACKUP_GLOB[0]}" "backup_path creates readable backup file"

printf 'source-file\n' > "$TMPROOT/source-file"
ln -s "$TMPROOT/source-file" "$TMPROOT/source-link"
assert_true "same_symlink_target matches identical symlink target" same_symlink_target "$TMPROOT/source-link" "$TMPROOT/source-file"
assert_false "same_symlink_target rejects different target" same_symlink_target "$TMPROOT/source-link" "$TMPROOT/other-file"

printf 'same\n' > "$TMPROOT/file-a"
printf 'same\n' > "$TMPROOT/file-b"
assert_true "same_file_content accepts identical regular files" same_file_content "$TMPROOT/file-a" "$TMPROOT/file-b"
ln -s "$TMPROOT/file-a" "$TMPROOT/file-link"
assert_false "same_file_content rejects symlink destination in copy mode" same_file_content "$TMPROOT/file-a" "$TMPROOT/file-link"

mkdir -p "$TMPROOT/dir-a" "$TMPROOT/dir-b"
printf 'x\n' > "$TMPROOT/dir-a/one"
printf 'x\n' > "$TMPROOT/dir-b/one"
assert_true "same_dir_content accepts identical real directories" same_dir_content "$TMPROOT/dir-a" "$TMPROOT/dir-b"
ln -s "$TMPROOT/dir-a" "$TMPROOT/dir-link"
assert_false "same_dir_content rejects symlink destination in copy mode" same_dir_content "$TMPROOT/dir-a" "$TMPROOT/dir-link"

log STEP "install_link"

FORCE=0
assert_status 0 "install_link creates symlink for file target" install_link "$TMPROOT/source-file" "$TMPROOT/link-target/file"
assert_symlink "$TMPROOT/link-target/file" "install_link result is a symlink"
assert_status 0 "install_link is idempotent on matching symlink" install_link "$TMPROOT/source-file" "$TMPROOT/link-target/file"

printf 'conflict\n' > "$TMPROOT/link-conflict"
assert_status 1 "install_link rejects conflicts without force" install_link "$TMPROOT/source-file" "$TMPROOT/link-conflict"

log STEP "install_copy_file"

FORCE=0
printf 'copy-src\n' > "$TMPROOT/copy-source"
assert_status 0 "install_copy_file copies missing target" install_copy_file "$TMPROOT/copy-source" "$TMPROOT/copy-target/file"
assert_file "$TMPROOT/copy-target/file" "install_copy_file result is a regular file"
COPY_FILE_CONTENT="$(<"$TMPROOT/copy-target/file")"
assert_eq "$COPY_FILE_CONTENT" "copy-src" "install_copy_file preserves file content"
assert_status 0 "install_copy_file is idempotent on matching regular file" install_copy_file "$TMPROOT/copy-source" "$TMPROOT/copy-target/file"

rm -f "$TMPROOT/copy-target/file"
ln -s "$TMPROOT/copy-source" "$TMPROOT/copy-target/file"
FORCE=1
assert_status 0 "install_copy_file replaces link target with real file in copy mode" install_copy_file "$TMPROOT/copy-source" "$TMPROOT/copy-target/file"
assert_file "$TMPROOT/copy-target/file" "install_copy_file converts symlink to regular file"

log STEP "install_copy_dir"

mkdir -p "$TMPROOT/copy-dir-source/sub"
printf 'dir-content\n' > "$TMPROOT/copy-dir-source/sub/item"
FORCE=0
assert_status 0 "install_copy_dir copies missing directory target" install_copy_dir "$TMPROOT/copy-dir-source" "$TMPROOT/copy-dir-target"
assert_dir "$TMPROOT/copy-dir-target" "install_copy_dir result is a real directory"
DIR_FILE_CONTENT="$(<"$TMPROOT/copy-dir-target/sub/item")"
assert_eq "$DIR_FILE_CONTENT" "dir-content" "install_copy_dir preserves directory contents"
assert_status 0 "install_copy_dir is idempotent on matching real directory" install_copy_dir "$TMPROOT/copy-dir-source" "$TMPROOT/copy-dir-target"

rm -rf "$TMPROOT/copy-dir-target"
ln -s "$TMPROOT/copy-dir-source" "$TMPROOT/copy-dir-target"
FORCE=1
assert_status 0 "install_copy_dir replaces link target with real directory in copy mode" install_copy_dir "$TMPROOT/copy-dir-source" "$TMPROOT/copy-dir-target"
assert_dir "$TMPROOT/copy-dir-target" "install_copy_dir converts symlink to real directory"

log RESULT "PASS=$PASS_COUNT FAIL=$FAIL_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
