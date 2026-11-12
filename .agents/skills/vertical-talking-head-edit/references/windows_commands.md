# 命令对照：Linux 实测命令 → Windows 写法

来源：Linux 上实际跑通过的脚本（ffmpeg 7.1、Playwright 1.65、whisperX 3.8 + torch 2.8，均在 CPU 上运行）。标「未验证」的 Windows 写法尚未在实机跑过。


标记说明：
- **「未验证」**：这条 Windows 写法没有在 Windows 上跑过。
- **「平台无关」**：纯 Python/numpy/wave/cv2 代码，不调用外部程序，也不涉及路径格式。
- 推荐做法：在 Windows 上一律用 **Python `subprocess.run([...参数列表...])`** 调 ffmpeg，不要拼一整条字符串交给 PowerShell。我们的脚本本来就是参数列表写法，移到 Windows 时基本只需要改路径。

---


## 1. ffprobe 检查：VFR、旋转、HDR/HLG

**Linux 实际（`work/inv.py`）**，用 Python 参数列表：
```python
j=json.loads(subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',f],capture_output=True,text=True).stdout)
# 旋转：v['side_data_list'][*]['rotation']
# VFR：|r_frame_rate - avg_frame_rate| > 0.05 判为 'yes'
# HDR：color_transfer == 'arib-std-b67' → HLG；'smpte2084' → PQ；否则 SDR
```
模板里也有同样的判断（`lib/common.py`）：
```python
def is_hdr(path): return probe(path).get('color_transfer') in ('arib-std-b67','smpte2084')
# probe = ffprobe -v error -select_streams v:0 -show_streams -of json <path>
```

**Windows 对应**
- Python：同一段代码可以直接用，只是 `f` 要换成 Windows 路径，例如 `r'D:\素材\IMG 094102.MOV'`。「未验证」
- PowerShell 单条：「未验证」
  ```powershell
  & ffprobe -v error -show_streams -show_format -of json "D:\素材\IMG 094102.MOV" | ConvertFrom-Json
  ```
- 判断逻辑本身（比较 r/avg 帧率、看 side_data 旋转、看 color_transfer）是「平台无关」的。

---

## 2. 规范化：CFR 30fps，HLG→SDR

**Linux 实际**：我们**没有**先转一份中间文件。每次读素材时，都在滤镜链里同时做 CFR、HDR 转 SDR、缩放和裁切（`lib/common.py`）：
```python
HDR="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p,eq=gamma=1.12:saturation=1.08,"
def vf_cover(path,zoom=1.0,ypos='(ih-1920)/2',extra=''):
    tw,th=int(round(W*zoom/2)*2),int(round(H*zoom/2)*2)
    return (HDR if is_hdr(path) else '')+f"fps={FPS},scale={tw}:{th}:force_original_aspect_ratio=increase:flags=lanczos,crop={W}:{H}:(iw-{W})/2:{ypos},setsar=1{extra}"
```
- 口播镜头的 `ypos='(ih-1920)*0.2'`（偏上，留住头部）；B-roll 用居中裁切 `(ih-1920)/2`。
- 素材接触表（`minisheet.py`）里同一条转换用的是 `npl=203`，模板用的是 `npl=100` 再加 `eq=gamma=1.12:saturation=1.08`。成片以模板为准。

**Windows 对应**
- Python 参数列表：同一个滤镜字符串可以直接用。「未验证」
- **前提是 ffmpeg 必须带 zimg（zscale 滤镜）**。推荐 gyan.dev 的 *full* build（essentials 版可能不带）。先自检：「未验证」
  ```powershell
  & ffmpeg -hide_banner -filters | Select-String "zscale|tonemap"
  ```
  如果没有 zscale，HLG 素材会报错，或者直接按 SDR 处理导致画面发灰（见坑 7）。
- 如果 Skill 需要先输出 CFR 的中间文件（我们没有这样做），可以写成下面这样（用上面同一个 vf 字符串，PowerShell 里用单引号包住）。这条我们没跑过：「未验证」
  ```powershell
  & ffmpeg -y -i "D:\素材\in.MOV" -vf '<同上 vf_cover 字符串>' -c:v libx264 -crf 12 -preset veryfast -an "D:\work\in_cfr30.mp4"
  ```

