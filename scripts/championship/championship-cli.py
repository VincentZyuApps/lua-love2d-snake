# /// script
# requires-python = ">=3.10"
# dependencies = ["matplotlib==3.10.6", "pyparsing==3.2.5"]
# ///

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
REPORT_KIND = "lua-love2d-snake-championship"
REPORT_SCHEMA_VERSION = 1
CHART_FILENAMES = (
    "championship-reliability.png",
    "championship-efficiency.png",
    "championship-scenarios.png",
)
REPORT_FILENAMES = ("championship.md", "championship.csv", "championship.json")
VISUALS_START = "<!-- CHAMPIONSHIP_VISUALS_START -->"
VISUALS_END = "<!-- CHAMPIONSHIP_VISUALS_END -->"
ALGORITHM_NAMES = {
    "random-safe": "Random Safe",
    "greedy": "Greedy",
    "bfs-shortest": "BFS Shortest",
    "astar-tail-safe": "A* Tail Safe",
    "space-scoring": "Space Scoring",
    "beam-search": "Beam Search",
    "hamiltonian": "Hamiltonian",
    "hamiltonian-shortcut": "Hamiltonian Shortcut",
}


def repository_path(value: str | Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else REPOSITORY_ROOT / path


def load_report(path: Path) -> dict[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Could not read championship report: {error}") from error
    if not isinstance(document, dict):
        raise ValueError("Championship report must be a JSON object")
    if document.get("schemaVersion") != REPORT_SCHEMA_VERSION:
        raise ValueError("Unsupported championship schema version")
    if document.get("kind") != REPORT_KIND:
        raise ValueError("Unsupported championship report kind")
    if not isinstance(document.get("rankings"), dict) or not isinstance(document.get("config"), dict):
        raise ValueError("Championship report is missing rankings or config")
    return document


def algorithm_name(algorithm_id: str) -> str:
    return ALGORITHM_NAMES.get(algorithm_id, algorithm_id.replace("-", " ").title())


def configure_matplotlib() -> Any:
    os.environ.setdefault("MPLBACKEND", "Agg")
    os.environ.setdefault("MPLCONFIGDIR", str(REPOSITORY_ROOT / "build" / "matplotlib-cache"))
    import matplotlib

    matplotlib.use("Agg")
    from matplotlib import pyplot as plt

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 10,
            "axes.titleweight": "bold",
            "axes.spines.top": False,
            "axes.spines.right": False,
            "figure.facecolor": "white",
            "savefig.facecolor": "white",
        }
    )
    return plt


def save_figure(figure: Any, path: Path) -> None:
    figure.savefig(
        path,
        dpi=150,
        bbox_inches="tight",
        metadata={"Software": "lua-love2d-snake championship-cli"},
    )


def render_reliability(document: dict[str, Any], output: Path, plt: Any) -> None:
    ranking = document["rankings"]["overall"]["reliability"]
    labels = [algorithm_name(item["algorithm"]) for item in ranking]
    completion = [item["completionRate"] * 100 for item in ranking]
    fill = [item["averageFillRate"] * 100 for item in ranking]
    positions = list(range(len(labels)))
    height = 0.36
    figure, axis = plt.subplots(figsize=(10.667, 6))
    axis.barh([position - height / 2 for position in positions], completion, height,
              color="#16865b", label="Completion rate")
    axis.barh([position + height / 2 for position in positions], fill, height,
              color="#2878b5", label="Average fill")
    axis.set_yticks(positions, labels)
    axis.invert_yaxis()
    axis.set_xlim(0, 100)
    axis.set_xlabel("Percent")
    axis.set_title("Overall Reliability")
    axis.grid(axis="x", color="#d9dde3", linewidth=0.8)
    axis.set_axisbelow(True)
    axis.legend(loc="lower right")
    for position, value in enumerate(completion):
        axis.text(min(value + 1, 98), position - height / 2, f"{value:.1f}%", va="center", fontsize=8)
    for position, value in enumerate(fill):
        axis.text(min(value + 1, 98), position + height / 2, f"{value:.1f}%", va="center", fontsize=8)
    figure.tight_layout()
    save_figure(figure, output)
    plt.close(figure)


