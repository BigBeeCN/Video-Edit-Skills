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
- 写剪映草稿目录这类工作区外的路径，要加可写目录（建议正斜杠；待验证）：
  ```toml
  [sandbox_workspace_write]
  writable_roots = ["C:/你的/剪映草稿目录"]
  ```
  项目级 `.codex/config.toml` 只在项目被信任时加载。
- 沙箱里能否正常跑 ffmpeg、CUDA 版 torch：官方没专门说明，待验证。若 CUDA 在沙箱里不可用，GPU 步骤在沙箱外跑或回退 CPU。模型缓存（`%USERPROFILE%\.cache`）要么在 `writable_roots` 里，要么在沙箱外先下好。

## 自检清单（不过不开工）
| 项 | 检查 | 通过标准 |
|---|---|---|
| ffmpeg 完整版 | `ffmpeg -hide_banner -filters`、`-encoders` | 有 `zscale`、`tonemap`、`afftdn`、`sidechaincompress`、`loudnorm`、`ebur128`、`blackdetect`、`freezedetect`，编码器有 `prores_ks`、`libx264`（推荐 gyan.dev full build） |
| Python | `python --version` | 3.10 或 3.11（pyJianYingDraft 自动导出依赖的 uiautomation 在 3.13 上可能出问题） |
| 听写 | faster-whisper 和 whisperX 装在两个独立环境，分别在各自环境里 `python -c "import faster_whisper"`、`python -c "import whisperx"` | 都能导入，模型已下载 |
| 特效层 | `python -m playwright install chromium` 后渲染一帧 | 截图里中文是目标字体，不是宋体/雅黑顶替 |
| 字体 | 目标字体已安装，或 CSS 用 `@font-face` 指向字体文件 | 同上 |
| 可选 | demucs、onnxruntime / torch（RVM） | 能导入；没有就用剪映「智能抠像」 |
| 沙箱内可执行 | 在 Codex 沙箱里跑 `ffmpeg -version`、`python --version` | 都能输出版本（待验证） |
| 剪映草稿目录 | 剪辑师在剪映「全局设置」的草稿位置里查到并填进配置 | 目录存在且可写 |

## Windows 特有的坑
- 中文路径和空格：脚本统一用 Python `subprocess.run([...参数列表...])` 调 ffmpeg，不拼命令字符串（这是通用 Python 惯例，不是 Codex 官方要求）。PowerShell 里 `$` 会被当变量，filtergraph 用单引号。
- 编码：Windows 默认可能是 GBK，所有 `open()` 显式写 `encoding='utf-8'`，`subprocess.run(..., encoding='utf-8', errors='replace')`。
- 丢弃输出统一写 `-f null -`（两个平台都能用）。
- ffmpeg 滤镜里写 Windows 路径（字体、ass 字幕）要转义冒号：`C\:/Windows/Fonts/xxx.ttc`。
- concat 列表用正斜杠；网页地址用 `Path(...).as_uri()`。
- multiprocessing 在 Windows 是 spawn：脚本入口必须有 `if __name__ == '__main__':`，先用单进程跑通。
- 脚本里不要写死 `/tmp`、字体目录、素材根目录，全部做成配置项。
- whisperX 首次会下载 nltk 分句模型，网络关着会失败：每段本来就是一句时，可换成“整段当一句”的分句器。
- RVM 走 torch.hub 要从 GitHub 拉模型，拉不下来就用 onnx 版或剪映「智能抠像」。

## Windows 首次实测清单（跑一条完整测试片时逐项确认，通过后去掉对应「待验证」）
| 项 | 测法 | 通过标准 |
|---|---|---|
| 命令移植 | 同一份 spec 在 Windows 与已跑通的环境各出一版 | 帧数一致，响度相差 ≤0.2 LU，帧差与冻帧检查结果一致 |
| ffmpeg 滤镜 | `ffmpeg -hide_banner -filters \| findstr "zscale afftdn sidechaincompress loudnorm"`；`ffmpeg -hide_banner -encoders \| findstr prores_ks` | 五项都列出 |
| 路径与编码 | concat 列表用正斜杠跑一次；看 stderr 解析和 `as_uri()` 结果 | 能拼接；JSON 解析正常；URL 形如 `file:///C:/...` |
| 特效层 | 渲染一帧高光段，与参考 QC 帧对比 | 中文字体一致、无方框字，透明区确实透明 |
| 可写目录 | 草稿目录加进 `writable_roots` 后，在沙箱里往该目录写一个文件 | 不弹批准且写入成功 |
| 沙箱内 GPU | 沙箱里跑 `ffmpeg -version`、`python -c "import torch; print(torch.cuda.is_available())"`，再转一段 5 秒片子 | 三项都正常 |
| 安装 | 两个环境各自 import；CUDA 版跑完 10 秒素材 | 不报缺 DLL，模型缓存目录可写 |
| 剪映草稿 | 在剪辑师的 Windows 剪映上打开脚本新建的草稿。核对主文件是 `draft_content.json` 还是 `draft_info.json`；每条特效的 alpha 短片是否真透明；素材路径是不是这台机器上的 Windows 路径。加密只影响读取，生成不需要解密 | 草稿能打开。口播分段、空镜分轨、字幕、分轨音频都能改。alpha 不对就改走 PNG 序列，或合成进画面。结果写回 `jianying_route.md`。通过前这一步保持「待验证」 |
| 起音前 ≤67 ms | 平台无关：剪点量到首字起音（能量首次超过 max(p10+14 dB, −48 dBFS) 的 10 ms 窗口） | 全部 ≤67 ms 且试听不吞字头，才改为默认；否则保持 ≤90 ms |

固定语法，直接当规则用：cmd 的 `.bat` 里 `%05d` 写成 `%%05d`；ffmpeg 滤镜里的盘符冒号写成 `C\:/`；多进程脚本入口加 `if __name__ == "__main__":`。
