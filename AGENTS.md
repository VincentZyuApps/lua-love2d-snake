# 🐍 仓库协作说明 / Repository Agent Guide

## 💬 沟通 / Communication

- 默认使用亲近、直接、清晰的中文，不使用猫娘语气。/ Use friendly, direct, clear Chinese by default; do not use catgirl phrasing.
- 涉及代码、命令、权限、安全与故障时，给出准确且可验证的信息。/ Give accurate, verifiable information for code, commands, permissions, security, and failures.

## 🧱 实现 / Implementation

- 游戏运行时保持纯 Lua，并兼容 LÖVE 11.5 与 Lua 5.1。/ Keep the game runtime pure Lua and compatible with LÖVE 11.5 and Lua 5.1.
- 游戏内可见文字使用英文；README 与主要文档每行先中文再英文。/ Use English for in-game text; write README and primary docs Chinese first, then English on each line.
- README 不超过 50 行，所有 `#` 标题包含 Emoji。/ Keep README within 50 lines and add an Emoji to every `#` heading.
- 优先复用现有模块、算法注册表、Game Factory、RNG 与存储格式。/ Reuse existing modules, the algorithm registry, Game Factory, RNG, and storage formats.
- 不提交构建产物、临时文件、玩家存档或锦标赛输出。/ Do not commit builds, temporary files, player saves, or championship output.

## 🏷️ 命名 / Naming

- `src/` 直属的通用 Lua 模块优先使用单个英文单词，如 `board.lua` 与 `factory.lua`。/ Prefer one English word for general Lua modules directly under `src/`, such as `board.lua` and `factory.lua`.
- `src/ai/` 直属 Lua 文件除 `shared/` 外必须使用至少两个单词的 kebab-case 文件名。/ Direct Lua files under `src/ai/`, excluding `shared/`, must use kebab-case names with at least two words.
- 所有 Python 文件必须使用至少两个单词的 kebab-case 文件名并纳入 Git。/ Every Python filename must use at least two kebab-case words and be tracked by Git.
- 新增脚本和工作流使用描述用途的 kebab-case 名称。/ Give new scripts and workflows descriptive kebab-case names.

## ✅ 验证 / Verification

- 修改游戏逻辑后运行 `lovec . --run-tests`；修改构建工具后运行 Python 单元测试。/ Run `lovec . --run-tests` after game logic changes and Python unit tests after build-tool changes.
- 可复现功能不得依赖墙钟时间、无序遍历或平台相关路径。/ Reproducible features must not depend on wall-clock time, unordered iteration, or platform-specific paths.
- 动态棋盘宽高限制为 5–50，且至少一边为偶数。/ Dynamic boards are limited to 5–50 and require at least one even dimension.
- 视觉改动需检查 960×720 与 720×540，避免文字、控件和棋盘重叠。/ Check visual changes at 960×720 and 720×540 to prevent text, control, and board overlap.

## 🧾 Git 与发布 / Git and Releases

- 提交格式为 `type(scope): 中文说明`。/ Format commits as `type(scope): Chinese description`.
- 每笔提交添加 `Co-authored-by: Codex <codex@openai.com>`。/ Add `Co-authored-by: Codex <codex@openai.com>` to every commit.
- 功能与 CI 修改先正常提交且不带触发词，验证任务再用独立空提交触发。/ Commit feature and CI changes without trigger tokens, then use separate empty commits for validation jobs.
- `[build-action]` 生成游戏 Artifact，`[build-release]` 发布 Latest 游戏 Release。/ `[build-action]` creates game artifacts; `[build-release]` publishes the Latest game release.
- `[run-championship]` 生成报告 Artifact，`[release-championship]` 发布非 Latest、非 Pre-release 的独立报告。/ `[run-championship]` creates report artifacts; `[release-championship]` publishes a separate report that is neither Latest nor a Pre-release.
- 游戏 Release 不含锦标赛文件，锦标赛 Release 不含游戏二进制。/ Game releases exclude championship files; championship releases exclude game binaries.
- `gh workflow run` 是无需空提交的等价手动入口。/ `gh workflow run` is the equivalent manual entry that needs no empty commit.
- Release 正文必须从 `.github/release-templates/` 的对应模板渲染且不得残留占位符。/ Render Release bodies from the matching `.github/release-templates/` template with no unresolved placeholders.
- 发布前确认 VERSION、工作树、测试、标签和 Release 状态。/ Verify VERSION, worktree, tests, tags, and Release state before publishing.
