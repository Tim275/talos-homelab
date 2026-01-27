# Apache Druid - Real-Time Analytics

## Was ist Apache Druid?

Apache Druid ist eine Real-Time Analytics Datenbank, entwickelt für:
- **Sub-Sekunden Queries** auf Milliarden von Zeilen
- **Real-Time Ingestion** von Streaming-Daten (Kafka)
- **OLAP Workloads** (Online Analytical Processing)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         WO DRUID EINGESETZT WIRD                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Netflix      → Streaming-Metriken, User-Verhalten                              │
│  Airbnb       → Echtzeit-Buchungsanalysen                                       │
│  Twitter/X    → Event-Tracking, Engagement-Metriken                             │
│  Alibaba      → E-Commerce Analytics (Singles Day: 500k Events/Sek)             │
│                                                                                 │
│  Use Cases:   Dashboards, Monitoring, Event Analytics, User Behavior            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Das Problem OHNE Druid

### Szenario: Kafka Microservices (unser Projekt)

```
order-service ──► Kafka ──► payment-service ──► PostgreSQL
                       ──► stock-service   ──► PostgreSQL

Fragen die aufkommen:
├─ "Wie viele Orders pro Stunde?"
├─ "Welche Produkte verkaufen sich am besten?"
├─ "Wie lange dauert eine Saga im Durchschnitt?"
├─ "Warum scheitern 5% der Payments?"
└─ "Welche Kunden haben den höchsten Umsatz?"
```

### Lösungsversuche OHNE Druid:

| Ansatz | Problem |
|--------|---------|
| **PostgreSQL Query** | Langsam bei Millionen Rows, blockiert Transaktionen |
| **Kafka Consumer + Logs** | Keine Aggregationen, kein SQL, schwer zu durchsuchen |
| **Elasticsearch** | Gut für Suche, schlecht für Aggregationen |
| **Data Warehouse (BigQuery)** | Teuer, Batch-orientiert (nicht Real-Time) |

```
PROBLEM: PostgreSQL für Analytics
═════════════════════════════════

SELECT customer_id, COUNT(*), SUM(amount)
FROM orders
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY customer_id
ORDER BY 3 DESC;

→ 10 Millionen Rows
→ 30 Sekunden Query Time
→ Datenbank unter Last
→ Transaktionen blockiert
→ Kein Real-Time (Daten erst nach Commit sichtbar)
```

## Was Druid löst

```
MIT DRUID:
══════════

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Kafka     │────►│   DRUID     │────►│  Dashboard  │
│  (Events)   │     │ (Analytics) │     │  (Grafana)  │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ PostgreSQL  │  ← Bleibt für Transaktionen
                    │ (OLTP)      │
                    └─────────────┘

OLTP (PostgreSQL) = Transaktionen (INSERT, UPDATE, DELETE)
OLAP (Druid)      = Analytics (SELECT mit GROUP BY, SUM, COUNT)
```

| Feature | PostgreSQL | Druid |
|---------|------------|-------|
| Query auf 10M Rows | 30 Sekunden | < 1 Sekunde |
| Real-Time Ingestion | Nach Commit | Sofort (< 1 Sek) |
| Aggregationen | CPU-intensiv | Optimiert (Columnar) |
| Concurrent Queries | Begrenzt | Tausende |
| Use Case | Transaktionen | Analytics |

## Warum Enrichment Service?

### Problem: Roh-Events sind nicht aussagekräftig

```json
// Roh-Event von Kafka (order-service)
{
  "orderId": "O-12345",
  "customerId": "C-789",      ← Wer ist das?
  "productId": "P-456",       ← Welches Produkt?
  "status": "NEW",            ← Saga noch nicht fertig
  "price": 29.99
}
```

**Im Dashboard willst du aber sehen:**
- "Max Mustermann hat Widget Pro bestellt" (nicht "C-789 hat P-456 bestellt")
- "Saga erfolgreich abgeschlossen" (nicht nur "NEW")
- "Verarbeitung dauerte 45ms"

