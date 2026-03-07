# features/history.zsh
# 历史记录策略.
#
# 这个 feature 不依赖第三方框架.
# 只用 zsh 自带的历史能力, 但把常用选项一次配好.
#
# 设计目标.
# 1. 历史文件放到缓存目录, 不污染配置目录.
# 2. 多窗口共享历史.
# 3. 尽量减少重复和脏数据.
# 4. 并发写入时尽量稳一些.

# 先确保缓存目录存在.
zsh_ensure_dir "$ZSH_CACHE_DIR"

# 配置历史文件位置和容量.
HISTFILE="$ZSH_CACHE_DIR/history"
HISTSIZE=50000
SAVEHIST=50000
export HISTFILE

# 退出时追加写入, 避免覆盖其他会话的历史.
setopt APPEND_HISTORY

# 多个会话共享历史.
setopt SHARE_HISTORY

# 忽略连续重复命令.
setopt HIST_IGNORE_DUPS

# 以空格开头的命令不写入历史.
setopt HIST_IGNORE_SPACE

# 历史超限时优先淘汰重复项.
setopt HIST_EXPIRE_DUPS_FIRST

# 使用文件锁降低并发写入冲突.
setopt HIST_FCNTL_LOCK

# 压缩命令中的多余空白.
setopt HIST_REDUCE_BLANKS
