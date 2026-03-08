# oh-box-zsh

一个不依赖 oh-my-zsh 的轻量 zsh 配置框架.

## 目标

- 启动路径短, 默认行为可预期.
- `login` / `interactive` 明确分阶段.
- 用户配置入口清晰, 不再把"配置"和"脚本"混在一起.
- 保留 zsh 原生里高价值的默认交互体验, 但不把外部行为默认全开.
- 重逻辑只在显式启用时接入, 且优先走 cache / lazy.

## 设计

本仓库采用四层模型.

1. `zsh/conf/defaults.zsh`
   - 项目默认值.
   - 只定义变量默认值.

2. `zsh/user/config.zsh`
   - 用户声明式配置.
   - 在 `login` / `interactive` 之前加载.
   - 适合放 feature 列表, 主题, 编辑模式, 模块参数.

3. `zsh/features/*.zsh`
   - 功能实现层.
   - 所有能力统一称为 feature.
   - feature 的加载顺序由数组顺序决定.

4. `zsh/user/local.zsh`
   - 用户个人脚本层.
   - 只在 interactive 最后加载.
   - 适合放 alias, function, bindkey, 临时代码.

## 目录

```text
.
├── install.sh
├── test/
│   └── test-zsh.sh
├── zshenv
└── zsh/
    ├── .zprofile
    ├── .zshrc
    ├── init.zsh
    ├── conf/
    │   ├── defaults.zsh
    │   ├── config.zsh.example
    │   └── local.zsh.example
    ├── core/
    │   ├── 00-core.zsh
    │   ├── 10-path.zsh
    │   ├── 20-detect.zsh
    │   ├── 30-cache.zsh
    │   └── 40-lazy.zsh
    ├── features/
    │   ├── env-path.zsh
    │   ├── history.zsh
    │   ├── completion.zsh
    │   ├── keybinds.zsh
    │   ├── prompt.zsh
    │   ├── homebrew.zsh
    │   ├── pyenv.zsh
    │   ├── fzf.zsh
    │   └── tmux.zsh
    ├── stage/
    │   ├── login.zsh
    │   └── interactive.zsh
    ├── themes/
    │   ├── basic.zsh
    │   └── basic-git.zsh
    └── user/
        ├── config.zsh
        └── local.zsh
```

## 启动顺序

```text
~/.zshenv
  -> ZDOTDIR
  -> zsh/.zprofile or zsh/.zshrc
  -> zsh/init.zsh
  -> zsh/core/*
  -> zsh/conf/defaults.zsh
  -> zsh/user/config.zsh
  -> zsh/stage/login.zsh 或 zsh/stage/interactive.zsh

interactive 阶段:
  -> ZSH_INTERACTIVE_FEATURES 按顺序加载
  -> zsh/user/local.zsh
```

## 默认配置

当前 `zsh/user/config.zsh` 默认是.

- login features:
  - `env-path`

- interactive features:
  - `history`
  - `completion`
  - `keybinds`
  - `prompt`

也就是先给一个轻量可用的基线, 再按需加.

- `homebrew`
- `pyenv`
- `fzf`
- `tmux`

## 默认迁入的高价值体验

这版默认做了几件事, 目的是保留 zsh 原生里最有用的体验, 但不照搬大型框架的"全开策略".

### completion
- 大小写不敏感补全.
- substring 匹配.
- partial-word 匹配.
- 自动弹出补全菜单.
- 在单词中间补全.
- 补全后光标移到单词末尾.
- `.` 和 `..` 目录补全.
- completion cache.

### keybinds
- `Ctrl-R` 增量历史搜索.
- 输入前缀后, 上下箭头按前缀搜索历史.
- `Ctrl-X Ctrl-E` 外部编辑器编辑当前命令行.
- 常见终端里的 Home / End / Delete / Shift-Tab 兼容绑定.

### history
- `share_history`
- `extended_history`
- `hist_verify`
- `hist_ignore_dups`
- `hist_ignore_space`
- `hist_expire_dups_first`

## 推荐做法

### 1. 把"声明"写进 `user/config.zsh`

```zsh
typeset -ga ZSH_LOGIN_FEATURES
ZSH_LOGIN_FEATURES=(
  env-path
  homebrew
  pyenv
)

typeset -ga ZSH_INTERACTIVE_FEATURES
ZSH_INTERACTIVE_FEATURES=(
  history
  completion
  keybinds
  prompt
  fzf
  tmux
  pyenv
)

ZSH_THEME="basic-git"
ZSH_KEYMAP="vi"

# 按需关掉某一项默认增强.
ZSH_COMPLETION_CASE_INSENSITIVE=0
ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH=0
ZSH_HISTORY_SHARE=0
```

### 2. 把"个人脚本"写进 `user/local.zsh`

```zsh
alias ll='ls -lah'

mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}
```

## 安装

### link 模式

```bash
./install.sh --link --force
```

### copy 模式

```bash
./install.sh --copy --force
```

安装后.

- `~/.zshenv` 指向仓库根的 `zshenv`.
- `~/.config/zsh` 或 `$XDG_CONFIG_HOME/zsh` 指向或复制仓库里的 `zsh/`.

## 测试

```bash
chmod +x ./test/test-zsh.sh
./test/test-zsh.sh
```

## feature 说明

### env-path
轻量 PATH 基础层. 适合放到 login.

### history
历史记录策略. interactive.

### completion
执行 `compinit`, 把 `zcompdump` 放到缓存目录, 并启用一组可配置的高价值补全增强. interactive.

### keybinds
设置 `emacs` / `vi` 编辑模式, `Ctrl-X Ctrl-E`, 上下箭头前缀搜历史, Home / End / Delete 等常见按键行为. interactive.

### prompt
按主题名加载 `themes/*.zsh`. interactive.

### homebrew
检测 brew 并执行 `brew shellenv`. 支持缓存输出片段. 通常放 login.

### pyenv
- login: 补充 `PYENV_ROOT/bin` 和 `shims`.
- interactive: 按需执行 `pyenv init - zsh`.
- 默认是 lazy 模式.

如果你想完整接入 pyenv, 通常把 `pyenv` 同时放到 login 和 interactive feature 列表.

### fzf
尝试 source 常见路径下的 fzf shell 集成脚本. interactive.

### tmux
支持按开关自动附着到指定 session, 默认关闭. interactive.

## 已知取舍

- 默认不追求"功能最多", 而追求"结构清楚, 启动可控".
- `completion` 仍然会带来一定启动开销. 如果你想更极致地压启动时间, 可以把它从 `ZSH_INTERACTIVE_FEATURES` 移除.
- `pyenv` / `homebrew` / `fzf` 都按"显式启用"处理, 不默认全开.
- 默认没有迁入"自动标题栏", "大量 alias 注入", "自动更新逻辑"这类更容易引起副作用的行为.
