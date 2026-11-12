# 分镜 spec.json 字段（唯一剪辑依据）

顶层：
- `spec_version`、`name`、`root`（素材根目录，其余路径都写相对路径，换机器只改它）、`raw_dirs`、`words`（转写逐词时间戳 JSON）、`align`（whisperX 对校对稿的逐字对齐结果，卡点以它为准）
- `safe`（默认 x 90–930、y 200–1540）、`caption`（字号、行底 y、是否关键词上色）
- `music`：列表，按章节换曲 `[{"file","db","from","to","xfade"}]`，`from/to` 可写 `segN`
- `cover`：`title / tag / stickers / frame_candidates[{src,t,note}] / versions / preferred_frame / aspects`
- `variants`：对比版本（如句间 2–3 帧的气口版）

每段 `segments[]`：
- `src`、`in`、`out`（源素材秒）、`zoom`
- `layout`：`full` 全屏口播 / `broll` 全屏空镜 / `split` 上下分屏 / `pip` 小窗口播 / `grid` 四宫格或多格快切 / `speed` 变速 / `cutout` / `circle` / `cta`。穿插形式怎么轮换见 `pacing.md`。
- `bg` / `bg_in`（B-roll 文件与入点）、`origin`（real / ai，AI 镜头要在 QC 标出）
- `importance`：`high` / `mid` / `low`。穿插镜头必填。纯口播段不靠它把单段放到 3 秒以上。
- `dur`：计划时长（秒）。先按 `pacing.md` 的类型基准，再按重要程度取上限或下限。
- `speed`：播放速度。观感不快于 1.5 倍。
- `grid_cells[]`：多格快切时每格一条，`src`、`in`、`out`、`dur`。整组仍是上面这条 segment。
- `lines[]`：`text`（一行 ≤12 字）、`src_t`（原话时间戳）、`kw_class`、`fx[]`
- `fx[]`：`type`、`at`（锚点词，效果从该词首字发声帧开始）、`tier`（normal / hero）、`sfx`（null = 不出声）、`importance`（`high` / `mid` / `low`，必填）、`dur`（计划时长，秒，含入场、停留、出场）

`kw_class`（关键词类别 → 默认特效）：
number 数字 · contrast 反差 · punchline 金句 · emotion 情绪 · term 专业词 · action 动作 · stack_list 累加清单 · couplet_vertical 竖排对仗 · list 并列 · name 称呼 · chapter 章节 · brand 企业口号 · object_icon 实物配图 · default 普通。
每类写：识别规则、示例、特效、版式位置、默认音效、剪映对应做法（未实测的标「待验证」）。

`fx.type` 参考：kw_pop（关键词大字）、number（数字滚动）、obj（实物贴图 + 拟音）、list_item / list_gather（累加清单）、stamp（红章）、q_flash（问号 + 闪白）、vcol（竖排双列）、jumpcut_punch（跳切推拉）、matte_behind（字在人后，爆点）、glyph_mask（文字遮罩转场，爆点）、freeze（定格，爆点）。

自动检查分两处：`check_rules` 在时间线上查效果最大间隔 ≤3 秒、音效间隔 ≥0.25 秒，结果写进 `rules`。音效密度的工作值是全片 ≤0.4 个/秒、任意 4 秒 ≤3 个（「待确认」：旧标准约 0.5 个/秒、每 4 秒 1–3 个，见 `pacing.md`）。效果间隔和种类 18–22 也在 `pacing.md` 标了「待确认」，不要为了通过检查改其中一边。口播占比、单段纯口播、穿插时长按 `pacing.md` 算，写进 `timing_stats.csv`；标了「待确认」的不算通过。安全区、压脸、压 logo、同屏 ≤3 层由页面里的 `checkSafe()` 逐帧查，结果写进 `<name>_safe_violations.json`（要求为 `[]`）。

## 重要程度分析表（`importance.csv`）

交付物。每个穿插镜头一行，每个字幕特效一行。UTF-8，表头用下面的列名。渲染前和分镜一起交给用户确认。

| 列 | 填什么 |
|---|---|
| 编号 | 稳定 id，如 `broll-03`、`fx-12`，和 spec 里的 segment、`fx` 对得上 |
| 种类 | `穿插` 或 `特效` |
| 所在段 | segment 序号或 id |
| 内容 | 镜头里是什么；特效写 `fx.type` 加锚点词 |
| 入点_秒 | 成片入点 |
| 出点_秒 | 成片出点 |
| 撑主题 | 是否直接撑起主题主线：是/否，加一句理由 |
| 关键词或转折 | 是否对上关键词或转折点：是/否，写出是哪个 |
| 要看清的信息 | 是否有必须看清的信息：是/否；有就写出信息 |
| 重要程度 | 高 / 中 / 低 |
| 计划时长_秒 | 按类型基准和重要程度定的时长 |
| 处理 | 保留 / 取上限 / 取下限 / 删除。写了删除的不能留在成片里 |

三条依据（撑主题、关键词或转折、要看清的信息）都要填，不能只打一个高/中/低。

## 时长统计表（`timing_stats.csv`）

交付物。每段穿插画面一行，每个特效动画一行；多格快切的每一格再加一行。UTF-8。时长从成片量，不抄计划值充数。

| 列 | 填什么 |
|---|---|
| 编号 | 和重要程度表同一套 id。多格的单格写成 `broll-03-g2` 这种 |
| 种类 | `穿插`、`特效动画`，或汇总行的 `汇总` |
| 类型 | 大全景/运镜、信息特写、静态特写、分屏、小窗口、多格快切-整组、多格快切-单格，或 `fx.type`。汇总行写统计范围 |
| 重要程度 | 高 / 中 / 低。汇总行空着 |
| 时长_秒 | 这一条的实测时长。汇总行里：最短值填最短的那条，平均值填该范围的平均 |
| 底线_秒 | 这一条适用的底线，数字来自 `pacing.md`。汇总行空着 |
| 底线说明 | 底线从哪条规则来。若和另一条底线冲突（例如单格 0.6–1 秒对 1.6 秒），写「待确认」并写上两个数字 |
| 低于底线 | 是 / 否。写「是」则这条不通过。底线说明里有「待确认」的，这里写「待确认」，不算通过 |
| 整组编号 | 多格快切填整组的编号，其余空着 |

明细后面必须有汇总行（种类 = `汇总`），至少这五行：

- `summary-insert-min`：穿插画面最短值（多格按整组，不把单格混进这条）
- `summary-insert-avg`：穿插画面平均值
- `summary-fx-min`：特效动画最短值
- `summary-fx-avg`：特效动画平均值
- `summary-all-min`：上面两类里全片最短的一条，用来对「不能一闪而过」

多格单格另加 `summary-gridcell-min` 和 `summary-gridcell-avg`。单格短于 1.6 秒时按 `pacing.md` 标「待确认」。不要因为整组已经 ≥ 2 秒，就把这些单格算成通过。

汇总的最短值和平均值要能用明细行重算出来，对不上就还没做完。
