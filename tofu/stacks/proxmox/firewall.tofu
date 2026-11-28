resource "proxmox_virtual_environment_firewall_alias" "lan" {
  name = "lan"
  cidr = "192.168.0.0/24"
}

resource "proxmox_virtual_environment_firewall_alias" "netbird" {
  name = "netbird"
  cidr = "100.64.0.0/10"
}

# WebGUI, SSH und Corosync aus dem Cluster-Netz erlaubt Proxmox selbst
resource "proxmox_virtual_environment_firewall_rules" "cluster" {
  rule {
    type   = "in"
    action = "ACCEPT"
    macro  = "Ceph"
    source = proxmox_virtual_environment_firewall_alias.lan.name
  }

  rule {
    type   = "in"
    action = "ACCEPT"
    macro  = "Ping"
    source = proxmox_virtual_environment_firewall_alias.lan.name
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "9100,9633"
    source  = proxmox_virtual_environment_firewall_alias.lan.name
    comment = "node_exporter, smartctl_exporter"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "80,443"
    source  = proxmox_virtual_environment_firewall_alias.lan.name
    comment = "nginx vor der WebGUI"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    proto   = "tcp"
    dport   = "7480,9283"
    source  = proxmox_virtual_environment_firewall_alias.lan.name
    comment = "RGW, Ceph-mgr Prometheus"
  }

  rule {
    type   = "in"
    action = "ACCEPT"
    proto  = "tcp"
    dport  = "22,80,443,8006"
    source = proxmox_virtual_environment_firewall_alias.netbird.name
  }
}

resource "proxmox_virtual_environment_cluster_firewall" "this" {
  enabled = true

  depends_on = [proxmox_virtual_environment_firewall_rules.cluster]
}