### Lösung: Enrichment Service

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           ENRICHMENT FLOW                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1. RAW EVENT (Kafka: orders)                                                   │
│     { orderId: "O-12345", customerId: "C-789", productId: "P-456" }             │
│                          │                                                      │
│                          ▼                                                      │
│  2. ENRICHMENT SERVICE                                                          │
│     ├─ Customer Lookup: C-789 → "Max Mustermann"                                │
│     ├─ Product Lookup:  P-456 → "Widget Pro"                                    │
│     ├─ Saga Status:     Warten auf Payment + Stock → "COMPLETED"                │
│     └─ Processing Time: System.currentTimeMillis() - startTime                  │
│                          │                                                      │
│                          ▼                                                      │
│  3. ENRICHED EVENT (Kafka: orders-analytics)                                    │
│     {                                                                           │
│       orderId: "O-12345",                                                       │
│       customerId: "C-789",                                                      │
│       customerName: "Max Mustermann",    ← Enriched                             │
│       productId: "P-456",                                                       │
│       productName: "Widget Pro",          ← Enriched                            │
│       sagaStatus: "COMPLETED",            ← Enriched                            │
│       processingTimeMs: 45                ← Enriched                            │
│     }                                                                           │
│                          │                                                      │
│                          ▼                                                      │
│  4. DRUID konsumiert und macht querybar                                         │
│     SELECT customerName, COUNT(*) FROM orders GROUP BY 1                        │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Warum eigener Microservice für Enrichment?

| Grund | Erklärung |
|-------|-----------|
| **Separation of Concerns** | Saga-Logik ≠ Analytics-Logik |
| **Unabhängig skalierbar** | Analytics-Last ≠ Business-Last |
| **Keine Kopplung** | order-service muss nichts von Druid wissen |
| **Testbar** | Enrichment isoliert testbar |
| **Wiederverwendbar** | Gleiche Enrichment-Logik für andere Systeme |

---

## Unser Setup

### Projekt-Struktur

```
Desktop/kafka/sample-spring-kafka-microservices/
├── order-service/       ← Producer + Saga Orchestrator
├── payment-service/     ← Consumer: Zahlung prüfen
├── stock-service/       ← Consumer: Lager reservieren
└── base-domain/         ← Shared Avro Schemas

Manifests: homelabtm/taloshomelab/kubernetes/
├── apps/base/kafka-demo/        ← Kafka Topics
└── platform/data/druid/         ← Druid + Analytics Topics
```

### Event Flow (Unser Projekt)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SAGA + ANALYTICS FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

  POST /orders
       │
       ▼
  ┌─────────────┐    produce     ┌─────────────┐
  │order-service│───────────────►│ orders      │ (Kafka Topic)
  └─────────────┘                └──────┬──────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
            ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
            │order-service│     │payment-svc  │     │stock-service│
            │(Saga Logic) │     │(Balance)    │     │(Reserve)    │
            └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
                   │                   │                   │
                   │ confirm()         │                   │
                   │◄──────────────────┴───────────────────┘
                   │
                   ▼
            ┌─────────────────────────────────────────────────────┐
            │ Enrichment (im Service oder separater MS)           │
            │                                                     │
            │ Order + CustomerName + ProductName + SagaStatus     │
            └──────────────────────┬──────────────────────────────┘
                                   │
                                   ▼
                           ┌───────────────┐
                           │orders-analytics│ (Kafka Topic)
                           └───────┬───────┘
                                   │
                                   ▼
                           ┌───────────────┐
                           │    DRUID      │
                           │               │
                           │ SELECT ...    │
                           │ GROUP BY ...  │
                           └───────────────┘
