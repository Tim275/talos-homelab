# AWS S3 Offsite Backup Setup Guide

## Overview

This guide explains how to activate optional AWS S3 offsite backups for disaster recovery. The current setup uses Ceph RGW for local backups, but AWS S3 provides an additional offsite copy for datacenter-level failures.

## Current Backup Strategy

**Active (Ceph RGW - Local)**:
- Tier-0: Every 6 hours (n8n-prod, keycloak, infisical, authelia, lldap)
- Tier-1: Daily (n8n-dev, grafana)
- Tier-2: Weekly (sealed-secrets)
- Storage: Ceph RGW S3 (fast local restore)

**Optional (AWS S3 - Offsite)**:
- Tier-0 ONLY: Daily at 4 AM
- Purpose: Disaster recovery (datacenter failure, fire, ransomware)
- Storage: AWS S3 Glacier Instant Retrieval (low cost, fast retrieval)
- Estimated cost: EUR 0.50/month for ~50GB

## Why AWS S3 Offsite Backup?

1. **3-2-1 Rule Compliance**: 3 copies, 2 media types, 1 offsite
2. **Datacenter Failure**: If homelab is destroyed, AWS backups survive
3. **Ransomware Protection**: Offsite backups not accessible from homelab
4. **Compliance**: Many industries require offsite backups
5. **Cost-Effective**: Glacier Instant Retrieval = EUR 0.004/GB/month

## Prerequisites

- AWS Account (free tier available)
- kubectl access to cluster
- kubeseal installed (`brew install kubeseal`)

## Step 1: Create AWS S3 Bucket

```bash
# Login to AWS Console: https://console.aws.amazon.com

# Navigate to S3 service

# Create bucket:
#   - Name: timour-homelab-velero-dr
#   - Region: eu-central-1 (Frankfurt - closest to Germany)
#   - Versioning: Enabled
#   - Encryption: AES-256 (server-side)
#   - Public access: Block all

# Configure lifecycle policy (OPTIONAL - cost optimization):
#   - Transition to Glacier Instant Retrieval after 0 days
#   - Delete backups older than 365 days (matches TTL)
```

## Step 2: Create IAM User

```bash
# Navigate to IAM service -> Users -> Add user

# User details:
#   - Name: velero-backup-user
#   - Access type: Programmatic access (no console)

# Attach custom policy (least privilege):
```

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": "arn:aws:s3:::timour-homelab-velero-dr"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::timour-homelab-velero-dr/*"
    }
  ]
}
```

```bash
# Generate Access Key:
#   - Save Access Key ID (AKIAIOSFODNN7EXAMPLE)
#   - Save Secret Access Key (wJalrXUtnFEMI/K7MDENG/...)
```

## Step 3: Create AWS Credentials Secret

```bash
# Create plaintext credentials file
cat > /tmp/aws-credentials <<EOF
[default]
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

# Generate SealedSecret
kubectl create secret generic velero-aws-credentials \
  --from-file=cloud=/tmp/aws-credentials \
  --namespace velero \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets -o yaml \
  > kubernetes/infrastructure/storage/velero/sealed-secret-aws.yaml

# Clean up plaintext credentials (IMPORTANT!)
rm -f /tmp/aws-credentials

# Verify SealedSecret was created
cat kubernetes/infrastructure/storage/velero/sealed-secret-aws.yaml
```

## Step 4: Activate AWS Configuration

```bash
# Edit kustomization.yaml
cd kubernetes/infrastructure/storage/velero

# 1. Uncomment line 15 (sealed-secret-aws.yaml)
# BEFORE:
#   # - sealed-secret-aws.yaml   # OPTIONAL: AWS S3 credentials for offsite DR (uncomment to activate)

# AFTER:
#   - sealed-secret-aws.yaml   # OPTIONAL: AWS S3 credentials for offsite DR (uncomment to activate)

# 2. Uncomment lines 79-86 (aws-s3-offsite BackupStorageLocation)
# BEFORE:
#   # - name: aws-s3-offsite
#   #   provider: aws
#   #   bucket: timour-homelab-velero-dr
#   #   ...

# AFTER:
#   - name: aws-s3-offsite
#     provider: aws
#     bucket: timour-homelab-velero-dr
#     credential:
#       name: velero-aws-credentials
#       key: cloud
#     config:
#       region: eu-central-1
```

## Step 5: Activate AWS Backup Schedules

```bash
# Edit backup-schedules-aws.yaml
cd kubernetes/infrastructure/storage/velero-schedules

# Uncomment ALL schedules (lines 14-132)
# Remove leading '#' and 1 space from each line

# Quick method (use with caution):
sed -i '' 's/^# //' backup-schedules-aws.yaml

# Verify (should show valid YAML, not comments):
cat backup-schedules-aws.yaml
```

## Step 6: Apply Configuration

```bash
# Apply Velero configuration (creates BackupStorageLocation + credentials)
kubectl apply -f kubernetes/infrastructure/storage/velero/

# Wait for BackupStorageLocation to be available
kubectl get backupstoragelocation -n velero
# Expected output:
# NAME              PHASE       LAST VALIDATED   AGE
# cluster-backups   Available   5s               30d
# pv-backups        Available   5s               30d
# aws-s3-offsite    Available   5s               1m

