from __future__ import annotations

import importlib.util
import re
import tempfile
import unittest
from pathlib import Path
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


class TriggerTests(unittest.TestCase):
    def test_exact_tokens(self) -> None:
        self.assertTrue(trigger.contains_token("ship [build-action]", "build-action"))
        self.assertTrue(trigger.contains_token("[build-release]\nnotes", "build-release"))

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


if __name__ == "__main__":
    unittest.main()
