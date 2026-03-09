# oh-box-zsh

一个不依赖 oh-my-zsh 的自用 zsh 配置框架.
不追求功能多, 而追求结构清楚, 启动可控.

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
  -> zsh/.zprofile or zsh/.zshrc
  -> zsh/init.zsh
  -> zsh/core/*
  -> zsh/conf/defaults.zsh
  -> zsh/user/config.zsh
  -> zsh/stage/login.zsh 或 zsh/stage/interactive.zsh

interactive 阶段:
  -> ZSH_INTERACTIVE_FEATURES 按顺序加载
  -> zsh/user/local.zsh (if present)
```
