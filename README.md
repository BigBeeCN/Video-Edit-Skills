# Video-Edit-Skills

本仓库提供竖屏口播剪辑 skill `vertical-talking-head-edit`。在 Windows 上使用 OpenAI Codex（CLI、IDE 扩展或桌面版）时，克隆本仓库或按下面的方式安装后，Codex 会发现这个 skill：用户要求把已经拍好的口播视频剪成竖屏短视频时，按 `description` 隐式调用它。

Windows 平台 Codex 竖屏口播剪辑 skill。在 Windows 上用 Codex，把别人已经拍好的竖屏口播素材（企业口播、实拍、空镜）剪成 9:16 抖音风短视频：素材体检、听写对齐、叙事重组、分镜、剪气口、两档字幕特效与音效。交付成片，并附重要程度表和时长统计表。剪映工程给剪辑师自己改特效、空镜时长和变速，这一步待验证；验证前保底是成片 + SRT + 分镜表。不涉及拍摄环节。

## 仓库布局

```
.
├── .agents/skills/vertical-talking-head-edit/
│   ├── SKILL.md                 # name、description 与剪辑流程
│   ├── agents/openai.yaml       # 显示名、短说明、默认提示、允许隐式调用
│   └── references/              # 环境、命令、分镜、节奏、质检、剪映、硬规则
├── install.ps1                  # 安装到用户目录（USER 范围）
├── templates/AGENTS.md          # 贴进视频项目 AGENTS.md 的片段
├── .gitattributes
└── README.md
```

仓库里只有这一份 skill。Codex 不会合并同名 skill，两处各有一份就会列出两次。

## Codex 如何发现它

一个 skill 是带 `SKILL.md` 的文件夹，frontmatter 里要有 `name` 和 `description`。Codex 预加载时只读 name、description 和路径；当前任务和 `description` 对得上就会隐式调用。本 skill 的 `description` 把用途和触发词放在前面，并把「不用于」写清楚。装了很多 skill 时，description 可能被截短，所以关键句在开头。

会扫描的位置（符号链接会跟随）：

- 当前工作目录下的 `.agents/skills`，以及向上直到仓库根目录的 `.agents/skills`（REPO 范围）
- 用户目录 `%USERPROFILE%\.agents\skills`（USER 范围）
- `/etc/codex/skills`

显式调用写 `$vertical-talking-head-edit`，或用 `/skills` 查看已安装列表。Codex 会自动发现文件变化；列表里没有就重启 Codex。

## 安装

三种方式选一种。用户范围和仓库范围同时存在时，同名 skill 会各出现一次，不会合并。

### A. 用户范围：任意文件夹都能用

在仓库根目录打开 PowerShell，运行：

```powershell
.\install.ps1
```