def render_efficiency(document: dict[str, Any], output: Path, plt: Any) -> None:
    reliability = document["rankings"]["overall"]["reliability"]
    efficiency = {
        item["algorithm"]: item for item in document["rankings"]["overall"]["efficiency"]
    }
    algorithms = [item["algorithm"] for item in reliability]
    labels = [algorithm_name(algorithm) for algorithm in algorithms]
    values = [efficiency.get(algorithm, {}).get("median", 0) for algorithm in algorithms]
    colors = ["#d78221" if algorithm in efficiency else "#c9ced6" for algorithm in algorithms]
    positions = list(range(len(labels)))
    figure, axis = plt.subplots(figsize=(10.667, 6))
    axis.barh(positions, values, color=colors, height=0.62)
    axis.set_yticks(positions, labels)
    axis.invert_yaxis()
    axis.set_xlabel("Median steps per food (lower is better)")
    axis.set_title("Winning Efficiency")
    axis.grid(axis="x", color="#d9dde3", linewidth=0.8)
    axis.set_axisbelow(True)
    maximum = max(values, default=0)
    axis.set_xlim(0, maximum * 1.18 if maximum > 0 else 1)
    for position, algorithm in enumerate(algorithms):
        item = efficiency.get(algorithm)
        if item:
            axis.text(item["median"] + maximum * 0.015, position,
                      f"{item['median']:.2f} ({item['wins']} wins)", va="center", fontsize=8)
        else:
            axis.text(maximum * 0.015 if maximum > 0 else 0.02, position,
                      "No wins", va="center", fontsize=8, color="#59616d")
    figure.tight_layout()
    save_figure(figure, output)
    plt.close(figure)


def render_scenarios(document: dict[str, Any], output: Path, plt: Any) -> None:
    overall = document["rankings"]["overall"]["reliability"]
    algorithms = [item["algorithm"] for item in overall]
    scenarios = document["rankings"]["scenarios"]
    if not scenarios or not algorithms:
        raise ValueError("Championship report contains no scenario rankings")
    matrix: list[list[float]] = []
    annotations: list[list[str]] = []
    for algorithm in algorithms:
        values, labels = [], []
        for scenario in scenarios:
            by_algorithm = {item["algorithm"]: item for item in scenario["reliability"]}
            item = by_algorithm[algorithm]
            fill, wins = item["averageFillRate"] * 100, item["completionRate"] * 100
            values.append(fill)
            labels.append(f"F {fill:.0f}%\nW {wins:.0f}%")
        matrix.append(values)
        annotations.append(labels)
    width = max(10.667, min(20.0, 4.2 + len(scenarios) * 1.25))
    figure, axis = plt.subplots(figsize=(width, 6))
    image = axis.imshow(matrix, cmap="viridis", vmin=0, vmax=100, aspect="auto")
    axis.set_xticks(range(len(scenarios)),
                    [f"{item['size']}\n{item['edge'].upper()}" for item in scenarios])
    axis.set_yticks(range(len(algorithms)), [algorithm_name(item) for item in algorithms])
    axis.set_title("Scenario Performance")
    axis.set_xlabel("Board and edge mode")
    for row, labels in enumerate(annotations):
        for column, label in enumerate(labels):
            color = "white" if matrix[row][column] < 55 else "black"
            axis.text(column, row, label, ha="center", va="center", color=color, fontsize=7)
    colorbar = figure.colorbar(image, ax=axis, pad=0.02)
    colorbar.set_label("Average fill (%)")
    figure.tight_layout()
    save_figure(figure, output)
    plt.close(figure)


def visual_markdown() -> str:
    lines = [
        VISUALS_START,
        "## 📈 Visual Summary",
        "",
        "![Overall reliability](championship-reliability.png)",
        "",
        "![Winning efficiency](championship-efficiency.png)",
        "",
        "![Scenario performance](championship-scenarios.png)",
        VISUALS_END,
    ]
    return "\n".join(lines)


def inject_visuals(markdown: str) -> str:
    block = visual_markdown()
    if VISUALS_START in markdown and VISUALS_END in markdown:
        prefix, remainder = markdown.split(VISUALS_START, 1)
        _, suffix = remainder.split(VISUALS_END, 1)
        return prefix.rstrip() + "\n\n" + block + suffix
    return markdown.rstrip() + "\n\n" + block + "\n"


