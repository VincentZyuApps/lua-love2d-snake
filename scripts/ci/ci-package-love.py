from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


PACKAGE_FILES = ("ai-cycle.lua", "conf.lua", "main.lua")


def add_file(archive: ZipFile, source: Path, archive_name: str) -> None:
    info = ZipInfo(archive_name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    archive.writestr(info, source.read_bytes())


def build_package(source_dir: Path, output: Path) -> None:
    missing = [name for name in PACKAGE_FILES if not (source_dir / name).is_file()]
    if missing:
        raise FileNotFoundError("Missing game files: " + ", ".join(missing))

    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w") as archive:
        for name in PACKAGE_FILES:
            add_file(archive, source_dir / name, name)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build a deterministic LÖVE package.")
    parser.add_argument("--path", type=Path, default=Path("."), help="Game source directory")
    parser.add_argument("--output", type=Path, required=True, help="Output .love file")
    args = parser.parse_args()
    build_package(args.path.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()
