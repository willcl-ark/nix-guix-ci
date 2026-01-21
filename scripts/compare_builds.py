#!/usr/bin/env python3
"""Compare Guix build hashes between architectures on CDash."""

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from itertools import combinations

CDASH_API = "https://my.cdash.org/api/v1"
PROJECT = "core"
BUILD_GROUP = "Guix"


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=30) as resp:
        return json.loads(resp.read().decode())


def fetch_builds(hours=None):
    url = f"{CDASH_API}/index.php?project={PROJECT}"
    data = fetch_json(url)

    if hours:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
        cutoff_ts = cutoff.timestamp()
    else:
        cutoff_ts = None

    builds = []
    for group in data.get("buildgroups", []):
        if group.get("name") != BUILD_GROUP:
            continue
        for build in group.get("builds", []):
            if cutoff_ts and build.get("builddatefull", 0) < cutoff_ts:
                continue
            builds.append(
                {
                    "id": build["id"],
                    "name": build.get("buildname", ""),
                    "site": build.get("site", ""),
                    "builddatefull": build.get("builddatefull", 0),
                }
            )
    return builds


def fetch_notes(build_id):
    url = f"{CDASH_API}/viewNotes.php?buildid={build_id}"
    data = fetch_json(url)
    notes = data.get("notes", [])
    if not notes:
        return None
    return notes[0].get("text", "")


def group_builds_by_name(builds):
    groups = defaultdict(list)
    for build in builds:
        groups[build["name"]].append(build)
    return groups


def create_github_issue(build_a, build_b, arch_a, arch_b, diff):
    title = f"Reproducibility failure: {build_a['name']}"
    body = f"""## Reproducibility Failure

Build hashes do not match between architectures for `{build_a['name']}`.

| Architecture | Build ID | CDash Link |
|--------------|----------|------------|
| {arch_a} | {build_a['id']} | https://my.cdash.org/builds/{build_a['id']} |
| {arch_b} | {build_b['id']} | https://my.cdash.org/builds/{build_b['id']} |

### Diff
```
{diff}
```
"""
    # Check for existing open issue with same title
    result = subprocess.run(
        ["gh", "issue", "list", "--state", "open", "--search", f'"{title}" in:title'],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0 and title in result.stdout:
        print(f"  Issue already exists for '{build_a['name']}', skipping")
        return

    result = subprocess.run(
        ["gh", "issue", "create", "--title", title, "--body", body, "--label", "reproducibility"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print(f"  Created issue: {result.stdout.strip()}")
    else:
        print(f"  Failed to create issue: {result.stderr}", file=sys.stderr)


def compare_notes(notes_a, notes_b):
    lines_a = notes_a.strip().split("\n")
    lines_b = notes_b.strip().split("\n")

    arch_a = lines_a[0] if lines_a else ""
    arch_b = lines_b[0] if lines_b else ""
    hashes_a = lines_a[1:] if len(lines_a) > 1 else []
    hashes_b = lines_b[1:] if len(lines_b) > 1 else []

    if hashes_a == hashes_b:
        return True, arch_a, arch_b, ""

    diff_lines = []
    max_lines = max(len(hashes_a), len(hashes_b))
    for i in range(max_lines):
        line_a = hashes_a[i] if i < len(hashes_a) else "<missing>"
        line_b = hashes_b[i] if i < len(hashes_b) else "<missing>"
        if line_a != line_b:
            diff_lines.append(f"  Line {i + 2}:")
            diff_lines.append(f"    < {line_a}")
            diff_lines.append(f"    > {line_b}")
    return False, arch_a, arch_b, "\n".join(diff_lines)


def main():
    parser = argparse.ArgumentParser(
        description="Compare Guix build hashes between architectures on CDash"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument(
        "--hours",
        type=int,
        default=48,
        help="Only compare builds from the last N hours (default: 48)",
    )
    parser.add_argument(
        "--create-issue",
        action="store_true",
        help="Create GitHub issue on mismatch (requires gh CLI and GITHUB_TOKEN)",
    )
    args = parser.parse_args()

    print(f"Fetching builds from CDash '{BUILD_GROUP}' group (last {args.hours}h)...")

    try:
        builds = fetch_builds(hours=args.hours)
    except Exception as e:
        print(f"Error fetching builds: {e}", file=sys.stderr)
        return 2

    if not builds:
        print("No builds found in Guix group.")
        return 0

    groups = group_builds_by_name(builds)
    print(f"Found {len(builds)} builds in {len(groups)} group(s)")

    failures = []
    comparisons = 0

    for name, group_builds in sorted(groups.items()):
        if len(group_builds) < 2:
            if args.verbose:
                print(f"  '{name}': only {len(group_builds)} build(s), skipping")
            continue

        print(f"\nComparing builds for '{name}':")

        for build_a, build_b in combinations(group_builds, 2):
            comparisons += 1
            try:
                notes_a = fetch_notes(build_a["id"])
                notes_b = fetch_notes(build_b["id"])
            except Exception as e:
                print(f"  Error fetching notes: {e}", file=sys.stderr)
                failures.append((build_a, build_b, f"fetch error: {e}"))
                continue

            if notes_a is None or notes_b is None:
                print(
                    f"  {build_a['site']} ({build_a['id']}) vs {build_b['site']} ({build_b['id']}): SKIPPED (no notes)"
                )
                continue

            match, arch_a, arch_b, diff = compare_notes(notes_a, notes_b)

            if match:
                print(
                    f"  {arch_a} ({build_a['id']}) vs {arch_b} ({build_b['id']}): MATCH"
                )
            else:
                print(
                    f"  {arch_a} ({build_a['id']}) vs {arch_b} ({build_b['id']}): MISMATCH"
                )
                if diff:
                    print(diff)
                failures.append((build_a, build_b, arch_a, arch_b, diff))
                if args.create_issue:
                    create_github_issue(build_a, build_b, arch_a, arch_b, diff)

    print()
    if not comparisons:
        print("No comparisons performed (need 2+ builds with same name).")
        return 0

    if failures:
        print(f"FAILURE: {len(failures)} comparison(s) failed")
        for build_a, build_b, *_ in failures:
            print(f"  - https://my.cdash.org/builds/{build_a['id']}")
            print(f"  - https://my.cdash.org/builds/{build_b['id']}")
        return 1

    print(f"All {comparisons} comparison(s) passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
