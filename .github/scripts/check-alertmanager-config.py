#!/usr/bin/env python3
"""Validate the Alertmanager routing config with amtool.

alert-lint deckte PrometheusRules und Dashboards ab, die Alertmanager-Config aber nicht —
dabei ist sie der fragilste Teil: eine Route auf einen nicht existierenden Receiver oder ein
nicht definiertes mute_time_intervals bricht die Zustellung still, ohne dass eine Regel failt.

Die Config liegt als `alertmanager.config` in den Helm-Values, nicht als eigenes Dokument.
Sie wird hier rausgeschnitten und amtool vorgeworfen.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

VALUES_GLOB = "**/alertmanager*.yaml"
ROUTES = Path(".github/tests/alertmanager/routes.yaml")

GRAFANA = "https://grafana.timourhomelab.org/d"
LINK_CASES = [
    (f"{GRAFANA}/etcd", f"{GRAFANA}/etcd?from=1791196472000&to=now"),
    (
        f"{GRAFANA}/k8s-views-nodes?var-node=worker-1",
        f"{GRAFANA}/k8s-views-nodes?var-node=worker-1&from=1791196472000&to=now",
    ),
    ("https://argo.timourhomelab.org/applications", "https://argo.timourhomelab.org/applications"),
]
RENDER_ALL = ["slack.body", "telegram.body", "jira.summary", "jira.description"]


def extract_templates(tree: Path) -> list[tuple[Path, dict]]:
    found = []
    for path in sorted(tree.glob(VALUES_GLOB)):
        if "/charts/" in str(path):
            continue
        for doc in yaml.safe_load_all(path.read_text()):
            if isinstance(doc, dict) and isinstance(doc.get("alertmanager"), dict):
                files = doc["alertmanager"].get("templateFiles")
                if files:
                    found.append((path, files))
    return found


def alert_data(dashboard_url: str) -> dict:
    return {
        "receiver": "test",
        "status": "firing",
        "alerts": [
            {
                "status": "firing",
                "labels": {"alertname": "Test", "severity": "warning", "namespace": "test"},
                "annotations": {"dashboard_url": dashboard_url, "summary": "s"},
                "startsAt": "2026-10-05T11:34:32Z",
                "endsAt": "0001-01-01T00:00:00Z",
                "generatorURL": "http://prometheus/graph",
                "fingerprint": "f",
            }
        ],
        "groupLabels": {"alertname": "Test"},
        "commonLabels": {"alertname": "Test"},
        "commonAnnotations": {},
        "externalURL": "http://alertmanager",
    }


def render(tmp: Path, text: str, data: dict) -> subprocess.CompletedProcess:
    data_file = tmp / "data.json"
    data_file.write_text(json.dumps(data))
    return subprocess.run(
        [
            "amtool",
            "template",
            "render",
            f"--template.glob={tmp}/tmpl/*",
            f"--template.text={text}",
            f"--template.data={data_file}",
        ],
        capture_output=True,
        text=True,
    )


def check_templates(path: Path, files: dict) -> bool:
    ok = True
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp = Path(tmp_dir)
        (tmp / "tmpl").mkdir()
        for name, body in files.items():
            (tmp / "tmpl" / name).write_text(body)
        for url, want in LINK_CASES:
            result = render(tmp, '{{ template "alert.dashboard_url" . }}', alert_data(url))
            got = result.stdout.strip()
            if result.returncode != 0 or got != want:
                ok = False
                print(f"FAIL dashboard-link {url}: erwartet {want}, bekommen {got or result.stderr.strip()}")
        for name in RENDER_ALL:
            result = render(tmp, f'{{{{ template "{name}" . }}}}', alert_data(LINK_CASES[0][0]))
            if result.returncode != 0:
                ok = False
                print(f"FAIL template {name}: {result.stderr.strip()}")
    print(f"{'OK  ' if ok else 'FAIL'} {path}  ({len(LINK_CASES)} Link-Tests, {len(RENDER_ALL)} Render-Tests)")
    return ok


def extract_configs(tree: Path) -> list[tuple[Path, dict]]:
    found = []
    for path in sorted(tree.glob(VALUES_GLOB)):
        if "/charts/" in str(path):
            continue
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


def check_routes(path: Path, cfg_file: str) -> bool:
    spec = yaml.safe_load(ROUTES.read_text())
    if not str(path).endswith(spec["config"]):
        return True
    ok = True
    for case in spec["cases"]:
        labels = [f"{k}={v}" for k, v in case["labels"].items()]
        result = subprocess.run(
            ["amtool", "config", "routes", "test", f"--config.file={cfg_file}", *labels],
            capture_output=True,
            text=True,
        )
        got = result.stdout.strip()
        want = ",".join(case["receivers"])
        if result.returncode != 0 or got != want:
            ok = False
            print(f"FAIL route {case['labels']}: erwartet {want}, bekommen {got or result.stderr.strip()}")
    print(f"{'OK  ' if ok else 'FAIL'} {path}  ({len(spec['cases'])} Routentests)")
    return ok


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
        routes_ok = result.returncode != 0 or check_routes(path, tmp_path)
        Path(tmp_path).unlink(missing_ok=True)
        if not routes_ok:
            failed = True
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

    for path, files in extract_templates(tree):
        if not check_templates(path, files):
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
