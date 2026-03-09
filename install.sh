#!/usr/bin/env bash
set -euo pipefail
# ^ 开启 Bash 严格模式
#   -e 表示只要有命令失败就尽早退出
#   -u 表示未定义变量直接报错
#   pipefail 表示管道中任一环节失败都视为失败

MODE="link"
# ^ 安装模式
#   默认使用 link, 因为对 git 管理的配置仓库更友好
#   另外也支持 copy
#   适合不想让目标目录和仓库保持实时联动的场景

FORCE=0
# ^ 是否允许强制覆盖现有目标
#   0 表示默认不强制
#   1 表示如果目标已存在, 则先备份再替换

backup_path() {
# ^ 备份已有目标
#   如果路径存在, 就重命名为带时间戳的备份文件或备份目录
  local target="$1"
  local ts
  local backup

  if [[ -e "$target" || -L "$target" ]]; then
    ts="$(date +%Y%m%d_%H%M%S)"
    backup="${target}.backup.${ts}"
    printf 'Backup: %s -> %s\n' "$target" "$backup"
    mv "$target" "$backup"
  fi
}

ensure_parent_dir() {
# ^ 确保某个目标路径的父目录存在
  mkdir -p "$(dirname "$1")"
}

same_symlink_target() {
# ^ 判断一个符号链接是否已经指向期望的源路径
#   这用于 link 模式的幂等判定
  local path="$1"
  local expected="$2"

  [[ -L "$path" ]] || return 1
  [[ "$(readlink "$path" 2>/dev/null)" == "$expected" ]]
}

same_file_content() {
# ^ 判断两个真实普通文件内容是否一致
#   这用于 copy 模式下 ~/.zshenv 的幂等判定
#   注意这里显式把符号链接排除在外
#   否则从 link 模式切到 copy 模式时, 会被误判成"已经同步", 结果保留下来的仍然是链接
  local a="$1"
  local b="$2"

  [[ -f "$a" && ! -L "$a" && -f "$b" && ! -L "$b" ]] || return 1
  cmp -s "$a" "$b"
}

same_dir_content() {
# ^ 判断两个目录的内容是否一致
#   copy 模式如果只比较项目标识文件, 源目录更新后会误判成"已经同步"
#   这里直接比较目录内容, 让重复安装在源码变更后也能正确刷新目标副本
#   同时也要求目标必须是真实目录而不是符号链接
#   这样从 link 模式切到 copy 模式时, --force 才会真正把链接替换成副本
  local src="$1"
  local dst="$2"

  [[ -d "$src" && ! -L "$src" && -d "$dst" && ! -L "$dst" ]] || return 1
  diff -qr "$src" "$dst" >/dev/null 2>&1
}

install_link() {
# ^ 以符号链接方式安装单个目标
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  # 如果目标已经是正确的符号链接, 直接视为成功
  if same_symlink_target "$dst" "$src"; then
    printf 'OK: %s already linked to %s\n' "$dst" "$src"
    return 0
  fi

  # 如果目标已存在但不是我们想要的状态
  if [[ -e "$dst" || -L "$dst" ]]; then
    if (( FORCE )); then
      backup_path "$dst"
    else
      printf 'Conflict: %s already exists. Use --force to replace.\n' "$dst" >&2
      return 1
    fi
  fi

  ln -s "$src" "$dst"
  printf 'Link: %s -> %s\n' "$dst" "$src"
}

install_copy_file() {
# ^ 以复制方式安装普通文件
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  if same_file_content "$src" "$dst"; then
    printf 'OK: %s already matches source\n' "$dst"
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    if (( FORCE )); then
      backup_path "$dst"
    else
      printf 'Conflict: %s already exists. Use --force to replace.\n' "$dst" >&2
      return 1
    fi
  fi

  cp "$src" "$dst"
  printf 'Copy: %s -> %s\n' "$src" "$dst"
}

install_copy_dir() {
# ^ 以复制方式安装目录
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  if same_dir_content "$src" "$dst"; then
    printf 'OK: %s already matches source directory\n' "$dst"
    return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    if (( FORCE )); then
      backup_path "$dst"
    else
      printf 'Conflict: %s already exists. Use --force to replace.\n' "$dst" >&2
      return 1
    fi
  fi

  cp -R "$src" "$dst"
  printf 'Copy: %s -> %s\n' "$src" "$dst"
}

main() {
# ^ 安装脚本主入口
  local arg
  local project_dir
  local src_zshenv
  local src_zsh_dir
  local dst_zshenv
  local dst_config_dir
  local dst_zsh_dir

  MODE="link"
  FORCE=0

  for arg in "$@"; do
  # ^ 逐个解析命令行参数
  #   "$@" 会保留原始参数边界
    case "$arg" in
      --link|-l)
        MODE="link"
        ;;
      --copy|-c)
        MODE="copy"
        ;;
      --force|-f)
        FORCE=1
        ;;
      *)
        printf 'Unknown option: %s\n' "$arg" >&2
        printf 'Usage: %s [--link|--copy] [--force]\n' "${BASH_SOURCE[0]}" >&2
        return 1
        ;;
    esac
  done

  project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # ^ 计算仓库根目录的绝对路径
  #   使用 BASH_SOURCE[0] 比单纯依赖 $0 更稳
  #   这样无论从哪里调用 install.sh 都能正确找到仓库根

  src_zshenv="$project_dir/zshenv"
  # ^ 仓库内的 zshenv 源文件

  src_zsh_dir="$project_dir/zsh"
  # ^ 仓库内真正的 zsh 配置目录
  #   注意仓库根不是 ZDOTDIR, zsh/ 才是

  dst_zshenv="$HOME/.zshenv"
  # ^ 安装目标 1. 用户家目录下的 ~/.zshenv

  dst_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  # ^ 安装目标 2 的父目录
  #   默认优先使用 XDG_CONFIG_HOME
  #   未设置时回落到 ~/.config

  dst_zsh_dir="$dst_config_dir/zsh"
  # ^ 安装目标 2. 真正的 ZDOTDIR

  # 基础前置检查
  if [[ ! -f "$src_zshenv" ]]; then
    printf 'Missing source file: %s\n' "$src_zshenv" >&2
    return 1
  fi

  if [[ ! -d "$src_zsh_dir" ]]; then
    printf 'Missing source dir: %s\n' "$src_zsh_dir" >&2
    return 1
  fi

  # 先准备配置根目录
  mkdir -p "$dst_config_dir"

  # 根据模式执行安装
  case "$MODE" in
    link)
      install_link "$src_zshenv" "$dst_zshenv"
      install_link "$src_zsh_dir" "$dst_zsh_dir"
      ;;
    copy)
      install_copy_file "$src_zshenv" "$dst_zshenv"
      install_copy_dir "$src_zsh_dir" "$dst_zsh_dir"
      ;;
  esac

  printf 'Done. ZDOTDIR will be: %s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
