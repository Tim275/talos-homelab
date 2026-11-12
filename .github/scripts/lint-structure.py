#!/usr/bin/env python3
"""Lint the repository layout.

Checks:
- every ApplicationSet row points at an existing kustomization (or a rendered/ folder)
- the Application name is the folder name, sub-components are named parent-child
- every component (a folder owning base/ or overlays/) is claimed by exactly one row
- every file in a component is reachable from its kustomization, nothing is commented out
- base/ holds no helmCharts, no deprecated kustomize fields, no hostnames, addresses or node names
- the environment label is prod
- a SecurityPolicy and the secret it references live in the same component
"""
import re
import sys
from pathlib import Path

import yaml

STACKS = ("infrastructure", "platform", "apps", "tenants")
SKIP_DIRS = {"charts", "parked", "rendered"}
HOMELAB = "https://github.com/Tim275/talos-homelab"
DEPRECATED = ("commonLabels", "patchesStrategicMerge", "patchesJson6902", "vars")
ENV_SPECIFIC = {
    "hostname": re.compile(r"timourhomelab\.org|@outlook\.|@hotmail\.|@gmail\."),
    "address": re.compile(r"\b(?!10\.0\.0\.0/8|192\.168\.0\.0/16)(?:192\.168|10\.\d{1,3})\.\d{1,3}\.\d{1,3}\b"),
    "node name": re.compile(r"\b(?:worker|ctrl|storage)-\d\b"),
}
ENV_EXEMPT_KINDS = {"PrometheusRule", "GrafanaDashboard", "CustomResourceDefinition"}
global_errors = []
COMMENTED_ENTRY = re.compile(r"^\s*#\s*-\s+\S", re.M)


def skip(path: Path) -> bool:
    return any(p in SKIP_DIRS for p in path.parts)


def load(path: Path) -> list:
    try:
        return [d for d in yaml.safe_load_all(path.read_text()) if isinstance(d, dict)]
    except yaml.YAMLError:
        return []


def components(root: Path) -> set[Path]:
    found = set()
    for k in root.rglob("kustomization.yaml"):
        if skip(k.relative_to(root)):
            continue
        d = k.parent
        if d.name == "base":
            found.add(d.parent)
        elif d.parent.name == "overlays":
            found.add(d.parent.parent)
    return {c for c in found if c.relative_to(root).parts[0] in STACKS}


def rows(root: Path):
    for f in sorted((root / "argocd" / "applicationsets").glob("*.yaml")):
        for doc in load(f):
            if doc.get("kind") != "ApplicationSet":
                continue
            gens = doc["spec"]["generators"][0]["matrix"]["generators"]
            ign = doc["spec"]["template"]["spec"].get("ignoreDifferences")
            if ign is not None and not (isinstance(ign, list) and all(isinstance(i, dict) and i.get("kind") for i in ign)):
                print(f"::error file={f}::ignoreDifferences must be a list of entries with kind")
                global_errors.append(f)
            for e in gens[1]["list"]["elements"]:
                yield f, e


def expected_name(root: Path, comp: Path) -> str:
    rel = comp.relative_to(root)
    parent = comp.parent
    if (parent / "base").is_dir() or (parent / "overlays").is_dir():
        return f"{parent.name}-{comp.name}"
    return rel.name


def referenced(k: Path) -> set[Path]:
    """Files and directories a kustomization names."""
    out = set()
    for doc in load(k):
        refs = list(doc.get("resources") or []) + list(doc.get("components") or []) + list(doc.get("crds") or [])
        for p in doc.get("patches") or []:
            if isinstance(p, dict) and p.get("path"):
                refs.append(p["path"])
        for h in doc.get("helmCharts") or []:
            refs += [v for v in [h.get("valuesFile")] + list(h.get("additionalValuesFiles") or []) if v]
        for g in (doc.get("configMapGenerator") or []) + (doc.get("secretGenerator") or []):
            refs += [x.split("=", 1)[-1] for x in (g.get("files") or []) + (g.get("envs") or [])]
        for r in refs:
            if "://" in r:
                continue
            out.add((k.parent / r).resolve())
    return out


def reachable(root: Path, starts: list[Path]) -> set[Path]:
    seen_files, seen_dirs, todo = set(), set(), [s.resolve() for s in starts]
    while todo:
        d = todo.pop()
        if d in seen_dirs or not d.is_dir():
            continue
        seen_dirs.add(d)
        k = d / "kustomization.yaml"
        if not k.is_file():
            for f in d.iterdir():
                if f.is_file():
                    seen_files.add(f)
            continue
        seen_files.add(k)
        for r in referenced(k):
            if r.is_dir():
                todo.append(r)
            elif r.is_file():
                seen_files.add(r)
    return seen_files


