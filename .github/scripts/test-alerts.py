#!/usr/bin/env python3
"""Run promtool unit tests against the PrometheusRule CRDs.

Extracts every .spec.groups from PrometheusRule CRs into one raw rules file
(.github/tests/alerts/.rules.generated.yaml), then runs `promtool test rules`
on each *_test.yaml in that directory. The test files reference the generated
rules via `rule_files: [.rules.generated.yaml]`.
"""
import subprocess
import sys
from pathlib import Path

import yaml

TESTS_DIR = Path(".github/tests/alerts")
GENERATED = TESTS_DIR / ".rules.generated.yaml"


def extract_rules(root: Path) -> int:
    groups = []
    seen = set()
    for path in root.rglob("*.yaml"):
        if "/charts/" in str(path):
            continue
        try:
            docs = list(yaml.safe_load_all(path.open()))
        except yaml.YAMLError:
            continue
        for doc in docs:
            if not isinstance(doc, dict) or doc.get("kind") != "PrometheusRule":
                continue
            for grp in doc.get("spec", {}).get("groups", []):
                if grp.get("name") in seen:
                    continue
                seen.add(grp.get("name"))
                groups.append(grp)
    GENERATED.write_text(yaml.safe_dump({"groups": groups}))
    return len(groups)


def main(root: str = "kubernetes") -> int:
    n = extract_rules(Path(root))
    print(f"extracted {n} rule groups from {root}")
    test_files = sorted(TESTS_DIR.glob("*_test.yaml"))
    if not test_files:
        print("no *_test.yaml files found")
        return 1
    failures = 0
    for tf in test_files:
        proc = subprocess.run(
            ["promtool", "test", "rules", tf.name],
            capture_output=True,
            text=True,
            cwd=TESTS_DIR,
        )
        print(f"--- {tf.name} ---")
        print((proc.stdout + proc.stderr).strip())
        if proc.returncode != 0:
            failures += 1
    GENERATED.unlink(missing_ok=True)
    print(f"\nSummary: {len(test_files)} test file(s), {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "kubernetes"))
