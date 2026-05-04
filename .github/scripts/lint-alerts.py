#!/usr/bin/env python3
"""Lint PrometheusRule CRDs: promtool syntax + required annotations/labels.

Required per alert rule:
- annotations.summary
- labels.severity
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

REQUIRED_ANNOTATIONS = ["summary"]
REQUIRED_LABELS = ["severity"]
VALID_SEVERITIES = {"critical", "warning", "info"}


def iter_prometheus_rules(root: Path):
    for path in root.rglob("*.yaml"):
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
            if doc.get("kind") == "PrometheusRule":
                yield path, doc


def check_promtool_syntax(rule_doc: dict) -> tuple[bool, str]:
    spec = rule_doc.get("spec", {})
    rules_yaml = yaml.safe_dump({"groups": spec.get("groups", [])})
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tmp:
        tmp.write(rules_yaml)
        tmp_path = tmp.name
    try:
        proc = subprocess.run(
            ["promtool", "check", "rules", tmp_path],
            capture_output=True,
            text=True,
        )
        return proc.returncode == 0, proc.stdout + proc.stderr
    finally:
        os.unlink(tmp_path)


def check_annotations(rule_doc: dict) -> list[str]:
    violations: list[str] = []
    for grp in rule_doc.get("spec", {}).get("groups", []):
        for rule in grp.get("rules", []):
            alert_name = rule.get("alert")
            if not alert_name:
                continue
            ann = rule.get("annotations") or {}
            lbl = rule.get("labels") or {}
            missing: list[str] = []
            for key in REQUIRED_ANNOTATIONS:
                if not ann.get(key):
                    missing.append(f"annotations.{key}")
            for key in REQUIRED_LABELS:
                if not lbl.get(key):
                    missing.append(f"labels.{key}")
            severity = lbl.get("severity")
            if severity and severity not in VALID_SEVERITIES:
                missing.append(
                    f"labels.severity={severity!r} (must be one of {sorted(VALID_SEVERITIES)})"
                )
            if missing:
                violations.append(f"{alert_name}: {', '.join(missing)}")
    return violations


def main(root: str) -> int:
    root_path = Path(root)
    syntax_failures = 0
    annotation_failures = 0
    files_checked = 0

    for path, doc in iter_prometheus_rules(root_path):
        files_checked += 1

        ok, output = check_promtool_syntax(doc)
        if not ok:
            print(f"::error file={path}::promtool syntax error")
            print(output)
            syntax_failures += 1

        violations = check_annotations(doc)
        if violations:
            print(f"::error file={path}::missing required annotations/labels")
            for v in violations:
                print(f"  - {v}")
            annotation_failures += 1

    print(f"\nSummary: {files_checked} PrometheusRule files checked")
    print(f"  syntax failures: {syntax_failures}")
    print(f"  annotation failures: {annotation_failures}")

    if syntax_failures or annotation_failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "kubernetes"))
