#!/usr/bin/env bash
# Pre-Strimzi-Upgrade Check
# Run BEFORE: renovate-PR mergen für Strimzi-Operator version-bump
#
# Why: 2026-05-16 disaster — Strimzi 0.51 auto-upgrade hat Kafka 4.0.0 deprecated,
# parallel-broker-delete + falsche election.timeout → 3h+ Cluster down + 504s in Drova-prod.
#
# Captures state + warns about danger-signals BEFORE you touch anything.

set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
SNAP="/tmp/pre-strimzi-${TS}"
mkdir -p "$SNAP"
echo "Snapshot dir: $SNAP"
echo ""

# ─────────────────────────────────────────────────────────────────
# 1) CURRENT STATE SNAPSHOT
# ─────────────────────────────────────────────────────────────────
echo "→ Strimzi-Operator current version"
kubectl get deploy strimzi-cluster-operator -n kafka \
  -o jsonpath='{.spec.template.spec.containers[0].image}' > "$SNAP/strimzi-current.txt" 2>&1
echo "  $(cat $SNAP/strimzi-current.txt)"
echo ""

echo "→ Supported Kafka versions in current operator"
kubectl get deploy strimzi-cluster-operator -n kafka \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="STRIMZI_KAFKA_IMAGES")].value}' \
  > "$SNAP/supported-kafka-versions.txt" 2>&1
cat "$SNAP/supported-kafka-versions.txt"
echo ""

echo "→ Active Kafka clusters + their versions"
kubectl get kafka -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,VERSION:.spec.kafka.version,METADATA:.spec.kafka.metadataVersion \
  --no-headers > "$SNAP/kafka-clusters.txt" 2>&1
cat "$SNAP/kafka-clusters.txt"
echo ""

echo "→ KafkaNodePool details"
kubectl get kafkanodepool -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,ROLES:.spec.roles,REPLICAS:.spec.replicas \
  --no-headers > "$SNAP/kafkanodepools.txt" 2>&1
cat "$SNAP/kafkanodepools.txt"
echo ""

echo "→ Topics + Users snapshot (for restore)"
kubectl get kafkatopic,kafkauser -A -o yaml > "$SNAP/kafka-crs.yaml" 2>&1
echo "  Saved $(grep -c '^---' $SNAP/kafka-crs.yaml) CRs"
echo ""

echo "→ Broker pod-IPs (for quorum verification later)"
kubectl get pod -A -l strimzi.io/kind=Kafka -o wide --no-headers > "$SNAP/kafka-pods.txt" 2>&1
cat "$SNAP/kafka-pods.txt"
echo ""

# ─────────────────────────────────────────────────────────────────
# 2) DANGER-SIGNAL CHECKS
# ─────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────────"
echo "DANGER-SIGNAL CHECKS"
echo "─────────────────────────────────────────────"
DANGER=0

# Check 1: Is target Strimzi version supported by current Kafka version?
TARGET_STRIMZI="${1:-}"
if [ -z "$TARGET_STRIMZI" ]; then
  echo "⚠  Pass target Strimzi version as arg 1, e.g.: $0 0.52.0"
else
  echo "→ Checking compat for target Strimzi $TARGET_STRIMZI..."
  echo "  Strimzi 0.49 supports Kafka 3.9, 4.0"
  echo "  Strimzi 0.50 supports Kafka 4.0"
  echo "  Strimzi 0.51 supports Kafka 4.1.0, 4.1.1  ← drops 4.0!"
  echo "  Strimzi 0.52 supports Kafka 4.1, 4.2     ← drops 4.0!"
  echo ""
  CURRENT_KAFKA=$(awk -F'|' '{print $3}' "$SNAP/kafka-clusters.txt" | tr -d ' ' | sort -u | head -1)
  echo "  Current Kafka version in cluster: $CURRENT_KAFKA"
  echo "  → Manually verify if new Strimzi supports this Kafka version!"
  echo "  → If NOT: must bump Kafka version IN SAME PR + soak in pi-staging first"
fi
echo ""

# Check 2: Election-timeout sane?
echo "→ Election-Timeout sanity"
BAD_ELECTION=$(kubectl get kafka -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} election={.spec.kafka.config.controller\.quorum\.election\.timeout\.ms}{"\n"}{end}' 2>&1 | awk -F= '$2>30000' || true)
if [ -n "$BAD_ELECTION" ]; then
  echo "  ✗ DANGER: election.timeout.ms >30000 — blockt KRaft Leader-Election!"
  echo "$BAD_ELECTION"
  DANGER=$((DANGER+1))
