# features/rustup.zsh
# Homebrew rustup 是 keg-only, 需要显式暴露 rustc/cargo proxy

if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  path_prepend "$HOMEBREW_PREFIX/opt/rustup/bin"
fi
