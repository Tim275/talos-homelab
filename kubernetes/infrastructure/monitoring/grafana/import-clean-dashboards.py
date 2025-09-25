#!/usr/bin/env python3
"""
Import ONLY the essential 2025 dashboards - clean and organized
One dashboard per application as requested
"""

import requests
import json
import base64
import sys
import time

# 🎯 CLEAN 2025 DASHBOARD COLLECTION - ONE PER APPLICATION
DASHBOARDS = [
    # Infrastructure & Core
    {"id": 1860, "title": "Node Exporter Full (Talos)", "folder": "Talos"},
    {"id": 15757, "title": "Kubernetes Global View", "folder": "Kubernetes"},

    # Applications
    {"id": 2842, "title": "Ceph Cluster", "folder": "Ceph"},            # Storage
    {"id": 7581, "title": "Kafka Strimzi", "folder": "Kafka"},         # Messaging
    {"id": 14191, "title": "Elasticsearch Cluster", "folder": "Elasticsearch"},  # Search
    {"id": 24056, "title": "Cilium Agent", "folder": "Cilium"},        # Networking
    {"id": 7639, "title": "Istio Mesh Dashboard", "folder": "Istio"},   # Service Mesh
    {"id": 20842, "title": "Cert-Manager", "folder": "Cert-Manager"},   # Security
    {"id": 19993, "title": "ArgoCD Operational", "folder": "ArgoCD"},   # GitOps
]

def import_dashboard(dashboard_id, title, folder="General"):
    """Import dashboard from Grafana.com via API"""
    grafana_url = "http://localhost:3000"  # Port-forward to Grafana
    admin_user = "admin"
    admin_pass = "admin"  # Default

    # Create folder first
    folder_response = create_folder(grafana_url, admin_user, admin_pass, folder)

    # Step 1: Get dashboard JSON from Grafana.com
    try:
        print(f"📥 Fetching dashboard {dashboard_id}: {title}")
        grafana_com_url = f"https://grafana.com/api/dashboards/{dashboard_id}/revisions/latest/download"

        response = requests.get(grafana_com_url, timeout=30)
        response.raise_for_status()
        dashboard_json = response.json()

        # Step 2: Prepare for import
        dashboard_json["id"] = None  # Reset ID for import
        dashboard_json["uid"] = None  # Reset UID for import

        # Step 3: Update datasource to VictoriaMetrics
        dashboard_str = json.dumps(dashboard_json)
        dashboard_str = dashboard_str.replace('"${DS_PROMETHEUS}"', '"VictoriaMetrics"')
        dashboard_str = dashboard_str.replace('"$__rate_interval"', '"5m"')
        dashboard_json = json.loads(dashboard_str)

        # Step 4: Import to Grafana
        import_payload = {
            "dashboard": dashboard_json,
            "folderId": folder_response.get("id", 0),
            "overwrite": True
        }

        headers = {"Content-Type": "application/json"}
        auth = (admin_user, admin_pass)

        import_response = requests.post(
            f"{grafana_url}/api/dashboards/db",
            json=import_payload,
            headers=headers,
            auth=auth,
            timeout=30
        )

        if import_response.status_code == 200:
            result = import_response.json()
            print(f"✅ Imported: {title} → {folder} folder (UID: {result.get('uid', 'N/A')})")
            return True
        else:
            print(f"❌ Failed to import {title}: {import_response.status_code} - {import_response.text}")
            return False

    except Exception as e:
        print(f"❌ Error importing {title}: {e}")
        return False

def create_folder(grafana_url, admin_user, admin_pass, folder_name):
    """Create folder in Grafana"""
    headers = {"Content-Type": "application/json"}
    auth = (admin_user, admin_pass)

    folder_payload = {
        "uid": folder_name.lower().replace(" ", "-"),
        "title": folder_name
    }

    response = requests.post(
        f"{grafana_url}/api/folders",
        json=folder_payload,
        headers=headers,
        auth=auth
    )

    if response.status_code in [200, 409]:  # 409 = already exists
        if response.status_code == 409:
            # Folder exists, get its ID
            get_response = requests.get(
                f"{grafana_url}/api/folders/{folder_payload['uid']}",
                headers=headers,
                auth=auth
            )
            if get_response.status_code == 200:
                return get_response.json()
        else:
            return response.json()

    return {"id": 0}  # Default to General folder

def main():
    print("🚀 Starting Clean Dashboard Import (2025 Collection)")
    print("=" * 60)

    success_count = 0
    total_count = len(DASHBOARDS)

    for dashboard in DASHBOARDS:
        success = import_dashboard(
            dashboard["id"],
            dashboard["title"],
            dashboard["folder"]
        )

        if success:
            success_count += 1

        time.sleep(2)  # Rate limiting

    print("\n" + "=" * 60)
    print(f"🎯 Import Complete: {success_count}/{total_count} dashboards imported")

    if success_count == total_count:
        print("✅ All dashboards imported successfully!")
        sys.exit(0)
    else:
        print(f"⚠️ {total_count - success_count} dashboards failed to import")
        sys.exit(1)

if __name__ == "__main__":
    main()
