# features/homebrew.zsh
# Homebrew 接入层.
#
# 这个 feature 的目标是解决一个很常见的问题.
# - 你希望在 shell 里拿到 brew shellenv 的结果.
# - 但你又不想每次启动都无条件执行一次 brew shellenv.
#
# 所以这里的策略是.
# 1. 先找到 brew 可执行文件.
# 2. 找到了才继续.
# 3. 如果缓存层可用, 优先用 zcache_source_cmd 缓存 brew shellenv 输出.
# 4. 缓存层不可用时, 再直接 eval brew shellenv.
#
# 通常建议把 homebrew 放到 login feature 列表中.

# 全局开关.
(( ${ZSH_HOMEBREW_ENABLE:-1} )) || return 0

# 先准备一个空变量, 稍后用它保存 brew 的绝对路径.
local brew_bin=""

# 准备候选路径列表.
# 这里覆盖 arm64 macOS, Intel macOS, Linuxbrew 三类常见安装位置.
local -a candidates
candidates=()

# 如果用户显式设置了 HOMEBREW_PREFIX, 就先尝试它.
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  candidates+=("${HOMEBREW_PREFIX}/bin/brew")
fi

candidates+=(
  "/opt/homebrew/bin/brew"
  "/usr/local/bin/brew"
  "/home/linuxbrew/.linuxbrew/bin/brew"
)

# 优先使用当前 PATH 中已经可见的 brew.
if zsh_has_cmd brew; then
  brew_bin="${commands[brew]}"
else
  # 否则再遍历候选路径.
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      brew_bin="$candidate"
      break
    fi
  done
fi

# 没找到 brew 就静默返回.
# 这是 feature 设计里很重要的一条.
# 缺失某个可选工具时, 不应该把整个 shell 搞挂.
[[ -n "$brew_bin" ]] || return 0

# 如果缓存层可用, 优先走缓存.
if typeset -f zcache_source_cmd >/dev/null 2>&1; then
  zcache_source_cmd "homebrew-shellenv" "${ZSH_HOMEBREW_SHELLENV_TTL:-86400}" -- "$brew_bin" shellenv
else
  # 没有缓存层时才直接执行.
  eval "$("$brew_bin" shellenv)"
fi
