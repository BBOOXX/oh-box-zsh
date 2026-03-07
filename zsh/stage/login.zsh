# login 阶段调度器.
#
# 这个文件只做一件事.
# - 按顺序加载 ZSH_LOGIN_FEATURES.
#
# 它不直接写 feature 细节.
# 这样 login 阶段新增或删除功能时, 只需要改 config 里的数组, 而不是改 stage 文件本身.
typeset -g ZSH_CURRENT_STAGE="login"
zsh_load_feature_list "${ZSH_LOGIN_FEATURES[@]}"