---

## 3. 识别：Whisper → whisperX 逐字强制对齐（CPU）

### 3a. 抽音频
**Linux 实际**
- 模板 `lib/common.py` 的 `audio48`：
  ```python
  ['ffmpeg','-v','error','-y','-i',src,'-map','0:a:0','-ac','1','-ar','48000','-c:a','pcm_s16le',out_wav]
  ```
- 识别脚本（`catalog/work/asr_x.py`、`asr_long.py`）直接用管道送 16k 音频：
  ```python
  ['ffmpeg','-v','error','-i',p,'-map','0:a:0','-ac','1','-ar','16000','-f','s16le','-']
  ```
- 注意：`work/a48/*.wav` 是更早生成的，生成它的命令没有留在脚本里。模板里与之等价的是 `audio48`。

**Windows**：参数列表不用改，只改路径。「未验证」

### 3b. Whisper 初识别
**Linux 实际（`work/asr.py`，faster-whisper）**
```python
m=WhisperModel('medium',device='cpu',compute_type='int8',cpu_threads=6)
segs,info=m.transcribe(a,language='zh',word_timestamps=True,vad_filter=True,
    initial_prompt='以下是普通话的句子，关于塑料助剂、改性塑料、颗粒、挤出、配方、工厂。')
```
- 长口播另跑一版不开 VAD 的（`asr_nv.py`）：`vad_filter=False, condition_on_previous_text=False`。
- 用 whisperX 做整段识别的写法（`template/work/highlight/wx_full.py`）：
  ```python
  m=whisperx.load_model("medium",device="cpu",compute_type="int8",language="zh",vad_method="silero")
  r=m.transcribe(audio,batch_size=4,language="zh")
  ```

### 3c. whisperX 强制对齐（逐字时间）
**Linux 实际（`wx_align_hl.py`，用 `<venv>/python` 运行）**
```python
import whisperx.alignment as A
class _One:
    def span_tokenize(self,t): return [(0,len(t))]
A.nltk_load=lambda *a,**k:_One()   # 离线环境下载不到 NLTK punkt_tab；每段本来就是一句，直接整段当一句
audio=whisperx.load_audio('work/a48/094102.wav')
segs=[{"start":41.3,"end":43.8,"text":"实习第一天面销售岗"}, ...]   # 文字是人工校对过的原话
m,meta=whisperx.load_align_model(language_code="zh",device="cpu")   # 中文默认模型 jonatasgrosman/wav2vec2-large-xlsr-53-chinese-zh-cn
r=whisperx.align(segs,m,meta,audio,"cpu",return_char_alignments=True)
```
- 运行时会打印 torchcodec 警告，不影响结果（音频用的是 `whisperx.load_audio`）。
- 字的**结束时间不可靠**，出点要按能量判断（见第 5 步）。

### 3d. 人工校对（必须做）
实测例子：
- 094102 的「实习第一天 面销售岗」被识别成「实习第一天面销售**赶**」（岗→赶）。
- 同一条素材 0.73–28.46s 的那一段里，还冒出一段他根本没说过的「试骑第一天」。

做法：先校对文字，再把校对后的文字送进 `whisperx.align` 做对齐。字幕和大字一律用校对后的原话。

### Windows 对应
- 上面的 Python 代码本身「平台无关」。但 whisperX、torch、faster-whisper 在 Windows 上的安装我们没做过：「未验证」
  ```powershell
  python -m venv venv_wx; .\venv_wx\Scripts\Activate.ps1; pip install whisperx
  ```
- **CUDA 还是 CPU**：
  - 我们全部用 `device="cpu", compute_type="int8"`。
  - Windows 上有 NVIDIA 显卡时，可以改成 `device="cuda", compute_type="float16"`。这需要装和 CUDA 版本匹配的 torch，faster-whisper 用的 ctranslate2 还需要 cuBLAS/cuDNN 的 DLL。「未验证」
  - 没有显卡就保持 CPU 设置，代码不用改。
- NLTK 的替身写法在 Windows 上照样有效（纯 Python）。「平台无关」
- 模型缓存位置：Linux 是 `~/.cache/huggingface` 和 `~/.cache/torch/hub`；Windows 对应 `%USERPROFILE%\.cache\...`。「未验证」

