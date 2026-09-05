from __future__ import annotations

import argparse
import random
from collections import deque


MIN_SIZE = 5
MAX_SIZE = 50


def build_even_width_cycle(cols: int, rows: int) -> list[tuple[int, int]]:
    cells = [(x, 1) for x in range(1, cols + 1)]
    cells.extend((cols, y) for y in range(2, rows + 1))
    current_y = rows
    for x in range(cols - 1, 1, -1):
        cells.append((x, current_y))
        target_y = 2 if current_y == rows else rows
        step = 1 if target_y > current_y else -1
        cells.extend((x, y) for y in range(current_y + step, target_y + step, step))
        current_y = target_y
    if current_y != rows:
        raise ValueError("The generated cycle cannot close.")
    cells.extend((1, y) for y in range(rows, 1, -1))
    return cells


def build_cycle(cols: int, rows: int) -> list[tuple[int, int]]:
    if cols < MIN_SIZE or rows < MIN_SIZE or cols > MAX_SIZE or rows > MAX_SIZE:
        raise ValueError("Board dimensions must be between 5 and 50.")
    if cols % 2 and rows % 2:
        raise ValueError("At least one board dimension must be even.")
    if cols % 2 == 0:
        return build_even_width_cycle(cols, rows)
    return [(y, x) for x, y in build_even_width_cycle(rows, cols)]


def validate_cycle(cells: list[tuple[int, int]], cols: int, rows: int) -> None:
    if len(cells) != cols * rows or len(set(cells)) != cols * rows:
        raise ValueError(f"{cols}x{rows} does not cover each cell exactly once.")
    for index, current in enumerate(cells):
        following = cells[(index + 1) % len(cells)]
        if abs(following[0] - current[0]) + abs(following[1] - current[1]) != 1:
            raise ValueError(f"{cols}x{rows} contains non-adjacent cycle cells.")


def simulate_win(cells: list[tuple[int, int]], seed: int) -> int:
    rng = random.Random(seed)
    head_index = len(cells) // 2
    body = deque(cells[(head_index - offset) % len(cells)] for offset in range(4))
    occupied = set(body)
    steps = 0
    while len(body) < len(cells):
        open_cells = [cell for cell in cells if cell not in occupied]
        food = rng.choice(open_cells)
        while body[0] != food:
            head_index = (head_index + 1) % len(cells)
            next_head = cells[head_index]
            entering_tail = next_head == body[-1]
            if next_head in occupied and not entering_tail:
                raise AssertionError(f"Seed {seed} collided at step {steps}.")
            if next_head != food:
                occupied.remove(body.pop())
            body.appendleft(next_head)
            occupied.add(next_head)
            steps += 1
    return steps


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify dynamic Hamiltonian cycles for every supported board.")
    parser.add_argument("--path", help="Accepted for compatibility; the verifier does not write files.")
    parser.add_argument("--check", action="store_true", help="Accepted for compatibility.")
    parser.add_argument("--seeds", type=int, default=10, help="Default-board simulations to run.")
    args = parser.parse_args()
    if args.seeds < 1:
        parser.error("--seeds must be at least 1")

    count = 0
    for cols in range(MIN_SIZE, MAX_SIZE + 1):
        for rows in range(MIN_SIZE, MAX_SIZE + 1):
            if cols % 2 == 0 or rows % 2 == 0:
                validate_cycle(build_cycle(cols, rows), cols, rows)
                count += 1

    default_cycle = build_cycle(30, 21)
    longest = max(simulate_win(default_cycle, seed) for seed in range(args.seeds))
    print(f"Verified {count} supported board sizes and {args.seeds} complete games; longest run: {longest} steps.")


if __name__ == "__main__":
    main()
