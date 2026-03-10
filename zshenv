# 这个文件会被安装到 ~/.zshenv
# 这里只做最早期的启动守卫
# - 设置 ZDOTDIR
# - 避免 Debian/Ubuntu 的全局 zshrc 抢先运行默认 compinit
#   否则 link 模式下会把 .zcompdump 写进仓库里的 zsh/ 目录

export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
export skip_global_compinit=1
