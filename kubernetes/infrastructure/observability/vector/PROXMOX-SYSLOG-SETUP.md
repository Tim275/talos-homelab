# Proxmox Syslog Configuration for Vector

## Purpose
Send Proxmox host logs (nipogi, minisforum) to Vector Aggregator for centralized logging with Elasticsearch.

## Architecture

```
Proxmox Host (nipogi/minisforum)
    └─> rsyslog
        └─> UDP 5140
            └─> Vector Aggregator Service (LoadBalancer)
                └─> Elasticsearch Data Streams
                    └─> logs-proxmox.{severity}-{hostname}
```

## Step 1: Get Vector Aggregator Service IP

```bash
export KUBECONFIG=/path/to/kube-config.yaml

# Get Vector Aggregator Service IP (should be LoadBalancer or NodePort)
kubectl get svc -n elastic-system vector-aggregator

# Expected output:
# NAME                TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
# vector-aggregator   LoadBalancer   10.96.x.x       192.168.68.x      5140:xxxxx/UDP
```

**Note**: If you see `<pending>` for EXTERNAL-IP, Vector Aggregator is using ClusterIP. You'll need to:
1. Use a NodePort (access via any worker node IP)
2. Or use MetalLB/kube-vip for LoadBalancer support

## Step 2: Configure Proxmox Rsyslog

SSH into each Proxmox host and configure rsyslog:

### On Proxmox Host (nipogi):

```bash
# SSH to nipogi
ssh root@192.168.68.X  # Replace with nipogi IP

# Create rsyslog config for Vector
cat > /etc/rsyslog.d/50-vector.conf <<'EOF'
# Send all syslog to Vector Aggregator
# Format: @@ for TCP, @ for UDP
# Vector expects UDP on port 5140

# Forward all logs to Vector
*.* @192.168.68.X:5140  # Replace X with Vector LoadBalancer IP

# Optional: Add hostname to each message
$ActionForwardDefaultTemplate RSYSLOG_SyslogProtocol23Format
EOF

# Restart rsyslog
systemctl restart rsyslog

# Verify rsyslog is running
systemctl status rsyslog

# Test by generating a log
logger -t test-proxmox "Test message from nipogi to Vector"
```

### On Proxmox Host (minisforum):

```bash
# SSH to minisforum
ssh root@192.168.68.Y  # Replace with minisforum IP

# Create rsyslog config for Vector
cat > /etc/rsyslog.d/50-vector.conf <<'EOF'
# Send all syslog to Vector Aggregator
*.* @192.168.68.X:5140  # Replace X with Vector LoadBalancer IP
$ActionForwardDefaultTemplate RSYSLOG_SyslogProtocol23Format
EOF

# Restart rsyslog
systemctl restart rsyslog

# Test
logger -t test-proxmox "Test message from minisforum to Vector"
```

## Step 3: Verify in Kibana

After configuring rsyslog:

1. Wait 30 seconds for logs to flow
2. Open Kibana: http://localhost:5601
3. Go to **Discover**
4. Select Data View: **"Proxmox - Nipogi Host"** or **"Proxmox - Minisforum Host"**
5. You should see logs with:
   - `data_stream.namespace` = "nipogi" or "minisforum"
   - `service.name` = "proxmox"
   - `proxmox_hostname` = "nipogi" or "minisforum"

### Example Kibana Query:

```
data_stream.namespace: "nipogi"
```

or

```
service.name: "proxmox" AND proxmox_hostname: "minisforum"
```

## Step 4: Alternative - NodePort Access

If Vector Aggregator doesn't have a LoadBalancer, use NodePort:

```bash
# Get NodePort
kubectl get svc -n elastic-system vector-aggregator -o jsonpath='{.spec.ports[?(@.name=="syslog")].nodePort}'

# Example output: 31234

# Then configure Proxmox to use ANY worker node IP:
# *.* @192.168.68.103:31234  # worker-1 IP + NodePort
```

## Troubleshooting

### No logs appearing in Kibana?

1. **Check Vector Aggregator Logs**:
```bash
kubectl logs -n elastic-system -l app.kubernetes.io/name=vector,app.kubernetes.io/component=aggregator --tail=50
```

Look for: `source{component_id=proxmox_syslog}` messages

2. **Check Proxmox rsyslog**:
```bash
# On Proxmox host
tail -f /var/log/syslog | grep rsyslogd

# Check if rsyslog is forwarding
netstat -an | grep 5140
```

3. **Test UDP connectivity**:
```bash
# From Proxmox host
echo "test" | nc -u -w1 192.168.68.X 5140  # Replace X with Vector IP
```

4. **Check Vector Service**:
```bash
kubectl get svc -n elastic-system vector-aggregator
kubectl describe svc -n elastic-system vector-aggregator
```

### Data Stream not created?

Vector will only create the data stream when the first log arrives. Make sure:
- Rsyslog is forwarding (`logger` test command)
- Vector Aggregator can receive UDP 5140
- Hostname extraction is working in Vector config

## Expected Data Streams

After successful setup, you should see these data streams in Elasticsearch:

- `logs-proxmox.critical-nipogi`
- `logs-proxmox.warn-nipogi`
- `logs-proxmox.info-nipogi`
- `logs-proxmox.critical-minisforum`
- `logs-proxmox.warn-minisforum`
- `logs-proxmox.info-minisforum`

## Security Notes

- Syslog over UDP is **not encrypted**
- Only use within trusted LAN
- For production, consider:
  - TLS encryption (rsyslog + Vector TLS)
  - VPN tunnel (Tailscale/WireGuard)
  - Firewall rules to restrict source IPs
