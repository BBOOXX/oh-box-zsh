# AGENTS.md

> 本仓库是“从 0 开始的 zsh 配置框架”，不使用 oh-my-zsh。
> 目标：稳定、可扩展、可加速（cache/lazy）、跨 macOS/Linux/Termux。

## 0. 你在这个仓库里扮演的角色（Codex 行为准则）

- 你是“工程协作者”，优先保证：**可启动、可回滚、可验证**。
- 所有变更必须：
  1) 给出明确改动点（文件 + 理由）
  2) 给出可复制的验证命令（含预期输出/判定标准）
  3) 尽量在“临时 HOME”中完成验证（除非我明确要求改真实 HOME）

## 1. 项目约束（必须遵守）

### 1.1 禁止项
- 禁用 oh-my-zsh / prezto 等框架；禁止引入其函数依赖。
- 禁止在 `~/.zshenv` 放重逻辑（外部命令、compinit、git 探测、eval 等）。
- 禁止把大量业务逻辑堆进 `init.zsh`（它只做调度）。
- 禁止把“用户主配置入口”重新分散到 `components/*`。

### 1.2 必须项
- `ZDOTDIR` 规则：优先 `"$XDG_CONFIG_HOME/zsh"`，若未设置则回退到 `"$HOME/.config/zsh"`
- 登录/交互分阶段：
  - `.zprofile` → `ZSH_INIT_STAGE=login` → `init.zsh`
  - `.zshrc`    → `ZSH_INIT_STAGE=interactive` → `init.zsh`
- 用户主配置入口固定为：`zsh/local.zsh`
- 项目默认配置固定为：`zsh/components/defaults.zsh`
- `local.zsh` 只在 interactive 阶段加载
- 跨平台：macOS / Linux（含 arm64/x86_64），必要时做分支兼容。
- 注释风格：中文为主，解释“为什么这么做”，尤其是 cache/lazy 这类基础设施。

## 2. 仓库布局（重要）

- 仓库根目录用于管理（git/README/install），**不作为 ZDOTDIR**。
- 真正的 zsh 配置目录是仓库内的 `zsh/` 子目录。

当前结构（节选）：

- `install.sh`：部署脚本（link/copy + force 备份）
- `test-local-zsh.sh`：本地集成测试脚本
- `zshenv`：将被部署到 `~/.zshenv`（只设置 ZDOTDIR）
- `zsh/components/defaults.zsh`：项目默认配置中心
- `zsh/local.zsh`：用户主配置入口（可选）
- `zsh/local.zsh.example`：用户主配置示例
- `zsh/components/`：zsh 行为实现与模块加载器
- `zsh/modules/`：可选模块（homebrew/pyenv/tmux/...）
- `zsh/lib/`：基础能力
- `zsh/stages/`：阶段调度

## 3. 关键设计原则（写代码时必须遵守）

### 3.1 init.zsh 只做“调度”
init.zsh 负责：
- 定义目录变量（ZSH_CONFIG_HOME / ZSH_CACHE_DIR / ...）
- 只加载基础库（lib/*）
- 只做环境探测（detect）
- 只加载项目默认层（components/defaults）
- 按阶段分发到 stages/*
- 防重复（bootstrap guard + stage guard）

除此以外的业务逻辑应放到：
- `stages/`（阶段逻辑）
- `modules/`（可选工具）
- `components/`（纯实现与组件加载器）

### 3.2 用户入口与实现分离
- `local.zsh` 放：开关、偏好、模块列表、模块参数、alias/function/临时代码。
- `components/defaults.zsh` 放：项目默认配置。
- `components/*` 放：这些配置值如何被消费与实现。
- `modules/*` 放：外部工具接入逻辑。

### 3.3 重逻辑必须可控
- 任何“外部命令 + eval/source”倾向：
  - 优先接入 `lib/30-cache.zsh`（缓存 shell 片段）
- 任何“初始化很重的工具链”（pyenv/nvm/...）：
  - 优先接入 `lib/40-lazy.zsh`（首次调用再初始化）

### 3.4 模块加载规则
- 模块按名字声明在数组中，不使用一堆 `ZSH_ENABLE_XXX`。
- `ZSH_LOGIN_MODULES`：login 阶段加载
- `ZSH_INTERACTIVE_MODULES`：interactive 阶段加载
- loader 只做“按名字加载”，模块具体逻辑下沉到 `modules/*.zsh`

### 3.5 安全边界
- `zcache_source_cmd` 只能用于“可信命令输出的 shell 片段”。
- 禁止缓存/落盘/`source` 不可信输入。
- 若必须 `eval`，必须说明风险与替代方案。

## 4. 开发/测试：默认使用“临时 HOME”验收（避免污染真实环境）

### 4.1 安全集成测试（推荐，默认执行）
在仓库根执行：

```bash
TMPHOME="$(mktemp -d)"

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
./install.sh --link --force

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
zsh -lc 'echo login:$ZDOTDIR'

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
zsh -ic 'echo interactive:$ZDOTDIR'

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
zsh -lic 'echo both:$ZDOTDIR'

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
zsh -lic 'echo OS=$ZSH_OS ARCH=$ZSH_ARCH SSH=$ZSH_IS_SSH TERMUX=$ZSH_IS_TERMUX WSL=$ZSH_IS_WSL'

HOME="$TMPHOME" \
XDG_CONFIG_HOME="$TMPHOME/.config" \
zsh -lic 'echo HISTFILE=$HISTFILE'
```

判定标准：

- 命令退出码为 0
- 三次输出的 `ZDOTDIR` 都等于：`$XDG_CONFIG_HOME/zsh`
- 环境探测值符合平台基本事实（macOS/Linux + arch）
- `HISTFILE` 在：`$HOME/.cache/zsh/history`

### 4.2 install.sh 的判定语义

必须按下面规则写测试：

- 目标不存在：成功
- 目标已存在且已正确：成功（幂等）
- 目标已存在但冲突：失败
- `--force`：备份后替换

不要把“幂等成功”误判为失败。

### 4.3 真实环境安装（仅在我明确要求时执行）

```bash
./install.sh --link --force
# 或：./install.sh --copy --force
```

注意：真实安装会改动：

- `~/.zshenv`
- `~/.config/zsh` 或 `$XDG_CONFIG_HOME/zsh`

## 5. 代码风格与提交规则

- shell 兼容目标：zsh（允许使用 zsh 特性，不要求 bash 兼容）。
- 任何新增函数：
  - 必须有“职责说明 + 输入输出约定 + 失败语义”注释
  - 尽量避免隐式全局副作用
- 文件命名：
  - 基础库用数字前缀（00/10/20/30/40）确保加载顺序清晰
  - 模块文件按模块名命名（例如 `homebrew.zsh` `pyenv.zsh`）
- 变更输出（你给我的最终回复里应包含）：
  1. 改动摘要（列表）
  2. diff（或逐文件关键片段）
  3. 你跑过的命令（尤其是 4.1 的临时 HOME 验证）
  4. 结果（成功/失败 + 失败原因）
