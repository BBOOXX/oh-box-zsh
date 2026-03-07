# components/module-loader-login.zsh
# login 阶段模块加载器：按名字从 modules/ 目录加载

zsh_source_optional "$ZSH_COMPONENT_DIR/module-loader-common.zsh"

zsh_load_login_modules() {
  local module_name

  for module_name in "${ZSH_LOGIN_MODULES[@]}"; do
    zsh_load_named_module "$module_name"
  done
}

zsh_load_login_modules
