# login 阶段调度器

# 按顺序加载 ZSH_LOGIN_FEATURES

# 新增或删除 login 功能时只改 config 数组
typeset -g ZSH_CURRENT_STAGE="login"

# login feature 列表由 stage 自己兜底
# 默认顺序和消费点放在同一层
if (( ! ${+ZSH_LOGIN_FEATURES} )); then
  typeset -ga ZSH_LOGIN_FEATURES
  ZSH_LOGIN_FEATURES=(env-path)
fi

zsh_load_feature_list "${ZSH_LOGIN_FEATURES[@]}"
