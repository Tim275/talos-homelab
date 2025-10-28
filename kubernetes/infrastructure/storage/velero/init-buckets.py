#!/usr/bin/env python3
"""
Initialize Velero S3 bucket directory structure for Ceph RGW
Ceph RGW requires prefix "directories" to exist before uploading objects
"""
import os
import boto3
from botocore.client import Config

def create_prefix_marker(s3_client, bucket, prefix):
    """Create empty marker object to initialize prefix directory"""
    try:
        key = f"{prefix}.velero" if not prefix.endswith('/') else f"{prefix}.velero"
        s3_client.put_object(Bucket=bucket, Key=key, Body=b'')
        print(f"✅ Created: s3://{bucket}/{key}")
        return True
    except Exception as e:
        print(f"❌ Failed to create {bucket}/{prefix}: {e}")
        return False

def main():
    endpoint = os.environ.get('ENDPOINT', 'http://rook-ceph-rgw-homelab-objectstore.rook-ceph.svc:80')

    # Initialize cluster-backups bucket
    print("=== Initializing velero-cluster-backups ===")
    s3_cluster = boto3.client(
        's3',
        endpoint_url=endpoint,
        aws_access_key_id=os.environ['ACCESS_KEY_CLUSTER'],
        aws_secret_access_key=os.environ['SECRET_KEY_CLUSTER'],
        config=Config(signature_version='s3v4'),
        region_name='us-east-1'
    )

    # Create Velero's expected directory structure
    create_prefix_marker(s3_cluster, 'velero-cluster-backups', 'backups/')
    create_prefix_marker(s3_cluster, 'velero-cluster-backups', 'metadata/')
    create_prefix_marker(s3_cluster, 'velero-cluster-backups', 'restic/')

    # Initialize pv-backups bucket
    print("\n=== Initializing velero-pv-backups ===")
    s3_pv = boto3.client(
        's3',
        endpoint_url=endpoint,
        aws_access_key_id=os.environ['ACCESS_KEY_PV'],
        aws_secret_access_key=os.environ['SECRET_KEY_PV'],
        config=Config(signature_version='s3v4'),
        region_name='us-east-1'
    )

    create_prefix_marker(s3_pv, 'velero-pv-backups', 'backups/')
    create_prefix_marker(s3_pv, 'velero-pv-backups', 'metadata/')
    create_prefix_marker(s3_pv, 'velero-pv-backups', 'restic/')

    print("\n✅ Done! Bucket directories initialized")

if __name__ == '__main__':
    main()