```

---

## Architektur (Enrichment Flow)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                              DRUID ARCHITEKTUR MIT ENRICHMENT                                │
└─────────────────────────────────────────────────────────────────────────────────────────────┘

  Spring Boot Producer          Kafka (Raw)         Spring Boot Consumer        Kafka (Analytics)      Druid
  ════════════════════         ═══════════         ════════════════════        ═════════════════     ═══════

  ┌─────────────────┐          ┌─────────┐         ┌─────────────────┐         ┌──────────────────┐
  │ order-service   │─produce─►│ orders  │─consume►│ order-service   │─enrich─►│ orders-analytics │──┐
  │ (REST API)      │          └─────────┘         │ (Saga Logic)    │         └──────────────────┘  │
  └─────────────────┘                              └─────────────────┘                               │
                                                           │                                         │
                               ┌─────────┐         ┌───────▼─────────┐         ┌──────────────────┐  │   ┌─────────────┐
  ┌─────────────────┐          │payments │◄────────│ payment-service │─enrich─►│payments-analytics│──┼──►│   DRUID     │
  │ (Saga Response) │◄─────────└─────────┘         │ (Payment Check) │         └──────────────────┘  │   │             │
  └─────────────────┘                              └─────────────────┘                               │   │ Supervisors │
                                                           │                                         │   │ Indexer     │
                               ┌─────────┐         ┌───────▼─────────┐         ┌──────────────────┐  │   │ Historical  │
                               │ stock   │◄────────│ stock-service   │─enrich─►│ stock-analytics  │──┤   │ Broker      │
                               └─────────┘         │ (Stock Reserve) │         └──────────────────┘  │   └─────────────┘
                                                   └─────────────────┘                               │
                                                           │                                         │
                                                           │ Saga Tracking    ┌──────────────────┐  │
                                                           └─────────────────►│ saga-events      │──┘
                                                                              └──────────────────┘
```

---

## Kafka Topics

| Topic | Typ | Producer | Consumer |
|-------|-----|----------|----------|
| `orders` | Raw | order-service (API) | order-service (Saga) |
| `payments` | Raw | Saga | payment-service |
| `stock` | Raw | Saga | stock-service |
| `orders-analytics` | Enriched | order-service | Druid |
| `payments-analytics` | Enriched | payment-service | Druid |
| `stock-analytics` | Enriched | stock-service | Druid |
| `saga-events` | Tracking | All services | Druid |

## Druid Datasources

| Datasource | Kafka Topic | Dimensionen |
|------------|-------------|-------------|
| **orders** | orders-analytics | orderId, customerId, customerName, productId, productName, status, sagaStatus, quantity, price, totalAmount, processingTimeMs |
| **payments** | payments-analytics | paymentId, orderId, customerId, customerName, status, sagaStatus, paymentMethod, paymentProvider, amount, processingTimeMs, failureReason |
| **stock** | stock-analytics | stockId, orderId, productId, productName, warehouseId, warehouseName, status, sagaStatus, quantity, availableStock, reservedStock, processingTimeMs |
| **saga_events** | saga-events | sagaId, orderId, step, service, status, eventType, durationMs, errorMessage, compensating |

---

## Spring Boot Code Beispiel

### AnalyticsEvent DTO

```java
@Data
@Builder
public class OrderAnalyticsEvent {
    private Instant timestamp;
    private String orderId;
    private String customerId;
    private String customerName;      // Enriched
    private String productId;
    private String productName;       // Enriched
    private String status;
    private String sagaStatus;        // Enriched
    private Long quantity;
    private Double price;
    private Double totalAmount;
    private Long processingTimeMs;    // Enriched
}
```

### Analytics Producer Service

```java
@Service
@RequiredArgsConstructor
public class AnalyticsProducer {

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final CustomerRepository customerRepo;
    private final ProductRepository productRepo;

    public void publishOrderAnalytics(Order order, String sagaStatus, long processingTimeMs) {
        Customer customer = customerRepo.findById(order.getCustomerId()).orElse(null);
        Product product = productRepo.findById(order.getProductId()).orElse(null);

        OrderAnalyticsEvent event = OrderAnalyticsEvent.builder()
            .timestamp(Instant.now())
            .orderId(order.getId())
            .customerId(order.getCustomerId())
            .customerName(customer != null ? customer.getName() : "Unknown")
            .productId(order.getProductId())
            .productName(product != null ? product.getName() : "Unknown")
            .status(order.getStatus())
            .sagaStatus(sagaStatus)
            .quantity(order.getQuantity())
            .price(order.getPrice())
            .totalAmount(order.getQuantity() * order.getPrice())
            .processingTimeMs(processingTimeMs)
            .build();

        kafkaTemplate.send("orders-analytics", order.getId(), event);
    }
}
```

### Integration in OrderManageService

