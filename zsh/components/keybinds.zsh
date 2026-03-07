# components/keybinds.zsh
# 按键行为入口 编辑模式 + 常用快捷键

# 根据 ZSH_KEYMAP 选择编辑模式
# 说明 默认 emacs 设置为 vi 时切换到 vi keymap
if [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]]; then
  bindkey -v
else
  bindkey -e
fi

# Ctrl-X Ctrl-E 在 $EDITOR 中编辑当前命令行
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
