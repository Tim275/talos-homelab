# Apache Druid - Enterprise Setup Guide

Enterprise-Grade Druid Cluster mit DataInfra Operator auf Kubernetes.

## Architektur-Übersicht

```
                                    INTERNET
                                        │
                                   HTTPRoute
                                        │
                              ┌─────────▼─────────┐
                              │   OAuth2-Proxy    │
                              │   (OIDC Auth)     │
                              └─────────┬─────────┘
                                        │
┌───────────────────────────────────────┼───────────────────────────────────────┐
│ DRUID NAMESPACE                       │                                       │
│                              ┌────────▼────────┐                              │
│                              │     Router      │                              │
│                              │    (8888)       │                              │
│                              └────────┬────────┘                              │
│                                       │                                       │
│         ┌─────────────────────────────┼─────────────────────────────┐         │
│         │                             │                             │         │
│  ┌──────▼──────┐              ┌───────▼───────┐              ┌──────▼──────┐  │
│  │ Coordinator │              │    Broker     │              │ Historical  │  │
│  │   (8081)    │              │    (8082)     │              │   (8083)    │  │
│  │ + Overlord  │              └───────────────┘              └─────────────┘  │
│  └──────┬──────┘                                                              │
│         │                                                                     │
│  ┌──────▼──────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐  │
│  │MiddleManager│     │  ZooKeeper  │     │ PostgreSQL  │     │  Rook-Ceph  │  │
│  │   (8091)    │     │   (2181)    │     │   (5432)    │     │  S3 (Deep)  │  │
│  │  + Peons    │     └─────────────┘     └─────────────┘     └─────────────┘  │
│  └─────────────┘                                                              │
│                                                                               │
│  ══════════════════════════════════════════════════════════════════════════   │
│  SECURITY LAYERS:                                                             │
│  • Basic Security Authentication (admin + druid_system)                       │
│  • NetworkPolicies (Ingress - Zero Trust)                                     │
│  • CiliumNetworkPolicies (Egress Control)                                     │
│  • Kafka mTLS (externe Kommunikation)                                         │
│  • Pod Anti-Affinity (HA Distribution)                                        │
│  • PodDisruptionBudgets (Rolling Updates)                                     │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Enterprise Features Checklist

| Feature | Beschreibung | Datei |
|---------|--------------|-------|
| Basic Security | Authentication + Authorization | `druid-cluster.yaml` |
| NetworkPolicies | Ingress Zero Trust | `network-policies.yaml` |
| CiliumNetworkPolicies | Egress Control | `cilium-network-policies.yaml` |
| Kafka mTLS | Externe Verschlüsselung | `druid-cluster.yaml` + `sealed-kafka-mtls.yaml` |
| Anti-Affinity | Pod Distribution | `druid-cluster.yaml` |
| PodDisruptionBudgets | Rolling Updates | `pod-disruption-budgets.yaml` |
| Security Context | Non-root, seccomp | `druid-cluster.yaml` |
| SealedSecrets | Verschlüsselte Credentials | `sealed-*.yaml` |

---

## Prerequisites

- Kubernetes Cluster mit Cilium CNI
- DataInfra Druid Operator installiert
- Sealed Secrets Controller
- Cert-Manager (für TLS Zertifikate)
- Strimzi Kafka Operator (für Kafka Integration)
- Rook-Ceph (für Deep Storage)
- CNPG Operator (für PostgreSQL)

---

## Step-by-Step Anleitung

### Step 1: Namespace erstellen

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: druid
  labels:
    kubernetes.io/metadata.name: druid
```

### Step 2: SealedSecrets erstellen

#### 2.1 PostgreSQL Credentials

```bash
kubectl create secret generic druid-postgres-credentials \
  --namespace=druid \
  --from-literal=username="druid" \
  --from-literal=password="$(openssl rand -base64 24)" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace=sealed-secrets --format yaml \
  > sealed-postgres-credentials.yaml
```

#### 2.2 Basic Auth Credentials (Admin + System User)

```bash
kubectl create secret generic druid-basic-auth \
  --namespace=druid \
  --from-literal=admin-password="$(openssl rand -base64 24)" \
  --from-literal=druid-system-password="$(openssl rand -base64 24)" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace=sealed-secrets --format yaml \
  > sealed-druid-basic-auth.yaml
```

