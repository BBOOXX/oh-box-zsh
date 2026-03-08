# features/history.zsh
# 历史记录策略.
#
# 这个 feature 只用 zsh 自带的历史能力.
# 但会把高频有用的选项一次配好, 并暴露成明确的配置项.
#
# 设计目标.
# 1. 历史文件放到缓存目录, 不污染配置目录.
# 2. 多窗口共享历史.
# 3. 尽量减少重复和脏数据.
# 4. 并发写入时尽量稳一些.
# 5. 历史展开在执行前给你一个确认机会.

# 先确保缓存目录存在.
zsh_ensure_dir "$ZSH_CACHE_DIR"

# 配置历史文件位置和容量.
HISTFILE="$ZSH_CACHE_DIR/history"
HISTSIZE="${ZSH_HISTORY_SIZE:-50000}"
SAVEHIST="${ZSH_HISTORY_SAVE_SIZE:-50000}"
export HISTFILE

# 退出时追加写入, 避免覆盖其他会话的历史.
setopt APPEND_HISTORY

# 记录时间戳和命令耗时信息.
# 这对排查"我之前什么时候执行过某条命令"很有用.
(( ${ZSH_HISTORY_EXTENDED:-1} )) && setopt EXTENDED_HISTORY || unsetopt EXTENDED_HISTORY

# 多个会话共享历史.
(( ${ZSH_HISTORY_SHARE:-1} )) && setopt SHARE_HISTORY || unsetopt SHARE_HISTORY

# 忽略连续重复命令.
setopt HIST_IGNORE_DUPS

# 以空格开头的命令不写入历史.
setopt HIST_IGNORE_SPACE

# 历史超限时优先淘汰重复项.
setopt HIST_EXPIRE_DUPS_FIRST

# 对 history expansion 做一次"先展开, 再让你确认"的保护.
# 这能减少 ! 前缀历史展开带来的误操作.
(( ${ZSH_HISTORY_VERIFY:-1} )) && setopt HIST_VERIFY || unsetopt HIST_VERIFY

# 使用文件锁降低并发写入冲突.
setopt HIST_FCNTL_LOCK

# 压缩命令中的多余空白.
setopt HIST_REDUCE_BLANKS
