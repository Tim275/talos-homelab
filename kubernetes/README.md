# Kubernetes Homelab (GitOps)

ArgoCD App-of-Apps + ApplicationSets. Bootstrap ArgoCD → it syncs everything else from Git.

## Structure

```
kubernetes/
├── bootstrap/          ArgoCD + App-of-Apps (argocd, projects, clusters, applicationsets)
├── applicationsets/    infrastructure, platform, apps, security, tenants, edge
├── infrastructure/     argocd, network, storage, certificates, secrets, operators, ingress, observability
├── platform/           identity, gitops
├── apps/               cloudbeaver, uptime-kuma, forgejo
├── tenants/            drova, n8n-prod, keycloak, lldap, ml, oms
└── security · projects · clusters · scripts
```

## Bootstrap

```sh
cd tofu && tofu apply && cd ..
git push
export KUBECONFIG=tofu/output/kube-config.yaml

kustomize build --enable-helm kubernetes/bootstrap | kubectl apply --server-side -f -
kustomize build --enable-helm kubernetes/bootstrap | kubectl apply --server-side -f -

kubectl get applications -n argocd -w
```

Apply twice — first pass installs the CRDs, second the CRs that reference them. `--server-side` is needed when a CRD >256 KB is created (fresh cluster); on re-apply plain works. No `--force-conflicts` on a fresh cluster.

## Components individually (optional — ArgoCD does this otherwise)

```sh
kustomize build --enable-helm kubernetes/infrastructure/secrets/sealed-secrets/overlays/prod | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/network/cilium/overlays/prod         | kubectl apply -f -
kustomize build --enable-helm kubernetes/infrastructure/storage/rook-ceph/overlays/prod      | kubectl apply --server-side -f -
kustomize build --enable-helm kubernetes/infrastructure/argocd/overlays/prod                 | kubectl apply --server-side -f -
```

sealed-secrets first — it ships the `sealedsecrets.bitnami.com` CRD that cilium (hubble-oidc) and rook-ceph reference. Wrong order → `NotFound` on the SealedSecret (ArgoCD retries past this, a manual apply does not).

## ArgoCD login

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Or via OIDC: https://argocd.timourhomelab.org

## New tenant

1. `tenants/<name>/` (namespace + resourcequota + limitrange + rbac + data subdirs)
2. add `<name>` to `tenants/kustomization.yaml` + `tenants-config.yaml` AppSet list
3. add `applicationsets/tenants/<name>-tenant.yaml`
4. commit + push → ArgoCD reconciles

## Fallen

Fehler, die schon einmal Stunden gekostet haben. Alle ohne Alert aufgefallen — deshalb hier.

### Proxmox-Ballooning lässt kubelet lügen

`ram_floating` in `tofu/talos_nodes.auto.tfvars` aktiviert den Balloon-Treiber. kubelet liest
die Kapazität **einmal beim Boot**; nimmt der Ballon danach Speicher weg, erfährt Kubernetes
das nie und der Scheduler überbucht den Node. Statt Pod-Eviction greift der Kernel-OOM-Killer.

```sh
kubectl get nodes -o custom-columns=NODE:.metadata.name,CAP:.status.capacity.memory
# dagegen halten: PromQL node_memory_MemTotal_bytes  →  Abweichung >2 GiB = Ballooning aktiv
# bestätigen:     PromQL increase(node_vmstat_oom_kill[2h]) > 0
```

Fix: `ram_floating` weglassen, `ram_dedicated` auf das setzen, was der Host wirklich backt.
Proxmox übernimmt das bei laufender VM nur mit Memory-Hotplug — sonst **VM stop/start**
(kein reboot), Worker einzeln nacheinander, sonst verliert Ceph mehrere OSDs gleichzeitig.

*2026-09-11: worker-4 meldete 21,25 GiB bei real 12,12 GiB → osd.1 89× OOM-Kill, Ceph
20s-Heartbeats, Prometheus-0 180 Restarts, App-Pods readyz-503. Ein Root, viele Symptome.*

### `osd_memory_target` muss zum OSD-Request passen

Steht das Ceph-Target über `resources.osd.requests.memory`, wächst die OSD über ihre
Reservierung hinaus und ist als Burstable erstes OOM-Opfer. Beide Werte hängen zusammen —
einer allein geändert = Fehlkonfiguration. Limit == Request setzen ⇒ Guaranteed QoS.

### grafana-operator trägt Datasource-Passwörter nicht ein

`valuesFrom` + `secretKeyRef` in einer `GrafanaDatasource` wird still ignoriert: der Operator
pusht per HTTP-API, meldet `successfully applied`, und die Datasource hat trotzdem kein
Passwort ([grafana-operator#2271](https://github.com/grafana/grafana-operator/issues/2271)).
`$__env{}` hilft dort ebenfalls nicht — das löst nur Grafanas eigener Provisioning-Loader auf.
Deshalb laufen Datasources mit Credentials über eine gemountete Provisioning-Datei, nicht
über die CRD. Prüfen lässt sich das nur am Health-Endpoint, nicht am CR-Status:

```sh
curl -su admin:$PW localhost:3000/api/datasources/uid/<uid>/health
```

*Die Elasticsearch-Datasource war so 110 Tage unbemerkt unauthentifiziert.*

### Grafana braucht ein PVC

Ohne Volume liegt die SQLite-DB auf `emptyDir` und ist bei jedem Pod-Restart weg. Danach
fehlen alle operator-verwalteten Datasources, bis der Operator nachzieht (Resync-Intervall,
Default 10 min). Datei-provisionierte sind sofort wieder da. `fsGroup` nicht vergessen,
sonst darf der Container nicht auf das Volume schreiben.

### PVC mit `WaitForFirstConsumer` nie in eine eigene, frühere Sync-Wave

Deadlock: ArgoCD wartet auf `Bound`, das PVC wartet auf den ersten Pod, der Pod wartet auf
die spätere Wave. PVC in dieselbe Wave wie den Workload legen.

### `PodCrashLooping` sieht saubere Restart-Schleifen nicht

Die Regel prüft `CrashLoopBackOff`. Wer sich sofort neu startet — OOM-Kill, oder ein Operator,
der bei verlorener Leader-Election mit Exit 0 endet — erreicht den Zustand nie und bleibt
unsichtbar. grafana-operator lief so auf 168 Restarts ohne einen einzigen Alert.