#### 2.3 Deep Storage (S3) Credentials

```bash
# Erst ObjectBucketClaim erstellen, dann Credentials auslesen
kubectl create secret generic druid-deep-storage \
  --namespace=druid \
  --from-literal=AWS_ACCESS_KEY_ID="<access-key>" \
  --from-literal=AWS_SECRET_ACCESS_KEY="<secret-key>" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace=sealed-secrets --format yaml \
  > sealed-deep-storage.yaml
```

#### 2.4 Kafka mTLS (Strimzi KafkaUser)

```bash
# KafkaUser erstellt automatisch Secrets - diese dann sealen
kubectl get secret druid-kafka-user -n kafka -o yaml | \
  sed 's/namespace: kafka/namespace: druid/' | \
  kubeseal --controller-namespace=sealed-secrets --format yaml \
  > sealed-kafka-mtls.yaml
```

### Step 3: PostgreSQL Cluster (CNPG)

```yaml
# postgres-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: druid-postgres
  namespace: druid
spec:
  instances: 1
  storage:
    size: 10Gi
    storageClass: rook-ceph-block-enterprise
  bootstrap:
    initdb:
      database: druid
      owner: druid
      secret:
        name: druid-postgres-credentials
```

### Step 4: Druid Cluster mit Enterprise Features

