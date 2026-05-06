# features/z.zsh
# 目录跳转索引

# 迁入 OMZ z 插件的核心跳转体验
# 1 记录你 cd 过的目录
# 2 用最近访问时间做主排序 访问次数只做次级打分
# 3 提供 z 命令做快速跳转
# 4 把状态放到缓存目录 不污染声明层和脚本层

if [[ -n "${__zsh_feature_z_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_feature_z_loaded=1

typeset -g ZSH_Z_DATA_FILE="${ZSH_Z_DATA_FILE:-$ZSH_CACHE_DIR/z/data}"
typeset -gi ZSH_Z_MAX_ENTRIES="${ZSH_Z_MAX_ENTRIES:-1000}"
typeset -gi ZSH_Z_LIST_MAX="${ZSH_Z_LIST_MAX:-20}"
typeset -gi ZSH_Z_CASE_INSENSITIVE="${ZSH_Z_CASE_INSENSITIVE:-1}"

typeset -gA __zsh_z_scores
typeset -gA __zsh_z_times
typeset -g __zsh_z_db_mtime="${__zsh_z_db_mtime:-}"
typeset -gi __zsh_z_db_loaded="${__zsh_z_db_loaded:-0}"
__zsh_z_scores=()
__zsh_z_times=()

# 校验路径文本是否适合进入索引
# 字符串层面限制格式 避免热路径文件系统探测
__zsh_z_is_valid_path_text() {
  emulate -L zsh

  local dir="$1"

  [[ -n "$dir" ]] || return 1
  [[ "$dir" == /* ]] || return 1
  [[ "$dir" == *$'\n'* ]] && return 1
  [[ "$dir" == *$'\t'* ]] && return 1
  return 0
}

# 过滤不写入索引的路径
# 跳过不存在目录 相对路径和带换行 / Tab 的路径
__zsh_z_should_track_path() {
  emulate -L zsh

  local dir="$1"

  __zsh_z_is_valid_path_text "$dir" || return 1
  [[ -d "$dir" ]] || return 1
  return 0
}

# 清空内存态索引
# 首次加载和按需重载共用同一条路径
__zsh_z_reset_db() {
  emulate -L zsh

  __zsh_z_scores=()
  __zsh_z_times=()
}

# 从缓存文件读回目录索引
# 只接受三列纯文本格式 visits<TAB>last_access<TAB>path
__zsh_z_load_db() {
  emulate -L zsh

  local file="$ZSH_Z_DATA_FILE"
  local visits
  local last_access
  local dir

  [[ -r "$file" ]] || return 0

  while IFS=$'\t' read -r visits last_access dir; do
    [[ "$visits" == <-> ]] || continue
    [[ "$last_access" == <-> ]] || continue
    __zsh_z_should_track_path "$dir" || continue

    __zsh_z_scores[$dir]="$visits"
    __zsh_z_times[$dir]="$last_access"
  done < "$file"

  __zsh_z_prune_db
}

# 确保当前 shell 里的索引已经就绪
# 只在第一次使用或数据文件 mtime 变化时才从磁盘重读
__zsh_z_ensure_db_loaded() {
  emulate -L zsh

  local file="$ZSH_Z_DATA_FILE"
  local mtime=""

  if zsh_file_mtime "$file"; then
    mtime="$REPLY"
  fi

  if (( __zsh_z_db_loaded )) && [[ "$mtime" == "${__zsh_z_db_mtime:-}" ]]; then
    return 0
  fi

  __zsh_z_reset_db
  [[ -n "$mtime" ]] && __zsh_z_load_db

  __zsh_z_db_loaded=1
  __zsh_z_db_mtime="$mtime"
}

# 把目录索引刷回缓存文件
# 只有在真正发生目录访问时才落盘 避免 shell 启动时白白做一次 I/O
__zsh_z_save_db() {
  emulate -L zsh

  local file="$ZSH_Z_DATA_FILE"
  local tmp_file="${file}.tmp.$$"
  local dir
  local rc

  zsh_ensure_dir "${file:h}"

  {
    for dir in "${(@ok)__zsh_z_scores}"; do
      printf '%s\t%s\t%s\n' "${__zsh_z_scores[$dir]}" "${__zsh_z_times[$dir]:-0}" "$dir"
    done
  } >| "$tmp_file" || {
    rc=$?
    rm -f "$tmp_file" 2>/dev/null
    return "$rc"
  }

  mv "$tmp_file" "$file" || {
    rc=$?
    rm -f "$tmp_file" 2>/dev/null
    return "$rc"
  }

  __zsh_z_db_loaded=1
  if zsh_file_mtime "$file"; then
    __zsh_z_db_mtime="$REPLY"
  else
    __zsh_z_db_mtime=""
  fi
}

# 生成排序键
# 最近访问优先 查询路径更短
# 访问次数只拿来做同时间戳下的次级排序 保留一点长期价值
__zsh_z_rank_key() {
  emulate -L zsh

  local visits="$1"
  local last_access="$2"

  [[ "$visits" == <-> ]] || visits=0
  [[ "$last_access" == <-> ]] || last_access=0

  REPLY="${(l:10::0:)last_access}"$'\t'"${(l:6::0:)visits}"
}

# 清理非法记录 并把索引规模控制在上限内
# 热路径只做字符串校验 避免每次 cd 都 stat 整张表
__zsh_z_prune_db() {
  emulate -L zsh

  local max_entries="${ZSH_Z_MAX_ENTRIES:-1000}"
  local dir
  local visits
  local last_access
  local worst_dir
  local worst_visits
  local worst_time

  [[ "$max_entries" == <-> ]] || max_entries=1000
  (( max_entries > 0 )) || max_entries=1000

  for dir in "${(@k)__zsh_z_scores}"; do
    if ! __zsh_z_is_valid_path_text "$dir"; then
      unset "__zsh_z_scores[$dir]"
      unset "__zsh_z_times[$dir]"
    fi
  done

  (( ${#__zsh_z_scores} <= max_entries )) && return 0

  while (( ${#__zsh_z_scores} > max_entries )); do
    worst_dir=""
    worst_visits=0
    worst_time=0

    for dir in "${(@k)__zsh_z_scores}"; do
      visits="${__zsh_z_scores[$dir]:-0}"
      last_access="${__zsh_z_times[$dir]:-0}"

      if [[ -z "$worst_dir" ]]; then
        worst_dir="$dir"
        worst_visits="$visits"
        worst_time="$last_access"
        continue
      fi

      if (( last_access < worst_time )); then
        worst_dir="$dir"
        worst_visits="$visits"
        worst_time="$last_access"
        continue
      fi

      if (( last_access == worst_time && visits < worst_visits )); then
        worst_dir="$dir"
        worst_visits="$visits"
      fi
    done

    [[ -n "$worst_dir" ]] || break
    unset "__zsh_z_scores[$worst_dir]"
    unset "__zsh_z_times[$worst_dir]"
  done
}

# 把一条目录访问事件写进内存索引并持久化
# 当前 shell 按需读盘 后续复用内存态更新
__zsh_z_touch_dir() {
  emulate -L zsh

  local dir="$1"
  local visits
  local now

  __zsh_z_should_track_path "$dir" || return 0

  __zsh_z_ensure_db_loaded
  if zsh_now_seconds; then
    now="$REPLY"
  else
    now=0
  fi
  visits="${__zsh_z_scores[$dir]:-0}"

  __zsh_z_scores[$dir]="$(( visits + 1 ))"
  __zsh_z_times[$dir]="$now"

  __zsh_z_prune_db
  __zsh_z_save_db || return $?
}

# 从内存态里移除一条坏记录并尝试落盘
# 跳转时发现目录失效再清理索引 避免查询热路径 stat
__zsh_z_drop_path() {
  emulate -L zsh

  local dir="$1"

  [[ -n "$dir" ]] || return 0
  unset "__zsh_z_scores[$dir]"
  unset "__zsh_z_times[$dir]"
  __zsh_z_save_db >/dev/null 2>&1 || true
}

# chpwd hook 入口
# 目录变更后由 zsh 自动调用
__zsh_z_record_pwd() {
  emulate -L zsh
  __zsh_z_touch_dir "${1:-$PWD}"
}

# 判断目录路径是否命中查询词
# 多个词必须按顺序出现
__zsh_z_path_matches() {
  emulate -L zsh

  local dir="$1"
  shift

  local haystack="$dir"
  local needle

  if (( ${ZSH_Z_CASE_INSENSITIVE:-1} )); then
    haystack="${(L)haystack}"
  fi

  for needle in "$@"; do
    [[ -n "$needle" ]] || continue

    if (( ${ZSH_Z_CASE_INSENSITIVE:-1} )); then
      needle="${(L)needle}"
    fi

    [[ "$haystack" == *"$needle"* ]] || return 1
    haystack="${haystack#*"$needle"}"
  done

  return 0
}

# 收集匹配目录并按排序键排序
# 结果通过 reply 数组返回
__zsh_z_collect_matches() {
  emulate -L zsh

  local -a queries
  local -a records
  local dir
  local visits
  local last_access

  queries=("$@")
  records=()

  __zsh_z_ensure_db_loaded

  for dir in "${(@k)__zsh_z_scores}"; do
    __zsh_z_path_matches "$dir" "${queries[@]}" || continue

    visits="${__zsh_z_scores[$dir]:-0}"
    last_access="${__zsh_z_times[$dir]:-0}"
    __zsh_z_rank_key "$visits" "$last_access"

    records+=("${REPLY}"$'\t'"$dir")
  done

  records=("${(@O)records}")
  reply=("${records[@]}")
}

# 为 zsh completion 产出目录候选
# 候选直接取完整路径 补全后 z 仍走直接 cd 快路径
__zsh_z_completion_candidates() {
  emulate -L zsh

  local -a queries
  local -a records
  local -a candidates
  local record
  local dir
  local _

  queries=("$@")
  candidates=()

  __zsh_z_collect_matches "${queries[@]}"
  records=("${reply[@]}")

  for record in "${records[@]}"; do
    IFS=$'\t' read -r _ _ dir <<< "$record"
    [[ -n "$dir" ]] || continue
    candidates+=("$dir")
  done

  reply=("${candidates[@]}")
}

# 打印匹配列表
# 默认只展示有限条数 避免索引很大时刷屏
__zsh_z_print_matches() {
  emulate -L zsh

  local -a records
  local limit="${ZSH_Z_LIST_MAX:-20}"
  local shown=0
  local record
  local last_access
  local visits
  local dir

  records=("$@")
  [[ "$limit" == <-> ]] || limit=20
  (( limit > 0 )) || limit=20

  if (( ! ${#records[@]} )); then
    zsh_msg info z "no tracked directories"
    return 0
  fi

  for record in "${records[@]}"; do
    (( shown >= limit )) && break
    IFS=$'\t' read -r last_access visits dir <<< "$record"
    printf '%6d  %s\n' "$(( 10#$visits ))" "$dir"
    (( shown += 1 ))
  done
}

# 输出 z 命令帮助
__zsh_z_print_help() {
  zsh_msg info z 'usage: z [-l] [keywords...]'
  zsh_msg info z '  z foo bar   jump to the best matching directory'
  zsh_msg info z '  z -l foo    list matching directories'
}

_z() {
  emulate -L zsh
  setopt extendedglob bareglobqual noshwordsplit

  local cur="${words[CURRENT]:-}"
  local word
  local i
  local -a queries
  local -a candidates

  queries=()
  candidates=()

  if (( CURRENT == 2 )) && [[ "$cur" == -* ]]; then
    compadd -Q -- -l --list -h --help
    return 0
  fi

  for (( i = 2; i <= CURRENT; i++ )); do
    word="${words[i]:-}"
    [[ -n "$word" ]] || continue

    case "$word" in
      -l|--list|--|-h|--help)
        continue
        ;;
    esac

    queries+=("$word")
  done

  __zsh_z_completion_candidates "${queries[@]}"
  candidates=("${reply[@]}")

  if (( ${#candidates[@]} )); then
    # 候选已经按 z 自己的规则完成过滤
    # -U 关闭 compadd 二次前缀匹配 确保 `z down<Tab>` 命中 `/.../Downloads`
    compadd -Q -U -- "${candidates[@]}"
    return 0
  fi

  if [[ "$cur" == [./~]* || "$cur" == /* ]]; then
    autoload -Uz _files
    _files -/
    return $?
  fi

  return 1
}

z() {
  emulate -L zsh

  local mode="jump"
  local target
  local record
  local _
  local -a queries
  local -a records

  while (( $# )); do
    case "$1" in
      -l|--list)
        mode="list"
        shift
        ;;
      -h|--help)
        __zsh_z_print_help
        return 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        zsh_msg warn z "unsupported option: $1"
        return 1
        ;;
      *)
        break
        ;;
    esac
  done

  queries=("$@")

  if [[ "$mode" == "jump" && ${#queries[@]} -eq 1 && -d "${queries[1]}" ]]; then
    builtin cd -- "${queries[1]}"
    return $?
  fi

  __zsh_z_collect_matches "${queries[@]}"
  records=("${reply[@]}")

  if [[ "$mode" == "list" || ${#queries[@]} -eq 0 ]]; then
    __zsh_z_print_matches "${records[@]}"
    return 0
  fi

  if (( ! ${#records[@]} )); then
    zsh_msg warn z "no match for: ${(j: :)queries}"
    return 1
  fi

  for record in "${records[@]}"; do
    IFS=$'\t' read -r _ _ target <<< "$record"
    [[ -n "$target" ]] || continue

    if ! __zsh_z_should_track_path "$target"; then
      __zsh_z_drop_path "$target"
      continue
    fi

    [[ "$target" == "$PWD" ]] && return 0
    builtin cd -- "$target"
    return $?
  done

  zsh_msg warn z "no usable match for: ${(j: :)queries}"
  return 1
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd __zsh_z_record_pwd

autoload -Uz compdef 2>/dev/null || true
(( $+functions[compdef] )) && compdef _z z
