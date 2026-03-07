# 这个文件会被安装到 ~/.zshenv.
# 它是 zsh 启动时最早读取的入口之一.
#
# 这里严格只做一件事, 就是设置 ZDOTDIR.
# 这样做的原因很明确.
# 1. ~/.zshenv 很早就会被加载.
# 2. 如果这里放重逻辑, 每个 zsh 进程都会付出代价.
# 3. 把真正的配置目录指向 ~/.config/zsh 或 $XDG_CONFIG_HOME/zsh, 可以让仓库根目录和运行目录职责分离.
#
# 注意.
# - 不要在这里写 PATH 拼接.
# - 不要在这里调用 brew, pyenv, compinit 等外部逻辑.
# - 不要在这里 source 其他复杂文件.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
