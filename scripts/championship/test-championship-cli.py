from __future__ import annotations

import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile


SCRIPT_PATH = Path(__file__).with_name("championship-cli.py")


def load_module():
    spec = importlib.util.spec_from_file_location("championship_cli", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load championship-cli.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


championship = load_module()


def sample_report(with_winner: bool = True) -> dict:
    greedy = {
        "algorithm": "greedy",
        "rank": 2,
        "runs": 2,
        "wins": 0,
        "completionRate": 0,
        "averageFillRate": 0.42,
        "timeouts": 0,
        "collisions": 2,
        "errors": 0,
    }
    hamiltonian = {
        "algorithm": "hamiltonian",
        "rank": 1,
        "runs": 2,
        "wins": 2 if with_winner else 0,
        "completionRate": 1 if with_winner else 0,
        "averageFillRate": 1 if with_winner else 0.81,
        "timeouts": 0 if with_winner else 2,
        "collisions": 0,
        "errors": 0,
    }
    reliability = [hamiltonian, greedy]
    efficiency = ([{"algorithm": "hamiltonian", "rank": 1, "wins": 2,
                    "median": 18.5, "mean": 19.25}] if with_winner else [])
    return {
        "schemaVersion": 1,
        "kind": "lua-love2d-snake-championship",
        "config": {
            "sizes": [{"cols": 10, "rows": 8, "key": "10x8"}],
            "edges": ["walls"],
            "algorithms": ["greedy", "hamiltonian"],
            "runs": 2,
            "masterSeed": "test",
        },
        "games": [],
        "rankings": {
            "overall": {"reliability": reliability, "efficiency": efficiency},
            "scenarios": [{
                "size": "10x8",
                "edge": "walls",
                "reliability": reliability,
                "efficiency": efficiency,
            }],
        },
    }


class ChampionshipCliTests(unittest.TestCase):
    def test_rejects_wrong_schema(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "report.json"
            path.write_text('{"schemaVersion":2}', encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "schema version"):
                championship.load_report(path)

    def test_engine_commands_support_lua_and_love(self) -> None:
        lua = championship.engine_command("lua5.1", ["--runs", "1"])
        self.assertTrue(lua[1].endswith("run-championship.lua"))
        love = championship.engine_command("lovec.exe", ["--runs", "1"])
        self.assertEqual(love[2], "--run-championship")

    def test_visual_markdown_is_idempotent(self) -> None:
        original = "# AI Championship\n\nResults.\n"
        first = championship.inject_visuals(original)
        second = championship.inject_visuals(first)
        self.assertEqual(first, second)
        self.assertEqual(first.count(championship.VISUALS_START), 1)
        for filename in championship.CHART_FILENAMES:
            self.assertIn(filename, first)

    def test_renders_pngs_and_deterministic_archive(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, output = root / "source", root / "rendered"
            source.mkdir()
            (source / "championship.json").write_text(
                json.dumps(sample_report()), encoding="utf-8"
            )
            (source / "championship.csv").write_text("size,algorithm\n", encoding="utf-8")
            (source / "championship.md").write_text("# 🏆 AI Championship\n", encoding="utf-8")
            championship.render_report(source / "championship.json", output)
            for filename in championship.REPORT_FILENAMES:
                self.assertTrue((output / filename).is_file())
            for filename in championship.CHART_FILENAMES:
                data = (output / filename).read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                width, height = struct.unpack(">II", data[16:24])
                self.assertGreater(width, 1000)
                self.assertGreater(height, 700)

            first, second = output / "first.zip", output / "second.zip"
            championship.archive_reports(output, first)
            championship.archive_reports(output, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with ZipFile(first) as archive:
                self.assertEqual(
                    archive.namelist(),
                    sorted(championship.REPORT_FILENAMES + championship.CHART_FILENAMES),
                )
                self.assertTrue(all(item.date_time == (1980, 1, 1, 0, 0, 0)
                                    for item in archive.infolist()))

    def test_efficiency_chart_handles_no_winners(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            document = sample_report(with_winner=False)
            plt = championship.configure_matplotlib()
            path = output / "efficiency.png"
            championship.render_efficiency(document, path, plt)
            self.assertTrue(path.is_file())


if __name__ == "__main__":
    unittest.main()
