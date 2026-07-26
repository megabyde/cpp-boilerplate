#!/usr/bin/env python3
"""Rename this template for a new project.

Derives kebab-case, snake_case, and PascalCase identifiers from a name in any common casing.
Rewrites the tracked project files, moves the include directory, then removes this script, its
README section, and the workflow that smoke-tests it. Use --dry-run to preview the changes first.

conan.lock needs no regeneration: the project name lives in conanfile.py/CMakeLists.txt, not
in the lock file's dependency graph.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

OLD_SNAKE = "cpp_boilerplate"
OLD_KEBAB = "cpp-boilerplate"
OLD_CONAN_CLASS = "CppBoilerplateConan"
OLD_TITLE = "C++ Boilerplate"
OLD_GITHUB_OWNER = "megabyde"
INSTANTIATE_HEADING = "## Instantiate this template"
# This workflow invokes scripts/rename.py, so remove both together to keep the renamed project's
# first CI run from referencing a missing script
TEMPLATE_WORKFLOW = Path(".github/workflows/template.yml")


def split_words(name: str) -> list[str]:
    """Split a kebab/snake/Pascal/plain name into lowercase words."""
    words = []
    for chunk in re.split(r"[^0-9A-Za-z]+", name):
        words.extend(re.findall(r"[A-Za-z][a-z0-9]*|[0-9]+", chunk))
    return [word.lower() for word in words]


def derive_names(new_name: str) -> tuple[str, str, str]:
    """Return (snake_case, kebab-case, PascalCase) derived from new_name.

    Raises:
        ValueError: new_name has no usable characters, or the derived snake_case form
            is not a valid C++/CMake identifier (e.g. it would start with a digit).
    """
    words = split_words(new_name)
    if not words:
        raise ValueError(f"'{new_name}' has no usable name characters")
    snake = "_".join(words)
    if not re.fullmatch(r"[a-z][a-z0-9_]*", snake):
        raise ValueError(f"derived identifier '{snake}' is not a valid C++/CMake identifier")
    kebab = "-".join(words)
    pascal = "".join(word.capitalize() for word in words)
    return snake, kebab, pascal


def tracked_files(root: Path) -> list[Path]:
    output = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"], check=True, capture_output=True
    ).stdout
    return [root / name for name in output.decode().split("\0") if name]


def build_replacements(
    snake: str, kebab: str, pascal: str, title: str, github_owner: str | None
) -> list[tuple[str, str]]:
    replacements = [
        (OLD_CONAN_CLASS, f"{pascal}Conan"),
        (OLD_SNAKE, snake),
        (OLD_KEBAB, kebab),
        (OLD_TITLE, title),
    ]
    if github_owner:
        replacements.append((OLD_GITHUB_OWNER, github_owner))
    return replacements


def apply_replacements(text: str, replacements: list[tuple[str, str]]) -> tuple[str, int]:
    """Apply every (old, new) pair and return the number of replaced occurrences."""
    count = 0
    for old, new in replacements:
        occurrences = text.count(old)
        if occurrences:
            text = text.replace(old, new)
            count += occurrences
    return text, count


def strip_instantiate_section(text: str) -> str:
    """Drop the 'Instantiate this template' section (up to the next top-level heading)."""
    pattern = re.compile(
        rf"^{re.escape(INSTANTIATE_HEADING)}\n.*?(?=^## |\Z)", re.DOTALL | re.MULTILINE
    )
    return pattern.sub("", text, count=1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", help="new project name, any casing (e.g. my-cool-project)")
    parser.add_argument("--title", help="README heading text (default: Title Case of NAME)")
    parser.add_argument(
        "--github-owner",
        help=f"replace the '{OLD_GITHUB_OWNER}' GitHub owner in README badge/clone URLs",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print planned changes without writing them"
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    try:
        snake, kebab, pascal = derive_names(args.name)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    title = args.title or " ".join(word.capitalize() for word in split_words(args.name))
    replacements = build_replacements(snake, kebab, pascal, title, args.github_owner)

    script_path = Path(__file__).resolve()
    changes: dict[Path, int] = {}
    for path in tracked_files(root):
        if path == script_path:
            continue
        try:
            # UnicodeDecodeError means the file is not UTF-8 text, for example a binary asset.
            # OSError means a tracked path no longer exists, for example a submodule gitlink or a
            # concurrent edit. Neither case contains text this script can rewrite.
            text = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        new_text, count = apply_replacements(text, replacements)
        if path.name == "README.md":
            stripped = strip_instantiate_section(new_text)
            if stripped != new_text:
                count += 1
                new_text = stripped
        if count:
            changes[path] = count
            if not args.dry_run:
                path.write_text(new_text)

    old_include_dir = root / "include" / OLD_SNAKE
    new_include_dir = root / "include" / snake
    will_move_include = old_include_dir.is_dir() and old_include_dir != new_include_dir

    if not changes and not will_move_include:
        print("Nothing to rename: already renamed, or run from the wrong directory?")
        return 1

    verb = "Would rewrite" if args.dry_run else "Rewrote"
    for path, count in sorted(changes.items()):
        print(f"{verb} {count} occurrence(s) in {path.relative_to(root)}")

    if will_move_include:
        print(
            f"{'Would move' if args.dry_run else 'Moved'} "
            f"{old_include_dir.relative_to(root)} -> {new_include_dir.relative_to(root)}"
        )
        if not args.dry_run:
            shutil.move(str(old_include_dir), str(new_include_dir))

    remove_verb = "Would remove" if args.dry_run else "Removing"
    for path in (script_path, root / TEMPLATE_WORKFLOW):
        if not path.exists():
            continue
        print(f"{remove_verb} {path.relative_to(root)}")
        if not args.dry_run:
            path.unlink()

    if args.github_owner is None:
        print(
            f"note: --github-owner not given; '{OLD_GITHUB_OWNER}' left as-is in README "
            "badge/clone URLs.",
            file=sys.stderr,
        )

    if args.dry_run:
        print("\nDry run: no files were changed. Re-run without --dry-run to apply.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