脚本把 `.agents\skills\vertical-talking-head-edit` 复制到 `%USERPROFILE%\.agents\skills\`（目录不存在会先创建）。若该处已有同名副本，先挪到带时间戳的备份文件夹，再覆盖。结束后会打印安装路径。

然后重启 Codex，输入 `/skills` 确认列表里有 `vertical-talking-head-edit`。

`install.ps1` 尚未在真实 Windows 机器上运行过。

### B. 仓库范围：克隆后在本仓库里打开 Codex

克隆本仓库，在仓库根目录启动 Codex。它会扫描 `.agents/skills`，不必再复制。从仓库里的子目录启动也可以：Codex 会沿父目录一直找到仓库根的 `.agents/skills`。

### C. 让 `$skill-installer` 安装（未实测）

在 Codex 里调用 `$skill-installer`，让它从本仓库的 `.agents/skills/vertical-talking-head-edit` 安装。这条路径未实测。

## 如何确认

1. 输入 `/skills`。列表里应有 `vertical-talking-head-edit`（界面显示名「竖屏口播剪辑」）。
2. 不要点名这个 skill，直接发下面的句子，看它是否自己调用。

### 应自动触发

- 这个文件夹里是别人已经拍好的口播和空镜，帮我剪成 9:16 的抖音短视频，30 到 60 秒。
- 做一期口播剪辑：竖屏，剪掉气口，加上字幕花字、音效和配乐，出剪映草稿。
- 这些实拍素材要剪成视频号和快手风格的竖屏成片，再出一张封面。
- Edit this talking head into a vertical video edit, about 45 seconds, Douyin style.

### 不应触发

- 帮我策划下周的口播拍摄：机位、提纲和分镜，素材还没拍。
- 把这段横屏发布会长视频转成字幕文件，不要剪辑。

### 强制调用

消息里写上 `$vertical-talking-head-edit`，Codex 会直接使用这个 skill，不依赖 description 是否匹配。`agents/openai.yaml` 里的默认提示是：`用 $vertical-talking-head-edit 把这个文件夹里的口播素材剪成竖屏短视频`。

## 为什么要在视频项目里放 AGENTS.md

把 `templates/AGENTS.md` 整段贴进你自己的视频项目根目录 `AGENTS.md`。Codex 每次开场都会读项目里的 `AGENTS.md`。这段要求：凡是剪辑、处理竖屏口播视频，先调用 `$vertical-talking-head-edit` 并按它的步骤执行，后面是 skill 规定必须放进 `AGENTS.md` 的硬规则（原文在 `references/AGENTS_rules.md`）。这样即使用户没点名 skill，或 description 被截短、这次没自动选中，剪辑任务仍会走这条流程。

## description 被截短时

安装的 skill 很多时，Codex 会缩短预加载的 description，触发词或文末的「不用于」可能被裁掉，隐式调用会变差。把配置项 `skills.max_context_tokens` 调大，让完整 description 参与匹配。

## 更新

拉取本仓库的新版本后，再运行一次 `.\install.ps1`。脚本会把现有安装备份到带时间戳的文件夹，再覆盖为新副本。若用的是方式 B（在本仓库里打开 Codex），拉取后就是新版本，不用再跑安装脚本。

## 依赖

以下内容概括自 `.agents/skills/vertical-talking-head-edit/references/windows_env.md` 的自检清单，开工前需要准备：

- **ffmpeg 完整版**（推荐 gyan.dev full build）：滤镜需有 `zscale`、`tonemap`、`afftdn`、`sidechaincompress`、`loudnorm`、`ebur128`、`blackdetect`、`freezedetect`，编码器需有 `prores_ks`、`libx264`。
- **Python 3.10 或 3.11**。pyJianYingDraft 自动导出依赖的 uiautomation 在 3.13 上可能出问题。
- **听写**：faster-whisper 与 whisperX 分别装在两个独立环境，模型已下载，各自环境里能 `import`。
- **特效层**：安装 Playwright 后执行 `python -m playwright install chromium`，渲染一帧时中文是目标字体。目标字体已安装，或在 CSS 里用 `@font-face` 指向字体文件。
- **可选**：demucs、onnxruntime / torch（RVM）。能导入即可；没有就用剪映「智能抠像」。
- **剪映草稿目录**：在剪映「全局设置」的草稿位置中查到并写入配置，目录存在且可写。

Codex 默认使用原生 PowerShell 与 Windows 沙箱。`workspace-write` 模式下网络默认关闭：安装依赖、下载 Whisper / whisperX / RVM 模型前要提前装好，或在 `config.toml` 里临时打开 `sandbox_workspace_write.network_access`。写入工作区外的剪映草稿目录时，把该目录加入 `writable_roots`。

## 待验证

标有「待验证」的条目还没有在真实 Windows 机器上测试过。首次实测时，按 `.agents/skills/vertical-talking-head-edit/references/windows_env.md` 里的「Windows 首次实测清单」逐项确认，通过后再去掉对应标记。`install.ps1` 以及方式 C（`$skill-installer`）同样还没有在真实 Windows 机器上运行过。