else
  echo "  ✓ election.timeout sane (<=30s)"
fi
echo ""

# Check 3: dual-role node pool warning?
echo "→ Dual-Role NodePool check (deadlock risk in Strimzi 0.51+)"
DUAL=$(kubectl get kafkanodepool -A -o json 2>&1 | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d['items']:
    roles = item['spec'].get('roles', [])
    if 'controller' in roles and 'broker' in roles and item['spec'].get('replicas',1) > 1:
        print(f\"  ✗ {item['metadata']['namespace']}/{item['metadata']['name']} is dual-role with {item['spec']['replicas']} replicas\")
" 2>&1 | grep "✗" || true)
if [ -n "$DUAL" ]; then
  echo "$DUAL"
  echo "  → 2026-05-16 disaster pattern. Recommend split into controller+broker NodePools BEFORE upgrade."
  DANGER=$((DANGER+1))
else
  echo "  ✓ No dual-role multi-replica NodePools found"
fi
echo ""

# Check 4: KRaft Quorum healthy NOW?
echo "→ KRaft Quorum health check"
QUORUM_BAD=0
for ns in $(kubectl get kafka -A -o jsonpath='{.items[*].metadata.namespace}' 2>&1 | tr ' ' '\n' | sort -u); do
  CTRL_PODS=$(kubectl get pods -n $ns -l strimzi.io/controller-role=true --no-headers 2>&1 | wc -l)
  CTRL_READY=$(kubectl get pods -n $ns -l strimzi.io/controller-role=true --no-headers 2>&1 | awk '$2 ~ /^[0-9]+\/[0-9]+$/ {split($2,a,"/"); if(a[1]==a[2] && $3=="Running") c++} END {print c+0}')
  if [ "$CTRL_PODS" -gt 0 ] && [ "$CTRL_READY" -lt "$CTRL_PODS" ]; then
    echo "  ✗ $ns: only $CTRL_READY/$CTRL_PODS controllers ready — DON'T upgrade now"
    QUORUM_BAD=$((QUORUM_BAD+1))
  else
    echo "  ✓ $ns: $CTRL_READY/$CTRL_PODS controllers ready"
  fi
done
[ "$QUORUM_BAD" -gt 0 ] && DANGER=$((DANGER+1))
echo ""

# Check 5: Pause-Reconciliation Reminder
echo "→ Strimzi-Pause-Annotation check"
PAUSED=$(kubectl get kafka -A -o jsonpath='{range .items[?(@.metadata.annotations.strimzi\.io/pause-reconciliation=="true")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>&1)
if [ -z "$PAUSED" ]; then
  echo "  ⚠ NO Kafka cluster is paused. STRONG RECOMMENDATION:"
  echo "    kubectl annotate kafka <name> -n <ns> strimzi.io/pause-reconciliation=true"
  echo "    BEFORE merging the Strimzi-bump PR. Unpause AFTER you verify cluster healthy."
  DANGER=$((DANGER+1))
else
  echo "  ✓ Paused: $PAUSED"
fi
echo ""

# Check 6: Backup exists?
echo "→ Recent backup check (last 24h)"
RECENT=$(kubectl get backup -A --no-headers 2>&1 | awk '$4 ~ /[0-9]+h/ && substr($4,1,length($4)-1)+0 <= 24 || $4 ~ /m$/' | wc -l)
if [ "$RECENT" -lt 1 ]; then
  echo "  ✗ No recent CNPG-Backup found in last 24h"
  DANGER=$((DANGER+1))
else
  echo "  ✓ $RECENT recent backup(s) found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────
# 3) VERDICT
# ─────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────────"
if [ "$DANGER" -eq 0 ]; then
  echo "✓ READY for Strimzi upgrade"
  echo "  Recommended steps:"
  echo "    1. Pause: kubectl annotate kafka drova-kafka -n drova strimzi.io/pause-reconciliation=true"
  echo "    2. Merge renovate-PR with Strimzi-bump"
  echo "    3. Wait for new operator pod stable (kubectl rollout status)"
  echo "    4. Unpause: kubectl annotate kafka drova-kafka -n drova strimzi.io/pause-reconciliation-"
  echo "    5. Watch: kubectl get pods -n drova -l strimzi.io/cluster=drova-kafka -w"
else
  echo "✗ $DANGER danger-signal(s) found — DO NOT UPGRADE until fixed"
fi
echo "─────────────────────────────────────────────"
echo ""
echo "Snapshot saved to: $SNAP"
echo "Restore via: kubectl apply -f $SNAP/kafka-crs.yaml (after disaster)"
exit $DANGER
