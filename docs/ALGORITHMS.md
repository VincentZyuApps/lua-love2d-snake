# 🤖 AI 算法 / AI Algorithms

游戏运行时完全使用 Lua；每个算法通过统一注册表读取只读局面并返回下一步方向。/ The runtime is entirely Lua; every algorithm reads a game state through one registry contract and returns the next direction.

## 🧭 策略对比 / Strategy Comparison

| 算法 / Algorithm | 取向 / Goal | 特性 / Behavior | 填满保证 / Fill Guarantee |
| --- | --- | --- | --- |
| Random Safe | 随机求生 / Random survival | 仅从当前安全方向随机选择 / Randomly picks an immediately safe direction | 否 / No |
| Greedy | 最快接近食物 / Approach food quickly | 最小化 Manhattan 距离，不预测陷阱 / Minimizes Manhattan distance without trap prediction | 否 / No |
| BFS Shortest | 当前最短路 / Current shortest path | 缓存到食物的 BFS 路径 / Caches a BFS path to food | 否 / No |
| A* Tail Safe | 吃完仍可逃生 / Preserve an escape | 拒绝危险路线后追尾，并按固定步数重试 / Follows the tail after rejecting danger, then retries at a fixed step interval | 否 / No |
| Space Scoring | 保留活动空间 / Preserve open space | 综合食物距离、洪泛空间和尾巴连通性 / Scores food distance, flood-fill space, and tail access | 否 / No |
| Beam Search | 有界预测未来 / Bounded lookahead | 使用固定节点预算搜索候选局面 / Searches candidate states with a fixed node budget | 否 / No |
| Hamiltonian | 稳定填满 / Reliable fill | 始终沿动态生成的全图回路前进 / Always follows a dynamically generated full-board cycle | 是 / Yes |
| Hamiltonian Shortcut | 更快填满 / Faster reliable fill | 保持回路顺序时朝食物安全抄近路 / Takes food-directed shortcuts while preserving cycle order | 是 / Yes |

## 🛡️ 保证边界 / Guarantee Boundary

“保证”只适用于算法独占控制且地图、食物和回路规则不变的 AUTO 模式。/ “Guaranteed” applies only to uninterrupted AUTO control under the current board, food, and cycle rules.

HYBRID 中玩家可覆盖下一步；发生不同于 AI 决策的干预后，界面会标记保证失效并重置算法缓存。/ In HYBRID, the player can override one step; a differing intervention removes the guarantee and resets algorithm memory.

## 🏆 榜单与复现 / Records and Replays

榜单按棋盘尺寸、`WALLS/WRAP`、`AUTO/HYBRID` 和算法分别保存；MANUAL 按尺寸与边界保存。/ Records are separated by board size, `WALLS/WRAP`, `AUTO/HYBRID`, and algorithm; MANUAL is separated by size and edge mode.

食物 RNG 与 AI RNG 使用独立流，因此同一 seed、模式和操作可重放相同轨迹。/ Food and AI RNG use independent streams, so the same seed, modes, and inputs replay the same trajectory.

## 🗂️ 源码结构 / Source Layout

算法实现在 `src/ai/*-algorithm.lua`，共享搜索在 `src/ai/shared/`，注册表是 `src/ai/algorithm-registry.lua`。/ Implementations live in `src/ai/*-algorithm.lua`, shared searches in `src/ai/shared/`, and registration in `src/ai/algorithm-registry.lua`.

Hamiltonian 回路在宽为偶数时直接生成，仅高为偶数时转置生成；双奇数棋盘会被拒绝。/ Hamiltonian cycles are generated directly for even widths and transposed for even-only heights; odd-by-odd boards are rejected.
