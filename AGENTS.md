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

### 1.2 必须项
- `ZDOTDIR` 固定为：`$HOME/.config/zsh`
- 登录/交互分阶段：
  - `.zprofile` → `ZSH_INIT_STAGE=login` → `init.zsh`
  - `.zshrc`    → `ZSH_INIT_STAGE=interactive` → `init.zsh`
- 跨平台：macOS / Linux（含 arm64/x86_64），必要时做分支兼容。
- 注释风格：中文为主，解释“为什么这么做”，尤其是 cache/lazy 这类基础设施。

## 2. 仓库布局（重要）

- 仓库根目录用于管理（git/README/install），**不作为 ZDOTDIR**。
- 真正的 zsh 配置目录是仓库内的 `zsh/` 子目录。

推荐结构（节选）：

- `install.sh`：部署脚本（link/copy + force 备份）
- `zshenv`：将被部署到 `~/.zshenv`（只设置 ZDOTDIR）
- `zsh/`：ZDOTDIR 内容
  - `.zprofile` / `.zshrc` / `init.zsh`
  - `lib/00-core.zsh` `10-path.zsh` `20-detect.zsh` `30-cache.zsh` `40-lazy.zsh`
  - `stages/login.zsh` `stages/interactive.zsh`
  - `modules/`：可选模块（homebrew/pyenv/tmux/...）

## 3. 关键设计原则（写代码时必须遵守）

### 3.1 init.zsh 只做“调度”
init.zsh 负责：
- 定义目录变量（ZSH_CONFIG_HOME / ZSH_CACHE_DIR / ...）
- 只加载基础库（lib/*）
- 只做环境探测（detect）
- 按阶段分发到 stages/*
- 防重复（bootstrap guard + stage guard）
除此以外的业务逻辑应放到：
- `stages/`（阶段逻辑）
- `modules/`（可选工具）
- `conf/`（纯配置片段，未来可用）

### 3.2 重逻辑必须可控
- 任何“外部命令 + eval/source”倾向：
  - 优先接入 `lib/30-cache.zsh`（缓存 shell 片段）
- 任何“初始化很重的工具链”（pyenv/nvm/...）：
  - 优先接入 `lib/40-lazy.zsh`（首次调用再初始化）

### 3.3 安全边界
- `zcache_source_cmd` 只能用于“可信命令输出的 shell 片段”。
- 禁止缓存/落盘/`source` 不可信输入。
- 若必须 `eval`，必须说明风险与替代方案。

## 4. 开发/测试：默认使用“临时 HOME”验收（避免污染真实环境）

### 4.1 安全集成测试（推荐，默认执行）
在仓库根执行（示例）：

```bash
TMPHOME="$(mktemp -d)"
# 用临时 HOME 安装（不会碰你真实 ~/.zshenv 和 ~/.config）
HOME="$TMPHOME" ./install.sh --link --force

# 验证三条启动路径都正确
HOME="$TMPHOME" zsh -lc  'echo login:$ZDOTDIR'
HOME="$TMPHOME" zsh -ic  'echo interactive:$ZDOTDIR'
HOME="$TMPHOME" zsh -lic 'echo both:$ZDOTDIR'

# 验证探测变量（仅示例：值会因平台不同）
HOME="$TMPHOME" zsh -lic 'echo OS=$ZSH_OS ARCH=$ZSH_ARCH SSH=$ZSH_IS_SSH TERMUX=$ZSH_IS_TERMUX WSL=$ZSH_IS_WSL'

# 验证 history 文件路径
HOME="$TMPHOME" zsh -lic 'echo HISTFILE=$HISTFILE'
````

判定标准：

* 命令退出码为 0
* 三次输出的 ZDOTDIR 都等于：`$HOME/.config/zsh`
* 环境探测值符合平台基本事实（macos/linux + arch）
* HISTFILE 在：`$HOME/.cache/zsh/history`

### 4.2 真实环境安装（仅在我明确要求时执行）

```bash
./install.sh --link --force
# 或：./install.sh --copy --force
```

注意：真实安装会改动：

* `~/.zshenv`
* `~/.config/zsh`

## 5. 代码风格与提交规则

* shell 兼容目标：zsh（允许使用 zsh 特性，不要求 bash 兼容）。
* 任何新增函数：

  * 必须有“职责说明 + 输入输出约定 + 失败语义”注释
  * 尽量避免隐式全局副作用
* 文件命名：

  * 基础库用数字前缀（00/10/20/30/40）确保加载顺序清晰
* 变更输出（你给我的最终回复里应包含）：

  1. 改动摘要（列表）
  2. diff（或逐文件关键片段）
  3. 你跑过的命令（尤其是 4.1 的临时 HOME 验证）
  4. 结果（成功/失败 + 失败原因）