```java
// Basierend auf: order-service/src/main/java/pl/piomin/order/service/OrderManageService.java

@Service
@RequiredArgsConstructor
public class OrderManageService {

    private final AnalyticsProducer analyticsProducer;

    public Order confirm(Order orderPayment, Order orderStock) {
        long startTime = System.currentTimeMillis();

        Order.Builder builder = Order.newBuilder()
                .setId(orderPayment.getId())
                .setCustomerId(orderPayment.getCustomerId())
                .setProductId(orderPayment.getProductId())
                .setProductCount(orderPayment.getProductCount())
                .setPrice(orderPayment.getPrice());

        String sagaStatus;
        if ("ACCEPT".equals(orderPayment.getStatus()) &&
                "ACCEPT".equals(orderStock.getStatus())) {
            builder.setStatus("CONFIRMED");
            sagaStatus = "COMPLETED";
        } else if ("REJECT".equals(orderPayment.getStatus()) ||
                "REJECT".equals(orderStock.getStatus())) {
            builder.setStatus("ROLLBACK");
            sagaStatus = "COMPENSATED";
        } else {
            builder.setStatus("REJECTED");
            sagaStatus = "FAILED";
        }

        Order result = builder.build();

        // Analytics Event senden
        analyticsProducer.publishOrderAnalytics(
            result,
            sagaStatus,
            System.currentTimeMillis() - startTime
        );

        return result;
    }
}
```

---

## Beispiel Queries

### Saga Performance
```sql
SELECT
  service,
  status,
  COUNT(*) AS count,
  AVG(durationMs) AS avg_duration_ms,
  MAX(durationMs) AS max_duration_ms
FROM saga_events
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '1' HOUR
GROUP BY 1, 2
ORDER BY 1, 2
```

### Top Kunden (mit Namen!)
```sql
SELECT
  customerName,
  COUNT(*) AS orders,
  SUM(totalAmount) AS revenue
FROM orders
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '24' HOUR
  AND sagaStatus = 'COMPLETED'
GROUP BY 1
ORDER BY 3 DESC
LIMIT 10
```

### Failed Payments Analysis
```sql
SELECT
  failureReason,
  paymentMethod,
  COUNT(*) AS failures,
  SUM(amount) AS lost_revenue
FROM payments
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
  AND sagaStatus = 'FAILED'
GROUP BY 1, 2
ORDER BY 3 DESC
```

---

## Befehle

```bash
# Kafka Topics prüfen
kubectl get kafkatopics -n kafka | grep analytics

# Druid Supervisors prüfen
kubectl exec -n druid druid-router-0 -- \
  wget -qO- http://localhost:8888/druid/indexer/v1/supervisor

# Supervisor Status
kubectl exec -n druid druid-router-0 -- \
  wget -qO- "http://localhost:8888/druid/indexer/v1/supervisor/orders/status"

# SQL Query in Druid ausführen
kubectl exec -n druid druid-router-0 -- \
  wget -qO- --post-data='{"query":"SELECT COUNT(*) FROM orders"}' \
  --header='Content-Type: application/json' \
  http://localhost:8888/druid/v2/sql
```

## Zugriff

| URL | Beschreibung |
|-----|--------------|
| https://druid.timourhomelab.org | Web Console (OAuth2/Keycloak) |
| Grafana Dashboard | Folder: Druid → Druid Overview |

---

## Production Setup

### Deep Storage (Rook-Ceph S3)

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEEP STORAGE ARCHITEKTUR                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Druid Indexer              Rook-Ceph                           │
│  ═══════════════           ══════════════                       │
│                                                                  │
│  ┌─────────────┐           ┌─────────────────────────────────┐  │
│  │ Peon Tasks  │──persist─►│ ObjectBucketClaim:              │  │
│  │ (Segments)  │           │ druid-deep-storage              │  │
│  └─────────────┘           │                                 │  │
│         ▲                  │ Bucket: druid-segments-xxx      │  │
│         │                  │ Endpoint: rook-ceph-rgw-xxx:80  │  │
│  ┌──────┴──────┐           └─────────────────────────────────┘  │
│  │ Historical  │◄──load──────────────────┘                      │
│  │ (Query)     │                                                │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Konfiguration in values.yaml:**
- Extension: `druid-s3-extensions`
- Storage Type: `s3`
- Endpoint: `http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80`
- Path Style Access: `true` (für MinIO/Ceph kompatibilität)
- Credentials: Via `extraEnvFrom` aus OBC Secret

