# 用户个人脚本层

export PYTHONBREAKPOINT="pudb.set_trace"
export COLORTERM="truecolor"

alias ggpull='git pull'

if (( ${ZSH_IS_LINUX:-0} )); then
  alias ls='ls -p --color=tty --time-style="+%F %T"'
  alias l='ls -lah'
  alias la='ls -lAh'
  alias ll='ls -lh'
fi

if (( ${ZSH_IS_MACOS:-0} )); then
  alias ls='ls -Gp -D "%F %T" '
  alias l='ls -lah'
  alias la='ls -lAh'
  alias ll='ls -lh'
  alias yoink='open -a Yoink'
  alias tree='tree -N '
  alias ytd='yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --output "[%(id)s].%(ext)s" --cookies-from-browser chrome '
  alias surge='/Applications/Surge.app/Contents/Applications/surge-cli'
  alias ffmpeg='ffmpeg -hide_banner '
  alias ffprobe='ffprobe -hide_banner '
fi


# SSH 会话需要把代理回指到客户端
# 本地 shell 则直接走 127.0.0.1
setproxy() {
  local proxy_host="127.0.0.1"
  local ssh_peer
  local http_proxy_url
  local all_proxy_url

  if (( ${ZSH_IS_SSH:-0} )); then
    ssh_peer="${SSH_CLIENT:-${SSH_CONNECTION:-}}"

    if [[ -n "$ssh_peer" ]]; then
      proxy_host="${ssh_peer%% *}"
    fi
  fi

  http_proxy_url="http://${proxy_host}:6152"
  all_proxy_url="socks5://${proxy_host}:6153"

  export https_proxy="$http_proxy_url"
  export HTTPS_PROXY="$http_proxy_url"
  export http_proxy="$http_proxy_url"
  export HTTP_PROXY="$http_proxy_url"
  export ALL_PROXY="$all_proxy_url"
}

unsetproxy() {
    unset ALL_PROXY
    unset https_proxy
    unset http_proxy
}

# 从 ~/.ssh/config 中抽取显式 Host, 让 ssh/scp 都能补全
_zsh_local_complete_ssh_hosts() {
  local config_file="$HOME/.ssh/config"
  local line
  local host_pattern
  local -a words
  local -aU ssh_hosts

  reply=()
  [[ -r "$config_file" ]] || return 0

  while IFS= read -r line; do
    words=(${(z)line})
    (( ${#words[@]} >= 2 )) || continue
    [[ "${words[1]:l}" == "host" ]] || continue

    for host_pattern in "${words[@][2,-1]}"; do
      [[ "$host_pattern" == \#* ]] && break
      [[ "$host_pattern" == *[\*\?]* ]] && continue
      ssh_hosts+=("$host_pattern")
    done
  done < "$config_file"

  reply=("${ssh_hosts[@]}")
}

zstyle -e ':completion:*:*:*:hosts' hosts '_zsh_local_complete_ssh_hosts'
