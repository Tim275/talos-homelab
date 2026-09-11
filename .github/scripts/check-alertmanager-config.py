#!/usr/bin/env python3
"""Validate the Alertmanager routing config with amtool.

alert-lint deckte PrometheusRules und Dashboards ab, die Alertmanager-Config aber nicht —
dabei ist sie der fragilste Teil: eine Route auf einen nicht existierenden Receiver oder ein
nicht definiertes mute_time_intervals bricht die Zustellung still, ohne dass eine Regel failt.

Die Config liegt als `alertmanager.config` in den Helm-Values, nicht als eigenes Dokument.
Sie wird hier rausgeschnitten und amtool vorgeworfen.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

VALUES_GLOB = "**/alertmanager*.yaml"


def extract_configs(tree: Path) -> list[tuple[Path, dict]]:
    found = []
    for path in sorted(tree.glob(VALUES_GLOB)):
        try:
            docs = list(yaml.safe_load_all(path.read_text()))
        except yaml.YAMLError as exc:
            print(f"FAIL {path}: kein gueltiges YAML: {exc}")
            sys.exit(1)
        for doc in docs:
            if isinstance(doc, dict) and isinstance(doc.get("alertmanager"), dict):
                cfg = doc["alertmanager"].get("config")
                if isinstance(cfg, dict) and "route" in cfg:
                    found.append((path, cfg))
    return found


def main() -> int:
    tree = Path(sys.argv[1] if len(sys.argv) > 1 else "kubernetes")
    configs = extract_configs(tree)
    if not configs:
        print(f"keine Alertmanager-Config unter {tree} gefunden")
        return 1

    failed = False
    for path, cfg in configs:
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tmp:
            yaml.dump(cfg, tmp, default_flow_style=False, sort_keys=False)
            tmp_path = tmp.name
        result = subprocess.run(
            ["amtool", "check-config", tmp_path],
            capture_output=True,
            text=True,
        )
        Path(tmp_path).unlink(missing_ok=True)
        if result.returncode != 0:
            failed = True
            print(f"FAIL {path}")
            print(result.stdout or result.stderr)
        else:
            routes = len(cfg["route"].get("routes", []))
            receivers = len(cfg.get("receivers", []))
            intervals = len(cfg.get("time_intervals", []))
            print(
                f"OK   {path}  ({routes} routes, {receivers} receivers, "
                f"{intervals} time_intervals)"
            )

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
