# components/history.zsh
# 历史记录策略

# 先确保缓存目录存在 避免 HISTFILE 指向不存在目录导致写入失败
zsh_ensure_dir "$ZSH_CACHE_DIR"

# 历史文件落在缓存目录 而不是 ZDOTDIR
# - 配置与运行时数据分离
# - 更利于清理与迁移
HISTFILE="$ZSH_CACHE_DIR/history"
HISTSIZE=50000
SAVEHIST=50000
export HISTFILE

# APPEND_HISTORY 退出时追加写入 避免覆盖
setopt APPEND_HISTORY
# SHARE_HISTORY 多窗口共享历史 交互更连贯
setopt SHARE_HISTORY
# HIST_IGNORE_DUPS 连续重复命令不重复入历史
setopt HIST_IGNORE_DUPS
# HIST_IGNORE_SPACE 前置空格命令不入历史 临时敏感命令有用
setopt HIST_IGNORE_SPACE
# HIST_EXPIRE_DUPS_FIRST 超限时优先淘汰重复项
setopt HIST_EXPIRE_DUPS_FIRST
# HIST_FCNTL_LOCK 并发会话写入时使用文件锁 降低冲突风险
setopt HIST_FCNTL_LOCK
# HIST_REDUCE_BLANKS 压缩多余空白 历史更整洁
setopt HIST_REDUCE_BLANKS