**ObjectBucketClaim erstellen:**
```bash
kubectl apply -f - <<EOF
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: druid-deep-storage
  namespace: druid
spec:
  generateBucketName: druid-segments
  storageClassName: rook-ceph-bucket
EOF
```

---

### Monitoring Stack

#### ServiceMonitor
Scraped alle Druid-Komponenten für Prometheus:
- Pfad: `monitoring/servicemonitor.yaml`
- Port: 9090 (Prometheus Emitter)
- Interval: 30s

#### PrometheusRule (15 Alerts)

| Alert | Severity | Trigger |
|-------|----------|---------|
| **Supervisor** | | |
| SupervisorNotRunning | critical | State != RUNNING für 5m |
| SupervisorUnhealthy | warning | Unhealthy für 5m |
| **Ingestion** | | |
| IngestionLagHigh | warning | Lag > 100k für 10m |
| IngestionLagCritical | critical | Lag > 500k für 5m |
| ParseExceptionsHigh | warning | Rate > 1/s für 5m |
| **Query** | | |
| QueryLatencyHigh | warning | p95 > 5s für 10m |
| QueryFailureRateHigh | critical | Failure > 5% für 5m |
| **Segments** | | |
| SegmentUnavailable | critical | Count > 0 für 5m |
| SegmentUnderReplicated | warning | Count > 0 für 15m |
| **JVM** | | |
| JvmHeapUsageHigh | warning | Usage > 90% für 5m |
| GcTimeHigh | warning | GC > 0.5s/s für 10m |
| **Tasks** | | |
| TasksFailing | warning | Rate > 0 für 5m |
| PendingTasksHigh | warning | Count > 10 für 10m |

#### Grafana Dashboard

**Sections:**
1. **Supervisors & Ingestion**: Status, Kafka Lag, Ingestion Rate, Parse Errors
2. **Query Performance**: Latency (p50/p90/p99), Rate, Success Rate
3. **Segments & Storage**: Count, Size, Unavailable, Under-Replicated
4. **JVM & Resources**: Heap Usage, GC Time, Memory
5. **Tasks**: Running, Pending, Success Rate, Failed

---

## Troubleshooting

### Problem: 0 Rows in Druid trotz Kafka-Daten

**Ursache 1: Schema Mismatch**
```
Kafka-Daten:    { "productCount": 1 }
Druid Schema:   { "quantity": long }
→ Feld wird nicht gemapped → 0 Rows
```

**Lösung:** Schema in Supervisor an Kafka-Daten anpassen oder Producer ändern.

**Ursache 2: Parse Exceptions (silent)**
```bash
# Parse Logging aktivieren
curl -X POST http://localhost:8888/druid/indexer/v1/supervisor \
  -H "Content-Type: application/json" \
  -d '{
    "spec": {
      "tuningConfig": {
        "logParseExceptions": true,
        "maxSavedParseExceptions": 100
      }
    }
  }'
```

### Problem: Broker kann Peons nicht erreichen

**Symptom:** `Faulty channel in resource pool` in Broker Logs

**Ursache:** Peon-Ports (8101-8104) nicht im Service exponiert

**Lösung:**
```bash
# Peon-Ports zum Service hinzufügen
kubectl patch svc druid-indexer-default-0 -n druid --type='json' -p='[
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "peon-1", "port": 8101, "targetPort": 8101}},
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "peon-2", "port": 8102, "targetPort": 8102}},
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "peon-3", "port": 8103, "targetPort": 8103}},
  {"op": "add", "path": "/spec/ports/-", "value": {"name": "peon-4", "port": 8104, "targetPort": 8104}}
]'
```

### Problem: UNHEALTHY_TASKS Supervisor

**Symptome:**
- Supervisor Status: UNHEALTHY_TASKS
- Tasks laufen aber

**Ursachen:**
1. Worker Capacity zu niedrig (default: 2, aber 4 Supervisors)
2. Memory Issues bei Peons

**Lösung:**
```yaml
# values.yaml
indexer:
  defaults:
    envVars:
      druid_worker_capacity: "4"  # = Anzahl Supervisors
      druid_indexer_runner_javaOpts: "-Xms512m -Xmx512m"
```

---

## Aktueller Status

**Getestet am:** 2026-01-27

