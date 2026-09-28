#!/usr/bin/env python3
"""Prueft jede host_node/datastore-Paarung aus talos_nodes.auto.tfvars gegen die Proxmox-API.

Auch auskommentierte Bloecke, denn die werden spaeter einkommentiert.
Braucht TF_VAR_proxmox (JSON mit endpoint) und TF_VAR_proxmox_api_token.
"""
import json
import os
import re
import ssl
import sys
import urllib.request

TFVARS = "tofu/talos_nodes.auto.tfvars"
FIELDS = ("datastore_id", "ceph_disk_datastore")


def api(endpoint, token, path):
    req = urllib.request.Request(
        endpoint.rstrip("/") + "/api2/json" + path,
        headers={"Authorization": "PVEAPIToken=" + token},
    )
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    with urllib.request.urlopen(req, timeout=30, context=ctx) as r:
        return json.load(r)["data"]


def parse_nodes(text):
    """(name, host_node, {feld: wert}, auskommentiert) je Block."""
    out = []
    for name, body in re.findall(
        r'^\s*#?\s*"([a-z0-9-]+)"\s*=\s*\{(.*?)^\s*#?\s*\}', text, re.S | re.M
    ):
        host = re.search(r'host_node\s*=\s*"([^"]+)"', body)
        vals = {}
        for f in FIELDS:
            m = re.search(r'%s\s*=\s*"([^"]+)"' % f, body)
            if m:
                vals[f] = m.group(1)
        parked = bool(re.search(r'^\s*#\s*"%s"' % re.escape(name), text, re.M))
        out.append((name, host.group(1) if host else None, vals, parked))
    return out


def main():
    cfg = os.environ.get("TF_VAR_proxmox")
    token = os.environ.get("TF_VAR_proxmox_api_token")
    if not cfg or not token:
        print("TF_VAR_proxmox / TF_VAR_proxmox_api_token fehlen", file=sys.stderr)
        return 2
    endpoint = json.loads(cfg)["endpoint"]

    nodes = {n["node"] for n in api(endpoint, token, "/nodes")}
    active = {
        n: {s["storage"] for s in api(endpoint, token, "/nodes/%s/storage" % n) if s.get("active")}
        for n in nodes
    }

    entries = parse_nodes(open(TFVARS).read())
    problems = []
    for name, host, vals, parked in entries:
        tag = " (geparkt)" if parked else ""
        if host not in nodes:
            problems.append("%s%s: host_node '%s' gibt es nicht — Cluster: %s"
                            % (name, tag, host, ", ".join(sorted(nodes))))
            continue
        for field, ds in vals.items():
            if ds not in active[host]:
                problems.append("%s%s: %s='%s' ist auf %s nicht aktiv — dort aktiv: %s"
                                % (name, tag, field, ds, host, ", ".join(sorted(active[host]))))

    print("%d Node-Definitionen geprueft, %d Proxmox-Nodes" % (len(entries), len(nodes)))
    for p in problems:
        print("  FEHLER: " + p)
    if problems:
        print("\nEine Paarung zeigt auf einen Storage, den der Host nicht hat.")
        print("Das war die Ursache der pve-Reset-Schleife am 28.09.2026.")
        return 1
    print("  alle Paarungen stimmen")
    return 0


if __name__ == "__main__":
    sys.exit(main())
