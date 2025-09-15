#!/bin/bash
# 🚀 COMPREHENSIVE TALOS LOGGING DEPLOYMENT SCRIPT
# Deploys dual-index EFK architecture with complete Talos monitoring
# 
# ARCHITECTURE:
# FluentBit (privileged) -> Fluentd (comprehensive) -> Elasticsearch -> Kibana
# 
# INDICES CREATED:
# - kubernetes-logs-YYYY.MM.DD -> All Kubernetes pod/container logs
# - talos-logs-YYYY.MM.DD -> ALL Talos host logs (etcd, kube-apiserver, kubelet, containerd, kernel, machine services)

set -e

KUBECONFIG="/Users/timour/Desktop/kubecraft/mealie/homelabtm/taloshomelab/talos-homelab-scratch/tofu/output/kube-config.yaml"

echo "🔧 Deploying Comprehensive Talos Logging Architecture..."
echo "📊 This will collect EVERYTHING from Talos: etcd, kube-apiserver, kubelet, containerd, kernel logs, machine services, systemd"
echo

# Step 1: Apply comprehensive FluentBit configuration
echo "1️⃣ Applying comprehensive Talos FluentBit configuration..."
kubectl --kubeconfig="$KUBECONFIG" apply -f fluent-bit-comprehensive-talos.yaml
echo

# Step 2: Delete existing FluentBit DaemonSet to force recreation
echo "2️⃣ Removing existing FluentBit DaemonSet..."
kubectl --kubeconfig="$KUBECONFIG" delete daemonset fluent-bit -n elastic-system --ignore-not-found --force --grace-period=0
echo

# Step 3: Apply comprehensive privileged FluentBit DaemonSet
echo "3️⃣ Deploying comprehensive privileged FluentBit DaemonSet..."
kubectl --kubeconfig="$KUBECONFIG" apply -f fluent-bit-comprehensive-privileged.yaml
echo

# Step 4: Delete existing Fluentd deployment
echo "4️⃣ Removing existing Fluentd deployments..."
kubectl --kubeconfig="$KUBECONFIG" delete deployment -n elastic-system -l app.kubernetes.io/name=fluentd --ignore-not-found --force --grace-period=0
echo

# Step 5: Apply comprehensive Fluentd configuration
echo "5️⃣ Deploying comprehensive Talos Fluentd..."
kubectl --kubeconfig="$KUBECONFIG" apply -f fluentd-comprehensive-talos.yaml
echo

# Step 6: Wait for deployments to be ready
echo "6️⃣ Waiting for FluentBit DaemonSet to be ready..."
kubectl --kubeconfig="$KUBECONFIG" rollout status daemonset fluent-bit -n elastic-system --timeout=120s
echo

echo "7️⃣ Waiting for Fluentd deployment to be ready..."
kubectl --kubeconfig="$KUBECONFIG" rollout status deployment fluentd-comprehensive-talos -n elastic-system --timeout=120s
echo

# Step 7: Verify deployment
echo "8️⃣ Verifying comprehensive Talos logging deployment..."
echo
echo "FluentBit DaemonSet status:"
kubectl --kubeconfig="$KUBECONFIG" get daemonset fluent-bit -n elastic-system -o wide
echo
echo "Fluentd deployment status:"
kubectl --kubeconfig="$KUBECONFIG" get deployment fluentd-comprehensive-talos -n elastic-system -o wide
echo
echo "Service status:"
kubectl --kubeconfig="$KUBECONFIG" get svc fluentd -n elastic-system -o wide
echo

echo "🎉 COMPREHENSIVE TALOS LOGGING DEPLOYMENT COMPLETE!"
echo
echo "📊 LOG COLLECTION SOURCES:"
echo "   • Kubernetes pod/container logs -> kubernetes-logs-*"
echo "   • Talos kernel logs (kmsg, dmesg) -> talos-logs-*"
echo "   • etcd logs (CRITICAL) -> talos-logs-*"
echo "   • kube-apiserver audit logs -> talos-logs-*"
echo "   • kubelet logs -> talos-logs-*"
echo "   • containerd logs -> talos-logs-*"
echo "   • machine service logs -> talos-logs-*"
echo "   • systemd service logs -> talos-logs-*"
echo
echo "🔍 NEXT STEPS:"
echo "   1. Generate test logs to verify collection"
echo "   2. Check Elasticsearch indices for talos-logs-* creation"
echo "   3. Access Kibana to configure index patterns"
echo
echo "🌐 ACCESS POINTS:"
echo "   • Kibana: http://localhost:5601 (if port-forward active)"
echo "   • ArgoCD: http://localhost:8080 (if port-forward active)"