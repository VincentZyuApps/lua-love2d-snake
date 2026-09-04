# 🐍 Lua LÖVE Snake

一个支持人工、Hamiltonian AI 与混合控制的 LÖVE 贪吃蛇小游戏，需要 LÖVE 11.5 或更高版本。/ A LÖVE snake game with manual, Hamiltonian AI, and hybrid control, requiring LÖVE 11.5 or later.

> 本项目也可作为使用 GitHub Actions 构建 LÖVE 游戏的跨平台模板。/ This project also serves as a cross-platform GitHub Actions template for LÖVE games.

## 🪟 Windows / Windows

使用 [Scoop](https://scoop.sh/) 安装并运行：/ Install and run with [Scoop](https://scoop.sh/):

```powershell
scoop install love
cd path\to\lua-love2d-snake
love .
```

## 🐧 Linux / Linux

安装 LÖVE 并运行：/ Install LÖVE and run:

```bash
sudo apt install love          # Debian / Ubuntu
sudo dnf install love          # Fedora
sudo pacman -S love            # Arch Linux
cd path/to/lua-love2d-snake && love .
```

## 🍎 macOS / macOS

使用 [Homebrew](https://brew.sh/) 安装并运行：/ Install and run with [Homebrew](https://brew.sh/):

```bash
brew install --cask love
cd path/to/lua-love2d-snake
open -n -a love .
```

## 🎮 操作 / Controls

- `WASD` 或方向键转向；`P` 或 `Esc` 暂停；`Enter` 开始。/ Turn with `WASD` or arrows; pause with `P` or `Esc`; start with `Enter`.
- `M` 切换 `WALLS/WRAP`；`C` 切换 `MANUAL/AUTO/HYBRID`；局中更改需按 `Y/N` 确认。/ `M` changes `WALLS/WRAP`; `C` changes `MANUAL/AUTO/HYBRID`; mid-run changes require `Y/N` confirmation.
- `-` 或 `_` 降速，`=` 或 `+` 加速；15 档倍率默认 `2x`。/ Slow down with `-` or `_`, speed up with `=` or `+`; 15 presets default to `2x`.
- AUTO 忽略方向键；HYBRID 允许覆盖下一步，但干预后不再保证获胜。/ AUTO ignores direction keys; HYBRID overrides one step, but intervention removes the win guarantee.
- 窗口失焦时自动暂停；BEST 按边界与控制模式分别记录。/ The game pauses when unfocused; BEST is tracked separately by edge and control mode.

## 📦 构建 / Builds

- `[build-action]` 构建四平台 Artifact；`[build-release]` 发布 Latest Release。/ `[build-action]` builds four-platform artifacts; `[build-release]` publishes a Latest Release.
- 原生包未正式签名，Windows 与 macOS 可能显示安全警告。/ Native packages are unsigned and may trigger Windows or macOS warnings.
- Python 仅生成、模拟并校验 AI 路线，游戏运行时保持纯 Lua。/ Python only generates, simulates, and verifies the AI route; the game runtime remains pure Lua.
