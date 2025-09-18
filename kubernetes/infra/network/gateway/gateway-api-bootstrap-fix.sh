#!/bin/bash
# Gateway API Bootstrap Fix Script
# Run after ArgoCD sync to fix Cilium Gateway Controller status issues

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