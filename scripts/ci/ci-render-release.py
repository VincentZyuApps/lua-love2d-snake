from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Mapping


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
PLACEHOLDER = re.compile(r"__[A-Z0-9_]+__")


def read_path(path: str | Path) -> Path:
    value = Path(path)
    return value if value.is_absolute() else REPOSITORY_ROOT / value


def render_template(template: str, values: Mapping[str, str]) -> str:
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace(f"__{key}__", value)
    unresolved = sorted(set(PLACEHOLDER.findall(rendered)))
    if unresolved:
        raise ValueError("Unresolved release placeholders: " + ", ".join(unresolved))
    return rendered.rstrip() + "\n"


def display_algorithm(algorithm_id: str) -> str:
    names = {
        "random-safe": "Random Safe",
        "greedy": "Greedy",
        "bfs-shortest": "BFS Shortest",
        "astar-tail-safe": "A* Tail Safe",
        "space-scoring": "Space Scoring",
        "beam-search": "Beam Search",
        "hamiltonian": "Hamiltonian",
        "hamiltonian-shortcut": "Hamiltonian Shortcut",
    }
    return names.get(algorithm_id, algorithm_id.replace("-", " ").title())


def ranked_names(items: list[dict]) -> str:
    winners = [display_algorithm(item["algorithm"]) for item in items if item.get("rank") == 1]
    return ", ".join(winners) if winners else "No winner / 无胜者"


def game_values(args: argparse.Namespace) -> dict[str, str]:
    base_url = f"https://github.com/{args.repository}/releases/download/{args.tag}"
    changes = read_path(args.changes_file).read_text(encoding="utf-8").strip()
    return {
        "VERSION": args.version,
        "TAG": args.tag,
        "REPOSITORY": args.repository,
        "BASE_URL": base_url,
        "SHA": args.sha,
        "SHORT_SHA": args.sha[:7],
        "RECORDED_AT_UTC": args.recorded_at_utc,
        "WORKFLOW_URL": args.workflow_url,
        "CHANGES": changes or "- 本次未提供变更记录。/ No change log was provided for this run.",
    }


def championship_values(args: argparse.Namespace) -> dict[str, str]:
    report = json.loads(read_path(args.report).read_text(encoding="utf-8"))
    if report.get("schemaVersion") != 1 or report.get("kind") != "lua-love2d-snake-championship":
        raise ValueError("Unsupported championship report")
    config = report["config"]
    overall = report["rankings"]["overall"]
    base_url = f"https://github.com/{args.repository}/releases/download/{args.tag}"
    sizes = ", ".join(item["key"] for item in config["sizes"])
    edges = ", ".join(item.upper() for item in config["edges"])
    game_count = len(report.get("games", []))
    return {
        "VERSION": args.version,
        "TAG": args.tag,
        "REPOSITORY": args.repository,
        "BASE_URL": base_url,
        "SHA": args.sha,
        "SHORT_SHA": args.sha[:7],
        "RECORDED_AT_UTC": args.recorded_at_utc,
        "RECORDED_AT_LOCAL": args.recorded_at_local,
        "WORKFLOW_URL": args.workflow_url,
        "TRIGGER": args.trigger,
        "SIZES": sizes,
        "EDGES": edges,
        "RUNS": str(config["runs"]),
        "GAME_COUNT": str(game_count),
        "MASTER_SEED": str(config["masterSeed"]),
        "RELIABILITY_WINNER": ranked_names(overall["reliability"]),
        "EFFICIENCY_WINNER": ranked_names(overall["efficiency"]),
        "ARCHIVE_NAME": args.archive_name,
        "ARCHIVE_URL": f"{base_url}/{args.archive_name}",
        "RELIABILITY_URL": f"{base_url}/championship-reliability.png",
        "EFFICIENCY_URL": f"{base_url}/championship-efficiency.png",
        "SCENARIOS_URL": f"{base_url}/championship-scenarios.png",
    }


def common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--template", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--recorded-at-utc", required=True)
    parser.add_argument("--workflow-url", required=True)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render strict GitHub Release templates.")
    commands = parser.add_subparsers(dest="kind", required=True)
    game = commands.add_parser("game")
    common_arguments(game)
    game.add_argument("--changes-file", required=True)
    championship = commands.add_parser("championship")
    common_arguments(championship)
    championship.add_argument("--report", required=True)
    championship.add_argument("--archive-name", required=True)
    championship.add_argument("--recorded-at-local", required=True)
    championship.add_argument("--trigger", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_arguments()
    template = read_path(args.template).read_text(encoding="utf-8")
    values = game_values(args) if args.kind == "game" else championship_values(args)
    output = read_path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_template(template, values), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
