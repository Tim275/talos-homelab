#!/usr/bin/env python3
"""Lint the repository layout.

Checks:
- every ApplicationSet row points at an existing kustomization or at rendered/<environment>
- a component with rendered manifests is deployed from them in every environment
- the Application name is the folder name, sub-components are named parent-child
- every component (a folder owning base/ or overlays/) is claimed by a row, by at most one per environment,
  a commented-out row keeps its component parked
- every file in a component is reachable from its kustomization, nothing is commented out
- base/ holds no helmCharts, no image tags, no remote resources, no deprecated kustomize fields, no hostnames, addresses or node names
- every image of a component gets its tag in each overlay
- the Cilium version of the Talos bootstrap equals the chart version Argo CD deploys
- the environment label is prod or staging
- a row deploys the overlay of its own environment
- every Application of prod also runs in staging and the other way round, exceptions are named in PROD_ONLY and STAGING_ONLY
- a SecurityPolicy and the secret it references live in the same component
"""
import re
import sys
from pathlib import Path

import yaml

STACKS = ("infrastructure", "platform", "apps", "tenants")
ENVIRONMENTS = ("prod", "staging")
PROD_ONLY = {
    "prometheus-edge": "Proxmox hosts",
    "pve-exporter": "Proxmox hosts",
    "rook-ceph": "Ceph on Proxmox",
    "rook-ceph-rgw": "Ceph on Proxmox",
    "cloudflared": "needs its own tunnel",
    "cilium": "addresses of the cluster network",
    "coredns": "addresses of the cluster network",
    "gateway": "node names",
    "elasticsearch": "node names",
}
STAGING_ONLY = {"local-path": "block storage instead of rook-ceph"}
SKIP_DIRS = {"charts", "rendered"}
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
PARKED_ROW = re.compile(r"^[ \t]*#[ \t]*(-[ \t]*\{.*\})[ \t]*\n", re.M)


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


def parked(text: str) -> list:
    out = []
    for m in PARKED_ROW.finditer(text):
        try:
            e = yaml.safe_load(m.group(1))[0]
        except (yaml.YAMLError, IndexError, TypeError):
            continue
        if isinstance(e, dict) and e.get("app") and e.get("path"):
            out.append((m, e))
    return out


def rows(root: Path):
    """(file, environment, row, parked) for every ApplicationSet row."""
    sets = root / "argocd" / "applicationsets"
    for f in sorted((sets / "base").glob("*.yaml")):
        for doc in load(f):
            if doc.get("kind") != "ApplicationSet":
                continue
            ign = doc["spec"]["template"]["spec"].get("ignoreDifferences")
            if ign is not None and not (isinstance(ign, list) and all(isinstance(i, dict) and i.get("kind") for i in ign)):
                print(f"::error file={f}::ignoreDifferences must be a list of entries with kind")
                global_errors.append(f)
    for env in ENVIRONMENTS:
        for f in sorted((sets / env).glob("*.yaml")):
            for _, e in parked(f.read_text()):
                yield f, env, e, True
            for doc in load(f):
                if doc.get("kind") != "ApplicationSet":
                    continue
                for e in doc["spec"]["generators"][0]["matrix"]["generators"][1]["list"]["elements"]:
                    yield f, env, e, False


def expected_name(root: Path, comp: Path) -> str:
    rel = comp.relative_to(root)
    parent = comp.parent
    if (parent / "base").is_dir() or (parent / "overlays").is_dir():
        return f"{parent.name}-{comp.name}"
    return rel.name


def images(path: Path) -> list[str]:
    """Values of the image fields in a YAML file."""
    out = []

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k in ("image", "imageName") and isinstance(v, str) and v and "*" not in v:
                    out.append(v)
                else:
                    walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    try:
        for d in yaml.safe_load_all(path.read_text()):
            walk(d)
    except yaml.YAMLError:
        pass
    return out


