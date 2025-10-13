# Schema Registry - TEMPORARILY DISABLED

**Status**: Disabled (2025-10-13)
**Reason**: Bitnami Helm chart broken (discontinued free Docker images Aug 2025)

---

## Problem

Bitnami discontinued all free Docker images on **August 28th, 2025**:
- `docker.io/bitnami/schema-registry` → DEAD (only 1 broken tag remains)
- Bitnami Helm chart v26.0.5 references non-existent images
- Cannot override to use Confluent images (hardcoded Bitnami entrypoints)

---

## Enterprise Production Solution (TODO)

**Use Confluent for Kubernetes (CFK) Operator** - This is how enterprises run Schema Registry:

### 1. Install CFK Operator

```yaml
# kubernetes/infrastructure/operators/confluent-for-kubernetes/kustomization.yaml
helmCharts:
- name: confluent-for-kubernetes
  repo: https://packages.confluent.io/helm
  version: 0.921.23
  releaseName: confluent-operator
  namespace: confluent
```

### 2. Deploy Schema Registry via CRD

```yaml
# kubernetes/platform/messaging/schema-registry/schemaregistry.yaml
apiVersion: platform.confluent.io/v1beta1
kind: SchemaRegistry
metadata:
  name: schema-registry
  namespace: kafka
spec:
  replicas: 1
  image:
    application: confluentinc/cp-schema-registry:8.0.2

  # Connect to Strimzi Kafka
  dependencies:
    kafka:
      bootstrapEndpoint: my-cluster-kafka-bootstrap:9092

  # Storage
  dataVolumeCapacity: 2Gi
  storageClass:
    name: rook-ceph-block-enterprise

  # Resources
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

### 3. Benefits

- ✅ Official Confluent solution
- ✅ Native Kubernetes CRDs (GitOps-ready)
- ✅ Automatic upgrades via operator
- ✅ Production-grade HA and scaling
- ✅ Integrated monitoring and metrics
- ✅ Works with any Kafka (including Strimzi)

---

## Alternative: Manual Deployment (Not Recommended)

If you need Schema Registry NOW without operator:

```bash
kubectl run schema-registry \
  --image=confluentinc/cp-schema-registry:8.0.2 \
  --env="SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://my-cluster-kafka-bootstrap:9092" \
  --env="SCHEMA_REGISTRY_HOST_NAME=schema-registry" \
  --env="SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081" \
  -n kafka

kubectl expose pod schema-registry --port=8081 -n kafka
```

**WARNING**: This is NOT production-ready (no HA, no persistence, no monitoring).

---

## References

- **Confluent for Kubernetes**: https://docs.confluent.io/operator/current/overview.html
- **Schema Registry Docs**: https://docs.confluent.io/platform/current/schema-registry/index.html
- **Bitnami Migration Issue**: https://github.com/bitnami/containers/issues/83267

---

**Next Steps**: Install CFK Operator when you have time for proper production setup.
