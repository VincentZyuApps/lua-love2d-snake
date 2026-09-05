# 🏆 无头 AI 锦标赛 / Headless AI Championship

锦标赛只运行无玩家干预的 AUTO，因此不会把 HYBRID 的相同基线重复计算。/ The championship runs uninterrupted AUTO only, avoiding duplicate HYBRID baselines.

## ▶️ 本地运行 / Local Run

安装 LÖVE 后可执行 `lovec . --run-championship`；安装 Lua 5.1 后也可执行 `lua5.1 scripts/championship/run-championship.lua`。/ With LÖVE installed, run `lovec . --run-championship`; with Lua 5.1, run `lua5.1 scripts/championship/run-championship.lua`.

默认运行 `20x14,30x21,40x28`、`walls,wrap`、全部八种算法和每场景 10 个 seed，共 480 局。/ Defaults cover `20x14,30x21,40x28`, `walls,wrap`, all eight algorithms, and 10 seeds per scenario, totaling 480 games.

```text
lovec . --run-championship --sizes 10x8,20x14 --edges walls,wrap --algorithms greedy,hamiltonian --runs 3 --master-seed demo --output-dir build/championship
```

## 📊 输出与排名 / Outputs and Rankings

输出目录包含 `championship.md`、`championship.csv` 与 `championship.json`，且不记录时间戳或 CPU 时间。/ The output directory contains `championship.md`, `championship.csv`, and `championship.json`, with no timestamps or CPU timing.

可靠性榜依次比较完成率、平均最终填充率和 timeout 数；指标完全相同时并列。/ Reliability ranks completion rate, average final fill, then timeout count; identical metrics share a rank.

效率榜只统计成功局；总榜比较每个食物所需步数，分榜比较原始完成步数。/ Efficiency includes successful games only; the overall table compares steps per food and scenario tables compare raw completion steps.

每局最多执行 `2 × (宽 × 高)²` 步，连续一个完整棋盘格数的步数未进食也会停止；两者均记为 `timeout` 并标注原因，碰撞记为 `collision`。/ Each game runs at most `2 × (width × height)²` steps and also stops after one full board of steps without food; both are `timeout` with a recorded reason, while a crash is `collision`.

## ⚙️ GitHub Actions / GitHub Actions

提交信息包含 `[run-championship]` 时运行默认赛事，也可从 Actions 页面手动填写尺寸、边界、算法、局数和 master seed。/ A commit containing `[run-championship]` runs the defaults; Actions dispatch also accepts sizes, edges, algorithms, runs, and a master seed.

六个默认“尺寸 × 边界”场景并行执行，合并后的报告写入 Job Summary 并作为 Artifact 保留 14 天。/ The six default size-by-edge scenarios run in parallel; merged reports go to the Job Summary and a 14-day Artifact.

锦标赛结果不会写入玩家排行榜；相同参数再次运行会生成逐字节一致的三份报告。/ Championship results never enter player records; rerunning identical parameters produces byte-identical reports.