def pinned(image: str) -> bool:
    return "@" in image or ":" in image.rsplit("/", 1)[-1]


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
    deployed, parked_names = {env: set() for env in ENVIRONMENTS}, set()
    for f, env, e, is_parked in rows(root):
        f = f.relative_to(repo)
        if e.get("repoURL") not in (None, HOMELAB):
            continue
        name, p = e["app"], e["path"]
        target = repo / p
        if is_parked:
            parked_names.add(name)
        else:
            deployed[env].add(name)
        if target.parent.name in ("overlays", "rendered") and target.name != env:
            err(f, f"{name}: a {env} row deploys {p}")
        starts.append(target)
        if target.parent.name == "rendered":
            if not (target / "manifests.yaml").is_file():
                err(f, f"{name}: {p}/manifests.yaml missing")
            comp = target.parent.parent
            starts.append(comp / "overlays" / target.name)
        elif (target / "kustomization.yaml").is_file():
            comp = target.parent.parent if target.parent.name == "overlays" else target
            if (comp / "rendered").is_dir():
                err(f, f"{name}: {comp.relative_to(repo)} has rendered manifests, deploy rendered/{env}")
        else:
            err(f, f"{name}: {p} has no kustomization.yaml")
            continue
        if comp.relative_to(root).parts[0] in STACKS:
            want = expected_name(root, comp)
            if name != want:
                err(f, f"Application {name} should be named {want} after its folder")
            claimed.setdefault((comp, env), []).append(name)
    for c in sorted(comps):
        if not any((c, env) in claimed for env in ENVIRONMENTS):
            err(f"{c.relative_to(repo)}/kustomization.yaml", f"{c.relative_to(repo)} is in no ApplicationSet")
    for (c, env), names in sorted(claimed.items()):
        if len(names) > 1:
            err(c.relative_to(repo), f"{c.relative_to(repo)} is claimed by {names} in {env}")
    sets = (root / "argocd" / "applicationsets").relative_to(repo)
    for name in sorted(deployed["prod"] - deployed["staging"] - set(PROD_ONLY) - parked_names):
        err(sets / "staging", f"{name} runs in prod but not in staging, add the row or name it in PROD_ONLY")
    for name in sorted(deployed["staging"] - deployed["prod"] - set(STAGING_ONLY)):
        err(sets / "prod", f"{name} runs in staging but not in prod, add the row or name it in STAGING_ONLY")
    for name in sorted((set(PROD_ONLY) & deployed["staging"]) | (set(STAGING_ONLY) & deployed["prod"])):
        err(".github/scripts/lint-structure.py", f"{name} runs in both environments, remove it from the exceptions")

    seen = reachable(root, starts + [root / "argocd" / "bootstrap" / "prod", root / "argocd" / "bootstrap" / "argocd" / "overlays" / "prod", root / "argocd" / "bootstrap" / "argocd" / "overlays" / "staging", root / "argocd" / "bootstrap" / "staging", root / "argocd" / "crds", root / "argocd" / "projects", root / "argocd" / "clusters" / "prod", root / "argocd" / "clusters" / "staging", root / "argocd" / "applicationsets" / "prod", root / "argocd" / "applicationsets" / "staging"])
    for f in sorted(root.rglob("*")):
        if not f.is_file() or skip(f.relative_to(root)) or f.name in (".gitattributes", "README.md"):
            continue
        if f.suffix in (".yaml", ".yml", ".json", ".toml", ".alloy", ".tftpl") and f.resolve() not in seen:
            err(f.relative_to(repo), "not referenced by any kustomization")

    for k in sorted([*root.rglob("kustomization.yaml"), *(root / "argocd" / "projects").glob("*.yaml"), *(root / "argocd" / "applicationsets").glob("*/*.yaml"), *(root / "argocd" / "clusters").glob("*/*.yaml")]):
        rel = k.relative_to(root)
        if skip(rel):
            continue
        text = k.read_text()
        if k.parent.parent.name == "applicationsets":
            for m, _ in parked(text):
                text = text.replace(m.group(0), "", 1)
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
            if {"base", "components"} & set(rel.parts[:-1]) and "overlays" not in rel.parts:
                for r in (d.get("resources") or []) + (d.get("crds") or []):
                    if "://" in r:
                        err(k.relative_to(repo), f"remote resource in base, its version belongs in overlays: {r}")

    for comp in sorted({k.parent.parent for k in root.rglob("base/kustomization.yaml") if not skip(k.relative_to(root))}):
        names = set()
        for d in ("base", "components"):
            for f in sorted((comp / d).rglob("*.y*ml")):
                if skip(f.relative_to(root)):
                    continue
                for image in images(f):
                    if pinned(image):
                        err(f.relative_to(repo), f"image tag in {d}, set {image.split('@')[0].rsplit(':', 1)[0]} in overlays")
                    else:
                        names.add(image)
        for overlay in sorted(p for p in (comp / "overlays").glob("*") if p.is_dir()):
            tagged = set()
            for f in overlay.rglob("*.y*ml"):
                tagged |= {i.split("@")[0].rsplit(":", 1)[0] for i in images(f) if pinned(i)}
                if f.name == "kustomization.yaml":
                    tagged |= {i.get("name") for d in load(f) for i in d.get("images") or [] if i.get("newTag") or i.get("digest")}
            for name in sorted(names - tagged):
                err(overlay.relative_to(repo) / "kustomization.yaml", f"{name} has no tag, add it to images")

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
            if m and m.group(1) not in ENVIRONMENTS:
                err(f"{f.relative_to(repo)},line={i}", f"environment is {m.group(1)}, known are {', '.join(ENVIRONMENTS)}")

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

    job = repo / "tofu" / "modules" / "talos" / "inline-manifests" / "cilium-bootstrap.yaml"
    chart = root / "infrastructure" / "network" / "cilium" / "overlays" / "prod" / "kustomization.yaml"
    if job.is_file() and chart.is_file():
        boot = re.search(r"--version=v?([\d.]+)", job.read_text())
        want = next((str(h.get("version")).lstrip("v") for d in load(chart) for h in d.get("helmCharts") or [] if h.get("name") == "cilium"), None)
        if boot and want and boot.group(1) != want:
            err(job.relative_to(repo), f"bootstrap installs Cilium {boot.group(1)}, Argo CD deploys {want}")

    failed += len(global_errors)
    print(f"\nSummary: {len(comps)} components, {len(starts)} rows, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "kubernetes"))