| Komponente | Status | Details |
|------------|--------|---------|
| **Datasources** | ✅ | orders (105), payments (5), stock (5), saga_events (5) |
| **Supervisors** | ✅ | 4/4 Running |
| **Deep Storage** | ✅ | Rook-Ceph S3 konfiguriert |
| **Monitoring** | ✅ | ServiceMonitor, PrometheusRule, GrafanaDashboard |
| **Alerts** | ✅ | 15 Alert Rules aktiv |

**Verifizierung:**
```bash
# Datasources
curl -s http://localhost:8888/druid/v2/datasources
# → ["saga_events","payments","orders","stock"]

# Row Counts
curl -s -X POST http://localhost:8888/druid/v2/sql \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT COUNT(*) FROM orders"}'
# → [{"EXPR$0":105}]

# Supervisors
curl -s http://localhost:8888/druid/indexer/v1/supervisor
# → ["saga_events","payments","orders","stock"]
```

---

## Datei-Struktur

```
kubernetes/platform/data/druid/
├── application.yaml          # ArgoCD Application
├── kustomization.yaml        # Kustomize root
├── values.yaml               # Helm values (S3, Extensions, Resources)
├── DRUID.md                  # Diese Dokumentation
├── cluster/
│   ├── namespace.yaml
│   ├── postgres-credentials.yaml
│   ├── postgres-cluster.yaml   # CNPG für Metadata
│   ├── tls-certificates.yaml   # mTLS Certificates (Enterprise)
│   ├── security-config.yaml    # Auth/NetworkPolicy (Enterprise)
│   ├── oauth2-proxy-*.yaml     # OIDC Proxy
│   ├── httproute.yaml          # Ingress
│   └── kafka-supervisors.yaml  # Supervisor Setup Job
└── monitoring/
    ├── kustomization.yaml
    ├── servicemonitor.yaml     # Prometheus Scraping
    ├── prometheusrule.yaml     # Alert Rules
    ├── grafana-dashboard.yaml  # GrafanaDashboard CRD
    └── dashboard-configmap.yaml # Dashboard JSON
```

---

## Enterprise Features (Homelab-Optimized)

### mTLS - Internal Communication

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           mTLS ARCHITEKTUR                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  cert-manager                      Druid Components                              │
│  ════════════                      ════════════════                              │
│                                                                                   │
│  ┌──────────────────┐                                                            │
│  │ selfsigned-      │                                                            │
│  │ cluster-issuer   │                                                            │
│  └────────┬─────────┘                                                            │
│           │                                                                       │
│           ▼                                                                       │
│  ┌──────────────────┐                                                            │
│  │ druid-internal-ca│──────┬─────────┬─────────┬─────────┬───────┐              │
│  │ (Certificate)    │      │         │         │         │       │              │
│  └──────────────────┘      ▼         ▼         ▼         ▼       ▼              │
│                       Coordinator  Broker  Historical  Indexer  Router           │
│                          TLS       TLS       TLS        TLS      TLS            │
│                                                                                   │
│  All internal communication encrypted with mutual TLS                            │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Files:**
- `cluster/tls-certificates.yaml` - CA + Component Certificates
- Issuer: `druid-internal-issuer` (namespace-scoped)
- Duration: 1 year, auto-renewal

### Schema Registry (Apicurio)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       SCHEMA REGISTRY INTEGRATION                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                   │
│  Spring Boot Producer          Apicurio Registry          Druid Consumer         │
│  ═══════════════════          ════════════════════        ══════════════         │
│                                                                                   │
│  ┌─────────────┐    register   ┌─────────────────┐                              │
│  │ order-svc   │──────────────►│ apicurio-       │                              │
│  │ (Avro)      │               │ registry:8080   │                              │
│  └──────┬──────┘               │                 │                              │
│         │                      │ /apis/ccompat/  │   validate                   │
│         │                      │ v7/schemas/ids/ │◄─────────────┐               │
│         ▼                      └─────────────────┘              │               │
│  ┌─────────────┐                                         ┌──────┴──────┐        │
│  │ Kafka       │────────consume────────────────────────►│ Druid       │        │
│  │ (orders-    │                                         │ Supervisor  │        │
│  │ analytics)  │                                         └─────────────┘        │
│  └─────────────┘                                                                 │
│                                                                                   │
│  URL: http://apicurio-registry.kafka.svc:8080/apis/ccompat/v7                    │
│                                                                                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Apicurio already deployed:**
```bash
kubectl get pods -n kafka | grep apicurio
# apicurio-registry-8655dc9866-gcsrw   1/1     Running
```

