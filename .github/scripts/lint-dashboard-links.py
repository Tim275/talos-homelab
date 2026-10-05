#!/usr/bin/env python3
"""Lint dashboard_url in PrometheusRules gegen die Dashboards im Repo.

Pro Link auf Grafana:
- die UID (/d/<uid>) muss als GrafanaDashboard im Repo existieren
- jedes var-<name> muss in den Template-Variablen dieses Dashboards stehen

Dashboards mit spec.json werden direkt gelesen, die mit spec.url (Community) werden
geladen. Ist der Download nicht moeglich, wird nur die UID geprueft.
"""
import json
import sys
import urllib.request
from pathlib import Path
from urllib.parse import parse_qsl, urlparse

import yaml

GRAFANA_HOST = "grafana.timourhomelab.org"


def load_yaml_docs(path: Path) -> list:
    try:
        return [d for d in yaml.safe_load_all(path.read_text()) if isinstance(d, dict)]
    except yaml.YAMLError:
        return []


def fetch_json(url: str) -> dict | None:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "dashboard-link-lint"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except Exception:
        return None


def variable_names(model: dict) -> set[str]:
    return {v["name"] for v in model.get("templating", {}).get("list", []) if "name" in v}


def load_dashboards(root: Path) -> tuple[dict[str, set[str] | None], list[str]]:
    dashboards: dict[str, set[str] | None] = {}
    errors: list[str] = []
    for path in sorted(root.rglob("*.yaml")):
        if "/charts/" in str(path):
            continue
        for doc in load_yaml_docs(path):
            if doc.get("kind") != "GrafanaDashboard":
                continue
            spec = doc.get("spec", {})
            model = None
            if "json" in spec:
                try:
                    model = json.loads(spec["json"])
                except json.JSONDecodeError:
                    continue
            elif "url" in spec:
                model = fetch_json(spec["url"])
            uid = spec.get("uid") or (model or {}).get("uid")
            if not uid:
                errors.append(f"{path}: Dashboard ohne uid")
                continue
            dashboards[uid] = variable_names(model) if model else None
    return dashboards, errors


def iter_alert_links(root: Path):
    for path in sorted(root.rglob("*.yaml")):
        if "/charts/" in str(path):
            continue
        for doc in load_yaml_docs(path):
            if doc.get("kind") != "PrometheusRule":
                continue
            for group in doc.get("spec", {}).get("groups", []):
                for rule in group.get("rules", []):
                    url = (rule.get("annotations") or {}).get("dashboard_url")
                    if rule.get("alert") and url:
                        yield path, rule["alert"], url


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "kubernetes")
    dashboards, errors = load_dashboards(root)
    unchecked = sorted(uid for uid, names in dashboards.items() if names is None)
    checked = 0
    for path, alert, url in iter_alert_links(root):
        parsed = urlparse(url)
        if parsed.hostname != GRAFANA_HOST or not parsed.path.startswith("/d/"):
            continue
        checked += 1
        uid = parsed.path.split("/")[2]
        if uid not in dashboards:
            errors.append(f"{path}: {alert}: Dashboard '{uid}' existiert nicht im Repo")
            continue
        names = dashboards[uid]
        for key, _ in parse_qsl(parsed.query):
            if key.startswith("var-") and names is not None and key[4:] not in names:
                errors.append(f"{path}: {alert}: '{uid}' hat keine Variable '{key[4:]}'")

    for line in errors:
        print(f"FAIL {line}")
    if unchecked:
        print(f"WARN Variablen nicht pruefbar (Download fehlgeschlagen): {', '.join(unchecked)}")
    print(f"\nSummary: {len(dashboards)} dashboards, {checked} Links, {len(errors)} failed")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
