# 🏆 无头 AI 锦标赛 / Headless AI Championship

锦标赛只运行无玩家干预的 AUTO，Lua 是唯一比赛引擎，Python 只负责命令调度、绘图与归档。/ The championship runs uninterrupted AUTO only; Lua is the sole game engine, while Python only orchestrates commands, charts, and archives.

## ▶️ 本地运行 / Local Run

安装 [uv](https://docs.astral.sh/uv/) 与 Lua 5.1 后，在仓库根目录执行统一入口；脚本会隔离并安装固定版本的 Matplotlib。/ Install [uv](https://docs.astral.sh/uv/) and Lua 5.1, then use the unified entry from the repository root; it installs the pinned Matplotlib version in isolation.

```text
uv run --script scripts/championship/championship-cli.py run
```

Windows 只有 LÖVE 时会自动回退到 `lovec`；也可通过 `--engine <路径>` 显式选择 Lua 或 LÖVE。/ On Windows the CLI falls back to `lovec` when only LÖVE is installed; use `--engine <path>` to select Lua or LÖVE explicitly.

原始入口仍为 `lua5.1 scripts/championship/run-championship.lua` 或 Windows 上的 `lovec . --run-championship`。/ Raw entries remain `lua5.1 scripts/championship/run-championship.lua` or `lovec . --run-championship` on Windows.

```text
uv run --script scripts/championship/championship-cli.py run --sizes 10x8,20x14 --edges walls,wrap --algorithms greedy,hamiltonian --runs 3 --master-seed demo --output-dir build/championship
uv run --script scripts/championship/championship-cli.py render --input build/championship/championship.json
```

默认覆盖 `20x14,30x21,40x28`、`walls,wrap`、全部八种算法和每场景 10 个 seed，共 480 局。/ Defaults cover `20x14,30x21,40x28`, `walls,wrap`, all eight algorithms, and 10 seeds per scenario, totaling 480 games.

## 📊 输出与图表 / Outputs and Charts

输出目录包含 `championship.md`、`championship.csv`、`championship.json` 和三张 PNG。/ The output directory contains `championship.md`, `championship.csv`, `championship.json`, and three PNG charts.

| 文件 / File | 内容 / Contents |
| --- | --- |
| `championship-reliability.png` | 完成率与平均填充率 / Completion rate and average fill |
| `championship-efficiency.png` | 成功局的每个食物步数中位数 / Median steps per food among wins |
| `championship-scenarios.png` | 各棋盘与边界的填充率热力图和胜率 / Fill heatmap and win rate by board and edge |

可靠性依次比较完成率、平均最终填充率和 timeout 数；效率榜只统计成功局，总榜使用每个食物所需步数。/ Reliability ranks completion rate, average final fill, then timeouts; efficiency includes wins only and uses overall steps per food.

每局最多执行 `2 × (宽 × 高)²` 步，连续一个棋盘格数的步数未进食也会记为 `timeout`；碰撞记为 `collision`。/ A game times out after `2 × (width × height)²` steps or one boardful of steps without food; crashes are `collision`.

JSON、CSV 与比赛结果不含墙钟时间；相同参数与版本会产生相同的比赛数据。/ JSON, CSV, and game outcomes exclude wall-clock time; identical parameters and code produce identical competition data.

## ⚙️ Actions 与独立发布 / Actions and Separate Releases

提交信息中的 `[run-championship]` 生成保留 14 天的 Artifact；`[release-championship]` 运行相同赛事并创建永久报告 Release。/ `[run-championship]` in a commit creates a 14-day artifact; `[release-championship]` runs the same event and creates a permanent report release.

```text
gh workflow run run-championship.yml -f destination=artifact
gh workflow run run-championship.yml -f destination=release
```

工作流将尺寸与边界分片并行运行，聚合后生成图表、校验文件与完整 ZIP。/ The workflow runs size-and-edge shards in parallel, then aggregates charts, checksums, and a complete ZIP.

锦标赛 tag 包含版本、UTC 时间、短 SHA、run ID 与 attempt；正文同时记录北京时间和 UTC。/ Championship tags include version, UTC time, short SHA, run ID, and attempt; the body records both China Standard Time and UTC.

锦标赛 Release 只上传完整 ZIP、三张可嵌入 PNG 和 `SHA256SUMS.txt`，并设置为非 Latest、非 Pre-release。/ A championship release uploads only the complete ZIP, three embeddable PNGs, and `SHA256SUMS.txt`, and is neither Latest nor a Pre-release.

游戏 Release 与锦标赛 Release 永不混装；前者由 `build-release.yml` 和 `[build-release]` 独立控制。/ Game and championship releases never mix; the former is controlled independently by `build-release.yml` and `[build-release]`.
