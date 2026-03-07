# interactive 阶段调度器.
#
# 执行顺序固定如下.
# 1. 按顺序加载 ZSH_INTERACTIVE_FEATURES.
# 2. 如果启用了脚本层, 再加载 user/local.zsh.
#
# 这么排的原因.
# - feature 是框架定义的能力.
# - local 是用户最后一层自由覆盖.
# - 把 local 放最后, alias, function, bindkey 才最稳定.
typeset -g ZSH_CURRENT_STAGE="interactive"

# 先加载 interactive feature.
zsh_load_feature_list "${ZSH_INTERACTIVE_FEATURES[@]}"

# 再加载个人脚本层.
if (( ${ZSH_ENABLE_LOCAL:-1} )) && zsh_is_interactive; then
  zsh_source_optional "$ZSH_USER_DIR/local.zsh"
fi
