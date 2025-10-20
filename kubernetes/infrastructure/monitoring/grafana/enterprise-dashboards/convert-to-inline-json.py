#!/usr/bin/env python3
"""
Convert GrafanaDashboard CRDs from configMapRef (v2.x) to inline JSON (v5.x) format.

This script:
1. Finds all GrafanaDashboard CRDs using configMapRef
2. Locates the corresponding ConfigMap
3. Extracts the dashboard.json from ConfigMap
4. Rewrites the GrafanaDashboard CRD with inline JSON
5. Deletes the ConfigMap file (no longer needed)
"""

import yaml
import json
import glob
import os
from pathlib import Path

# Base directory
BASE_DIR = Path(__file__).parent

def find_configmap_file(configmap_name):
    """Find the ConfigMap YAML file by name."""
    for file_path in BASE_DIR.rglob("*.yaml"):
        if file_path.name == "convert-to-inline-json.py":
            continue
        try:
            with open(file_path) as f:
                docs = list(yaml.safe_load_all(f))
                for doc in docs:
                    if (doc and doc.get("kind") == "ConfigMap" and
                        doc.get("metadata", {}).get("name") == configmap_name):
                        return file_path
        except:
            pass
    return None

def convert_dashboard(dashboard_file):
    """Convert a single GrafanaDashboard from configMapRef to inline JSON."""
    print(f"\n📄 Processing: {dashboard_file.relative_to(BASE_DIR)}")

    with open(dashboard_file) as f:
        dashboard_crd = yaml.safe_load(f)

    # Check if it uses configMapRef
    configmap_ref = dashboard_crd.get("spec", {}).get("configMapRef")
    if not configmap_ref:
        print(f"  ⏭️  Skipping (already uses inline JSON or grafanaCom)")
        return False

    configmap_name = configmap_ref.get("name")
    configmap_key = configmap_ref.get("key", "dashboard.json")

    print(f"  🔍 Found configMapRef: {configmap_name} (key: {configmap_key})")

    # Find ConfigMap file
    configmap_file = find_configmap_file(configmap_name)
    if not configmap_file:
        print(f"  ❌ ConfigMap file not found: {configmap_name}")
        return False

    print(f"  📦 ConfigMap file: {configmap_file.relative_to(BASE_DIR)}")

    # Extract dashboard JSON from ConfigMap
    with open(configmap_file) as f:
        configmap = yaml.safe_load(f)

    dashboard_json_str = configmap.get("data", {}).get(configmap_key)
    if not dashboard_json_str:
        print(f"  ❌ No '{configmap_key}' found in ConfigMap data")
        return False

    # Validate JSON
    try:
        dashboard_json = json.loads(dashboard_json_str)
        print(f"  ✅ Dashboard JSON valid ({len(dashboard_json_str)} bytes)")
    except json.JSONDecodeError as e:
        print(f"  ❌ Invalid JSON in ConfigMap: {e}")
        return False

    # Remove configMapRef from spec
    del dashboard_crd["spec"]["configMapRef"]

    # Add inline JSON to spec
    dashboard_crd["spec"]["json"] = dashboard_json_str

    # Write updated dashboard CRD
    with open(dashboard_file, 'w') as f:
        yaml.safe_dump(dashboard_crd, f, default_flow_style=False, sort_keys=False, width=120)

    print(f"  ✅ Updated dashboard CRD with inline JSON")

    # Delete ConfigMap file
    configmap_file.unlink()
    print(f"  🗑️  Deleted ConfigMap file: {configmap_file.name}")

    return True

def main():
    print("🔧 GRAFANA DASHBOARD CONVERSION TOOL")
    print("=" * 60)
    print("Converting GrafanaDashboard CRDs from v2.x to v5.x format")
    print("  FROM: spec.configMapRef (deprecated)")
    print("    TO: spec.json (inline JSON)")
    print("=" * 60)

    # Find all GrafanaDashboard YAML files
    dashboard_files = list(BASE_DIR.rglob("*.yaml"))
    dashboard_files = [f for f in dashboard_files if f.name != "kustomization.yaml"]

    converted = 0
    skipped = 0
    errors = 0

    for dashboard_file in dashboard_files:
        try:
            if convert_dashboard(dashboard_file):
                converted += 1
            else:
                skipped += 1
        except Exception as e:
            print(f"  ❌ ERROR: {e}")
            errors += 1

    print("\n" + "=" * 60)
    print("📊 CONVERSION SUMMARY")
    print("=" * 60)
    print(f"  ✅ Converted: {converted} dashboards")
    print(f"  ⏭️  Skipped:   {skipped} dashboards (already modern format)")
    print(f"  ❌ Errors:    {errors} dashboards")
    print("=" * 60)

    if converted > 0:
        print("\n🎯 NEXT STEPS:")
        print("  1. Review changes: git diff")
        print("  2. Update kustomization.yaml (remove deleted ConfigMap references)")
        print("  3. Commit changes: git add -A && git commit")
        print("  4. Deploy: kubectl apply or ArgoCD sync")

if __name__ == "__main__":
    main()
