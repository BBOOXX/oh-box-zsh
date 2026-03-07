# components/completion.zsh
# 补全系统初始化 把 compdump 放到缓存目录 避免污染配置目录

# 目录预创建 保证 compinit -d 写入路径可用
zsh_ensure_dir "$ZSH_CACHE_DIR/compdump"

# compdump 文件名包含平台与 zsh 版本 避免跨平台 跨版本互相污染
local zver="${ZSH_VERSION//./_}"
typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/compdump/zcompdump-${ZSH_OS}-${ZSH_ARCH}-${zver}"

# compinit 只在功能开关开启时触发
# 这样默认路径保持轻量 需要补全时再启用
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"
