# components/module-loader-common.zsh
# 模块公共加载函数：按名字从 modules/ 目录加载

zsh_load_named_module() {
  local module_name="$1"
  local module_file

  [[ -n "$module_name" ]] || return 0

  module_file="$ZSH_MODULE_DIR/${module_name}.zsh"
  if [[ -r "$module_file" ]]; then
    zsh_log_debug "load module: $module_name"
    source "$module_file"
    return 0
  fi

  zsh_log_debug "module not found: $module_file"
  return 0
}