def main(path: str) -> int:
    root = Path(path).resolve()
    repo = root.parent
    failed = 0

    def err(where, msg):
        nonlocal failed
        print(f"::error file={where}::{msg}")
        failed += 1

    comps = components(root)
    claimed, starts = {}, []
    for f, e in rows(root):
        f = f.relative_to(repo)
        if e.get("repoURL") not in (None, HOMELAB):
            continue
        name, p = e["name"], e["path"]
        target = repo / p
        starts.append(target)
        if target.name == "rendered":
            if not (target / "manifests.yaml").is_file():
                err(f, f"{name}: {p}/manifests.yaml missing")
            comp = target.parent
            starts.append(comp / "overlays" / "prod")
        elif (target / "kustomization.yaml").is_file():
            comp = target.parent.parent if target.parent.name == "overlays" else target
        else:
            err(f, f"{name}: {p} has no kustomization.yaml")
            continue
        if comp.relative_to(root).parts[0] in STACKS:
            want = expected_name(root, comp)
            if name != want:
                err(f, f"Application {name} should be named {want} after its folder")
            claimed.setdefault(comp, []).append(name)
    for c in sorted(comps):
        if c not in claimed:
            err(f"{c.relative_to(repo)}/kustomization.yaml", f"{c.relative_to(repo)} is in no ApplicationSet")
        elif len(claimed[c]) > 1:
            err(c.relative_to(repo), f"{c.relative_to(repo)} is claimed by {claimed[c]}")

    seen = reachable(root, starts + [root / "argocd" / "bootstrap", root / "argocd" / "bootstrap" / "root", root / "argocd" / "crds", root / "argocd" / "projects", root / "argocd" / "clusters", root / "argocd" / "applicationsets"])
    for f in sorted(root.rglob("*")):
        if not f.is_file() or skip(f.relative_to(root)) or f.name in (".gitattributes", "README.md"):
            continue
        if f.suffix in (".yaml", ".yml", ".json", ".toml", ".alloy", ".tftpl") and f.resolve() not in seen:
            err(f.relative_to(repo), "not referenced by any kustomization")

    for k in sorted([*root.rglob("kustomization.yaml"), *(root / "argocd" / "projects").glob("*.yaml"), *(root / "argocd" / "applicationsets").glob("*.yaml"), *(root / "argocd" / "clusters").glob("*.yaml")]):
        rel = k.relative_to(root)
        if skip(rel):
            continue
        text = k.read_text()
        if COMMENTED_ENTRY.search(text):
            err(k.relative_to(repo), "commented-out entry, delete it or park it")
        if k.name != "kustomization.yaml":
            continue
        docs = load(k)
        for d in docs:
            for key in DEPRECATED:
                if key in d:
                    err(k.relative_to(repo), f"{key} is deprecated, run kustomize edit fix")
            if k.parent.name == "base" and d.get("helmCharts"):
                err(k.relative_to(repo), "helmCharts belong in overlays/prod, base is chart-free")

    for f in sorted(root.rglob("*")):
        rel = f.relative_to(root) if f.is_file() else None
        if rel is None or skip(rel) or "base" not in rel.parts or rel.parts[0] not in STACKS:
            continue
        if f.suffix not in (".yaml", ".yml", ".toml", ".alloy") or f.name == "alerting-rules.yaml":
            continue
        docs = load(f) if f.suffix in (".yaml", ".yml") else []
        if docs and all(d.get("kind") in ENV_EXEMPT_KINDS for d in docs):
            continue
        for i, line in enumerate(f.read_text().splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            code = re.sub(r"\s+#.*$", "", line)
            for what, rx in ENV_SPECIFIC.items():
                if rx.search(code):
                    err(f"{f.relative_to(repo)},line={i}", f"{what} in base, move it to overlays/prod")

    for f in sorted(root.rglob("*.yaml")):
        if skip(f.relative_to(root)):
            continue
        for i, line in enumerate(f.read_text().splitlines(), 1):
            m = re.match(r"^\s*environment:\s*['\"]?([A-Za-z]+)['\"]?\s*$", line)
            if m and m.group(1) != "prod":
                err(f"{f.relative_to(repo)},line={i}", f"environment is {m.group(1)}, only prod exists")

    granted = set()
    for g in root.rglob("*.yaml"):
        if skip(g.relative_to(root)):
            continue
        for d in load(g):
            if d.get("kind") == "ReferenceGrant":
                granted |= {t.get("name") for t in d.get("spec", {}).get("to", []) if t.get("kind") == "Secret"}
    for f in sorted(root.rglob("*.yaml")):
        if skip(f.relative_to(root)):
            continue
        for doc in load(f):
            if doc.get("kind") != "SecurityPolicy":
                continue
            comp = next((d for d in f.parents if (d / "base").is_dir() or (d / "overlays").is_dir()), f.parent)
            owned = {
                (d.get("spec", {}).get("target") or {}).get("name") or d.get("metadata", {}).get("name")
                for g in comp.rglob("*.yaml") if not skip(g.relative_to(root))
                for d in load(g) if d.get("kind") in ("Secret", "ExternalSecret")
            }
            spec = doc.get("spec", {})
            names = set()
            oidc = spec.get("oidc") or {}
            for key in ("clientIDRef", "clientSecret"):
                if isinstance(oidc.get(key), dict) and oidc[key].get("name"):
                    names.add(oidc[key]["name"])
            users = (spec.get("basicAuth") or {}).get("users") or {}
            if users.get("name"):
                names.add(users["name"])
            for name in names - owned - granted:
                err(f.relative_to(repo), f"SecurityPolicy {doc['metadata']['name']} references secret {name}, which {comp.relative_to(repo)} does not own")

    failed += len(global_errors)
    print(f"\nSummary: {len(comps)} components, {len(starts)} rows, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "kubernetes"))
