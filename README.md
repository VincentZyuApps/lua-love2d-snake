# 🐍 Lua LÖVE Snake

一款支持八种 AI、人工干预、可复现 seed 与双边界规则的 LÖVE 贪吃蛇，需要 LÖVE 11.5 或更高版本。/ A LÖVE Snake game with eight AIs, player intervention, reproducible seeds, and two edge rules; LÖVE 11.5 or later is required.

> 🧩 本项目也可作为使用 GitHub Actions 构建 LÖVE 游戏的跨平台模板。/ 🧩 This project also serves as a cross-platform GitHub Actions template for LÖVE games.

## ✨ 功能 / Features

- 八种可切换算法，从随机安全移动到 Hamiltonian Shortcut。/ Eight switchable algorithms, from random safe movement to Hamiltonian Shortcut.
- `MANUAL`、`AUTO`、`HYBRID` 三种控制方式；AUTO 与 HYBRID 分榜记录每种算法。/ `MANUAL`, `AUTO`, and `HYBRID` controls; AUTO and HYBRID keep separate records per algorithm.
- `WALLS` 与 `WRAP` 两种边界规则，15 档速度从 `1x` 到 `10000x`，默认 `2x`。/ `WALLS` and `WRAP` rules with 15 speeds from `1x` to `10000x`, defaulting to `2x`.
- 最佳分数、最快完成局、胜率和 seed 自动保存在程序旁，失败时回退用户目录。/ Best score, fastest clear, win rate, and seed persist beside the game, with user-directory fallback.

## 🧰 安装与运行 / Setup and Run

Windows 使用 Scoop 安装并在仓库目录运行：/ On Windows, install with Scoop and run inside the repository:
```powershell
scoop install love
love .
```
Linux 使用发行版包管理器安装并运行：/ On Linux, install with your distribution package manager and run:
```bash
sudo apt install love # Debian / Ubuntu；Fedora 用 dnf，Arch 用 pacman / use dnf on Fedora or pacman on Arch
love .
```
macOS 使用 Homebrew 安装并运行：/ On macOS, install with Homebrew and run:
```bash
brew install --cask love
open -n -a love .
```

## 🎮 操作 / Controls

- `WASD` 或方向键转向，`P` 或 `Esc` 暂停，`Enter` 或空格开始。/ Turn with `WASD` or arrows, pause with `P` or `Esc`, and start with `Enter` or Space.
- `M` 切换边界，`C` 切换控制，`G` 轮换算法；点击算法名称可打开 2×4 选择面板。/ `M` changes edges, `C` changes control, and `G` cycles algorithms; click the algorithm name for the 2×4 picker.
- 局中更改边界、控制、算法或 seed 会按 `Y/N` 确认，并结束本局且不计分。/ Mid-run edge, control, algorithm, or seed changes require `Y/N`, end the run, and discard its score.
- `-`/`+` 调速，`F2` 输入 seed，`R` 重放当前 seed，`L` 打开榜单。/ Use `-`/`+` for speed, `F2` for a seed, `R` to replay it, and `L` for leaderboards.
- AUTO 忽略转向；HYBRID 允许覆盖下一步，但人工干预会取消保证获胜。/ AUTO ignores turns; HYBRID overrides the next step, but intervention removes the win guarantee.

## 📦 构建 / Builds

- `[build-action]` 构建 `.love`、Windows、Linux 与 macOS Artifact；`[build-release]` 额外发布 Release。/ `[build-action]` builds `.love`, Windows, Linux, and macOS artifacts; `[build-release]` also publishes a release.
- 原生包未正式签名，Windows 与 macOS 可能显示安全警告。/ Native packages are unsigned and may trigger Windows or macOS warnings.
- Python 仅生成、验证和打包；游戏运行时保持纯 Lua。/ Python only generates, verifies, and packages; the game runtime remains pure Lua.

## 📚 算法说明 / Algorithm Guide

八种策略、保证条件和源码结构见 `docs/ALGORITHMS.md`。/ See `docs/ALGORITHMS.md` for all eight strategies, guarantees, and source layout.
