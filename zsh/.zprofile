# .zprofile 只负责声明当前是 login 阶段, 然后把控制权交给统一入口 init.zsh.
#
# 为什么不在这里直接写 login 逻辑.
# 1. 这样 login 和 interactive 都能共用同一个 bootstrap 入口.
# 2. 阶段差异由 ZSH_INIT_STAGE 表达, 而不是靠重复代码表达.
# 3. 后续调试时, 只需要看 init.zsh 和 stage/* 两层.
export ZSH_INIT_STAGE="login"

# 统一入口.
# 所有真正的框架初始化都在 init.zsh 内部完成.
source "$ZDOTDIR/init.zsh"

# 清理阶段变量, 避免把框架内部状态继续暴露给用户交互环境.
unset ZSH_INIT_STAGE
