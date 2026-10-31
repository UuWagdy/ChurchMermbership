#!/usr/bin/env python3
"""Offline structural validator for the secure-project-audit skill package."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    skill = root / "SKILL.md"
    if not skill.is_file():
        fail("SKILL.md is missing")

    text = skill.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n", text, flags=re.S)
    if not match:
        fail("YAML front matter is missing or malformed")

    front = match.group(1)
    if not re.search(r"^name:\s*secure-project-audit\s*$", front, flags=re.M):
        fail("name must be secure-project-audit")
    if not re.search(r"^description:\s*.+$", front, flags=re.M):
        fail("description is missing")

    referenced = sorted(set(re.findall(r"`(references/[^`]+\.md)`", text)))
    missing = [path for path in referenced if not (root / path).is_file()]
    if missing:
        fail("missing referenced files: " + ", ".join(missing))

    required_phrases = [
        "Server-authoritative with local cache",
        "Signed licensing, trials, and device enrollment",
        "PostgreSQL as a security and consistency boundary",
        "Redis, cache, queue, and event boundary",
        "Reconcile old reports with current reality",
        "FINAL_SECURITY_STATUS_AR.md",
    ]
    for phrase in required_phrases:
        if phrase not in text:
            fail(f"required section/phrase missing: {phrase}")

    if "100% secure" not in text:
        fail("risk-limitation language is missing")

    print(f"PASS: {root.name} is structurally valid")
    print(f"References checked: {len(referenced)}")
    print(f"SKILL.md lines: {len(text.splitlines())}")


if __name__ == "__main__":
    main()
