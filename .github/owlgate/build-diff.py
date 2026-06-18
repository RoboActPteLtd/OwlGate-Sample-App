#!/usr/bin/env python3
"""Build the OwlGate diff payload from a git range.

Emits ``{"diff": [{"path", "lines", "hunks": [{start, lines, function}]}]}``.
The hunks carry the changed line range + the enclosing function (git puts it in
the ``@@ ... @@`` hunk header), so OwlGate can flag the exact function to review.

Usage: build-diff.py <git-range>   e.g.  origin/main...HEAD
"""

from __future__ import annotations

import json
import re
import subprocess
import sys

RANGE = sys.argv[1] if len(sys.argv) > 1 else "HEAD~1...HEAD"
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@(.*)$")


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout


# changed-line counts per file
counts: dict[str, int] = {}
for line in git("diff", "--numstat", RANGE).splitlines():
    parts = line.split("\t")
    if len(parts) < 3:
        continue
    added = 0 if parts[0] == "-" else int(parts[0])
    removed = 0 if parts[1] == "-" else int(parts[1])
    counts[parts[2]] = added + removed

# hunks (line range + enclosing function) per file
hunks: dict[str, list[dict]] = {}
current: str | None = None
for line in git("diff", RANGE).splitlines():
    if line.startswith("+++ b/"):
        current = line[6:]
    elif line.startswith("+++ ") and "/dev/null" in line:
        current = None
    elif line.startswith("@@") and current:
        m = HUNK.match(line)
        if m:
            hunks.setdefault(current, []).append(
                {
                    "start": int(m.group(1)),
                    "lines": int(m.group(2) or 1),
                    "function": m.group(3).strip(),
                }
            )

diff = [{"path": p, "lines": n, "hunks": hunks.get(p, [])} for p, n in counts.items()]
print(json.dumps({"diff": diff}))
