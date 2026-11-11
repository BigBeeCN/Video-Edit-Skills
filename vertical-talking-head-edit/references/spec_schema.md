# 分镜 spec.json 字段（唯一剪辑依据）

顶层：
- `spec_version`、`name`、`root`（素材根目录，其余路径都写相对路径，换机器只改它）、`raw_dirs`、`words`（转写逐词时间戳 JSON）、`align`（whisperX 对校对稿的逐字对齐结果，卡点以它为准）
- `safe`（默认 x 90–930、y 200–1540）、`caption`（字号、行底 y、是否关键词上色）
- `music`：列表，按章节换曲 `[{"file","db","from","to","xfade"}]`，`from/to` 可写 `segN`
- `cover`：`title / tag / stickers / frame_candidates[{src,t,note}] / versions / preferred_frame / aspects`
- `variants`：对比版本（如句间 2–3 帧的气口版）

每段 `segments[]`：
- `src`、`in`、`out`（源素材秒）、`layout`（full / broll / cutout / circle / cta）、`zoom`
- `bg` / `bg_in`（B-roll 文件与入点）、`origin`（real / ai，AI 镜头要在 QC 标出）
- `lines[]`：`text`（一行 ≤12 字）、`src_t`（原话时间戳）、`kw_class`、`fx[]`
- `fx[]`：`type`、`at`（锚点词，效果从该词首字发声帧开始）、`tier`（normal / hero）、`sfx`（null = 不出声）

`kw_class`（关键词类别 → 默认特效）：
number 数字 · contrast 反差 · punchline 金句 · emotion 情绪 · term 专业词 · action 动作 · stack_list 累加清单 · couplet_vertical 竖排对仗 · list 并列 · name 称呼 · chapter 章节 · brand 企业口号 · object_icon 实物配图 · default 普通。
每类写：识别规则、示例、特效、版式位置、默认音效、剪映对应做法（未实测的标「待验证」）。

`fx.type` 参考：kw_pop（关键词大字）、number（数字滚动）、obj（实物贴图 + 拟音）、list_item / list_gather（累加清单）、stamp（红章）、q_flash（问号 + 闪白）、vcol（竖排双列）、jumpcut_punch（跳切推拉）、matte_behind（字在人后，爆点）、glyph_mask（文字遮罩转场，爆点）、freeze（定格，爆点）。

自动检查分两处：`check_rules` 在时间线上查效果最大间隔 ≤3 秒、音效每 4 秒 1–3 个、音效间隔 ≥0.25 秒，结果写进 `rules`；安全区、压脸、压 logo、同屏 ≤3 层由页面里的 `checkSafe()` 逐帧查，结果写进 `<name>_safe_violations.json`（要求为 `[]`）。
