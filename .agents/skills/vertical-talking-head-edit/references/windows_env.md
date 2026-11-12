# Windows 环境（Codex + 剪映）

> 已核实的条目附来源方向；标「待验证」的要在目标机器上实测一次再去掉标记。完整命令对照见 `windows_commands.md`。

## 安装这个 skill
- 个人级：`%USERPROFILE%\.agents\skills\vertical-talking-head-edit\SKILL.md`（Codex 官方当前位置）；仓库级：`<项目>\.agents\skills\`。
- 旧位置 `%USERPROFILE%\.codex\skills\` 仍会被扫描；内置 `$skill-installer` 目前还装到这里。两处都放会出现两个同名 skill，只放一处。
- 加完重启 Codex，用 `/skills` 确认能看到；可用 `$vertical-talking-head-edit` 点名调用，也会按 description 自动触发。
- 硬规则放项目根目录 `AGENTS.md`（内容见 `AGENTS_rules.md`）。AGENTS.md 每次开场都加载，默认合计上限约 32 KiB，所以只放规则；skill 按需加载，放流程。

## Codex 运行方式
- 默认用原生 PowerShell + Windows 沙箱（官方推荐），WSL 只是备选。一条流水线只用一种环境；若用 WSL，写进剪映草稿的路径要用 `wslpath -w` 转成 `C:\...`。
- `workspace-write` 模式下网络默认关闭：装依赖、下载 Whisper / whisperX / RVM 模型前，要么提前装好，要么在 `config.toml` 里临时打开：
  ```toml
  [sandbox_workspace_write]
  network_access = true
  ```
- 写剪映草稿目录这类工作区外的路径，要加可写目录（建议正斜杠），然后重启 Codex：
  ```toml
  [sandbox_workspace_write]
  writable_roots = ["C:/你的/剪映草稿目录"]
  ```
  项目级 `.codex/config.toml` 只在项目被信任时加载。
- 沙箱写文件（已验证失败的那一半）：桌面版这次是 `[windows] sandbox = "elevated"`，配置里没有 `writable_roots`。写工作区以外直接 `Access is denied`，不弹批准。工作区本身在只读沙箱里也不能写；调用时带 `require_escalated` 之后，工作区可以写。配上 `writable_roots` 并重启之后，草稿目录能不能写成，这次没复测，待验证。
- 沙箱里能否跑 CUDA 版 torch：这次没装 torch，待验证。若 CUDA 在沙箱里不可用，GPU 步骤在沙箱外跑或回退 CPU。模型缓存（`%USERPROFILE%\.cache`）要么在 `writable_roots` 里，要么在沙箱外先下好。沙箱里跑 `ffmpeg -version` 和解码到 `-f null -` 是可以的。

## 自检清单（不过不开工）
| 项 | 检查 | 通过标准 |
|---|---|---|
| ffmpeg 完整版 | 先 `where.exe ffmpeg`。再对这一份跑 `ffmpeg -hide_banner -filters`、`-encoders` | 有 `zscale`、`tonemap`、`afftdn`、`sidechaincompress`、`loudnorm`、`ebur128`、`blackdetect`、`freezedetect`，编码器有 `prores_ks`、`libx264`。用 gyan.dev full build，或项目 `tools` 目录里的便携完整版。剪映安装目录里的 `ffmpeg.exe` 没有 zscale、也没有 libx264，不能算通过 |
| Python | `where.exe python`，再 `python --version`。不要用 Microsoft Store 的占位 `python.exe` | 3.10 或 3.11（这次用过便携版 3.11）。pyJianYingDraft 自动导出依赖的 uiautomation 在 3.13 上可能出问题。便携版放在项目 `tools` 目录即可，不必写进系统 PATH，但自检要指向这一份 |
| 听写 | faster-whisper 和 whisperX 装在两个独立环境，分别在各自环境里 `python -c "import faster_whisper"`、`python -c "import whisperx"` | 都能导入，模型已下载 |
| 特效层 | `python -m playwright install chromium` 后渲染一帧 | 截图里中文是目标字体，不是宋体/雅黑顶替 |
| 字体 | 目标字体已安装，或 CSS 用 `@font-face` 指向字体文件 | 同上 |
| 可选 | demucs、onnxruntime / torch（RVM） | 能导入；没有就用剪映「智能抠像」 |
| 沙箱内可执行 | 在 Codex 沙箱里跑 `ffmpeg -version`、`python --version` | 都能输出版本。`ffmpeg -version` 已在沙箱里跑通；写输出文件见上面的 `writable_roots` / `require_escalated` |
| ProRes 4444 | `ffprobe` 看 profile 和 `pix_fmt` | `profile=4444`，并且 `pix_fmt` 是 `yuva444p12le` 或 `yuva444p10le`。ffmpeg 7.1 解出来是 `yuva444p12le`，不要因为不是 10le 判失败 |
| 剪映草稿目录 | 剪辑师在剪映「全局设置」的草稿位置里查到并填进配置 | 目录存在且可写 |

## Windows 特有的坑
- 中文路径和空格：脚本统一用 Python `subprocess.run([...参数列表...])` 调 ffmpeg，不拼命令字符串（这是通用 Python 惯例，不是 Codex 官方要求）。PowerShell 里 `$` 会被当变量，filtergraph 用单引号。
- 编码：Windows 默认可能是 GBK，所有 `open()` 显式写 `encoding='utf-8'`，`subprocess.run(..., encoding='utf-8', errors='replace')`。
- 丢弃输出统一写 `-f null -`（两个平台都能用）。
- ffmpeg 滤镜里写 Windows 路径（字体、ass 字幕）：盘符冒号写成 `C\:/`，并且 `fontfile` 的值整体用单引号包住。已验证的写法是 `fontfile='C\:/Windows/Fonts/msyh.ttc'`。只转义、不加引号，会报 `No option name`。
- concat 列表用正斜杠；网页地址用 `Path(...).as_uri()`。
- multiprocessing 在 Windows 是 spawn：脚本入口必须有 `if __name__ == '__main__':`，先用单进程跑通。
- 脚本里不要写死 `/tmp`、字体目录、素材根目录，全部做成配置项。
- whisperX 首次会下载 nltk 分句模型，网络关着会失败：每段本来就是一句时，可换成“整段当一句”的分句器。
- RVM 走 torch.hub 要从 GitHub 拉模型，拉不下来就用 onnx 版或剪映「智能抠像」。

## Windows 首次实测清单（跑一条完整测试片时逐项确认，通过后去掉对应「待验证」）
| 项 | 测法 | 通过标准 |
|---|---|---|
| 命令移植 | 同一份 spec 在 Windows 与已跑通的环境各出一版 | 帧数一致，响度相差 ≤0.2 LU，帧差与冻帧检查结果一致。整份对照还没做，待验证。单段重编码（`-ss` 在 `-i` 前、`-frames:v`、libx264）在 Windows 上出过 1.000 秒、30 帧 |
| ffmpeg 滤镜 | 对完整版跑 `ffmpeg -hide_banner -filters`，确认 zscale、afftdn、sidechaincompress、loudnorm；`-encoders` 确认 prores_ks、libx264 | 已验证：完整版有这些项。剪映自带的 ffmpeg 缺 zscale 和 libx264，不能算通过 |
| 路径与编码 | concat 列表用正斜杠跑一次；`drawtext` 的 fontfile；`.bat` 里的序列号；`as_uri()` | 已验证：正斜杠 concat 能接上；`fontfile='C\:/Windows/Fonts/msyh.ttc'` 能写出中文；`.bat` 里要 `%%05d`；`Path.resolve().as_uri()` 得到 `file:///C:/...`；中文 JSON 用 utf-8 能往返 |
| 特效层 | 渲染一帧高光段，与参考 QC 帧对比 | 已验证：Playwright Chromium 能截透明 PNG，再编成 ProRes 4444（`yuva444p12le`）。和参考 QC 帧对过没有，待验证 |
| 可写目录 | 草稿目录加进 `writable_roots` 后重启，在沙箱里往该目录写一个文件 | 没配 `writable_roots` 时直接 Access denied、不弹批准（已验证）。配上并重启后的成功写入没复测，待验证。工作区在 `require_escalated` 之后可以写（已验证） |
| 沙箱内 GPU | 沙箱里跑 `ffmpeg -version`、`python -c "import torch; print(torch.cuda.is_available())"`，再转一段 5 秒片子 | `ffmpeg -version` 已通过。torch 没装，待验证。沙箱里写 5 秒片子的输出文件会被拒绝，除非提权或目录在可写范围内 |
| 安装 | 两个听写环境各自 import；CUDA 版跑完 10 秒素材 | 待验证。这次只装了便携 Python、pyJianYingDraft、Playwright，没装 whisper / whisperX / demucs / torch |
| 剪映草稿 | 见 `jianying_route.md` | 主文件、绝对路径、ProRes/PNG 透明、剪映文本和分色、口播变速、音效分轨、明文草稿能打开：已验证。分屏位置、空镜拖换、音乐闪避关键帧、剪映点导出：待验证 |
| 起音前 ≤67 ms | 剪点的源时间用 `source_timerange.start`，不要用 `target_timerange.start`。能量阈值 max(p10+14 dB, −48 dBFS)，连续 3 个 10 ms 窗口 | 能量口径已通过：29/29 ≤67 ms，最大 40 ms。量的是已经降噪压缩的人声，没有 demucs，也没有试听。听感确认字头没被切掉之前，不把 ≤67 ms 改成默认，仍用两侧静音合计 ≤90 ms |

固定语法，直接当规则用：cmd 的 `.bat` 里 `%05d` 写成 `%%05d`（已验证）；`fontfile='C\:/Windows/Fonts/msyh.ttc'`（已验证）；多进程脚本入口加 `if __name__ == "__main__":`（这条还没在 Windows 上跑多进程，待验证）。