```yaml
# druid-cluster.yaml
apiVersion: "druid.apache.org/v1alpha1"
kind: "Druid"
metadata:
  name: druid
  namespace: druid
spec:
  image: apache/druid:30.0.1
  startScript: /druid.sh

  # Security Context (non-root, restricted PSS compliant)
  securityContext:
    fsGroup: 1000
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault

  containerSecurityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault

  # Kafka mTLS Certificates
  volumes:
    - name: kafka-mtls-certs
      secret:
        secretName: druid-kafka-mtls

  volumeMounts:
    - name: kafka-mtls-certs
      mountPath: /opt/druid/kafka-certs
      readOnly: true

  common.runtime.properties: |
    # ============================================
    # ZOOKEEPER
    # ============================================
    druid.zk.service.host=druid-zookeeper:2181
    druid.zk.paths.base=/druid

    # ============================================
    # METADATA STORE (PostgreSQL)
    # ============================================
    druid.metadata.storage.type=postgresql
    druid.metadata.storage.connector.connectURI=jdbc:postgresql://druid-postgres-rw.druid.svc:5432/druid
    druid.metadata.storage.connector.user=${env:DRUID_METADATA_USER}
    druid.metadata.storage.connector.password=${env:DRUID_METADATA_PASSWORD}

    # ============================================
    # DEEP STORAGE (Rook-Ceph S3)
    # ============================================
    druid.storage.type=s3
    druid.storage.bucket=${env:DRUID_S3_BUCKET}
    druid.storage.baseKey=segments
    druid.s3.accessKey=${env:AWS_ACCESS_KEY_ID}
    druid.s3.secretKey=${env:AWS_SECRET_ACCESS_KEY}
    druid.s3.endpoint.url=http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80
    druid.s3.enablePathStyleAccess=true

    # ============================================
    # EXTENSIONS
    # ============================================
    druid.extensions.loadList=["druid-kafka-indexing-service","druid-datasketches","druid-multi-stage-query","postgresql-metadata-storage","druid-s3-extensions","prometheus-emitter","druid-basic-security"]

    # ============================================
    # NETWORK SECURITY
    # ============================================
    druid.enablePlaintextPort=true
    druid.enableTlsPort=false

    # ============================================
    # BASIC SECURITY (Authentication + Authorization)
    # ============================================
    druid.auth.authenticatorChain=["BasicMetadataAuthenticator"]
    druid.auth.authenticator.BasicMetadataAuthenticator.type=basic
    druid.auth.authenticator.BasicMetadataAuthenticator.credentialsValidator.type=metadata
    druid.auth.authenticator.BasicMetadataAuthenticator.skipOnFailure=false
    druid.auth.authenticator.BasicMetadataAuthenticator.authorizerName=BasicMetadataAuthorizer
    druid.auth.authenticator.BasicMetadataAuthenticator.initialAdminPassword=${env:DRUID_ADMIN_PASSWORD}
    druid.auth.authenticator.BasicMetadataAuthenticator.initialInternalClientPassword=${env:DRUID_SYSTEM_PASSWORD}

    # Escalator (internal cluster communication)
    druid.escalator.type=basic
    druid.escalator.internalClientUsername=druid_system
    druid.escalator.internalClientPassword=${env:DRUID_SYSTEM_PASSWORD}
    druid.escalator.authorizerName=BasicMetadataAuthorizer

    # Authorizer
    druid.auth.authorizers=["BasicMetadataAuthorizer"]
    druid.auth.authorizer.BasicMetadataAuthorizer.type=basic

    # ============================================
    # PROMETHEUS METRICS
    # ============================================
    druid.emitter=prometheus
    druid.emitter.prometheus.port=9090
    druid.emitter.prometheus.strategy=exporter

  # Environment Variables from Secrets
  env:
    - name: DRUID_METADATA_USER
      valueFrom:
        secretKeyRef:
          name: druid-postgres-credentials
          key: username
    - name: DRUID_METADATA_PASSWORD
      valueFrom:
        secretKeyRef:
          name: druid-postgres-credentials
          key: password
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: druid-deep-storage
          key: AWS_ACCESS_KEY_ID
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: druid-deep-storage
          key: AWS_SECRET_ACCESS_KEY
    - name: DRUID_S3_BUCKET
      valueFrom:
        configMapKeyRef:
          name: druid-deep-storage
          key: BUCKET_NAME
    - name: DRUID_ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: druid-basic-auth
          key: admin-password
    - name: DRUID_SYSTEM_PASSWORD
      valueFrom:
        secretKeyRef:
          name: druid-basic-auth
          key: druid-system-password

  # ============================================
  # NODE CONFIGURATIONS (mit Anti-Affinity)
  # ============================================
  nodes:
    coordinators:
      nodeType: coordinator
      druid.port: 8081
      replicas: 1
      # Anti-Affinity: spread across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    nodeSpecUniqueStr: druid-druid-coordinators
                topologyKey: kubernetes.io/hostname
      runtime.properties: |
        druid.service=druid/coordinator
        druid.plaintextPort=8081
        druid.coordinator.asOverlord.enabled=true
        druid.coordinator.asOverlord.overlordService=druid/overlord
      resources:
        requests:
          cpu: 150m
          memory: 896Mi
        limits:
          cpu: 750m
          memory: 1792Mi

    brokers:
      nodeType: broker
      druid.port: 8082
      replicas: 1
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    nodeSpecUniqueStr: druid-druid-brokers
                topologyKey: kubernetes.io/hostname
      runtime.properties: |
        druid.service=druid/broker
        druid.plaintextPort=8082
      resources:
        requests:
          cpu: 150m
          memory: 896Mi
        limits:
          cpu: 750m
          memory: 1792Mi

    historicals:
      nodeType: historical
      druid.port: 8083
      replicas: 1
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    nodeSpecUniqueStr: druid-druid-historicals
                topologyKey: kubernetes.io/hostname
      runtime.properties: |
        druid.service=druid/historical
        druid.plaintextPort=8083
      resources:
        requests:
          cpu: 150m
          memory: 1024Mi
        limits:
          cpu: 750m
          memory: 2048Mi

    middlemanagers:
      nodeType: middleManager
      druid.port: 8091
      replicas: 1
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    nodeSpecUniqueStr: druid-druid-middlemanagers
                topologyKey: kubernetes.io/hostname
      runtime.properties: |
        druid.service=druid/middleManager
        druid.plaintextPort=8091
        druid.worker.capacity=4
        druid.indexer.runner.startPort=8100
      resources:
        requests:
          cpu: 300m
          memory: 2560Mi
        limits:
          cpu: 2000m
          memory: 4608Mi

    routers:
      nodeType: router
      druid.port: 8888
      replicas: 1
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    nodeSpecUniqueStr: druid-druid-routers
                topologyKey: kubernetes.io/hostname
      runtime.properties: |
        druid.service=druid/router
        druid.plaintextPort=8888
        druid.router.managementProxy.enabled=true
      resources:
        requests:
          cpu: 50m
          memory: 256Mi
        limits:
          cpu: 300m
          memory: 512Mi
```

