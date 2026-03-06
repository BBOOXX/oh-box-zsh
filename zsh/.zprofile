# 告诉 init.zsh 当前处于 login 阶段
export ZSH_INIT_STAGE="login"

# 统一入口
source "$ZDOTDIR/init.zsh"

# 清理阶段变量 避免污染用户环境
unset ZSH_INIT_STAGE
