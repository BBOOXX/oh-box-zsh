# features/z.zsh
# 目录跳转索引

# 这个 feature 迁入了 OMZ z 插件里最核心的体验.
# 1. 记录你 cd 过的目录
# 2. 用频率 + 最近访问时间做排序
# 3. 提供 z 命令做快速跳转
# 4. 把状态放到缓存目录, 不污染声明层和脚本层

if [[ -n "${__zsh_feature_z_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_feature_z_loaded=1

# 这些变量默认不放到 defaults.zsh.
# 原因是它们更像 feature 自己的实现参数.
# 如果用户确实要改, 可以直接在 user/config.zsh 里预先声明覆盖.
typeset -g ZSH_Z_DATA_FILE="${ZSH_Z_DATA_FILE:-$ZSH_CACHE_DIR/z/data}"
typeset -gi ZSH_Z_MAX_ENTRIES="${ZSH_Z_MAX_ENTRIES:-1000}"
typeset -gi ZSH_Z_LIST_MAX="${ZSH_Z_LIST_MAX:-20}"
typeset -gi ZSH_Z_CASE_INSENSITIVE="${ZSH_Z_CASE_INSENSITIVE:-1}"

typeset -gA __zsh_z_scores
typeset -gA __zsh_z_times
__zsh_z_scores=()
__zsh_z_times=()

zsh_ensure_dir "${ZSH_Z_DATA_FILE:h}"
zmodload -F zsh/datetime b:EPOCHSECONDS 2>/dev/null || true

# 返回当前 Unix 时间戳.
# 优先使用 zsh/datetime, 退化时再用外部 date.
__zsh_z_now() {
  emulate -L zsh

  local now="${EPOCHSECONDS:-}"

  if [[ "$now" != <-> ]]; then
    now="$(date +%s 2>/dev/null)"
  fi

  [[ "$now" == <-> ]] || now=0
  REPLY="$now"
}

# 过滤不适合写入索引的路径.
# 这里显式跳过不存在目录, 相对路径和带换行 / Tab 的路径.
__zsh_z_should_track_path() {
  emulate -L zsh

  local dir="$1"

  [[ -n "$dir" ]] || return 1
  [[ "$dir" == /* ]] || return 1
  [[ -d "$dir" ]] || return 1
  [[ "$dir" == *$'\n'* ]] && return 1
  [[ "$dir" == *$'\t'* ]] && return 1
  return 0
}

# 从缓存文件读回目录索引.
# 只接受三列纯文本格式: visits<TAB>last_access<TAB>path
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
}

# 从磁盘重新加载目录索引.
# 这里会先清空内存态, 适合在每次写回前与其他 shell 做一次合并.
__zsh_z_reload_db() {
  emulate -L zsh

  __zsh_z_scores=()
  __zsh_z_times=()
  __zsh_z_load_db
}

# 把目录索引刷回缓存文件.
# 数据量被 ZSH_Z_MAX_ENTRIES 限住, 所以直接整文件重写更简单可验证.
__zsh_z_save_db() {
  emulate -L zsh

  local file="$ZSH_Z_DATA_FILE"
  local dir

  zsh_ensure_dir "${file:h}"

  {
    for dir in "${(@ok)__zsh_z_scores}"; do
      printf '%s\t%s\t%s\n' "${__zsh_z_scores[$dir]}" "${__zsh_z_times[$dir]:-0}" "$dir"
    done
  } >| "$file" || return 1
}

# 计算目录的跳转权重.
# 更近的目录会拿到更高乘数, 但访问次数仍然保留长期价值.
__zsh_z_rank_value() {
  emulate -L zsh

  local visits="$1"
  local last_access="$2"
  local now="$3"
  local age
  local multiplier

  [[ "$visits" == <-> ]] || visits=0
  [[ "$last_access" == <-> ]] || last_access=0
  [[ "$now" == <-> ]] || now=0

  age=$(( now - last_access ))
  (( age < 0 )) && age=0

  if (( age <= 3600 )); then
    multiplier=100
  elif (( age <= 86400 )); then
    multiplier=60
  elif (( age <= 604800 )); then
    multiplier=30
  elif (( age <= 2592000 )); then
    multiplier=10
  else
    multiplier=1
  fi

  REPLY=$(( visits * multiplier * 1000000000 + last_access ))
}

# 清理已经不存在的目录, 并把索引规模控制在上限内.
__zsh_z_prune_db() {
  emulate -L zsh

  local max_entries="${ZSH_Z_MAX_ENTRIES:-1000}"
  local now
  local dir
  local last_access
  local rank
  local worst_dir
  local worst_rank
  local worst_time

  [[ "$max_entries" == <-> ]] || max_entries=1000
  (( max_entries > 0 )) || max_entries=1000

  for dir in "${(@k)__zsh_z_scores}"; do
    if ! __zsh_z_should_track_path "$dir"; then
      unset "__zsh_z_scores[$dir]"
      unset "__zsh_z_times[$dir]"
    fi
  done

  (( ${#__zsh_z_scores} <= max_entries )) && return 0

  __zsh_z_now
  now="$REPLY"

  while (( ${#__zsh_z_scores} > max_entries )); do
    worst_dir=""
    worst_rank=0
    worst_time=0

    for dir in "${(@k)__zsh_z_scores}"; do
      last_access="${__zsh_z_times[$dir]:-0}"
      __zsh_z_rank_value "${__zsh_z_scores[$dir]:-0}" "$last_access" "$now"
      rank="$REPLY"

      if [[ -z "$worst_dir" ]]; then
        worst_dir="$dir"
        worst_rank="$rank"
        worst_time="$last_access"
        continue
      fi

      if (( rank < worst_rank )); then
        worst_dir="$dir"
        worst_rank="$rank"
        worst_time="$last_access"
        continue
      fi

      if (( rank == worst_rank && last_access < worst_time )); then
        worst_dir="$dir"
        worst_time="$last_access"
      fi
    done

    [[ -n "$worst_dir" ]] || break
    unset "__zsh_z_scores[$worst_dir]"
    unset "__zsh_z_times[$worst_dir]"
  done
}

# 把一条目录访问事件写进内存索引并持久化.
__zsh_z_touch_dir() {
  emulate -L zsh

  local dir="$1"
  local visits
  local now

  __zsh_z_should_track_path "$dir" || return 0

  __zsh_z_reload_db
  __zsh_z_now
  now="$REPLY"
  visits="${__zsh_z_scores[$dir]:-0}"

  __zsh_z_scores[$dir]="$(( visits + 1 ))"
  __zsh_z_times[$dir]="$now"

  __zsh_z_prune_db
  __zsh_z_save_db
}

# chpwd hook 入口.
# 目录变更后由 zsh 自动调用.
__zsh_z_record_pwd() {
  emulate -L zsh
  __zsh_z_touch_dir "${1:-$PWD}"
}

# 判断目录路径是否命中查询词.
# 多个词时要求按顺序出现, 这样 z foo bar 的结果更可控.
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

# 收集匹配目录并按权重排序.
# 结果通过 reply 数组返回.
__zsh_z_collect_matches() {
  emulate -L zsh

  local -a queries
  local -a records
  local dir
  local visits
  local last_access
  local rank
  local now

  queries=("$@")
  records=()

  __zsh_z_now
  now="$REPLY"

  for dir in "${(@k)__zsh_z_scores}"; do
    __zsh_z_should_track_path "$dir" || continue
    __zsh_z_path_matches "$dir" "${queries[@]}" || continue

    visits="${__zsh_z_scores[$dir]:-0}"
    last_access="${__zsh_z_times[$dir]:-0}"
    __zsh_z_rank_value "$visits" "$last_access" "$now"
    rank="$REPLY"

    records+=("$(printf '%018d\t%010d\t%06d\t%s' "$rank" "$last_access" "$visits" "$dir")")
  done

  records=("${(@O)records}")
  reply=("${records[@]}")
}

# 为 zsh completion 产出目录候选.
# 这里返回完整路径, 这样选中后 z 仍然可以走"直接 cd 到目录"的路径.
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

  __zsh_z_reload_db
  __zsh_z_collect_matches "${queries[@]}"
  records=("${reply[@]}")

  for record in "${records[@]}"; do
    IFS=$'\t' read -r _ _ _ dir <<< "$record"
    [[ -n "$dir" ]] || continue
    candidates+=("$dir")
  done

  reply=("${candidates[@]}")
}

# 打印匹配列表.
# 默认只展示有限条数, 避免索引很大时刷屏.
__zsh_z_print_matches() {
  emulate -L zsh

  local -a records
  local limit="${ZSH_Z_LIST_MAX:-20}"
  local shown=0
  local record
  local rank
  local last_access
  local visits
  local dir

  records=("$@")
  [[ "$limit" == <-> ]] || limit=20
  (( limit > 0 )) || limit=20

  if (( ! ${#records[@]} )); then
    print -r -- "z: no tracked directories"
    return 0
  fi

  for record in "${records[@]}"; do
    (( shown >= limit )) && break
    IFS=$'\t' read -r rank last_access visits dir <<< "$record"
    printf '%6d  %s\n' "$(( 10#$visits ))" "$dir"
    (( shown += 1 ))
  done
}

# 输出 z 命令帮助.
__zsh_z_print_help() {
  print -r -- 'usage: z [-l] [keywords...]'
  print -r -- '  z foo bar   jump to the best matching directory'
  print -r -- '  z -l foo    list matching directories'
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
    # 候选已经按 z 自己的规则完成过滤.
    # 这里用 -U 关闭 compadd 的二次前缀匹配, 否则 `z down<Tab>` 不会命中 `/.../Downloads`.
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
        zsh_warn "z: unsupported option: $1"
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
    zsh_warn "z: no match for: ${(j: :)queries}"
    return 1
  fi

  IFS=$'\t' read -r _ _ _ target <<< "${records[1]}"

  [[ -n "$target" ]] || return 1
  [[ "$target" == "$PWD" ]] && return 0

  builtin cd -- "$target"
}

__zsh_z_reload_db
__zsh_z_prune_db
__zsh_z_save_db

autoload -Uz add-zsh-hook
add-zsh-hook chpwd __zsh_z_record_pwd

autoload -Uz compdef 2>/dev/null || true
(( $+functions[compdef] )) && compdef _z z