### Authentication & Authorization

| Layer | Method | Config |
|-------|--------|--------|
| **UI Access** | OAuth2/OIDC (Keycloak) | oauth2-proxy.yaml |
| **API Access** | Basic Auth + Internal User | security-config.yaml |
| **Internal Comms** | mTLS | tls-certificates.yaml |
| **Network** | NetworkPolicy | security-config.yaml |

**Users:**
```yaml
# In druid-auth-credentials Secret
admin:          druid-admin-2026      # Full access
druid_internal: druid-internal-2026   # Inter-node comms
readonly:       druid-readonly-2026   # Dashboard queries
```

### Resource Tuning per Workload

| Component | Role | CPU Req/Limit | Memory Req/Limit | Notes |
|-----------|------|---------------|------------------|-------|
| **Coordinator** | Leadership | 150m/750m | 896Mi/1792Mi | Stability priority |
| **Broker** | Query routing | 150m/750m | 896Mi/1792Mi | Fast response |
| **Historical** | Segment serving | 150m/750m | 1024Mi/2048Mi | Disk I/O heavy |
| **Indexer** | Task execution | 300m/2000m | 2560Mi/4608Mi | CPU burst for ingestion |
| **Router** | Web console | 50m/300m | 256Mi/512Mi | Lightweight |
| **ZooKeeper** | Coordination | 50m/200m | 256Mi/512Mi | Stability |

### Enterprise Checklist

| Feature | Status | Config Location |
|---------|--------|-----------------|
| **mTLS Internal** | ✅ | cluster/tls-certificates.yaml |
| **Schema Registry** | ✅ | kafka namespace (Apicurio) |
| **OIDC (UI)** | ✅ | cluster/oauth2-proxy.yaml |
| **Basic Auth (API)** | ✅ | cluster/security-config.yaml |
| **NetworkPolicy** | ✅ | cluster/security-config.yaml |
| **PodDisruptionBudget** | ✅ | cluster/security-config.yaml |
| **Resource Limits** | ✅ | values.yaml (tuned per workload) |
| **Deep Storage (S3)** | ✅ | values.yaml (Rook-Ceph) |
| **Monitoring** | ✅ | monitoring/ (ServiceMonitor, Rules, Dashboard) |
| **Replicas** | 1 (Homelab) | values.yaml |
| **Worker Capacity** | 4 | values.yaml (matches supervisors) |

---

## Quick Test Commands

```bash
# 1. Port-Forward
kubectl port-forward -n druid svc/druid-router 8888:8888 &

# 2. Check Supervisors
for sup in orders payments stock saga_events; do
  echo -n "$sup: "
  curl -s "http://localhost:8888/druid/indexer/v1/supervisor/$sup/status" | \
    jq -c '{state: .payload.state, healthy: .payload.healthy, lag: .payload.aggregateLag}'
done

# 3. Row Counts
curl -s -X POST "http://localhost:8888/druid/v2/sql" \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT '\''orders'\'' as ds, COUNT(*) as cnt FROM orders UNION ALL SELECT '\''payments'\'', COUNT(*) FROM payments UNION ALL SELECT '\''stock'\'', COUNT(*) FROM stock UNION ALL SELECT '\''saga_events'\'', COUNT(*) FROM saga_events"}' | jq .

# 4. Send Test Events
for i in $(seq 1 25); do
  echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"orderId\":\"test-$i\",\"customerId\":\"cust-$i\",\"productCount\":$((RANDOM % 10 + 1)),\"totalAmount\":$((RANDOM % 500 + 50)),\"status\":\"completed\"}"
done | kubectl exec -i -n kafka my-cluster-dual-role-0 -- \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic orders-analytics

# 5. Verify Ingestion (wait 10s)
sleep 10
curl -s -X POST "http://localhost:8888/druid/v2/sql" \
  -H "Content-Type: application/json" \
  -d '{"query": "SELECT COUNT(*) FROM orders"}'

# 6. Cleanup
pkill -f "kubectl port-forward.*druid-router"
```