---

## 4. 剪辑单（spec JSON）字段

**Linux 实际**：两套剪辑单格式。

**(a) 完整成片**：`specs/v1_xiachejian_packaged.v2.json`，由 `render.py` 读取。
- 顶层字段：`spec_version, root, name, raw_dirs, words, caption, safe, sfx_db, segments, hook, chapters, progress, transitions, punch, emoji, bignum, glow, quotes, blush, hearts, cta, music, variants, cover`
- 每段（segment）的字段：`src, in, out, text, kw, layout(full|broll|cutout|circle|bg), zoom, origin, bg, bg_in, stroke, gate_y, gate_feather, fg_offset, circle, arc, dur, kwstyle, kw_sfx, char_sfx, char_sfx_db`
- 例子：
  ```json
  {"src":"094102","in":36.89,"out":39.8233,"text":"我终于明白/王总为什么让我下车间了","kw":["下车间"],"layout":"full","zoom":1.0,"origin":"real"}
  ```

**(b) 高光测试**：`specs/highlight_test_v2.json`，由 `highlight.py` 读取。
- 顶层字段：`name, raw_dirs, align, safe, avoid_talk, segments, hook, hits, jumpcut_punch, broll_in, music, climax_composite`
- 每段字段：`src, in, out, kind(hook|talk|broll), bg, text, fx[], zoom, whip_in, hide_sub`
- `fx` 的类型：`big`、`subcircle`、`tmask`、`counter`
- `hook` 里有 `label, matte, freeze, freeze_start_frame, freeze_src_frame, chair_erase, punch, shake_frames, bg_dark, sfx_db`
- `safe` = `{"x0":90,"x1":930,"y0":200,"y1":1540}`；`avoid_talk` 是 logo 避让带，例如 `[[0,712,1080,812]]`
- `music` 是一个列表：`[{"file":".../bed_calm_96bpm.wav","db":-14,"from":0,"to":"seg6","xfade":0.5}, ...]`

素材按文件名里的时间码查找（`lib/common.py` 的 `srcpath`）：
```python
glob(os.path.join(d,f'* {code}.*'))
```
即文件名形如 `XXX 094102.MOV`，中间有空格。

**Windows**
- JSON 本身「平台无关」。
- `raw_dirs`、`music.file` 里的 Windows 路径在 JSON 里要写成 `"D:/素材/261031"`（正斜杠）或 `"D:\\素材\\261031"`（双反斜杠）。「未验证」
- JSON 文件要存成 UTF-8；Python 读的时候写 `open(p,encoding='utf-8')`。我们的脚本没写 encoding，在 Linux 上默认就是 UTF-8，在 Windows 上默认可能是 GBK（见坑 1）。「未验证」

---

## 5. 剪辑：逐帧精确的重编码切点，换气空隙剪到 0

**Linux 实际**

逐段重编码，不用 `-c copy` 切（`lib/base.py` 的 `seg_full`）：
```python
['ffmpeg','-v','error','-y','-ss',str(t0),'-i',src,'-frames:v',str(nf),'-vf',vf,'-an',
 '-c:v','libx264','-preset','veryfast','-crf','12','-color_primaries','bt709','-color_trc','bt709','-colorspace','bt709',out]
```
- 用 `nf=round((out-in)*30)` 帧数来定长度，不用时长；然后把出点改成 `in+nf/30`。
- 旧版 `work/render.py` 额外加了 `-g 30 -bf 0 -r 30`。
- 各段再用 concat 拼起来（拼接前每段都已重编码成同样参数）：
  ```python
  ['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i','list.txt','-c','copy','base.mp4']
  ```
  其中 `list.txt` 每行是 `file '<绝对路径>'`。
- `highlight.py` 不切文件：它用 `read_frames` 通过 rawvideo 管道逐帧读进 numpy，合成后用 `writer()` 写出（libx264 crf 12）。

