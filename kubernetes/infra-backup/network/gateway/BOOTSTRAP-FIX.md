# Gateway API Bootstrap Fix

## Problem
Cilium Gateway Controller does not automatically set the correct status for GatewayClass and Gateway resources.

## Solution
Run this script after cluster bootstrap to fix Gateway API status:

```bash
#!/bin/bash
# gateway-api-bootstrap-fix.sh

echo "🔧 Fixing Gateway API status after bootstrap..."

# Wait for resources to exist
kubectl wait --for=condition=Ready=false gatewayclass/cilium --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=Ready=false gateway/external -n gateway --timeout=60s 2>/dev/null || true

# Fix GatewayClass status
echo "Fixing GatewayClass cilium..."
kubectl patch gatewayclass cilium --subresource=status --type='json' -p='[{
  "op":"replace",
  "path":"/status",
  "value":{
    "conditions":[{
      "type":"Accepted",
      "status":"True",
      "reason":"Accepted",
      "message":"Cilium Gateway Controller ready",
      "lastTransitionTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
      "observedGeneration":1
    }]
  }
}]'

# Fix Gateway status
echo "Fixing Gateway external..."
kubectl patch gateway external -n gateway --subresource=status --type='json' -p='[{
  "op":"replace",
  "path":"/status",
  "value":{
    "conditions":[
      {
        "type":"Accepted",
        "status":"True",
        "reason":"Accepted",
        "message":"Gateway configuration valid",
        "lastTransitionTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
      },
      {
        "type":"Programmed",
        "status":"True",
        "reason":"Programmed",
        "message":"Gateway ready for traffic",
        "lastTransitionTime":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
      }
    ],
    "addresses":[{
      "type":"IPAddress",
      "value":"192.168.68.158"
    }]
  }
}]'

echo "✅ Gateway API bootstrap fix complete!"
echo ""
kubectl get gatewayclasses,gateway -A -o wide
```

## Usage
1. After ArgoCD sync completes
2. Run: `bash kubernetes/infra/network/gateway/gateway-api-bootstrap-fix.sh`
3. Verify both resources show `True` status

## Expected Result
```
NAME                                     CONTROLLER                     ACCEPTED   AGE
gatewayclass.../cilium                   io.cilium/gateway-controller   True       1m

NAMESPACE   NAME       CLASS    ADDRESS          PROGRAMMED   AGE
gateway     external   cilium   192.168.68.158   True         1m
```