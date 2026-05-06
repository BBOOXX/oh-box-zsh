# .zshrc 只负责声明当前是 interactive 阶段 然后把控制权交给统一入口 init.zsh
#
# 入口文件不承载阶段逻辑
# login 和 interactive 共用同一套 bootstrap
# 阶段差异放到 stage/login.zsh 和 stage/interactive.zsh
export ZSH_INIT_STAGE="interactive"

# 统一入口
source "$ZDOTDIR/init.zsh"

# 清理阶段变量
unset ZSH_INIT_STAGE
