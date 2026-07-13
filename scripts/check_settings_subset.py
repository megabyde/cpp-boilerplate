#!/usr/bin/env python3
"""Check that an installed Conan settings_user.yml covers this project's sanitizer values.

Usage: check_settings_subset.py <required.yml> <installed.yml>

Exits 0 when, for every compiler in the required file, the installed file lists every
required sanitizer value. The installed file may be a superset: extra compilers, extra
sanitizer values, or unrelated subsettings (e.g. version:) are fine and left alone.

Parsing is deliberately limited to the two-level shape Conan documents for
settings_user.yml (stdlib only; PyYAML is not available everywhere this runs). Anything
that does not parse counts as not covering the requirement, so the failure mode is the
safe one: the caller asks the user to merge by hand.
"""

import re
import sys
from pathlib import Path

COMPILER_RE = re.compile(r"^ {2,4}([\w.+-]+):$")
SANITIZER_RE = re.compile(r"^\s+sanitizer:\s*\[(.*)\]$")


def sanitizer_values(text: str) -> dict[str, set[str]]:
    """Map each compiler to the set of sanitizer values it lists."""
    values: dict[str, set[str]] = {}
    compiler = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line:
            continue
        if match := COMPILER_RE.match(line):
            compiler = match.group(1)
        elif (match := SANITIZER_RE.match(line)) and compiler:
            values.setdefault(compiler, set()).update(
                value.strip() for value in match.group(1).split(",") if value.strip()
            )
    return values


def main() -> int:
    required_path, installed_path = sys.argv[1], sys.argv[2]
    required = sanitizer_values(Path(required_path).read_text())
    installed = sanitizer_values(Path(installed_path).read_text())
    status = 0
    for compiler, needed in sorted(required.items()):
        missing = needed - installed.get(compiler, set())
        if missing:
            print(
                f"{installed_path}: compiler '{compiler}' lacks sanitizer"
                f" values: {', '.join(sorted(missing))}",
                file=sys.stderr,
            )
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main())