### Step 5: NetworkPolicies (Ingress - Zero Trust)

```yaml
# network-policies.yaml
---
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: druid
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Druid internal communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-druid-internal
  namespace: druid
spec:
  podSelector:
    matchLabels:
      druid_cr: druid
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              druid_cr: druid
      ports:
        - protocol: TCP
          port: 8081
        - protocol: TCP
          port: 8082
        - protocol: TCP
          port: 8083
        - protocol: TCP
          port: 8091
        - protocol: TCP
          port: 8888
        # Peon ports
        - protocol: TCP
          port: 8100
        - protocol: TCP
          port: 8101
        - protocol: TCP
          port: 8102
        - protocol: TCP
          port: 8103
    # Prometheus scraping
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 9090

---
# ZooKeeper
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-zookeeper
  namespace: druid
spec:
  podSelector:
    matchLabels:
      app: druid-zookeeper
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              druid_cr: druid
      ports:
        - protocol: TCP
          port: 2181

---
# Router from Gateway
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-router-ingress
  namespace: druid
spec:
  podSelector:
    matchLabels:
      nodeSpecUniqueStr: druid-druid-routers
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: gateway
      ports:
        - protocol: TCP
          port: 8888

---
# PostgreSQL
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgres
  namespace: druid
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: druid-postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              druid_cr: druid
      ports:
        - protocol: TCP
          port: 5432
```

### Step 6: CiliumNetworkPolicies (Egress Control)

```yaml
# cilium-network-policies.yaml
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: druid-egress-policy
  namespace: druid
spec:
  endpointSelector:
    matchLabels:
      druid_cr: druid
  egress:
    # DNS
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
    # ZooKeeper
    - toEndpoints:
        - matchLabels:
            app: druid-zookeeper
      toPorts:
        - ports:
            - port: "2181"
              protocol: TCP
    # PostgreSQL
    - toEndpoints:
        - matchLabels:
            cnpg.io/cluster: druid-postgres
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
    # Kafka (Strimzi)
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kafka
            strimzi.io/cluster: kafka
      toPorts:
        - ports:
            - port: "9092"
              protocol: TCP
            - port: "9093"
              protocol: TCP
    # Rook-Ceph S3
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: rook-ceph
            app: rook-ceph-rgw
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
    # Inter-node Druid
    - toEndpoints:
        - matchLabels:
            druid_cr: druid
      toPorts:
        - ports:
            - port: "8081"
              protocol: TCP
            - port: "8082"
              protocol: TCP
            - port: "8083"
              protocol: TCP
            - port: "8091"
              protocol: TCP
            - port: "8888"
              protocol: TCP
            - port: "8100"
              protocol: TCP
            - port: "8101"
              protocol: TCP
            - port: "8102"
              protocol: TCP
            - port: "8103"
              protocol: TCP
            - port: "9090"
              protocol: TCP

---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: postgres-egress-policy
  namespace: druid
spec:
  endpointSelector:
    matchLabels:
      cnpg.io/cluster: druid-postgres
  egress:
    # DNS
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
    # Kubernetes API (required by CNPG)
    - toEntities:
        - kube-apiserver
    # PostgreSQL replication
    - toEndpoints:
        - matchLabels:
            cnpg.io/cluster: druid-postgres
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
```

### Step 7: PodDisruptionBudgets

```yaml
# pod-disruption-budgets.yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-coordinators-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      druid_cr: druid
      nodeSpecUniqueStr: druid-druid-coordinators
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-brokers-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      druid_cr: druid
      nodeSpecUniqueStr: druid-druid-brokers
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-historicals-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      druid_cr: druid
      nodeSpecUniqueStr: druid-druid-historicals
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-middlemanagers-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      druid_cr: druid
      nodeSpecUniqueStr: druid-druid-middlemanagers
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-routers-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      druid_cr: druid
      nodeSpecUniqueStr: druid-druid-routers
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: druid-zookeeper-pdb
  namespace: druid
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: druid-zookeeper
```

