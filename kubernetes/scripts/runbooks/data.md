# Daten

| Cluster | Namespace | Instanzen |
|---|---|---|
| drova-postgres | drova | 3 |
| keycloak-db | keycloak | 1 |
| n8n-postgres | n8n-prod | 1 |

Kafka: `drova-kafka` in `drova`, 3 Broker + 3 KRaft-Controller, Topics mit Replikationsfaktor 3.

## CnpgPrimaryDown

Ein CNPG-Cluster hat seit 2 min keinen Primary, der Traffic annimmt.

```bash
kubectl cnpg status <cluster> -n <ns>
kubectl -n <ns> get pods -l cnpg.io/cluster=<cluster> -o wide
kubectl -n <ns> logs <pod> -c postgres --tail 50
```

- drova-postgres (3 Instanzen): CNPG schwenkt selbst um. Hängt es, eine gesunde Replica befördern:
  ```bash
  kubectl cnpg promote <cluster> <instanz> -n <ns>
  ```
- keycloak-db und n8n-postgres haben nur eine Instanz, es gibt nichts zu befördern. Pod und PVC prüfen, notfalls aus Backup wiederherstellen.
- PVC voll → [PVCCriticallyFull](storage.md#pvccriticallyfull)

## CNPGClusterHACritical

Der Primary läuft, aber kein Standby streamt mehr. Fällt der Primary jetzt aus, gibt es kein Failover-Ziel.

```bash
kubectl cnpg status <cluster> -n <ns>
kubectl -n <ns> get pods -l cnpg.io/cluster=<cluster> -o wide
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -20
```

- Replica hängt in Pending oder CrashLoop: Events und PVC prüfen. CNPG baut die Replica selbst neu auf, sobald der Pod laufen kann.
- Gilt nur für Cluster mit mehr als einer Instanz.

## CNPGClusterHAWarning

Nur noch ein Standby streamt. Ein weiterer Ausfall → [CNPGClusterHACritical](#cnpgclusterhacritical), gleiche Befehle.

## CNPGBackupStale

Seit 25 h kein erfolgreiches Backup. CNPG wiederholt eine fehlgeschlagene ScheduledBackup nicht, das RPO bleibt bis zum nächsten Cron-Lauf verletzt.

```bash
kubectl -n <ns> get backups.postgresql.cnpg.io --sort-by=.metadata.creationTimestamp | tail -5
kubectl -n <ns> get scheduledbackups.postgresql.cnpg.io
kubectl -n <ns> describe backups.postgresql.cnpg.io <backup> | grep -iA5 -E "phase|error"
```

Von Hand nachholen:
```bash
kubectl cnpg backup <cluster> -n <ns> -m plugin --plugin-name barman-cloud.cloudnative-pg.io
```

- `completed` heißt nicht wiederherstellbar. Ein Backup vom Standby bei ruhender DB archiviert sein `endWal` nie:
  ```bash
  kubectl -n <ns> get backups.postgresql.cnpg.io <backup> -o jsonpath='{.status.endWal}{"\n"}'
  kubectl -n <ns> exec <primary> -c postgres -- psql -U postgres -At -c "SELECT last_archived_wal FROM pg_stat_archiver;"
  ```
  `endWal` größer als `last_archived_wal` → nicht wiederherstellbar.

## KafkaOfflinePartitions

Partitionen ohne Leader. Sie sind weder les- noch schreibbar.

```bash
kubectl -n drova get kafka drova-kafka -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
kubectl -n drova get pods -l strimzi.io/cluster=drova-kafka -o wide
kubectl -n drova logs drova-kafka-controller-3 --tail 50
```
```promql
sum by (topic) (kafka_cluster_partition_underreplicated{namespace="drova"})
min by (topic) (kafka_cluster_partition_insyncreplicascount{namespace="drova"})
```

- Offline heißt: alle Replikas im ISR sind weg. War der ISR vorher schon geschrumpft, reicht ein toter Broker. Zuerst die Nodes der Broker prüfen, oft liegen mehrere auf demselben Host.
- KRaft-Quorum weg (Controller-Pods nicht Ready) → keine Leader-Wahl, egal wie viele Broker laufen.
