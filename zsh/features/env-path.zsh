# features/env-path.zsh
# 轻量 PATH 基础层.
#
# 这个 feature 的目标非常克制.
# 1. 只做安全的 PATH 拼接.
# 2. 不调用重命令.
# 3. 不做复杂自动探测.
#
# 这层通常适合放到 login 阶段.
# 因为 PATH 是最基础的环境准备之一.

# 用户级常见目录优先.
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

# 按平台补一些常见系统路径.
# 这里故意只处理少量高价值目录, 不去做大而全的猜测.
if [[ "${ZSH_IS_MACOS:-0}" -eq 1 ]]; then
  path_append "/opt/homebrew/bin"
  path_append "/opt/homebrew/sbin"
  path_append "/usr/local/bin"
  path_append "/usr/local/sbin"
elif [[ "${ZSH_IS_LINUX:-0}" -eq 1 ]]; then
  path_append "/usr/local/bin"
  path_append "/usr/local/sbin"
  path_append "/home/linuxbrew/.linuxbrew/bin"
  path_append "/home/linuxbrew/.linuxbrew/sbin"
fi

# 显式再做一次去重, 让 feature 自身的语义完整.
path_dedup
