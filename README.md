# Video-Edit-Skills

本仓库收录视频剪辑相关的 Codex skill。

## vertical-talking-head-edit

Windows 平台 Codex 竖屏口播剪辑 skill。在 Windows 上用 Codex，把别人已经拍好的竖屏口播素材（企业口播、实拍、空镜）剪成 9:16 抖音风短视频：素材体检、听写对齐、叙事重组、分镜、剪气口、两档字幕特效与音效，最后交付剪映草稿或叠加层成片。不涉及拍摄环节。

### 在 Windows 上安装

把本仓库中的 `vertical-talking-head-edit` 文件夹整个复制到：

`%USERPROFILE%\.agents\skills\`

复制后应为 `%USERPROFILE%\.agents\skills\vertical-talking-head-edit\SKILL.md`。这是 Codex 当前的个人 skill 目录。也可以放到项目内的 `<项目>\.agents\skills\`。

`$skill-installer` 目前仍会安装到旧目录 `%USERPROFILE%\.codex\skills\`，该目录也仍会被扫描。两处都放会出现两个同名 skill，只放一处。加完后重启 Codex，用 `/skills` 确认能看到。

### 依赖

以下内容概括自 `vertical-talking-head-edit/references/windows_env.md` 的自检清单，开工前需要准备：

- **ffmpeg 完整版**（推荐 gyan.dev full build）：滤镜需有 `zscale`、`tonemap`、`afftdn`、`sidechaincompress`、`loudnorm`、`ebur128`、`blackdetect`、`freezedetect`，编码器需有 `prores_ks`、`libx264`。
- **Python 3.10 或 3.11**。pyJianYingDraft 自动导出依赖的 uiautomation 在 3.13 上可能出问题。
- **听写**：faster-whisper 与 whisperX 分别装在两个独立环境，模型已下载，各自环境里能 `import`。
- **特效层**：安装 Playwright 后执行 `python -m playwright install chromium`，渲染一帧时中文是目标字体。目标字体已安装，或在 CSS 里用 `@font-face` 指向字体文件。
- **可选**：demucs、onnxruntime / torch（RVM）。能导入即可；没有就用剪映「智能抠像」。
- **剪映草稿目录**：在剪映「全局设置」的草稿位置中查到并写入配置，目录存在且可写。

Codex 默认使用原生 PowerShell 与 Windows 沙箱。`workspace-write` 模式下网络默认关闭：安装依赖、下载 Whisper / whisperX / RVM 模型前要提前装好，或在 `config.toml` 里临时打开 `sandbox_workspace_write.network_access`。写入工作区外的剪映草稿目录时，把该目录加入 `writable_roots`。

### 待验证

标有「待验证」的条目还没有在真实 Windows 机器上测试过。首次实测时，按 `vertical-talking-head-edit/references/windows_env.md` 里的「Windows 首次实测清单」逐项确认，通过后再去掉对应标记。
