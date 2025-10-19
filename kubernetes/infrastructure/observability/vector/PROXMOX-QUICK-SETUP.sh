#!/bin/bash
# Proxmox Syslog Quick Setup for Vector Integration
# Run this script on EACH Proxmox host (nipogi, minisforum)

set -e

echo "======================================"
echo "Proxmox → Vector Syslog Setup"
echo "======================================"
echo ""

# Vector LoadBalancer IP (from Kubernetes)
VECTOR_IP="192.168.68.151"
VECTOR_PORT="514"

echo "📡 Vector Aggregator: ${VECTOR_IP}:${VECTOR_PORT}"
echo ""

# Get hostname
HOSTNAME=$(hostname)
echo "🖥️  Configuring host: ${HOSTNAME}"
echo ""

# Backup existing rsyslog config
if [ -f /etc/rsyslog.d/50-vector.conf ]; then
    echo "⚠️  Backing up existing config..."
    cp /etc/rsyslog.d/50-vector.conf /etc/rsyslog.d/50-vector.conf.bak.$(date +%Y%m%d-%H%M%S)
fi

# Create rsyslog config for Vector
echo "📝 Creating /etc/rsyslog.d/50-vector.conf..."
cat > /etc/rsyslog.d/50-vector.conf <<EOF
# ═══════════════════════════════════════════════════════════════
# Vector Syslog Integration
# Send all Proxmox logs to Elasticsearch via Vector Aggregator
# ═══════════════════════════════════════════════════════════════

# Forward all logs to Vector
# @ = UDP, @@ = TCP
# Vector expects UDP on port 514 (standard syslog)
*.* @${VECTOR_IP}:${VECTOR_PORT}

# Use RFC5424 format (includes hostname)
\$ActionForwardDefaultTemplate RSYSLOG_SyslogProtocol23Format

# Optional: Reduce local logging verbosity (save disk space)
# Uncomment if you don't need local logs (Vector has them all)
# *.info;mail.none;authpriv.none;cron.none /var/log/messages
EOF

echo "✅ Config created!"
echo ""

# Restart rsyslog
echo "🔄 Restarting rsyslog..."
systemctl restart rsyslog

# Check status
if systemctl is-active --quiet rsyslog; then
    echo "✅ rsyslog is running!"
else
    echo "❌ ERROR: rsyslog failed to start!"
    echo "Check logs: journalctl -u rsyslog -n 50"
    exit 1
fi

echo ""
echo "🧪 Testing syslog forwarding..."

# Generate test log
logger -t proxmox-vector-test "🚀 Test message from ${HOSTNAME} to Vector Aggregator at ${VECTOR_IP}:${VECTOR_PORT}"

echo ""
echo "======================================"
echo "✅ Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Wait 30 seconds for logs to reach Elasticsearch"
echo "2. Open Kibana: http://localhost:5601"
echo "3. Go to Discover"
echo "4. Select Data View: 'Proxmox - ${HOSTNAME}'"
echo "5. Search for: message: \"proxmox-vector-test\""
echo ""
echo "Expected data stream:"
echo "  - logs-proxmox.info-${HOSTNAME}"
echo ""
echo "Troubleshooting:"
echo "  - Check rsyslog: tail -f /var/log/syslog | grep rsyslog"
echo "  - Test connectivity: echo 'test' | nc -u -w1 ${VECTOR_IP} ${VECTOR_PORT}"
echo "  - View this script's test log: journalctl -t proxmox-vector-test"
echo ""
