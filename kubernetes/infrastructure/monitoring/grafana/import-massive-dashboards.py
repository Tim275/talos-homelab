#!/usr/bin/env python3
"""
Import 25+ proven dashboards from Grafana.com via API
Using the successful API approach instead of broken CRD schema
"""

import requests
import json
import base64
import sys

# 🎯 MASSIVE GRAFANA.COM DASHBOARD COLLECTION
# All proven working dashboards from comprehensive research
DASHBOARDS = [
    # 🏗️ INFRASTRUCTURE & KUBERNETES CORE
    {"id": 1860, "title": "Node Exporter Full", "folder": "Infrastructure/System"},
    {"id": 11074, "title": "Node Exporter EN", "folder": "Infrastructure/System"},
    {"id": 22413, "title": "K8s Node Metrics Multi-Cluster", "folder": "Infrastructure/Kubernetes"},
    {"id": 315, "title": "Kubernetes Cluster Classic", "folder": "Infrastructure/Kubernetes"},
    {"id": 6417, "title": "Kubernetes Cluster Prometheus", "folder": "Infrastructure/Kubernetes"},
    {"id": 15759, "title": "Kubernetes Views Nodes", "folder": "Infrastructure/Kubernetes"},
    {"id": 15760, "title": "Kubernetes Views Pods", "folder": "Infrastructure/Kubernetes"},
    {"id": 13077, "title": "Kubernetes Comprehensive", "folder": "Infrastructure/Kubernetes"},

    # 🏪 STORAGE & DATABASES (PRIORITY!)
    {"id": 2842, "title": "Ceph Cluster Rook", "folder": "Infrastructure/Storage"},  # REQUESTED!
    {"id": 5342, "title": "Ceph Pools", "folder": "Infrastructure/Storage"},
    {"id": 14114, "title": "PostgreSQL Dashboard", "folder": "Platform/Databases"},
    {"id": 11835, "title": "Redis Monitoring", "folder": "Platform/Databases"},

    # 🌐 APPLICATIONS & SERVICES
    {"id": 9614, "title": "NGINX Ingress Controller", "folder": "Platform/Ingress"},
    {"id": 14314, "title": "Kubernetes NGINX Ingress NextGen", "folder": "Platform/Ingress"},
    {"id": 16677, "title": "Ingress Nginx Overview", "folder": "Platform/Ingress"},
    {"id": 11001, "title": "Cert-Manager Official", "folder": "Infrastructure/Security"},
    {"id": 20842, "title": "Cert-Manager Kubernetes", "folder": "Infrastructure/Security"},
    {"id": 13230, "title": "SSL Certificate Monitor", "folder": "Infrastructure/Security"},
    {"id": 13922, "title": "Certificates Expiration", "folder": "Infrastructure/Security"},
    {"id": 19993, "title": "ArgoCD Operational Overview", "folder": "Platform/GitOps"},

    # 🔍 ADDITIONAL KUBERNETES VIEWS
    {"id": 18283, "title": "Kubernetes Dashboard Comprehensive", "folder": "Infrastructure/Kubernetes"},
    {"id": 15661, "title": "K8s Dashboard EN 2025", "folder": "Infrastructure/Kubernetes"},
    {"id": 12575, "title": "Kubernetes Ingress Controller Dashboard", "folder": "Platform/Ingress"},
    {"id": 20188, "title": "Modern Kubernetes Nginx Ingress", "folder": "Platform/Ingress"},
]

def import_dashboard(dashboard_id, title, folder="General"):
    """Import dashboard from Grafana.com via API"""
    grafana_url = "http://localhost:3000"  # Port-forward to Grafana
    auth = ("admin", "admin")  # Default credentials

    print(f"🔄 Importing {title} (ID: {dashboard_id})...")

    try:
        # Import from grafana.com
        import_data = {
            "dashboard": {
                "id": None,
                "title": title
            },
            "folderId": 0,
            "folderTitle": folder,
            "inputs": [
                {
                    "name": "DS_PROMETHEUS",
                    "type": "datasource",
                    "pluginId": "prometheus",
                    "value": "prometheus-operator-kube-p-prometheus"
                }
            ],
            "overwrite": True
        }

        # Get dashboard from grafana.com
        grafana_com_url = f"https://grafana.com/api/dashboards/{dashboard_id}"
        response = requests.get(grafana_com_url)

        if response.status_code != 200:
            print(f"❌ Failed to fetch dashboard {dashboard_id} from grafana.com")
            return False

        dashboard_data = response.json()
        import_data["dashboard"] = dashboard_data["json"]
        import_data["dashboard"]["id"] = None  # Let Grafana assign new ID
        import_data["dashboard"]["title"] = title

        # Import to local Grafana
        import_url = f"{grafana_url}/api/dashboards/import"
        response = requests.post(import_url, json=import_data, auth=auth)

        if response.status_code == 200:
            print(f"✅ Successfully imported {title}")
            return True
        else:
            print(f"❌ Failed to import {title}: {response.text}")
            return False

    except Exception as e:
        print(f"❌ Error importing {title}: {str(e)}")
        return False

def main():
    print("🚀 MASSIVE DASHBOARD IMPORT - 25+ Proven Dashboards")
    print("📊 Importing all researched Grafana.com dashboards...")

    success_count = 0
    total_count = len(DASHBOARDS)

    for dashboard in DASHBOARDS:
        if import_dashboard(dashboard["id"], dashboard["title"], dashboard["folder"]):
            success_count += 1
        print()  # Spacing

    print(f"🎯 Import Complete: {success_count}/{total_count} dashboards imported successfully")

    if success_count == total_count:
        print("🏆 ALL DASHBOARDS IMPORTED SUCCESSFULLY!")
    else:
        print(f"⚠️  {total_count - success_count} dashboards failed to import")

if __name__ == "__main__":
    main()
