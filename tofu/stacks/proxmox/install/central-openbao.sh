#!/bin/bash
# Run once on msa2. Creates the container for the central OpenBao outside Kubernetes and installs it.
# The unseal key and the first root token end up in /root/init.json inside the container:
# copy both into the password manager, then delete the file.
set -euo pipefail

id=1060
ip=192.168.0.60
name=bao.timourhomelab.org
ver=2.7.3
tpl=debian-13-standard_13.6-1_amd64.tar.zst

pveam list local | grep -q "$tpl" || { pveam update; pveam download local "$tpl"; }

if ! pct status "$id" >/dev/null 2>&1; then
  pct create "$id" "local:vztmpl/$tpl" \
    --hostname bao --unprivileged 1 --cores 1 --memory 1024 --swap 0 \
    --rootfs local-zfs:8 \
    --net0 "name=eth0,bridge=vmbr0,ip=$ip/24,gw=192.168.0.1,firewall=1" \
    --nameserver 192.168.0.1 --onboot 1
fi

cat >"/etc/pve/firewall/$id.fw" <<FW
[OPTIONS]
enable: 1
policy_in: DROP

[RULES]
IN ACCEPT -source 192.168.0.0/24 -p tcp -dport 8200
IN ACCEPT -source 100.64.0.0/10 -p tcp -dport 8200
IN Ping(ACCEPT) -source 192.168.0.0/24
FW

pct status "$id" | grep -q running || pct start "$id"
sleep 5

pct exec "$id" -- env VER="$ver" IP="$ip" NAME="$name" bash -s <<'INNER'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq curl ca-certificates jq openssl >/dev/null

if ! dpkg -s openbao >/dev/null 2>&1 || [ "$(dpkg-query -W -f='${Version}' openbao)" != "$VER" ]; then
  cd /tmp
  base="https://github.com/openbao/openbao/releases/download/v$VER"
  curl -fsSLO "$base/openbao_${VER}_linux_amd64.deb"
  curl -fsSL "$base/checksums.txt" | grep " openbao_${VER}_linux_amd64.deb$" | sha256sum -c -
  dpkg -i "openbao_${VER}_linux_amd64.deb" >/dev/null
  rm -f "openbao_${VER}_linux_amd64.deb"
fi

tls=/opt/openbao/tls
if ! openssl x509 -in "$tls/tls.crt" -noout -ext subjectAltName 2>/dev/null | grep -q "$IP"; then
  umask 077
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 3650 \
    -subj "/CN=central-openbao-ca" -keyout "$tls/ca.key" -out "$tls/ca.crt" 2>/dev/null
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -subj "/CN=$NAME" -keyout "$tls/tls.key" -out "$tls/tls.csr" 2>/dev/null
  openssl x509 -req -in "$tls/tls.csr" -CA "$tls/ca.crt" -CAkey "$tls/ca.key" -CAcreateserial -days 1095 \
    -extfile <(printf 'subjectAltName=DNS:%s,IP:%s\nextendedKeyUsage=serverAuth\n' "$NAME" "$IP") \
    -out "$tls/tls.crt" 2>/dev/null
  rm -f "$tls/tls.csr" "$tls/ca.srl"
  chmod 644 "$tls/ca.crt"
  chown -R openbao:openbao "$tls"
fi

install -d -o openbao -g openbao -m 700 /opt/openbao/data /var/log/openbao
cat >/etc/openbao/openbao.hcl <<HCL
ui            = true
cluster_name  = "central"
api_addr      = "https://$IP:8200"
cluster_addr  = "https://$IP:8201"
max_lease_ttl = "87600h"

storage "raft" {
  path    = "/opt/openbao/data"
  node_id = "central-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_cert_file   = "/opt/openbao/tls/tls.crt"
  tls_key_file    = "/opt/openbao/tls/tls.key"
  tls_min_version = "tls12"

  telemetry {
    unauthenticated_metrics_access = true
  }
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}

audit "file" "file" {
  options {
    file_path = "/var/log/openbao/audit.log"
  }
}
HCL
chown openbao:openbao /etc/openbao/openbao.hcl
chmod 640 /etc/openbao/openbao.hcl

systemctl enable --now openbao >/dev/null 2>&1 || true
systemctl restart openbao
sleep 3

export BAO_ADDR="https://127.0.0.1:8200" BAO_CACERT=/opt/openbao/tls/ca.crt BAO_TLS_SERVER_NAME="$NAME"
state() { bao status -format=json 2>/dev/null || true; }
if [ "$(state | jq -r .initialized)" = "false" ]; then
  umask 077
  bao operator init -key-shares=1 -key-threshold=1 -format=json >/root/init.json
fi
if [ "$(state | jq -r .sealed)" = "true" ] && [ -f /root/init.json ]; then
  jq -r '.unseal_keys_b64[0]' /root/init.json | bao write -format=json sys/unseal key=- | jq -c '{sealed}'
fi
state | jq -c '{initialized, sealed, version, storage_type}'
openssl x509 -in /opt/openbao/tls/ca.crt -noout -fingerprint -sha256
INNER
