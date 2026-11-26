#!/bin/bash
# Run on msa2 after central-openbao-config.sh. Daily Raft snapshot of the central OpenBao to Azure.
# OFFSITE_SAS_URL comes from: tofu -chdir=tofu/stacks/state output -raw offsite_sas_url
set -euo pipefail

id=1060
pct exec "$id" -- env OFFSITE_SAS_URL="${OFFSITE_SAS_URL:-}" bash -s <<'INNER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq rclone >/dev/null

install -d -m 700 /root/.config/rclone /var/backups/openbao
if [ -n "$OFFSITE_SAS_URL" ] && ! grep -q '^\[offsite\]' /root/.config/rclone/rclone.conf 2>/dev/null; then
  umask 077
  printf '[offsite]\ntype = azureblob\nsas_url = %s\n' "$OFFSITE_SAS_URL" >>/root/.config/rclone/rclone.conf
fi

export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME=bao.timourhomelab.org
if [ ! -s /etc/openbao/snapshot.token ]; then
  umask 077
  BAO_TOKEN=$(jq -r .root_token /root/init.json) bao token create -orphan -policy=snapshot -no-default-policy \
    -period=720h -display-name=snapshot -field=token >/etc/openbao/snapshot.token
fi

cat >/usr/local/sbin/openbao-snapshot <<'SCRIPT'
#!/bin/bash
set -euo pipefail
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME=bao.timourhomelab.org
BAO_TOKEN=$(cat /etc/openbao/snapshot.token)
export BAO_TOKEN
bao token renew >/dev/null
dir=/var/backups/openbao
file="$dir/central-$(date -u +%Y-%m-%dT%H-%M-%SZ).snap"
bao operator raft snapshot save "$file"
(cd "$dir" && sha256sum ./*.snap | sed 's| \./| |' >SHA256SUMS)
rclone copy "$dir" offsite:openbao-backups/central
find "$dir" -name 'central-*.snap' -mtime +14 -delete
SCRIPT
chmod 700 /usr/local/sbin/openbao-snapshot

cat >/etc/systemd/system/openbao-snapshot.service <<'UNIT'
[Unit]
Description=Snapshot of the central OpenBao to Azure
After=openbao.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/openbao-snapshot
UNIT

cat >/etc/systemd/system/openbao-snapshot.timer <<'UNIT'
[Unit]
Description=Daily snapshot of the central OpenBao

[Timer]
OnCalendar=*-*-* 01:45:00
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now openbao-snapshot.timer >/dev/null
INNER
