# themes/basic-git.zsh
# 一个仍然很轻量, 但会显示 git 分支信息的主题.
#
# 这里使用 zsh 自带的 vcs_info, 不依赖第三方 prompt 框架.
# 这样比大型主题系统轻得多, 也更可控.

autoload -Uz vcs_info

# 只启用 git.
zstyle ':vcs_info:*' enable git

# 正常状态显示分支名.
zstyle ':vcs_info:git:*' formats '%b'

# 操作中状态显示分支和 action.
zstyle ':vcs_info:git:*' actionformats '%b|%a'

# 避免重复把 vcs_info 塞进 precmd_functions.
if (( ${precmd_functions[(Ie)vcs_info]} == 0 )); then
  precmd_functions+=(vcs_info)
fi

PROMPT='%n@%m %1~ %# '
RPROMPT='${vcs_info_msg_0_}'
