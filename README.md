# 🐍 Lua LÖVE Snake

一个无外部游戏依赖的 LÖVE 贪吃蛇小游戏，需要 LÖVE 11.5 或更高版本。/ A dependency-free LÖVE snake game requiring LÖVE 11.5 or later.

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

- `WASD` 或方向键：转向；`P` 或 `Esc`：暂停 / `WASD` or arrows: turn; `P` or `Esc`: pause
- `Enter` 或鼠标：开始或重开 / `Enter` or mouse: start or restart

窗口失焦时游戏会自动暂停；重新点击窗口即可继续。/ The game pauses when unfocused; click the window to continue.