### Step 8: Kustomization

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: druid
resources:
  - namespace.yaml
  # SealedSecrets
  - sealed-postgres-credentials.yaml
  - sealed-druid-basic-auth.yaml
  - sealed-kafka-mtls.yaml
  # Database
  - postgres-cluster.yaml
  # Druid
  - druid-cluster.yaml
  # Security
  - network-policies.yaml
  - cilium-network-policies.yaml
  - pod-disruption-budgets.yaml
```

---

## Deployment

```bash
# 1. Apply all resources
kubectl apply -k .

# 2. Watch pods coming up
kubectl get pods -n druid -w

# 3. Verify all pods are ready
kubectl get pods -n druid
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
druid-druid-brokers-0          1/1     Running   0          5m
druid-druid-coordinators-0     1/1     Running   0          5m
druid-druid-historicals-0      1/1     Running   0          5m
druid-druid-middlemanagers-0   1/1     Running   0          5m
druid-druid-routers-0          1/1     Running   0          5m
druid-postgres-1               1/1     Running   0          5m
druid-zookeeper-0              1/1     Running   0          5m
```

---

## Verification

### Authentication prüfen

```bash
# Environment Variables verifizieren
kubectl exec -n druid druid-druid-coordinators-0 -- env | grep -E "DRUID_ADMIN|DRUID_SYSTEM"

# Runtime Properties verifizieren
kubectl exec -n druid druid-druid-coordinators-0 -- \
  cat /opt/druid/conf/druid/cluster/_common/common.runtime.properties | \
  grep -E "auth|escalator"
```

### NetworkPolicies prüfen

```bash
kubectl get networkpolicies -n druid
kubectl get ciliumnetworkpolicies -n druid
```

### PodDisruptionBudgets prüfen

```bash
kubectl get pdb -n druid
```

### Anti-Affinity prüfen

```bash
# Pods sollten auf verschiedenen Nodes sein (bei >1 Replica)
kubectl get pods -n druid -o wide
```

---

## Troubleshooting

### Problem: Pods starten nicht

```bash
# Logs prüfen
kubectl logs -n druid druid-druid-coordinators-0

# Events prüfen
kubectl describe pod -n druid druid-druid-coordinators-0
```

### Problem: PostgreSQL Connection Refused

```bash
# PostgreSQL Status prüfen
kubectl get pods -n druid -l cnpg.io/cluster=druid-postgres

# CiliumNetworkPolicy prüfen (Egress zum API-Server nötig)
kubectl get ciliumnetworkpolicies -n druid postgres-egress-policy -o yaml
```

### Problem: Kafka Tasks starten nicht

```bash
# MiddleManager Logs prüfen
kubectl logs -n druid druid-druid-middlemanagers-0 --tail=50

# Kafka mTLS Secret prüfen
kubectl get secret druid-kafka-mtls -n druid
```

---

## Security Best Practices

1. **Keine TLS intern** - NetworkPolicies isolieren den Traffic
2. **Kafka mTLS** - Externe Kommunikation ist verschlüsselt
3. **Basic Security** - Authentication für alle API-Zugriffe
4. **SealedSecrets** - Keine Klartext-Passwörter im Git
5. **Non-root Containers** - Minimale Privilegien
6. **Egress Control** - Nur erlaubte Verbindungen nach außen

---

## Dateistruktur

```
druid/
├── cluster/
│   ├── namespace.yaml
│   ├── sealed-postgres-credentials.yaml
│   ├── sealed-druid-basic-auth.yaml
│   ├── sealed-kafka-mtls.yaml
│   ├── postgres-cluster.yaml
│   ├── druid-cluster.yaml
│   ├── network-policies.yaml
│   ├── cilium-network-policies.yaml
│   ├── pod-disruption-budgets.yaml
│   └── kustomization.yaml
├── monitoring/
│   ├── servicemonitor.yaml
│   ├── prometheusrule.yaml
│   └── grafana-dashboard.yaml
└── DRUID-ENTERPRISE-SETUP.md  <-- Diese Datei
```
