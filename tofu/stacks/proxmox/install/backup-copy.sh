#!/bin/bash
# Run once on aoostar. Copies the backup buckets from the local RGW to the external disk every night,
# and the OpenBao snapshots to Azure. OFFSITE_SAS_URL comes from: tofu -chdir=tofu/stacks/state output -raw offsite_sas_url
set -euo pipefail

apt-get install -y rclone jq

install -d -m 700 /root/.config/rclone
if ! grep -q '^\[rgw\]' /root/.config/rclone/rclone.conf 2>/dev/null; then
  user=$(radosgw-admin user info --uid=backup-copy 2>/dev/null ||
    radosgw-admin user create --uid=backup-copy --display-name="backup copy" --system)
  umask 077
  cat >>/root/.config/rclone/rclone.conf <<CONF
[rgw]
type = s3
provider = Ceph
endpoint = http://127.0.0.1:7480
access_key_id = $(jq -r '.keys[0].access_key' <<<"$user")
secret_access_key = $(jq -r '.keys[0].secret_key' <<<"$user")
CONF
fi

if [ -n "${OFFSITE_SAS_URL:-}" ] && ! grep -q '^\[offsite\]' /root/.config/rclone/rclone.conf; then
  umask 077
  printf '[offsite]\ntype = azureblob\nsas_url = %s\n' "$OFFSITE_SAS_URL" >>/root/.config/rclone/rclone.conf
fi

install -d /mnt/backup-hdd
grep -q 'LABEL=backup-hdd' /etc/fstab ||
  echo 'LABEL=backup-hdd /mnt/backup-hdd ext4 noauto,nofail,noatime 0 2' >>/etc/fstab

cat >/usr/local/sbin/backup-copy <<'SCRIPT'
#!/bin/bash
set -euo pipefail

mnt=/mnt/backup-hdd
buckets='^(velero-|cnpg-|openbao-|etcd-|audit-archive|elasticsearch-snapshots|harbor-registry)'
prom=/var/lib/prometheus/node-exporter
rc=0

sums=$(mktemp)
rclone hashsum sha256 --download rgw:openbao-backups | sort -k2 >"$sums"

offsite() {
  grep -q '^\[offsite\]' /root/.config/rclone/rclone.conf || { echo "offsite not configured"; return 0; }
  rclone copy rgw:openbao-backups offsite:openbao-backups --transfers 4 || return 1
  rclone copyto "$sums" offsite:openbao-backups/SHA256SUMS || return 1
  central=$(rclone lsjson --files-only offsite:openbao-backups/central | jq -r '[.[] | select(.Name | endswith(".snap")) | .ModTime | sub("\\.[0-9]+";"") | fromdateiso8601] | max // 0') || return 1
  printf 'backup_central_openbao_last_snapshot_timestamp_seconds %s\n' "$central" >"$prom/backup_central_openbao.prom.tmp"
  mv "$prom/backup_central_openbao.prom.tmp" "$prom/backup_central_openbao.prom"
  printf 'backup_offsite_last_success_timestamp_seconds %s\n' "$(date +%s)" >"$prom/backup_offsite.prom.tmp"
  mv "$prom/backup_offsite.prom.tmp" "$prom/backup_offsite.prom"
}

disk() (
  [ -e /dev/disk/by-label/backup-hdd ] || { echo "backup disk not attached"; exit 0; }
  mountpoint -q "$mnt" || mount "$mnt" || exit 1
  trap 'umount "$mnt"' EXIT

  # never deletes, prune by hand if the disk fills
  radosgw-admin bucket list | jq -r '.[]' | grep -E "$buckets" | while read -r bucket; do
    rclone copy "rgw:$bucket" "$mnt/rgw/$bucket" --transfers 4 || exit 1
  done || exit 1
  cp "$sums" "$mnt/rgw/openbao-backups/SHA256SUMS" || exit 1

  printf 'backup_copy_last_success_timestamp_seconds %s\nbackup_copy_size_bytes %s\n' \
    "$(date +%s)" "$(du -sb "$mnt/rgw" | cut -f1)" >"$prom/backup_copy.prom.tmp"
  mv "$prom/backup_copy.prom.tmp" "$prom/backup_copy.prom"
)

offsite || rc=1
disk || rc=1
rm -f "$sums"
exit "$rc"
SCRIPT
chmod 750 /usr/local/sbin/backup-copy

cat >/etc/systemd/system/backup-copy.service <<'UNIT'
[Unit]
Description=Copy backup buckets to the external disk and Azure

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup-copy
UNIT

cat >/etc/systemd/system/backup-copy.timer <<'UNIT'
[Unit]
Description=Nightly copy of the backup buckets

[Timer]
OnCalendar=*-*-* 04:30:00
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now backup-copy.timer
