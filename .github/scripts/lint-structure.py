#!/usr/bin/env python3
"""Lint the repository layout.

Checks:
- every component has both base/ and overlays/
- every ApplicationSet path exists and holds a kustomization.yaml
- every component is claimed by at least one ApplicationSet
- a SecurityPolicy and the secret it references live in the same component
"""
import re
import sys
from pathlib import Path

import yaml

STACKS = ("infrastructure", "platform", "security", "apps", "tenants")
PATH_RE = re.compile(r"path:\s*[\"']?(kubernetes/[A-Za-z0-9/_.-]+)")


def components(root: Path) -> set[Path]:
    """A component is any directory that owns a base/ or an overlays/."""
    found = set()
    for k in root.rglob("kustomization.yaml"):
        if "/charts/" in str(k):
            continue
        d = k.parent
        if d.name == "base":
            found.add(d.parent)
        elif d.parent.name == "overlays":
            found.add(d.parent.parent)
    return {c for c in found if c.relative_to(root).parts[0] in STACKS}


def appset_paths(root: Path) -> set[str]:
    paths = set()
    for f in (root / "applicationsets").rglob("*.yaml"):
        for m in PATH_RE.finditer(f.read_text()):
            paths.add(m.group(1))
    return paths


def secret_names(doc: dict) -> set[str]:
    """Secret names a SecurityPolicy points at. targetRefs are routes, not secrets."""
    spec = doc.get("spec", {})
    names = set()

    oidc = spec.get("oidc", {})
    for key in ("clientIDRef", "clientSecret"):
        ref = oidc.get(key)
        if isinstance(ref, dict) and ref.get("kind", "Secret") == "Secret" and ref.get("name"):
            names.add(ref["name"])

    users = spec.get("basicAuth", {}).get("users")
    if isinstance(users, dict) and users.get("name"):
        names.add(users["name"])

    return names


def main(root_arg: str) -> int:
    root = Path(root_arg)
    repo = root.parent if root.name == "kubernetes" else root
    comps = components(root)
    declared = appset_paths(root)
    failed = 0

    for c in sorted(comps):
        for sub in ("base", "overlays"):
            if not (c / sub).is_dir():
                print(f"::error file={c}/kustomization.yaml::{c} has no {sub}/")
                failed += 1

    for p in sorted(declared):
        d = repo / p
        if not d.is_dir():
            print(f"::error::ApplicationSet points at {p}, which does not exist")
            failed += 1
        elif not (d / "kustomization.yaml").is_file():
            print(f"::error::{p} has no kustomization.yaml")
            failed += 1

    for c in sorted(comps):
        rel = str(c)
        if not any(p == rel or p.startswith(rel + "/") for p in declared):
            print(f"::error file={c}/kustomization.yaml::{c} is in no ApplicationSet")
            failed += 1

    for f in root.rglob("*.yaml"):
        if "/charts/" in str(f) or "/rendered/" in str(f):
            continue
        try:
            docs = list(yaml.safe_load_all(f.read_text()))
        except yaml.YAMLError:
            continue
        for doc in docs:
            if not isinstance(doc, dict) or doc.get("kind") != "SecurityPolicy":
                continue
            comp = f.parent.parent if f.parent.name == "base" else f.parent
            owned = {
                d.get("metadata", {}).get("name")
                for g in comp.rglob("*.yaml")
                if "/charts/" not in str(g)
                for d in (yaml.safe_load_all(g.read_text()) if g.suffix == ".yaml" else [])
                if isinstance(d, dict) and d.get("kind") in ("Secret", "SealedSecret")
            }
            for name in secret_names(doc) - owned:
                print(
                    f"::error file={f}::SecurityPolicy "
                    f"{doc['metadata']['name']} references secret {name}, "
                    f"which {comp} does not own"
                )
                failed += 1

    print(f"\nSummary: {len(comps)} components, {len(declared)} paths, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "kubernetes"))