换气空隙的处理：
- 入点和出点按能量裁（`lib/common.py` 的 `refine`）：每 10ms 一个窗口，阈值是 `max(第10百分位+14 dB, -48 dB)`，要求连续 3 个窗口有声；前留 0.10s，后留 0.14s。最后再人工逐段收紧。
- 每段音频首尾加 8ms 淡入、15ms 淡出（`build_audio`）。
- 检查：`tools_hl_onset.py` 测每个切点两侧低于 −42 dBFS 的连续长度，要求 ≤90ms。
  - 高光测试 v1 实测：先是 180/250/190ms，收紧入出点后变成 0/0/0/60/80ms。
  - 例外：v2 在「螺丝」之后有一段**故意保留**的 0.4s 定格停顿，该切点测出 490ms。

**Windows**
- 参数列表照用。「未验证」
- `list.txt` 里的 Windows 路径建议写成正斜杠 `file 'D:/work/seg001.mp4'`。路径里有单引号要转义成 `'\''`。「未验证」
- 能量计算代码「平台无关」。

---

## 6. 包装层渲染：HTML/Canvas → Playwright Chromium → PNG 序列 → 带透明通道的 ProRes 4444

**Linux 实际（`lib/overlay.py`）**
```python
b=p.chromium.launch(executable_path=os.environ.get('CHROME','/usr/bin/google-chrome'),
    args=['--no-sandbox','--font-render-hinting=none','--disable-gpu','--allow-file-access-from-files'])
pg=b.new_page(viewport={'width':1080,'height':1920},device_scale_factor=1)
pg.add_init_script('window.TL='+json.dumps(tl,ensure_ascii=False)+';')
pg.goto('file://'+os.path.abspath(html)); pg.wait_for_function('window.READY===true'); pg.evaluate('document.fonts.ready')
# 逐帧：
pg.evaluate(f'renderFrame({t},"{mode}")')   # 模式：overlay / mid（人物后面的字）/ glyph / mask
pg.screenshot(path=f'{f:05d}.png', omit_background=(mode not in ('mask','glyph')))   # omit_background=True → RGBA 透明 PNG
```
- 用 `multiprocessing.Pool(workers)` 把帧分给几个进程并行截图。
- 每帧调用 `checkSafe()` 做安全区检查。

ProRes 4444 带透明通道（`render.py --prores` 和 `highlight.py` 用的是同一组参数）：
```python
['ffmpeg','-v','error','-y','-framerate','30','-i','overlay/%05d.png',
 '-c:v','prores_ks','-profile:v','4444','-pix_fmt','yuva444p10le','-alpha_bits','16','<name>_overlay_prores4444.mov']
```
- 一条命令出片：`python3 render.py specs/xxx.json --workers 4 --prores`
- 高光测试：`python3 highlight.py specs/highlight_test_v2.json`

**Windows**
- 装 Playwright 和浏览器：「未验证」
  ```powershell
  pip install playwright; python -m playwright install chromium
  ```
  装好后可以不传 `executable_path`，直接用 Playwright 自带的 Chromium；或者设环境变量 `$env:CHROME="C:\Program Files\Google\Chrome\Application\chrome.exe"`。
- `'file://'+os.path.abspath(html)` 在 Windows 上会拼出 `file://C:\...`，这是错误的 URL。要改成 `pathlib.Path(html).resolve().as_uri()`，得到 `file:///C:/...`。「未验证」
- **`multiprocessing` 在 Windows 上用 spawn 方式启动子进程**，所以 `render.py` 和 `highlight.py` 的顶层代码必须包进 `if __name__=='__main__':`。我们现在的脚本没有包，在 Windows 上一定要改，否则子进程会重新执行整个脚本。「未验证」
- ProRes 那条参数列表照用；gyan.dev 的 build 带 `prores_ks`。「未验证」
- 剪映：ProRes 4444 的 .mov 能不能在剪映里保留透明通道，我们没有验证。备选方案是直接导入 PNG 序列，或者先在 ffmpeg 里合成好再导入。「未验证」

---

## 7. 抠像：RVM（实际用的就是这个；MediaPipe 我们没用过）

**Linux 实际**

