#!/usr/bin/env bash
set -euo pipefail
# ^ 开启 Bash 严格模式.
#   -e 表示只要有命令失败就尽早退出.
#   -u 表示未定义变量直接报错.
#   pipefail 表示管道中任一环节失败都视为失败.
#
# 为什么安装脚本要这么保守.
# 因为安装脚本会改动用户的 ~/.zshenv 和 ~/.config/zsh.
# 这类脚本宁可早失败, 也不要带着错误状态继续执行.

MODE="link"
# ^ 安装模式.
#   默认使用 link, 因为对 git 管理的配置仓库更友好.
#   link 的特点.
#   1. 仓库改动立刻生效.
#   2. 不会出现复制副本和仓库本体长期漂移的问题.
#
#   另外也支持 copy.
#   适合不想让目标目录和仓库保持实时联动的场景.

FORCE=0
# ^ 是否允许强制覆盖现有目标.
#   0 表示默认不强制.
#   1 表示如果目标已存在, 则先备份再替换.

for arg in "$@"; do
# ^ 逐个解析命令行参数.
#   "$@" 会保留原始参数边界, 这是 shell 里处理参数最稳妥的方式.
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
      printf 'Usage: %s [--link|--copy] [--force]\n' "$0" >&2
      exit 1
      ;;
  esac
done

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ^ 计算仓库根目录的绝对路径.
#   使用 BASH_SOURCE[0] 比单纯依赖 $0 更稳.
#   这样无论从哪里调用 install.sh, 都能正确找到仓库根.

SRC_ZSHENV="$PROJECT_DIR/zshenv"
# ^ 仓库内的 zshenv 源文件.

SRC_ZSH_DIR="$PROJECT_DIR/zsh"
# ^ 仓库内真正的 zsh 配置目录.
#   注意仓库根不是 ZDOTDIR, zsh/ 才是.

DST_ZSHENV="$HOME/.zshenv"
# ^ 安装目标 1. 用户家目录下的 ~/.zshenv.

DST_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# ^ 安装目标 2 的父目录.
#   默认优先使用 XDG_CONFIG_HOME.
#   未设置时回落到 ~/.config.

DST_ZSH_DIR="$DST_CONFIG_DIR/zsh"
# ^ 安装目标 2. 真正的 ZDOTDIR.

backup_path() {
# ^ 备份已有目标.
#   如果路径存在, 就重命名为带时间戳的备份文件或备份目录.
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
# ^ 确保某个目标路径的父目录存在.
  mkdir -p "$(dirname "$1")"
}

same_symlink_target() {
# ^ 判断一个符号链接是否已经指向期望的源路径.
#   这用于 link 模式的幂等判定.
  local path="$1"
  local expected="$2"

  [[ -L "$path" ]] || return 1
  [[ "$(readlink "$path" 2>/dev/null)" == "$expected" ]]
}

same_file_content() {
# ^ 判断两个普通文件内容是否一致.
#   这用于 copy 模式下 ~/.zshenv 的幂等判定.
  local a="$1"
  local b="$2"

  [[ -f "$a" && -f "$b" ]] || return 1
  cmp -s "$a" "$b"
}

same_project_copy() {
# ^ 粗粒度判断目标目录是否已经看起来是本项目的 copy.
#   这里不做全目录逐文件比对, 因为那样又慢又复杂.
#   这里只比较项目标识文件.
  local src="$1"
  local dst="$2"

  [[ -d "$dst" ]] || return 1
  [[ -f "$src/.oh-box-zsh-id" && -f "$dst/.oh-box-zsh-id" ]] || return 1
  cmp -s "$src/.oh-box-zsh-id" "$dst/.oh-box-zsh-id"
}

install_link() {
# ^ 以符号链接方式安装单个目标.
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  # 如果目标已经是正确的符号链接, 直接视为成功.
  if same_symlink_target "$dst" "$src"; then
    printf 'OK: %s already linked to %s\n' "$dst" "$src"
    return 0
  fi

  # 如果目标已存在但不是我们想要的状态.
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
# ^ 以复制方式安装普通文件.
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
# ^ 以复制方式安装目录.
  local src="$1"
  local dst="$2"

  ensure_parent_dir "$dst"

  if same_project_copy "$src" "$dst"; then
    printf 'OK: %s already looks like this project copy\n' "$dst"
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

# 基础前置检查.
if [[ ! -f "$SRC_ZSHENV" ]]; then
  printf 'Missing source file: %s\n' "$SRC_ZSHENV" >&2
  exit 1
fi

if [[ ! -d "$SRC_ZSH_DIR" ]]; then
  printf 'Missing source dir: %s\n' "$SRC_ZSH_DIR" >&2
  exit 1
fi

# 先准备配置根目录.
mkdir -p "$DST_CONFIG_DIR"

# 根据模式执行安装.
case "$MODE" in
  link)
    install_link "$SRC_ZSHENV" "$DST_ZSHENV"
    install_link "$SRC_ZSH_DIR" "$DST_ZSH_DIR"
    ;;
  copy)
    install_copy_file "$SRC_ZSHENV" "$DST_ZSHENV"
    install_copy_dir "$SRC_ZSH_DIR" "$DST_ZSH_DIR"
    ;;
esac

printf 'Done. ZDOTDIR will be: %s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
