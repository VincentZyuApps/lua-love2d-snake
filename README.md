# 🐍 Lua LÖVE Snake

一款基于 Love2D、支持八种 AI、人工干预、可复现 seed 与双边界规则的贪吃蛇游戏，需要 LÖVE 11.5 或更高版本。/ A Love2D Snake game with eight AIs, player intervention, reproducible seeds, and two edge rules; LÖVE 11.5 or later is required.

> 🧩 本项目也可作为使用 GitHub Actions 构建 LÖVE 游戏的跨平台模板。/ 🧩 This project also serves as a cross-platform GitHub Actions template for LÖVE games.

## ✨ 功能 / Features

支持 `MANUAL/AUTO/HYBRID`、`WALLS/WRAP`、`1x–10000x` 十五档速度，并按模式和算法持久化分数、完成步数、时间、倍率、seed 与胜率。/ Supports `MANUAL/AUTO/HYBRID`, `WALLS/WRAP`, 15 speeds from `1x–10000x`, and persistent score, clear steps, time, speed, seed, and win rate per mode and algorithm.

## 🤖 八种 AI 算法 / Eight AI Algorithms

每个算法读取同一局面并只返回下一步方向，因此可公平比较不同策略。/ Every algorithm reads the same state and returns only the next direction, enabling fair strategy comparisons.

| 算法 / Algorithm | 核心策略 / Core Strategy | 行为特点 / Behavior | AUTO 填满保证 / AUTO Fill Guarantee |
| --- | --- | --- | --- |
| Random Safe | 从当前安全方向随机选择 / Randomly picks an immediately safe direction | 轻量且不可预测，容易走入未来死局 / Lightweight and unpredictable, but can enter future traps | 否 / No |
| Greedy | 每步缩短到食物的棋盘距离 / Reduces board distance to food each step | 吃得积极，不检查吃完后的退路 / Aggressive eating without checking an escape afterward | 否 / No |
| BFS Shortest | 缓存当前局面到食物的最短路径 / Caches the current shortest path to food | 路线短，但不预测身体移动后的封闭空间 / Short routes without forecasting enclosed space after body movement | 否 / No |
| A* Tail Safe | 模拟完整进食路径并检查尾巴可达 / Simulates the food path and checks tail reachability | 危险时追尾或选择最大安全空间 / Follows the tail or largest safe space when food is risky | 否 / No |
| Space Scoring | 评分食物距离、洪泛空间和尾巴连通性 / Scores food distance, flood-fill space, and tail access | 倾向保留大面积活动空间 / Prefers moves that preserve large open regions | 否 / No |
| Beam Search | 搜索深度 10、宽度 24 的未来候选 / Searches a depth-10, width-24 beam of futures | 更有前瞻性，并受每帧 AI 时间预算约束 / More foresighted and bounded by the per-frame AI budget | 否 / No |
| Hamiltonian | 始终沿覆盖 630 格的固定回路前进 / Follows a fixed cycle covering all 630 cells | 最稳但通常最慢，最终一定吃满 / Safest but usually slowest, eventually filling the board | 是 / Yes |
| Hamiltonian Shortcut | 在不越过尾巴与食物顺序时沿回路抄近路 / Shortcuts without overtaking tail and food cycle order | 保留回路安全底线，同时明显缩短进食路线 / Keeps cycle safety while substantially shortening food routes | 是 / Yes |

保证仅适用于算法独占控制的 AUTO；HYBRID 的不同方向干预会清除算法缓存并取消保证。更完整原理见 `docs/ALGORITHMS.md`。/ Guarantees apply only to uninterrupted AUTO; a differing HYBRID override resets AI memory and removes the guarantee. See `docs/ALGORITHMS.md` for deeper details.

## 🧰 安装与运行 / Setup and Run

| 系统 / OS | 安装 LÖVE / Install LÖVE | 启动 / Launch |
| --- | --- | --- |
| Windows | `scoop install love` | `love .` |
| Debian / Ubuntu | `sudo apt install love` | `love .` |
| Fedora | `sudo dnf install love` | `love .` |
| Arch Linux | `sudo pacman -S love` | `love .` |
| macOS | `brew install --cask love` | `open -n -a love .` |

先进入仓库根目录再执行启动命令。/ Run the launch command from the repository root.

## 🎮 操作 / Controls

- `WASD` 或方向键转向，`Enter/Space` 开始，`P/Esc` 暂停。/ Turn with `WASD` or arrows, start with `Enter/Space`, and pause with `P/Esc`.
- `M` 切边界，`C` 切控制，`G` 轮换算法；点击算法名打开 2×4 面板；局中更改需按 `Y/N` 重开或取消。/ `M` changes edges, `C` changes control, and `G` cycles AI; click the name for the 2×4 picker; confirm mid-run changes with `Y/N`.
- `-/+` 调速，`F2` 输入 seed，`R` 重放，`L` 查看分榜；AUTO 忽略转向，HYBRID 覆盖下一步。/ Use `-/+` for speed, `F2` for seeds, `R` to replay, and `L` for leaderboards; AUTO ignores turns and HYBRID overrides one step.

## 📦 构建 / Builds

- `[build-action]` 构建 `.love`、Windows、Linux 与 macOS Artifact；`[build-release]` 额外发布 Release。/ `[build-action]` builds `.love`, Windows, Linux, and macOS artifacts; `[build-release]` also publishes a release.
- 原生包未正式签名；Python 仅生成、验证和打包，游戏运行时保持纯 Lua。/ Native packages are unsigned; Python only generates, verifies, and packages, while the runtime remains pure Lua.