(a) 高光钩子用 RVM resnet50（PyTorch torch.hub，CPU），沿用 Video Editor 的方法（`rvm.py`）：
```python
m=torch.hub.load('PeterL1n/RobustVideoMatting','resnet50',trust_repo=True).eval(); torch.set_num_threads(8)
fgr,pha,*rec=m(x,*rec,downsample_ratio=0.25)     # 循环状态 rec 逐帧往下传
```
- 模板封装成命令行（`tools_rvm_torch.py`，用 venv_wx 的 python）：
  ```bash
  <venv>/python tools_rvm_torch.py "<源文件>" 46.09 56 "<与 vf_cover 完全相同的 vf>" work/highlight/hook_matte_v2.npy 30
  ```
- 最后一个参数 30 是预热帧数：从 t0 往前 30 帧开始跑，前 30 帧的结果丢掉。vf 必须和合成时读帧用的 vf 完全一致，抠像结果才能逐像素对齐；实测新旧两次 matte 的前 44 帧差值为 0。
- 实测速度：74 帧约 11s（8 线程 CPU）。

(b) 旧模板 `lib/base.py` 用 ONNX 版 RVM（`models/rvm_mobilenetv3_fp32.onnx`，onnxruntime CPUExecutionProvider，downsample 0.4）。

去椅子（`highlight.py`）：
```python
gate=np.ones((H,W),np.float32)
for x0,y0,x1,y1 in hk['chair_erase']: gate[y0:y1,x0:x1]=0   # [[870,930,1080,1290],[0,1470,340,1920],[0,1640,1080,1920]]
gate=cv2.GaussianBlur(gate,(0,0),6)
m=mf*gate                                   # mf = 完整抠像
d=cv2.dilate((m>0.5).astype(np.uint8),cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(25,25))).astype(np.float32)
ol=np.clip(cv2.GaussianBlur(d,(0,0),1.5)-mf,0,1)   # 减去“完整”抠像：椅子切口处不会画出直线
```
- 人物层用完整抠像，不调色；白描边用的是擦掉椅子后的抠像。
- 抠像只用在开场钩子；文字遮罩转场不用抠像。

**Windows**
- torch.hub、numpy、cv2 部分「平台无关」。但 torch 的 Windows 安装和 `~/.cache/torch/hub` 缓存我们没测过。「未验证」
- `tools_rvm_torch.py` 用 ffmpeg 管道读帧，参数列表照用。「未验证」
- 如果 Skill 想改用 MediaPipe 做人像分割：我们**没有实际用过**，无法给出命令。

---

## 8. ffmpeg 叠加合成

**Linux 实际（`render.py` 和 `highlight.py` 的 final 阶段）**
```python
['ffmpeg','-v','error','-y','-i','base.mp4','-framerate','30','-i','overlay/%05d.png','-i','mix.wav',
 '-filter_complex','[0:v]eq=contrast=1.03:saturation=1.05[b];[b][1:v]overlay=0:0:format=auto:shortest=1,format=yuv420p[v]',
 '-map','[v]','-map','2:a', <第 10 步的导出参数>, '-t',str(T), out_mp4]
```
- `render.py` 的调色默认值是 `eq=contrast=1.04:saturation=1.07`；高光测试用 1.03/1.05。
- 人物后面的字、黑白背景、描边、文字遮罩、甩镜、推镜和抖动，都在 numpy/cv2 里做完，写进 `base.mp4`，不在 ffmpeg 里做。

**Windows**
- 参数列表照用。「未验证」
- PNG 序列的 `%05d` 在 PowerShell 里不需要转义；但在 cmd 的 `.bat` 文件里要写成 `%%05d`。「未验证」

---

## 9. 音频：降噪 → 闪避（ducking）→ 音效混音 → 合成一击 → 响度归一 −14 LUFS（两遍）

**Linux 实际（`lib/base.py` 的 `build_audio`）**

人声链：
```
highpass=f=80,afftdn=nf=-25:nr=10,equalizer=f=3500:t=q:w=1:g=2,acompressor=threshold=-22dB:ratio=3:attack=5:release=120:makeup=2
```

多段音乐：每段 `-stream_loop -1 -i file`，然后：
```
atrim, asetpts, lowpass=f=9000, volume, afade 进/出, adelay
```
多段之间用 `amix` 混合，段与段之间交叉淡化。

