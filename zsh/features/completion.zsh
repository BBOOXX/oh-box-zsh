# features/completion.zsh
# 补全系统初始化.
#
# 这是最常见也最容易带来一点启动成本的 feature 之一.
# 所以这里把副作用控制得尽量清楚.
# 1. compdump 放到缓存目录.
# 2. 文件名包含平台和 zsh 版本, 避免跨环境污染.
# 3. 只在 interactive 阶段启用比较合理.
#
# 如果你更在意极限启动速度, 可以把 completion 从 ZSH_INTERACTIVE_FEATURES 里移除.

# 确保 compdump 目录存在.
zsh_ensure_dir "$ZSH_CACHE_DIR/compdump"

# compdump 文件名包含环境特征.
local zver="${ZSH_VERSION//./_}"
typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/compdump/zcompdump-${ZSH_OS}-${ZSH_ARCH}-${zver}"

# 加载并初始化补全系统.
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"
