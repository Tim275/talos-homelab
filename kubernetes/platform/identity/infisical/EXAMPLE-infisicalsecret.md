---
# EXAMPLE: InfisicalSecret Custom Resource
# Purpose: Shows how to sync secrets from Infisical to Kubernetes
# This file is for documentation only - NOT applied by ArgoCD

# Step 1: Create a Service Token in Infisical UI:
#   - Go to Project Settings → Service Tokens
#   - Create token with scope: production environment
#   - Copy the token (starts with "st....")

# Step 2: Create a Kubernetes Secret with the token:
#   kubectl create secret generic infisical-service-token \
#     --from-literal=token=st.your-token-here \
#     --namespace=my-app

# Step 3: Create an InfisicalSecret CR like this:
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: my-app-secrets
  namespace: my-app
  annotations:
    # Optional: Auto-reload pods when secrets change
    secrets.infisical.com/auto-reload: "true"
spec:
  # Infisical API endpoint (use internal service)
  hostAPI: http://infisical.infisical.svc.cluster.local:8080/api

  # How often to check for secret updates (seconds)
  resyncInterval: 60

  # Authentication method: serviceToken
  authentication:
    serviceToken:
      # Reference to the secret containing service token
      serviceTokenSecretReference:
        secretName: infisical-service-token
        secretNamespace: my-app

      # Which Infisical project/environment to sync from
      secretsScope:
        projectSlug: homelab-secrets
        envSlug: production
        # Optional: sync only specific secret paths
        # secretsPath: /app/database

  # Target Kubernetes Secret to create/update
  managedSecretReference:
    secretName: my-app-secrets
    secretNamespace: my-app
    # Optional: secret type (default: Opaque)
    secretType: Opaque

---
# Example: Using the synced secrets in a Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: my-app:latest
          # Option 1: Use secrets as environment variables
          envFrom:
            - secretRef:
                name: my-app-secrets
          # Option 2: Mount secrets as files
          volumeMounts:
            - name: secrets
              mountPath: /etc/secrets
              readOnly: true
      volumes:
        - name: secrets
          secret:
            secretName: my-app-secrets
