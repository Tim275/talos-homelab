#!/bin/bash
set -euo pipefail
exec >>/var/log/first-boot.log 2>&1

src=/etc/apt/sources.list.d
for f in "$src/pve-enterprise.sources" "$src/ceph.sources"; do
  if [ -f "$f" ] && ! grep -q '^Enabled:' "$f"; then
    echo 'Enabled: no' >>"$f"
  fi
done

cat >"$src/proxmox.sources" <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

cat >"$src/debian-backports.sources" <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y -o Dpkg::Options::=--force-confold full-upgrade
apt-get install -y prometheus-node-exporter
apt-get install -y -t trixie-backports prometheus-smartctl-exporter

echo 'PasswordAuthentication no' >/etc/ssh/sshd_config.d/10-key-only.conf
sshd -t
systemctl reload ssh

systemctl mask --now rpcbind.socket rpcbind.service

apst=nvme_core.default_ps_max_latency_us=0
grep -q "$apst" /etc/kernel/cmdline || sed -i "s/\$/ $apst/" /etc/kernel/cmdline
echo "GRUB_CMDLINE_LINUX=\"\$GRUB_CMDLINE_LINUX $apst\"" >/etc/default/grub.d/nvme-apst.cfg
proxmox-boot-tool refresh
shutdown -r +1
