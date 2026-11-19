#!/bin/bash
# Run once on aoostar. Copies the backup buckets from the local RGW to the external disk every night.
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

install -d /mnt/backup-hdd
grep -q 'LABEL=backup-hdd' /etc/fstab ||
  echo 'LABEL=backup-hdd /mnt/backup-hdd ext4 noauto,nofail,noatime 0 2' >>/etc/fstab

cat >/usr/local/sbin/backup-copy <<'SCRIPT'
#!/bin/bash
set -euo pipefail

mnt=/mnt/backup-hdd
buckets='^(velero-|cnpg-|openbao-|etcd-|audit-archive|elasticsearch-snapshots|harbor-registry)'

[ -e /dev/disk/by-label/backup-hdd ] || { echo "backup disk not attached"; exit 0; }
mountpoint -q "$mnt" || mount "$mnt"
trap 'umount "$mnt"' EXIT

# never deletes, prune by hand if the disk fills
radosgw-admin bucket list | jq -r '.[]' | grep -E "$buckets" | while read -r bucket; do
  rclone copy "rgw:$bucket" "$mnt/rgw/$bucket" --transfers 4
done

out=/var/lib/prometheus/node-exporter/backup_copy.prom
printf 'backup_copy_last_success_timestamp_seconds %s\nbackup_copy_size_bytes %s\n' \
  "$(date +%s)" "$(du -sb "$mnt/rgw" | cut -f1)" >"$out.tmp"
mv "$out.tmp" "$out"
SCRIPT
chmod 750 /usr/local/sbin/backup-copy

cat >/etc/systemd/system/backup-copy.service <<'UNIT'
[Unit]
Description=Copy backup buckets to the external disk

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