闪避：
```
[vo]asplit[v1][v2];[m][v2]sidechaincompress=threshold=0.04:ratio=6:attack=15:release=350[md];[v1][md]amix=inputs=2:normalize=0:duration=first[mx0]
```

音效：
- `build_sfx` 在 numpy 里把各事件混成 `sfx.wav`，再用 `amix=inputs=2:normalize=0` 混进去。
- 电平是**相对人声**的：`db=-14` 表示音效 RMS 比人声有声段 RMS 低 14 dB。
- 音效文件由 `lib/sfx.py` 合成（boom、whoosh、scribble、counter、stamp 等，48k 单声道），不使用外部素材。

合成一击（v2）：
- `highlight.py` 把 boom（0s，−11）、counter（+0.1s，−14）、stamp（+0.603s，−12）按各自原来的电平叠成一个文件 `assets/sfx/climax_<name>.wav`，作为**一个**音效事件放进时间线。
- 文件做了峰值归一，所以要用 `dbc=_xr(file)-20*log10(c)` 把电平补回去。

响度（两遍 loudnorm + 限幅 + 增益修正）：
```python
# 第 1 遍：测量
fc+';[mix]loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json[o]'  → '-f','null','-'
# 第 2 遍：用测量值，linear 模式
"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I=..:measured_TP=..:measured_LRA=..:measured_thresh=..:offset=..:linear=true,aresample=48000,alimiter=limit=0.7:attack=1:release=30:level=false"
# 第 3 步：ebur128 复测，增益 g=min(-14-I, -2.9-Peak)；|g|>0.1 时再用 volume={g}dB 修正一次
['ffmpeg','-hide_banner','-i',mix,'-af','ebur128=peak=true','-f','null','-']
```
- 实测：高光测试 v1 是 −14.0 LUFS / −4.1 dBTP；v2 是 −14.0 LUFS / −4.0 dBTP。

**Windows**
- 滤镜链照用；gyan.dev full build 带 afftdn、sidechaincompress、loudnorm。「未验证」
- 输出到 `-f null -` 时，用 `-` 两个平台都能用（我们一直这样写）。Windows 上也可以写 `-f null NUL`。「未验证」
- loudnorm 的 JSON 我们是从 stderr 里截取的：`r.stderr[r.stderr.rfind('{'):r.stderr.rfind('}')+1]`。Windows 上 stderr 可能带 `\r\n`，并且要用 `text=True, encoding='utf-8', errors='replace'` 读。「未验证」

---

## 10. 最终导出参数

**Linux 实际（`render.py` 和 `highlight.py` 完全一致）**
```
-c:v libx264 -profile:v high -preset slow -crf 17 -maxrate 16M -bufsize 24M -g 60 -r 30 -pix_fmt yuv420p
-color_primaries bt709 -color_trc bt709 -colorspace bt709 -c:a aac -b:a 192k -movflags +faststart -t <时长>
```
- 1080×1920 由 `vf_cover` 和 numpy 帧尺寸保证。
- 旧版 `work/render.py` 另外加了 `-ar 48000`。
- 实测 ffprobe：`h264 1080x1920 30/1`，音频 aac。

**Windows**：参数列表照用。「未验证」

---

## 11. 质检脚本

