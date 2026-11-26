#!/bin/bash
# Run once on msa2. GitHub runner outside Kubernetes, label "bootstrap": it builds the cluster,
# so it cannot live inside it. Expects a registration token on stdin:
#   gh api -X POST repos/Tim275/talos-homelab/actions/runners/registration-token --jq .token | ssh root@msa2 bash bootstrap-runner.sh
set -euo pipefail

id=1061
ip=192.168.0.61
ver=2.338.2
sum=baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40
tpl=debian-13-standard_13.6-1_amd64.tar.zst
read -r token

if ! pct status "$id" >/dev/null 2>&1; then
  pct create "$id" "local:vztmpl/$tpl" \
    --hostname bootstrap-runner --unprivileged 1 --cores 2 --memory 2048 --swap 0 \
    --rootfs local-zfs:16 \
    --net0 "name=eth0,bridge=vmbr0,ip=$ip/24,gw=192.168.0.1,firewall=1" \
    --nameserver 192.168.0.1 --onboot 1
fi

cat >"/etc/pve/firewall/$id.fw" <<FW
[OPTIONS]
enable: 1
policy_in: DROP

[RULES]
IN Ping(ACCEPT) -source 192.168.0.0/24
FW

pct status "$id" | grep -q running || pct start "$id"
sleep 5

# the runner trusts the central OpenBao like any other client
pct pull 1060 /opt/openbao/tls/ca.crt /tmp/central-openbao-ca.crt
pct push "$id" /tmp/central-openbao-ca.crt /usr/local/share/ca-certificates/central-openbao.crt
rm -f /tmp/central-openbao-ca.crt

umask 077
printf '%s' "$token" >/root/runner-token
pct push "$id" /root/runner-token /root/runner-token --perms 600
rm -f /root/runner-token

pct exec "$id" -- env VER="$ver" SUM="$sum" bash -s <<'INNER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates jq git unzip >/dev/null
update-ca-certificates >/dev/null

id runner >/dev/null 2>&1 || useradd --create-home --shell /bin/bash runner
dir=/opt/actions-runner
if [ ! -x "$dir/run.sh" ]; then
  install -d -o runner -g runner "$dir"
  cd /tmp
  curl -fsSLo runner.tgz "https://github.com/actions/runner/releases/download/v$VER/actions-runner-linux-x64-$VER.tar.gz"
  echo "$SUM  runner.tgz" | sha256sum -c -
  tar -xzf runner.tgz -C "$dir" && rm -f runner.tgz
  chown -R runner:runner "$dir"
  "$dir/bin/installdependencies.sh" >/dev/null
fi
if [ ! -f "$dir/.runner" ]; then
  token=$(cat /root/runner-token)
  su runner -c "cd $dir && ./config.sh --unattended --url https://github.com/Tim275/talos-homelab --token $token --name bootstrap-msa2 --labels bootstrap --no-default-labels --replace" >/dev/null
  cd "$dir" && ./svc.sh install runner >/dev/null && ./svc.sh start >/dev/null
fi
rm -f /root/runner-token
systemctl is-active "actions.runner.Tim275-talos-homelab.bootstrap-msa2.service"
INNER