def render_report(report_path: Path, output_dir: Path) -> dict[str, Any]:
    document = load_report(report_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    source_dir = report_path.parent
    for filename in REPORT_FILENAMES:
        source, destination = source_dir / filename, output_dir / filename
        if not source.is_file():
            raise ValueError(f"Missing championship report: {source}")
        if source.resolve() != destination.resolve():
            shutil.copyfile(source, destination)
    plt = configure_matplotlib()
    render_reliability(document, output_dir / CHART_FILENAMES[0], plt)
    render_efficiency(document, output_dir / CHART_FILENAMES[1], plt)
    render_scenarios(document, output_dir / CHART_FILENAMES[2], plt)
    markdown_path = output_dir / "championship.md"
    markdown_path.write_text(
        inject_visuals(markdown_path.read_text(encoding="utf-8")), encoding="utf-8", newline="\n"
    )
    return document


def archive_reports(output_dir: Path, archive_path: Path) -> None:
    filenames = sorted(REPORT_FILENAMES + CHART_FILENAMES)
    missing = [name for name in filenames if not (output_dir / name).is_file()]
    if missing:
        raise ValueError("Missing championship files: " + ", ".join(missing))
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(archive_path, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for filename in filenames:
            info = ZipInfo(filename, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, (output_dir / filename).read_bytes())


def resolve_executable(explicit: str | None) -> str:
    if explicit:
        candidate = shutil.which(explicit)
        if candidate:
            return candidate
        path = repository_path(explicit)
        if path.is_file():
            return str(path)
        raise ValueError(f"Championship engine was not found: {explicit}")
    for name in ("lua5.1", "lua51", "lua", "lovec", "love"):
        candidate = shutil.which(name)
        if candidate:
            return candidate
    raise ValueError("No Lua or LÖVE CLI found; install Lua 5.1 or pass --engine")


def engine_command(executable: str, championship_args: Sequence[str]) -> list[str]:
    stem = Path(executable).stem.lower()
    if stem in {"love", "lovec"}:
        return [executable, str(REPOSITORY_ROOT), "--run-championship", *championship_args]
    return [executable, str(REPOSITORY_ROOT / "scripts/championship/run-championship.lua"),
            *championship_args]


def add_championship_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--sizes", default="20x14,30x21,40x28")
    parser.add_argument("--edges", default="walls,wrap")
    parser.add_argument("--algorithms", default="all")
    parser.add_argument("--runs", type=int, default=10)
    parser.add_argument("--master-seed", default="snake-championship-v1")
    parser.add_argument("--output-dir", default="build/championship")


def championship_arguments(args: argparse.Namespace, output_dir: Path) -> list[str]:
    return [
        "--sizes", args.sizes,
        "--edges", args.edges,
        "--algorithms", args.algorithms,
        "--runs", str(args.runs),
        "--master-seed", args.master_seed,
        "--output-dir", str(output_dir),
    ]


def parse_arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run and visualize deterministic Snake championships.")
    commands = parser.add_subparsers(dest="command", required=True)
    run = commands.add_parser("run", help="Run Lua games, then render charts.")
    add_championship_options(run)
    run.add_argument("--engine", help="Lua or LÖVE executable name/path; auto-detected by default.")
    run.add_argument("--archive", help="Optional deterministic ZIP output path.")
    render = commands.add_parser("render", help="Render charts from an existing report.")
    render.add_argument("--input", default="build/championship/championship.json")
    render.add_argument("--output-dir", help="Defaults to the JSON report directory.")
    render.add_argument("--archive", help="Optional deterministic ZIP output path.")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        args = parse_arguments(argv)
        if args.command == "run":
            output_dir = repository_path(args.output_dir)
            executable = resolve_executable(args.engine)
            subprocess.run(
                engine_command(executable, championship_arguments(args, output_dir)),
                cwd=REPOSITORY_ROOT,
                check=True,
            )
            report_path = output_dir / "championship.json"
        else:
            report_path = repository_path(args.input)
            output_dir = repository_path(args.output_dir) if args.output_dir else report_path.parent
        render_report(report_path, output_dir)
        if args.archive:
            archive_reports(output_dir, repository_path(args.archive))
        print(f"Visual championship report written to {output_dir}")
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