| 检查 | Linux 实际命令或脚本 | Windows |
|---|---|---|
| 卡点（首个可读帧） | `python3 tools_onset_check.py <name>`（字幕预设库）；`python3 tools_hl_onset.py <name>`（高光测试）。在同一个页面里逐帧调用 `renderFrame` 和 `fxState()`。“可读”指字的不透明度 ≥0.5，或手绘线已画出 ≥25%。偏差要求 ≤2 帧；v2 实测最大 0.75 帧 | 改 file URI 后照用。「未验证」 |
| 安全区、压脸、压 logo、层数 | 渲染时每帧调用 `checkSafe()`，结果写到 `out/<name>_safe_violations.json`（要求为 `[]`）。安全区 x 90–930、y 200–1540；人脸框来自 YuNet（`models/yunet.onnx`，`cv2.FaceDetectorYN`）；logo 避让带；同屏 >3 层算违规 | 同上。「未验证」 |
| 接触表（每秒一张） | `ffmpeg -i out.mp4 -vf "fps=1,scale=216:384,drawtext=fontfile=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc:text='%{pts\:gmtime\:0\:%M\\\:%S}':x=4:y=4:fontsize=20:fontcolor=red:box=1:boxcolor=white@0.7,tile=10xN:padding=4:color=gray" -frames:v 1 -q:v 3 qc.jpg`（`render.py`、`work/qc.py`；Python 里转义层数更多，以脚本原文为准） | fontfile 改成 `C\:/Windows/Fonts/msyhbd.ttc` 这种写法：冒号要转义，用正斜杠。「未验证」 |
| 响度 | `ffmpeg -hide_banner -i out.mp4 -af ebur128=peak=true -f null -`，从 stderr 最后的 Summary 里读 `I:` 和 `Peak:` | 照用。「未验证」 |
| 黑帧 | `ffmpeg -hide_banner -i out.mp4 -vf blackdetect=d=0.1:pix_th=0.08 -an -f null -`（`work/qc.py`，用正则抓 `black_start/black_end`） | 照用。「未验证」 |
| 定格检测 freezedetect | Linux 上已跑过：`ffmpeg -i out.mp4 -vf "freezedetect=n=0.003:d=0.2" -an -f null -`，两版测试片都只检出分镜里那一处定格。`d` 是能报出的最短冻帧，再用 `d=0.1` 扫一遍抓 2–3 帧的卡顿。freezedetect 不算入场动画，报出的时长比 spec 短（例：spec 0.43 s，只报 0.233 s）；核对定格时长用 PyAV 逐帧算帧差为 0 的区间 | 「未验证」 |
| 定格只能落在静音里 | v2 用的是临时内联脚本：读 `work/<name>/voice.wav`，每 10ms/20ms 算 RMS dBFS，要求定格区间内 ≤ −45 dB（实测平均 −53.2，最大 −45）；冻结用的帧是按嘴部裁图人工挑的（`out/highlight_test_v2_freeze_mouth.jpg`） | 「平台无关」（wave + numpy） |
| 换气空隙 | `tools_hl_onset.py` 的后半部分：切点两侧低于 −42 dBFS 的连续长度 ≤90ms | 「平台无关」 |
| 抠像边缘 | 头发、手、椅子三处的局部放大（合成图和 alpha 并排），由 `highlight.py` 跑完后用内联 cv2 生成 | 「平台无关」 |
| 腮红跟脸 | `python3 tools_blush_check.py <name>` | 「未验证」（调用了 ffmpeg） |

---

## 12. 踩坑清单（每条附检查方法）

