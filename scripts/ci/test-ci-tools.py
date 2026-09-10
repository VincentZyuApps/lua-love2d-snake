from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from zipfile import ZipFile


SCRIPT_DIR = Path(__file__).parent
REPOSITORY_ROOT = SCRIPT_DIR.parents[1]


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, SCRIPT_DIR / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {filename}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


trigger = load_module("ci_trigger", "ci-trigger.py")
package = load_module("package_love", "ci-package-love.py")
release_renderer = load_module("release_renderer", "ci-render-release.py")


class TriggerTests(unittest.TestCase):
    def test_exact_tokens(self) -> None:
        self.assertTrue(trigger.contains_token("ship [build-action]", "build-action"))
        self.assertTrue(trigger.contains_token("[build-release]\nnotes", "build-release"))
        self.assertTrue(trigger.contains_token("compare [run-championship]", "run-championship"))
        self.assertTrue(trigger.contains_token(
            "publish [release-championship]", "release-championship"))

    def test_rejects_unbracketed_and_wrong_case(self) -> None:
        self.assertFalse(trigger.contains_token("build-action", "build-action"))
        self.assertFalse(trigger.contains_token("[BUILD-ACTION]", "build-action"))


class PackageTests(unittest.TestCase):
    def test_package_has_game_files_at_root(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "main.lua").write_text("function love.draw() end\n", encoding="utf-8")
            (root / "conf.lua").write_text("function love.conf(t) end\n", encoding="utf-8")
            (root / "src" / "ai").mkdir(parents=True)
            (root / "src" / "app.lua").write_text("return {}\n", encoding="utf-8")
            (root / "src" / "ai" / "demo-algorithm.lua").write_text("return {}\n", encoding="utf-8")
            output = root / "dist" / "game.love"
            package.build_package(root, output)
            with ZipFile(output) as archive:
                self.assertEqual(
                    archive.namelist(),
                    ["conf.lua", "main.lua", "src/ai/demo-algorithm.lua", "src/app.lua"],
                )

            second_output = root / "dist" / "game-again.love"
            package.build_package(root, second_output)
            self.assertEqual(output.read_bytes(), second_output.read_bytes())


class ReleaseTemplateTests(unittest.TestCase):
    def test_unresolved_placeholders_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unresolved release placeholders"):
            release_renderer.render_template("Version __VERSION__ / __MISSING__", {"VERSION": "0.6.0"})

    def test_game_and_championship_templates_render(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            changes = root / "changes.md"
            changes.write_text("- Added charts", encoding="utf-8")
            game_args = SimpleNamespace(
                repository="VincentZyuApps/lua-love2d-snake",
                version="0.6.0",
                tag="v0.6.0",
                sha="a" * 40,
                recorded_at_utc="2026-09-10T12:00:00Z",
                workflow_url="https://github.com/example/actions/runs/1",
                changes_file=str(changes),
            )
            game_template = (REPOSITORY_ROOT / ".github/release-templates/game-release.md").read_text(
                encoding="utf-8")
            game = release_renderer.render_template(
                game_template, release_renderer.game_values(game_args))
            self.assertNotRegex(game, release_renderer.PLACEHOLDER)
            self.assertIn("lua-love2d-snake-v0.6.0.love", game)

            report = root / "championship.json"
            report.write_text(json.dumps({
                "schemaVersion": 1,
                "kind": "lua-love2d-snake-championship",
                "config": {
                    "sizes": [{"key": "10x8"}],
                    "edges": ["walls"],
                    "runs": 1,
                    "masterSeed": "test",
                },
                "games": [{}],
                "rankings": {"overall": {
                    "reliability": [{"algorithm": "hamiltonian", "rank": 1}],
                    "efficiency": [{"algorithm": "hamiltonian", "rank": 1}],
                }},
            }), encoding="utf-8")
            championship_args = SimpleNamespace(
                repository="VincentZyuApps/lua-love2d-snake",
                version="0.6.0",
                tag="championship-v0.6.0-test",
                sha="b" * 40,
                recorded_at_utc="2026-09-10T12:00:00Z",
                recorded_at_local="2026-09-10 20:00 CST",
                workflow_url="https://github.com/example/actions/runs/2",
                trigger="manual:release",
                report=str(report),
                archive_name="championship.zip",
            )
            championship_template = (
                REPOSITORY_ROOT / ".github/release-templates/championship-release.md"
            ).read_text(encoding="utf-8")
            championship_body = release_renderer.render_template(
                championship_template,
                release_renderer.championship_values(championship_args),
            )
            self.assertNotRegex(championship_body, release_renderer.PLACEHOLDER)
            self.assertIn("championship-reliability.png", championship_body)


class NamingTests(unittest.TestCase):
    def test_python_filenames_use_kebab_case(self) -> None:
        pattern = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)+\.py$")
        files = sorted(REPOSITORY_ROOT.rglob("*.py"))
        invalid = [path.relative_to(REPOSITORY_ROOT).as_posix() for path in files if not pattern.fullmatch(path.name)]
        self.assertEqual(invalid, [])

    def test_direct_ai_lua_filenames_have_multiple_words(self) -> None:
        pattern = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)+\.lua$")
        files = sorted((REPOSITORY_ROOT / "src" / "ai").glob("*.lua"))
        invalid = [path.name for path in files if not pattern.fullmatch(path.name)]
        self.assertEqual(invalid, [])

    def test_agent_guide_stays_compact_and_bilingual(self) -> None:
        lines = (REPOSITORY_ROOT / "AGENTS.md").read_text(encoding="utf-8").splitlines()
        self.assertLessEqual(len(lines), 50)
        content_lines = [line for line in lines if line.strip()]
        self.assertTrue(all("/ " in line for line in content_lines))


if __name__ == "__main__":
    unittest.main()
