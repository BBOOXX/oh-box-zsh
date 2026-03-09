# login 阶段调度器

# 这个文件只做一件事
# - 按顺序加载 ZSH_LOGIN_FEATURES

# 它不直接写 feature 细节
# 这样 login 阶段新增或删除功能时, 只需要改 config 里的数组, 而不是改 stage 文件本身
typeset -g ZSH_CURRENT_STAGE="login"

# login feature 列表由 stage 自己兜底
# 这样默认顺序和消费点放在同一层, 不需要单独维护一个集中 defaults 文件
if (( ! ${+ZSH_LOGIN_FEATURES} )); then
  typeset -ga ZSH_LOGIN_FEATURES
  ZSH_LOGIN_FEATURES=(env-path)
fi

zsh_load_feature_list "${ZSH_LOGIN_FEATURES[@]}"
