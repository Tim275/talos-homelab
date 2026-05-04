#!/usr/bin/env python3
"""Lint GrafanaDashboard CRs.

Checks per dashboard:
- spec.json is valid JSON if present
- every panel target's datasource UID is in the known set
- spec.url is reachable (HTTP 200) if used
- no panel gridPos overlap on the same row
"""
import json
import sys
import urllib.request
from pathlib import Path

import yaml

KNOWN_DS_UIDS = {
    "prometheus",
    "loki",
    "tempo",
    "alertmanager",
    "elasticsearch",
    "grafanacloud-prom",
}


def fetch_url(url: str) -> tuple[int, str]:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "dashboard-linter"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, ""
    except urllib.error.HTTPError as e:
        return e.code, str(e)
    except Exception as e:
        return 0, str(e)


def check_panel_datasources(panels: list, file: str, errors: list) -> None:
    for panel in panels:
        if panel.get("type") == "row":
            for sub in panel.get("panels", []):
                check_panel_datasources([sub], file, errors)
            continue
        for tgt in panel.get("targets", []) or []:
            ds = tgt.get("datasource") or panel.get("datasource") or {}
            if isinstance(ds, dict):
                uid = ds.get("uid")
                if uid and uid not in KNOWN_DS_UIDS:
                    errors.append(
                        f"  panel '{panel.get('title','?')}': unknown datasource uid '{uid}'"
                    )


def check_grid_overlap(panels: list, errors: list) -> None:
    seen: dict[tuple[int, int], str] = {}
    for panel in panels:
        gp = panel.get("gridPos") or {}
        x, y, w, h = gp.get("x", 0), gp.get("y", 0), gp.get("w", 0), gp.get("h", 0)
        for dx in range(w):
            for dy in range(h):
                key = (x + dx, y + dy)
                if key in seen and seen[key] != panel.get("title"):
                    errors.append(
                        f"  panel '{panel.get('title','?')}' overlaps with '{seen[key]}' at ({x+dx},{y+dy})"
                    )
                    return
                seen[key] = panel.get("title", "?")


def lint_dashboard(path: Path, doc: dict, check_urls: bool) -> list[str]:
    errors: list[str] = []
    spec = doc.get("spec", {})

    if "json" in spec:
        try:
            inner = json.loads(spec["json"])
        except json.JSONDecodeError as e:
            errors.append(f"  invalid JSON in spec.json: {e}")
            return errors
        panels = inner.get("panels", [])
        check_panel_datasources(panels, str(path), errors)
        check_grid_overlap(panels, errors)

    elif "url" in spec:
        if check_urls:
            status, msg = fetch_url(spec["url"])
            if status != 200:
                errors.append(f"  spec.url returned {status}: {spec['url']}  {msg}")

    elif "configMapRef" not in spec and "model" not in spec:
        errors.append("  no spec.json / spec.url / spec.configMapRef / spec.model")

    return errors


def main(root: str, check_urls: bool) -> int:
    root_path = Path(root)
    dashboards = 0
    failed = 0
    for path in root_path.rglob("*.yaml"):
        if "/charts/" in str(path):
            continue
        try:
            with path.open() as f:
                docs = list(yaml.safe_load_all(f))
        except yaml.YAMLError:
            continue
        for doc in docs:
            if not isinstance(doc, dict):
                continue
            if doc.get("kind") != "GrafanaDashboard":
                continue
            dashboards += 1
            errors = lint_dashboard(path, doc, check_urls)
            if errors:
                failed += 1
                print(f"::error file={path}::dashboard lint failed")
                print(f"  {doc['metadata'].get('name', '?')} in {path}:")
                for e in errors:
                    print(e)

    print(f"\nSummary: {dashboards} GrafanaDashboard CRs checked, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    args = sys.argv[1:]
    check_urls = "--check-urls" in args
    args = [a for a in args if a != "--check-urls"]
    root = args[0] if args else "kubernetes"
    sys.exit(main(root, check_urls))
