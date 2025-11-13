# Kafka Platform Notes

## Overview
Kafka messaging platform with Strimzi operator, demo applications, and Redpanda Console UI.

## Components
- **Kafka Cluster**: 3-broker cluster managed by Strimzi
- **Redpanda Console**: Web UI for Kafka management (port 8080)
- **Demo Applications**: Producer/Consumer examples
- **Topics**: user-registrations, email-notifications

## Producer/Consumer Testing & Triggering

### Current Demo Applications

#### Check Running Demo Apps
```bash
export KUBECONFIG="tofu/output/kube-config.yaml"
kubectl get pods -n kafka-demo
```

#### Monitor Producer Activity
```bash
# Watch user registration producer logs
kubectl logs -n kafka-demo -l app=user-registration-producer -f

# Check latest messages
kubectl logs -n kafka-demo -l app=user-registration-producer --tail=10
```

#### Monitor Consumer Activity
```bash
# Watch email notification consumer logs
kubectl logs -n kafka-demo -l app=email-notification-consumer -f

# Check processing status
kubectl logs -n kafka-demo -l app=email-notification-consumer --tail=10
```

### Manual Message Testing

#### Using Kafka CLI Tools
```bash
# Get into a Kafka pod with CLI tools
kubectl exec -it my-cluster-kafka-0 -n kafka -- /bin/bash

# List topics
bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# Produce test messages
bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic user-registrations
# Then type messages like:
# {"user_id":"test-123","email":"test@example.com","timestamp":"2025-09-16T10:00:00Z","region":"eu-west-1","event_type":"user_registration"}

# Consume messages
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic user-registrations --from-beginning
```

#### Create Custom Test Messages
```bash
# Scale up demo producer for more activity
kubectl scale deployment dev-user-registration-producer -n kafka-demo --replicas=2

# Scale down to reduce noise
kubectl scale deployment dev-user-registration-producer -n kafka-demo --replicas=0

# Restart for fresh activity
kubectl rollout restart deployment dev-user-registration-producer -n kafka-demo
kubectl rollout restart deployment dev-email-notification-consumer -n kafka-demo
```

### Trigger High-Volume Testing

#### Burst Mode Producer
```bash
# Create temporary burst producer job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-burst-producer
  namespace: kafka-demo
spec:
  template:
    spec:
      containers:
      - name: producer
        image: confluentinc/cp-kafka:latest
        command: ["/bin/bash"]
        args:
        - -c
        - |
          for i in {1..100}; do
            echo "{\"user_id\":\"burst-\$i\",\"email\":\"burst-\$i@test.com\",\"timestamp\":\"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"region\":\"test-region\",\"event_type\":\"burst_test\"}" | \
            kafka-console-producer --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic user-registrations
            sleep 0.1
          done
      restartPolicy: Never
EOF

# Watch the burst in action
kubectl logs job/kafka-burst-producer -n kafka-demo -f
```

### Redpanda Console Access

#### Port Forward to Console
```bash
kubectl port-forward svc/redpanda-console -n kafka 8080:8080
```

#### What You'll See in Console (http://localhost:8080)

1. **Topics Tab**:
   - `user-registrations`: Live producer messages
   - `email-notifications`: Consumer-generated notifications
   - Message count, partition distribution
   - Real-time throughput graphs

2. **Consumer Groups Tab**:
   - `email-notification-group`: Shows lag, offset, members
   - Consumer health and processing rate

3. **Messages Tab** (per topic):
   - Live message stream
   - JSON message inspection
   - Timestamp and partition info
   - Search and filter capabilities

4. **Brokers Tab**:
   - Cluster health: 3 brokers (my-cluster-kafka-0,1,2)
   - Resource usage and metrics

### Topic Management

#### Create Custom Test Topic
```bash
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 2
  config:
    retention.ms: 3600000  # 1 hour
    cleanup.policy: delete
EOF
```

#### Send Test Messages to Custom Topic
```bash
# Quick test producer
kubectl run kafka-producer --image=confluentinc/cp-kafka:latest --rm -it --restart=Never -n kafka -- \
  kafka-console-producer --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic test-topic

# Then type messages and press Enter
```

### Debugging & Monitoring

#### Check Kafka Cluster Health
```bash
kubectl get kafka my-cluster -n kafka
kubectl describe kafka my-cluster -n kafka
```

#### Topic Status
```bash
kubectl get kafkatopic -n kafka
kubectl describe kafkatopic user-registrations -n kafka
```

#### Consumer Group Status
```bash
# From inside Kafka pod
kubectl exec -it my-cluster-kafka-0 -n kafka -- bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group email-notification-group
```

### Performance Testing

#### High-Throughput Producer Test
```bash
kubectl run perf-producer --image=confluentinc/cp-kafka:latest --rm -it --restart=Never -n kafka -- \
  kafka-producer-perf-test --topic user-registrations \
  --num-records 10000 \
  --record-size 1024 \
  --throughput 1000 \
  --producer-props bootstrap.servers=my-cluster-kafka-bootstrap:9092
```

#### Consumer Performance Test
```bash
kubectl run perf-consumer --image=confluentinc/cp-kafka:latest --rm -it --restart=Never -n kafka -- \
  kafka-consumer-perf-test --topic user-registrations \
  --bootstrap-server my-cluster-kafka-bootstrap:9092 \
  --messages 10000
```

## Tips for Redpanda Console Demo

1. **Start Producer Activity**: `kubectl scale deployment dev-user-registration-producer -n kafka-demo --replicas=1`

2. **Watch Live in Console**: Go to Topics → user-registrations → Messages tab

3. **See Consumer Processing**: Topics → email-notifications → Messages tab

4. **Monitor Consumer Groups**: Consumer Groups → email-notification-group

5. **Create Test Burst**: Use the burst producer job above

6. **Reset Demo**: Scale down and up deployments to restart fresh

## Common Issues

- **No messages visible**: Check if producer/consumer pods are running
- **Console not connecting**: Verify port-forward and Kafka bootstrap servers
- **Topic not found**: Check KafkaTopic CRDs with `kubectl get kafkatopic -n kafka`
- **Consumer lag**: Check consumer group status and processing logs