# Apply backup schedules
kubectl apply -f kubernetes/infrastructure/storage/velero-schedules/backup-schedules-aws.yaml

# Verify schedules created
kubectl get schedules -n velero | grep aws
# Expected output:
# tier0-aws-n8n-prod       4m
# tier0-aws-keycloak       4m
# tier0-aws-infisical      4m
# tier0-aws-authelia       4m
# tier0-aws-lldap          4m
```

## Step 7: Trigger Test Backup

```bash
# Trigger manual backup to AWS (test credentials)
velero backup create test-aws-backup \
  --include-namespaces n8n-prod \
  --storage-location aws-s3-offsite \
  --wait

# Check backup status
velero backup describe test-aws-backup

# Expected output (after ~2-5 minutes):
# Phase:  Completed
# Warnings: 0
# Errors: 0

# Verify backup in S3
# AWS Console -> S3 -> timour-homelab-velero-dr -> backups/test-aws-backup/
```

## Step 8: Verify Daily Backups

```bash
# Wait 24 hours for first scheduled backup (4 AM next day)

# Check backup status next morning
kubectl get backups -n velero | grep aws
# Expected output:
# tier0-aws-n8n-prod-20241030040000       Completed   1d
# tier0-aws-keycloak-20241030040000       Completed   1d
# tier0-aws-infisical-20241030040000      Completed   1d
# tier0-aws-authelia-20241030040000       Completed   1d
# tier0-aws-lldap-20241030040000          Completed   1d

# Check S3 storage usage
# AWS Console -> S3 -> timour-homelab-velero-dr -> Metrics
# Expected: ~50GB after first full backup
```

## Cost Estimation

**Monthly Cost (50GB data)**:
- Glacier Instant Retrieval: 50GB * EUR 0.004 = EUR 0.20/month
- PUT requests: ~500 * EUR 0.02/1000 = EUR 0.01/month
- GET requests (restore): ~500 * EUR 0.01/1000 = EUR 0.005/month
- Data transfer OUT (restore): 50GB * EUR 0.09/GB = EUR 4.50 (one-time, only if needed)

**Total**: EUR 0.50/month (normal operation), EUR 5.00 (if disaster recovery restore needed)

## Disaster Recovery Restore

```bash
# In case of total homelab failure:

# 1. Rebuild Kubernetes cluster with Velero
# 2. Configure AWS BackupStorageLocation (same credentials)
# 3. Restore from AWS backup:

velero restore create --from-backup tier0-aws-n8n-prod-20241030040000
velero restore create --from-backup tier0-aws-keycloak-20241030040000
velero restore create --from-backup tier0-aws-infisical-20241030040000
velero restore create --from-backup tier0-aws-authelia-20241030040000
velero restore create --from-backup tier0-aws-lldap-20241030040000

# Monitor restore progress
velero restore get
```

## Deactivation (If Needed)

```bash
# 1. Delete AWS schedules
kubectl delete -f kubernetes/infrastructure/storage/velero-schedules/backup-schedules-aws.yaml

# 2. Comment out BackupStorageLocation in kustomization.yaml
# 3. Comment out sealed-secret-aws.yaml in kustomization.yaml
# 4. kubectl apply -f kubernetes/infrastructure/storage/velero/

# NOTE: S3 bucket and existing backups remain untouched
```

## Monitoring

```bash
# Check backup status
kubectl get backups -n velero | grep aws

# Check failed backups
kubectl get backups -n velero -l backup-target=aws-s3-offsite | grep -v Completed

# View backup logs
velero backup logs tier0-aws-n8n-prod-<timestamp>

# Check BackupStorageLocation status
kubectl get backupstoragelocation aws-s3-offsite -n velero -o yaml
```

## Troubleshooting

### BackupStorageLocation shows "Unavailable"

```bash
# Check Velero logs
kubectl logs -n velero deployment/velero | grep -i error

# Common causes:
# - Invalid AWS credentials
# - Wrong S3 bucket name
# - Wrong region
# - IAM policy missing permissions

# Test credentials manually
kubectl exec -n velero deployment/velero -- aws s3 ls s3://timour-homelab-velero-dr --region eu-central-1
```

### Backup stuck in "InProgress"

```bash
# Check node-agent pods (Restic/Kopia)
kubectl get pods -n velero | grep node-agent

# Check pod logs
kubectl logs -n velero <node-agent-pod> | tail -50

# Common causes:
# - Large PV taking time to upload
# - Network timeout (increase timeout in Velero config)
# - Restic encryption key mismatch
```

### High AWS costs

```bash
# Check S3 storage class
# AWS Console -> S3 -> timour-homelab-velero-dr -> Properties -> Storage Class
# Should be: Glacier Instant Retrieval

# If Standard storage class:
# 1. Create S3 Lifecycle Policy to transition to Glacier IR
# 2. Wait 24 hours for transition
# 3. Costs should drop from EUR 2/month to EUR 0.50/month
```

## References

- Velero AWS Plugin: https://github.com/vmware-tanzu/velero-plugin-for-aws
- AWS S3 Pricing: https://aws.amazon.com/s3/pricing/
- Glacier Instant Retrieval: https://aws.amazon.com/s3/storage-classes/glacier/instant-retrieval/
- 3-2-1 Backup Rule: https://www.vmware.com/topics/glossary/content/3-2-1-backup-rule
