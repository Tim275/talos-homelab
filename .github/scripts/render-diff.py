#!/usr/bin/env python3
"""Render every overlay a pull request touches, at base and at head, and report what changes.

Usage: render-diff.py <base-sha>   (run from the head checkout)
Writes a markdown report to stdout. Never fails on a difference, only on usage errors.
"""
import difflib
import subprocess
import sys
import tempfile
from pathlib import Path

MAX_LINES = 200


def run(*cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def component(tree: Path, changed: str) -> str | None:
    """Folder that owns overlays/ and contains the changed file."""
    d = (tree / changed).parent
    while d != tree and tree in d.parents:
        if (d / "overlays").is_dir():
            return str(d.relative_to(tree))
        d = d.parent
    return None


def render(tree: Path, overlay: str) -> str | None:
    if not (tree / overlay / "kustomization.yaml").is_file():
        return None
    r = run("kustomize", "build", "--enable-helm", "--load-restrictor", "LoadRestrictionsNone", overlay, cwd=tree)
    return r.stdout if r.returncode == 0 else f"BUILD FAILED\n{r.stderr}"


def main(base_sha: str) -> int:
    head = Path.cwd()
    base = Path(tempfile.mkdtemp()) / "base"
    if run("git", "worktree", "add", "--detach", str(base), base_sha).returncode != 0:
        print(f"cannot check out {base_sha}")
        return 1
    changed = run("git", "diff", "--name-only", base_sha, "HEAD", "--", "kubernetes").stdout.split()
    comps = {c for f in changed for t in (head, base) if (c := component(t, f))}
    overlays = sorted({str(p.relative_to(t)) for t in (head, base) for c in comps for p in (t / c / "overlays").glob("*") if p.is_dir()})
    print("### Render diff\n")
    if not overlays:
        print("No overlay is affected by this change.")
    for overlay in overlays:
        old, new = render(base, overlay), render(head, overlay)
        if old == new:
            print(f"- `{overlay}`: identical")
            continue
        diff = list(difflib.unified_diff((old or "").splitlines(), (new or "").splitlines(), "base", "head", lineterm="", n=2))
        added = sum(1 for l in diff if l.startswith("+") and not l.startswith("+++"))
        removed = sum(1 for l in diff if l.startswith("-") and not l.startswith("---"))
        state = "new" if old is None else "removed" if new is None else f"+{added} -{removed} lines"
        print(f"- `{overlay}`: {state}\n\n<details><summary>diff</summary>\n\n```diff")
        print("\n".join(diff[:MAX_LINES]))
        if len(diff) > MAX_LINES:
            print(f"... {len(diff) - MAX_LINES} more lines")
        print("```\n\n</details>\n")
    run("git", "worktree", "remove", "--force", str(base))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
