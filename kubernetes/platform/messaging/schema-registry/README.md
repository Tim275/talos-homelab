# Schema Registry - Confluent for Kubernetes (CFK)

**Status**: Production-ready (2025-10-13)
**Implementation**: Confluent for Kubernetes (CFK) Operator + CRD
**Use Case**: Protobuf/Avro schema management for gRPC (Golang/Rust/C++)

---

## Why CFK Operator?

Previous Bitnami Helm chart was discontinued (Aug 2025). CFK is the **enterprise-grade solution**:
-  Native Kubernetes CRDs (GitOps-ready)
-  Official Confluent solution
-  Automatic upgrades via operator
-  Production-grade HA and scaling
-  Integrated monitoring (Prometheus)
-  Works with any Kafka (including Strimzi)

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ ArgoCD (GitOps)                                          │
│ - infrastructure/operators/confluent-for-kubernetes      │
│ - platform/messaging/schema-registry                     │
└──────────────────┬───────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────┐
│ Confluent for Kubernetes Operator (namespace: confluent) │
│ - Watches SchemaRegistry CRDs                            │
│ - Manages lifecycle (create/update/scale)                │
└──────────────────┬───────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────┐
│ SchemaRegistry CRD (namespace: kafka)                    │
│ - Confluent official image (cp-schema-registry:7.8.0)    │
│ - Connects to Strimzi Kafka                              │
│ - Persistent storage (Rook Ceph)                         │
│ - Prometheus metrics enabled                             │
└──────────────────┬───────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────┐
│ Schema Registry Service                                  │
│ - HTTP API: :8081                                        │
│ - Protobuf/Avro/JSON Schema support                      │
│ - Schema validation & versioning                         │
└──────────────────────────────────────────────────────────┘
```

## Deployment Steps (Already Configured!)

### 1. CFK Operator Installed
```
kubernetes/infrastructure/operators/confluent-for-kubernetes/
├── application.yaml       # ArgoCD Application
├── kustomization.yaml     # Helm chart config
├── namespace.yaml         # confluent namespace
└── values.yaml            # Helm values
```

### 2. Schema Registry CRD Deployed
```
kubernetes/platform/messaging/schema-registry/
├── schemaregistry.yaml    # CFK CRD
├── servicemonitor.yaml    # Prometheus scraping
└── kustomization.yaml     # Kustomize config
```

### 3. Protobuf Support

Schema Registry supports Protobuf **out-of-the-box**! No extra configuration needed.

**Supported formats:**
-  Protobuf (for gRPC)
-  Avro
-  JSON Schema

---

## Usage Examples

### Register Protobuf Schema (gRPC)

```bash
# Example: Register a Protobuf schema
curl -X POST http://schema-registry.kafka.svc.cluster.local:8081/subjects/user-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{
    "schemaType": "PROTOBUF",
    "schema": "syntax = \"proto3\"; message User { string name = 1; int32 age = 2; }"
  }'
```

### List All Schemas

```bash
curl http://schema-registry.kafka.svc.cluster.local:8081/subjects
```

### Get Schema Version

```bash
curl http://schema-registry.kafka.svc.cluster.local:8081/subjects/user-value/versions/latest
```

### Golang gRPC Integration

```go
import (
    "github.com/riferrei/srclient"
)

// Connect to Schema Registry
client := srclient.CreateSchemaRegistryClient("http://schema-registry.kafka.svc.cluster.local:8081")

// Register Protobuf schema
schema, err := client.CreateSchema("user-value", protoSchema, srclient.Protobuf)
```

### Rust gRPC Integration

```rust
use schema_registry_converter::async_impl::schema_registry::SrSettings;

let sr_settings = SrSettings::new(
    "http://schema-registry.kafka.svc.cluster.local:8081".to_string()
);
```

---

## Monitoring

Schema Registry metrics are automatically scraped by Prometheus via ServiceMonitor.

**Check metrics:**
```bash
kubectl port-forward -n kafka svc/schema-registry 8081:8081
curl http://localhost:8081/metrics
```

**Grafana Dashboard:** Import dashboard ID `11777` (Confluent Schema Registry)

---

## Scaling for Production

```bash
# Scale to 3 replicas for HA
kubectl edit schemaregistry schema-registry -n kafka
# Change: spec.replicas: 3
```

---

## References

- **Confluent for Kubernetes**: https://docs.confluent.io/operator/current/overview.html
- **Schema Registry API**: https://docs.confluent.io/platform/current/schema-registry/develop/api.html
- **Protobuf Support**: https://docs.confluent.io/platform/current/schema-registry/serdes-develop/serdes-protobuf.html
- **gRPC Examples**: https://github.com/confluentinc/confluent-kafka-go

---

**Status**: Ready for Protobuf/gRPC workloads with Golang/Rust/C++! 