| # | 坑 | 检查方法 |
|---|---|---|
| 1 | **中文路径、空格**：我们的素材文件名就带空格（`XXX 094102.MOV`）。PowerShell 必须加引号 `"D:\素材\IMG 094102.MOV"`；字符串里有 `$` 时用单引号。Python 用参数列表就不需要引号。Windows 上的 `open()` 默认编码可能是 GBK | 把一个带中文和空格的路径交给 ffprobe 跑一遍；所有 `open()` 都显式写 `encoding='utf-8'`；`subprocess.run(..., encoding='utf-8', errors='replace')` |
| 2 | **字体路径**：drawtext 的 `fontfile=` 要写文件路径，Windows 上冒号要转义成 `C\:/Windows/Fonts/xxx.ttc`。网页 CSS 里我们写的是 `font-family:'Noto Sans CJK SC'` / `'Noto Serif CJK SC'`，依赖系统已经装了这些字体；Windows 默认没有 Noto CJK | 先装 Noto Sans/Serif CJK SC，或者在 CSS 里用 `@font-face{src:url(file:///C:/...)}` 指向字体文件；渲染一帧截图，确认不是宋体或微软雅黑在顶替；接触表上的 drawtext 要显示中文、不能是方块 |
| 3 | **`NUL` 和 `/dev/null`**：测量类命令要丢弃输出 | 统一写 `-f null -`，两个平台都能用；PowerShell 里要写 NUL 时用 `-f null NUL` |
| 4 | **续行符**：PowerShell 用反引号 `` ` ``，bash 用反斜杠 `\`；filtergraph 里的 `\:` 在 PowerShell 双引号里不会被吃掉，但 `$` 会被当成变量 | 一律用 Python 参数列表；非要写 PowerShell 就用单引号包 filtergraph，并 echo 出来核对 |
| 5 | **WSL 和 Windows 路径**：`/mnt/c/Users/...` 对应 `C:\Users\...`。在 WSL 里跑的 Linux ffmpeg 不认 `C:\`，Windows 版的 ffmpeg 不认 `/mnt/c` | 一个流水线里只用一种环境；需要转换时用 `wslpath -w` / `wslpath -u`；每一步都打印绝对路径 |
| 6 | **concat 列表和 file URL** 的路径格式 | `list.txt` 里用正斜杠；网页地址用 `Path(...).as_uri()` |
| 7 | **HLG 发灰**：ffmpeg 不带 zscale，或者直接当 SDR 解码，画面就会发灰、偏淡 | 用 `ffmpeg -filters` 确认有 zscale；ffprobe 看 `color_transfer`，是 `arib-std-b67` 就必须走 HDR 链；拿一帧和素材接触表对比 |
| 8 | **Whisper 同音字和幻觉**：实测「岗」被听成「赶」，还冒出一段没说过的「试骑第一天」 | 对照音频人工校对全文，校对后再送 whisperX 对齐；屏幕上的字必须能在校对稿里找到原话 |
| 9 | **卡点从“第一个看得清的帧”算**，不是从元素出现的那一帧算；入场动画提前 1 帧开始 | `tools_hl_onset.py` / `tools_onset_check.py`，偏差 ≤2 帧 |
| 10 | **定格只能放在 < −45 dB 的静音里**，否则嘴型和声音对不上（v1 就是这个问题：定格盖在说话上） | 测定格区间内人声 RMS（≤ −45 dBFS）；挑一帧闭嘴或接近闭嘴的画面来定格；音频照常走，不做时间拉伸 |
| 11 | **Windows 的 multiprocessing（spawn）**：脚本顶层没有 `if __name__=='__main__':` 会出错 | 改脚本，先用 `--workers 1` 跑通 |
| 12 | **字的结束时间不可靠**（whisperX） | 出点按能量裁，然后检查换气空隙 ≤90ms |
| 13 | **抠像和读帧的 vf 不一致**会导致描边错位 | 抠像和合成用同一个 vf 字符串，对比两次 matte 的差值（实测为 0） |
| 14 | **Douyin 右侧按钮区**：安全区右边界是 x=930，不是 990；旋转后的红章要按外接框算 | 看 `safe_violations.json` 是否为 `[]` |

---

## 13. Linux 和 Windows 的差异（简表）

- **Shell**：bash 和 PowerShell 的引号、续行、`$` 规则都不一样 → 用 Python 参数列表就能避开。
- **ffmpeg**：Debian 自带的包已经有 zimg 和全部滤镜；Windows 要选 gyan.dev full build，并自检 zscale、afftdn、sidechaincompress、prores_ks。
- **字体**：Linux 装好了 Noto CJK（在 `/usr/share/fonts/opentype/noto/`）；Windows 要另装，drawtext 路径要转义冒号。
- **浏览器**：Linux 用 `/usr/bin/google-chrome`；Windows 用 Playwright 自带的 Chromium，或 `C:\Program Files\...\chrome.exe`，网页地址用 `as_uri()`。
- **进程**：Linux 的 multiprocessing 用 fork；Windows 用 spawn，需要 `__main__` 保护，子进程启动也更慢。
- **编码**：Linux 默认 UTF-8；Windows 默认可能是 GBK，所有文件读写都要写 `encoding='utf-8'`。
- **GPU**：我们全程在 CPU 上跑（int8 whisper、CPU 对齐、CPU 抠像）；Windows 有 N 卡可以开 CUDA，但需要匹配的 torch 和 cuDNN，没有验证过。
- **路径**：Linux 路径和 `D:\...`；脚本里写死的 `/tmp`、`/usr/share/fonts`、`...` 都要改成可配置的。
- **剪映**：草稿怎么建、哪些能改、alpha 短片怎么放，见 `jianying_route.md`。整步待验证。质检打在剪辑师导出的 mp4 上，不必读草稿。`caption_presets.json` 里的 `jianying` 字段仍是未实测。
