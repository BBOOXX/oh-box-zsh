# oh-box-zsh

一个不依赖 oh-my-zsh 的自用 zsh 配置框架

不追求功能多, 而追求结构清楚, 启动可控

## 安装

```bash
./install.sh --f
```

## 目录

```text
.
├── install.sh
├── zshenv
└── zsh/
    ├── .zprofile
    ├── .zshrc
    ├── init.zsh
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
    │   └── prompt.zsh
    ├── stage/
    │   ├── login.zsh
    │   └── interactive.zsh
    ├── themes/
    │   └── basic.zsh
    └── user/
        └── config.zsh
```

## 启动顺序

```text
~/.zshenv
  -> ZDOTDIR
  -> skip_global_compinit guard
  -> zsh/.zprofile or zsh/.zshrc
  -> zsh/init.zsh
  -> zsh/core/*
  -> zsh/user/config.zsh
  -> zsh/stage/login.zsh 或 zsh/stage/interactive.zsh

interactive 阶段:
  -> ZSH_INTERACTIVE_FEATURES 按顺序加载
  -> zsh/user/local.zsh (if present)
```

默认值不再集中在单个 `defaults.zsh`.
模块参数由各自 `feature` 或 `theme` 用本地 fallback 处理, 阶段 feature 列表由 `stage/*.zsh` 负责兜底.

在 Debian/Ubuntu 一类带全局 `/etc/zsh/zshrc` 的环境里, `~/.zshenv` 还会提前声明 `skip_global_compinit=1`.
这样系统默认 `compinit` 不会先把 `.zcompdump` 写到 `$ZDOTDIR`, completion feature 只使用项目约定的 XDG cache 路径.
