# features/keybinds.zsh
# 常用按键与编辑模式.
#
# 这层只做几件基础事情.
# 1. 根据 ZSH_KEYMAP 选择 emacs 或 vi.
# 2. 打开 Ctrl-X Ctrl-E 的外部编辑能力.
#
# 不在这里塞大量个人快捷键.
# 个人 bindkey 更适合写到 user/local.zsh.

# 选择编辑模式.
if [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]]; then
  bindkey -v
else
  bindkey -e
fi

# Ctrl-X Ctrl-E 在外部编辑器里编辑当前命令行.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
