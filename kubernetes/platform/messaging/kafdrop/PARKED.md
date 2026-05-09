# Kafdrop — PARKED

**Status:** Folder existiert, NICHT in `platform/messaging/kustomization.yaml`. Kafka-Topic-UI.

## Warum entfernt

- Kafdrop war als Topic-Browser gedacht
- Stattdessen: Strimzi-Operator + Apicurio Schema-Registry (deployed separat)
- Topic-Inspection via `kafka-console-consumer.sh` aus Strimzi-Pod

## Restore

```bash
# platform/messaging/kustomization.yaml: + - kafdrop/application.yaml
```
