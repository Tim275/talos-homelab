# Coraza WAF — Phase 1 test rig (throwaway)

Not part of any kustomization / ArgoCD app — applied **manually** to prove the
WebSocket bypass survives the Coraza WASM filter **before** the gateway-wide WAF
(`../base/waf/`) is ever enabled on the real gateway.

A dedicated `coraza-test-gw` Gateway gets its own Envoy proxy → the production
gateway is untouched.

## Run
```sh
kubectl apply -f waf-test.yaml

# port-forward the test gateway's envoy
SVC=$(kubectl -n gateway get svc -l gateway.envoyproxy.io/owning-gateway-name=coraza-test-gw -o name | head -1)
kubectl -n gateway port-forward "$SVC" 8888:80

# in another shell — all must pass:
curl -s localhost:8888/ -H 'Host: waf-test.local'                       # HTTP echo works
websocat ws://localhost:8888/ -H 'Host: waf-test.local'                 # WS upgrade + echo works  <-- the proof
curl -s "localhost:8888/?id=1%27%20OR%201=1" -H 'Host: waf-test.local'  # passes (DetectionOnly)...
kubectl -n gateway logs -l gateway.envoyproxy.io/owning-gateway-name=coraza-test-gw | grep -i coraza  # ...but is logged

kubectl delete -f waf-test.yaml
```

## Pass criteria → proceed to Phase 2
- HTTP echo: 200
- **WebSocket: upgrades and echoes** (if this fails, the header bypass doesn't save WS → use Plan B: separate WS listener, see `notes/CLAUDE-PLANNING.md`)
- SQLi probe: returns normally **and** appears as a Coraza detection in the logs

Then enable `../base/waf/` (uncomment `- waf` in `../base/kustomization.yaml`), still `DetectionOnly`, and soak.
