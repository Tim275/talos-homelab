# Kafka Email Notification System

A real-time email notification system using Apache Kafka, demonstrating producer-consumer architecture with dynamic email routing.

## Architecture

- **Producer**: Kafka message producer that sends user registration events
- **Consumer**: Real email notification consumer that processes Kafka messages and sends actual emails via Gmail SMTP
- **Topics**:
  - `user-registrations` (input) - User registration events
  - `email-notifications` (output) - Email delivery status events

## Components

### 1. Real Email Notification Consumer

**File**: `real-email-consumer-deployment.yaml`

The consumer processes user registration messages from Kafka and sends welcome emails to the actual user email addresses specified in the messages.

#### Features:
- ✅ Dynamic email routing (recipient from Kafka message)
- ✅ Gmail SMTP integration with App Password authentication
- ✅ Anti-spam headers for better email deliverability
- ✅ HTML and plain text email formats
- ✅ Kafka event publishing for email delivery status

#### Deployment:
```bash
kubectl apply -f real-email-consumer-deployment.yaml
```

#### Monitoring Consumer:
```bash
# Check consumer logs
kubectl logs -n kafka-demo deployment/real-email-notification-consumer --tail=50

# Watch consumer in real-time
kubectl logs -n kafka-demo deployment/real-email-notification-consumer -f

# Check consumer status
kubectl get pods -n kafka-demo -l app.kubernetes.io/name=real-email-notification-consumer
```

### 2. Test Email Producer Job

**File**: `test-email-producer.yaml`

A Kubernetes Job that sends test user registration messages to Kafka for validating the email delivery system.

#### Deployment:
```bash
kubectl apply -f test-email-producer.yaml
```

#### Monitoring Producer:
```bash
# Check producer job status
kubectl get jobs -n kafka-demo test-email-producer

# Check producer logs
kubectl logs -n kafka-demo job/test-email-producer --tail=50

# Clean up test job
kubectl delete job -n kafka-demo test-email-producer
```

## SMTP Configuration

### Encrypted Configuration (Production)

**File**: `smtp-sealed-secret.yaml`

Encrypted SMTP credentials using Sealed Secrets for production deployment.

```bash
# Deploy encrypted SMTP configuration
kubectl apply -f smtp-sealed-secret.yaml

# Verify sealed secret
kubectl get sealedsecrets -n kafka-demo smtp-config
```

### Development Configuration

**File**: `smtp-secret.yaml` (⚠️ Contains plaintext credentials)

For development purposes only. Should be replaced with SealedSecret in production.

```bash
# Deploy development SMTP config (NOT for production)
kubectl apply -f smtp-secret.yaml
```

## Kafka Operations

### Producer Commands

#### Send Manual Test Message:
```bash
# Access Kafka pod
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- bash

# Send test user registration
echo '{"user_id":"manual-test","email":"your-email@example.com","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","region":"eu-central-1","event_type":"user_registration"}' | \
/opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --topic user-registrations
```

#### Multiple Test Messages:
```bash
# Send batch of test registrations
for i in {1..5}; do
  echo '{"user_id":"batch-test-'$i'","email":"your-email@example.com","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","region":"test-region","event_type":"batch_test"}' | \
  /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
    --topic user-registrations
  sleep 2
done
```

### Consumer Commands

#### Monitor Kafka Topics:
```bash
# List all topics
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- \
/opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --list

# Check user-registrations topic
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- \
/opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --topic user-registrations \
  --from-beginning

# Check email-notifications topic (delivery status)
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- \
/opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --topic email-notifications \
  --from-beginning
```

#### Check Consumer Groups:
```bash
# List consumer groups
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- \
/opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --list

# Check real-email-notification-group status
kubectl exec -it -n kafka deployment/my-cluster-entity-operator -- \
/opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server my-cluster-kafka-bootstrap.kafka:9092 \
  --group real-email-notification-group \
  --describe
```

## Testing Workflow

### 1. Deploy Components
```bash
# Deploy SMTP configuration (choose one)
kubectl apply -f smtp-sealed-secret.yaml  # Production (encrypted)
# OR
kubectl apply -f smtp-secret.yaml         # Development (plaintext)

# Deploy email consumer
kubectl apply -f real-email-consumer-deployment.yaml

# Wait for consumer to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=real-email-notification-consumer -n kafka-demo --timeout=60s
```

### 2. Send Test Email
```bash
# Run test producer job
kubectl apply -f test-email-producer.yaml

# Monitor test execution
kubectl logs -n kafka-demo job/test-email-producer -f
```

### 3. Verify Email Delivery
```bash
# Check consumer logs for email delivery status
kubectl logs -n kafka-demo deployment/real-email-notification-consumer --tail=20

# Look for success messages like:
# "✅ Real email sent successfully for user test-user-timour to your-email@example.com"
```

### 4. Cleanup
```bash
# Remove test job
kubectl delete job -n kafka-demo test-email-producer

# Restart consumer if needed
kubectl rollout restart -n kafka-demo deployment/real-email-notification-consumer
```

## Message Format

### User Registration Message (Input)
```json
{
  "user_id": "unique-user-identifier",
  "email": "user@example.com",
  "timestamp": "2025-09-16T10:30:00Z",
  "region": "eu-central-1",
  "event_type": "user_registration"
}
```

### Email Notification Event (Output)
```json
{
  "email_id": "real-email-1726483800123",
  "user_id": "unique-user-identifier",
  "recipient": "user@example.com",
  "status": "sent",
  "timestamp": "2025-09-16T10:30:15Z",
  "event_type": "real_email_notification",
  "smtp_host": "smtp.gmail.com",
  "error": null
}
```

## Troubleshooting

### Consumer Not Processing Messages
```bash
# Check if consumer is running
kubectl get pods -n kafka-demo -l app.kubernetes.io/name=real-email-notification-consumer

# Check consumer logs for errors
kubectl logs -n kafka-demo deployment/real-email-notification-consumer --tail=50

# Verify SMTP secret is loaded
kubectl get secret -n kafka-demo smtp-config
```

### Email Delivery Issues
```bash
# Check SMTP configuration in consumer logs
kubectl logs -n kafka-demo deployment/real-email-notification-consumer | grep "SMTP Config"

# Verify Gmail App Password is correct
kubectl get secret -n kafka-demo smtp-config -o yaml
```

### Kafka Connection Issues
```bash
# Test Kafka connectivity from consumer pod
kubectl exec -n kafka-demo deployment/real-email-notification-consumer -- \
  nc -zv my-cluster-kafka-bootstrap.kafka 9092

# Check Kafka cluster status
kubectl get kafka -n kafka my-cluster
```

## Security Notes

- 📧 **Gmail App Password**: Use dedicated App Password, not your regular Gmail password
- 🔐 **Sealed Secrets**: Always use encrypted SMTP configuration in production
- 🚫 **Never Commit**: Never commit plaintext SMTP credentials to git
- 🔒 **RBAC**: Ensure proper Kubernetes RBAC for kafka-demo namespace

## Email Deliverability

The system includes anti-spam headers to improve email deliverability:
- ✅ `Message-ID` with unique identifier
- ✅ `Reply-To` header for proper routing
- ✅ `X-Mailer` identification
- ✅ `List-Unsubscribe` for compliance
- ✅ `X-Auto-Response-Suppress` for automated systems
- ✅ Both HTML and plain text message formats