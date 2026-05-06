# 安装到 ~/.zshenv
# 最早期启动入口
# 设置 ZDOTDIR
# 让 Debian/Ubuntu 全局 zshrc 跳过默认 compinit
#   否则 link 模式下会把 .zcompdump 写进仓库里的 zsh/ 目录

export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export skip_global_compinit=1
