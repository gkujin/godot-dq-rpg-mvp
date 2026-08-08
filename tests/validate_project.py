#!/usr/bin/env python3
"""Dependency-free structural checks for CI environments without Godot."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "project.godot",
    "src/main/main.tscn",
    "src/main/main.gd",
    "src/core/game_state.gd",
    "src/core/save_service.gd",
    "src/core/game_database.gd",
    "src/battle/battle_engine.gd",
    "src/world/world_view.gd",
]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def referenced_resources() -> set[str]:
    paths: set[str] = set()
    for file_path in ROOT.rglob("*"):
        if file_path.suffix not in {".gd", ".tscn", ".godot", ".cfg"}:
            continue
        text = file_path.read_text(encoding="utf-8")
        paths.update(re.findall(r'res://([^"\'\n]+)', text))
    return paths


def validate_balanced_brackets(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    pairs = {")": "(", "]": "[", "}": "{"}
    opening = set(pairs.values())
    stack: list[tuple[str, int]] = []
    quote = ""
    escaped = False
    in_comment = False
    line = 1

    for char in text:
        if char == "\n":
            line += 1
            in_comment = False
            escaped = False
            continue
        if in_comment:
            continue
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
            continue
        if char == "#":
            in_comment = True
        elif char in {'"', "'"}:
            quote = char
        elif char in opening:
            stack.append((char, line))
        elif char in pairs:
            if not stack or stack[-1][0] != pairs[char]:
                fail(f"{path.relative_to(ROOT)}:{line}: unmatched {char}")
            stack.pop()
    if quote:
        fail(f"{path.relative_to(ROOT)}: unterminated string")
    if stack:
        token, token_line = stack[-1]
        fail(f"{path.relative_to(ROOT)}:{token_line}: unmatched {token}")


def main() -> None:
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            fail(f"missing required file: {relative}")

    for resource in sorted(referenced_resources()):
        if not (ROOT / resource).exists():
            fail(f"missing res:// resource: {resource}")

    class_names: dict[str, Path] = {}
    for script in ROOT.rglob("*.gd"):
        validate_balanced_brackets(script)
        match = re.search(r"^class_name\s+(\w+)", script.read_text(encoding="utf-8"), re.MULTILINE)
        if not match:
            continue
        class_name = match.group(1)
        if class_name in class_names:
            fail(f"duplicate class_name {class_name}: {script} and {class_names[class_name]}")
        class_names[class_name] = script

    database = (ROOT / "src/core/game_database.gd").read_text(encoding="utf-8")
    for required_id in [
        '"town"',
        '"field"',
        '"dungeon"',
        '"slime"',
        '"bat"',
        '"wolf"',
        '"stone_drake"',
        '"herb"',
        '"ether"',
        '"elixir"',
    ]:
        if required_id not in database:
            fail(f"missing MVP definition: {required_id}")

    print(f"PASS: validated {len(list(ROOT.rglob('*.gd')))} GDScript files and all res:// references")


if __name__ == "__main__":
    main()

