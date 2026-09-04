# 🐍 Lua LÖVE Snake

一个提供撞墙与穿越边界模式的 LÖVE 贪吃蛇小游戏，需要 LÖVE 11.5 或更高版本。/ A LÖVE snake game with solid-wall and border-wrapping modes, requiring LÖVE 11.5 or later.

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
cd path/to/lua-love2d-snake
love .
```

## 🍎 macOS / macOS

使用 [Homebrew](https://brew.sh/) 安装并运行：/ Install and run with [Homebrew](https://brew.sh/):

```bash
brew install --cask love
cd path/to/lua-love2d-snake
open -n -a love .
```

## 📦 构建 / Builds

- 提交含 `[build-action]` 时构建四平台 Artifact。/ Add `[build-action]` to a commit to build four-platform artifacts.
- 提交含 `[build-release]` 时发布正式 Latest Release。/ Add `[build-release]` to publish a stable Latest Release.
- 原生包未正式签名，Windows 与 macOS 可能显示安全警告。/ Native packages are unsigned and may trigger Windows or macOS warnings.

## 🎮 操作 / Controls

- `WASD` 或方向键：转向或开始；`P` 或 `Esc`：暂停；`Enter` 或点击其他位置：开始 / `WASD` or arrows: turn or start; `P` or `Esc`: pause; `Enter` or click elsewhere: start
- `M` 或模式按钮：切换 `WALLS` / `WRAP`，局中按 `Y` 重开或 `N` 取消 / `M` or mode buttons: switch `WALLS` / `WRAP`; during a run, press `Y` to restart or `N` to cancel

窗口失焦时自动暂停；两种模式在本次运行中分别记录 BEST。/ The game pauses when unfocused; each mode keeps its own BEST for the current session.
