<h1 align="center">Homelab 🏡</h1>

Repository for home infrastructure and Kubernetes cluster using GitOps practices.

Held together using Proxmox VE, OpenTofu, Talos Linux, Kubernetes, Argo CD and copious amounts of YAML — with some help from Renovate.

🌍 Live: [homepage.timourhomelab.org](https://homepage.timourhomelab.org)

[![Talos](https://img.shields.io/badge/OS-Talos%20Linux-FF7300?style=for-the-badge&logo=linux&logoColor=white)](https://www.talos.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![OpenTofu](https://img.shields.io/badge/IaC-OpenTofu-844FBA?style=for-the-badge&logo=opentofu&logoColor=white)](https://opentofu.org/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-00D4AA?style=for-the-badge&logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)

## Architecture

### Hardware & network

![Hardware & network](docs/architecture/1-hardware-network.svg)

### Platform, GitOps & bootstrap

![Platform, GitOps & bootstrap](docs/architecture/2-platform-gitops.svg)

### Three ways in

![Three ways in](docs/architecture/3-request-flows.svg)

### Secrets

![Secrets](docs/architecture/4-secret-flow.svg)

<sub>sources: `docs/architecture/*.excalidraw`</sub>

## Bootstrap

Needs:

- the remote state in Azure Blob (`tofu/stacks/state`), encrypted with OpenTofu state encryption; CI logs in via OIDC
- Proxmox with its Ceph pools, firewall and API tokens (`tofu/stacks/proxmox`, applied by hand)
- four local, git-ignored inputs in `tofu/stacks/cluster`: `proxmox.auto.tfvars` (endpoints and the API token from the proxmox stack), `openbao_values.auto.tfvars` (first secrets), `keys/seal.key` (OpenBao seal key) and `rook_external.auto.tfvars` (written by `mise run rook-external`)

**1 · OpenTofu builds the cluster**

```sh
cd tofu/stacks/cluster
export TF_ENCRYPTION="$(cat ~/.homelab/tofu-encryption/cluster.hcl)"
tofu init
tofu apply -parallelism=1
export KUBECONFIG=$PWD/output/kube-config.yaml
cd ../../..
```

**2 · Argo CD and root**, applied twice: the first run creates the CRDs

```sh
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone \
  kubernetes/argocd/bootstrap > /tmp/bootstrap.yaml
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
kubectl wait --for=condition=Established --timeout=180s \
  crd/applications.argoproj.io crd/applicationsets.argoproj.io crd/appprojects.argoproj.io
kubectl apply --server-side --force-conflicts -f /tmp/bootstrap.yaml
```

**3–5 · Argo CD takes over**: infrastructure and platform sync on their own, apps and tenants wait for a manual sync

```sh
kubectl -n argocd get applications -w
```

From then on every change goes through a PR. GitHub Actions runs the checks, plans OpenTofu on the PR and applies after approval: `tofu-root-cd` for the cluster, `tofu-cd` for NetBird and Uptime Kuma (start it once by hand after a rebuild). `tofu-drift` compares code and reality every morning.

## 📦 Applications

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/n8n.png"></td>
        <td><a href="https://n8n.io/">n8n</a></td>
        <td>Workflow automation in queue mode.</td>
    </tr>
    <tr>
        <td>🚗</td>
        <td><a href="https://github.com/Tim275/drova-gitops">Drova</a></td>
        <td>Ride-sharing microservices showcase, a tenant with its own repository.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/forgejo.png"></td>
        <td><a href="https://forgejo.org/">Forgejo</a></td>
        <td>Self-hosted Git.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/uptime-kuma.png"></td>
        <td><a href="https://uptime.kuma.pet/">Uptime Kuma</a></td>
        <td>Status page.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/pgadmin.png"></td>
        <td><a href="https://www.pgadmin.org/">pgAdmin</a></td>
        <td>PostgreSQL administration.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/homepage.png"></td>
        <td><a href="https://gethomepage.dev/">Homepage</a></td>
        <td>Start page for the homelab.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/excalidraw.png"></td>
        <td><a href="https://excalidraw.com/">Excalidraw</a></td>
        <td>Whiteboard.</td>
    </tr>
</table>

## 🛠️ Infrastructure

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/proxmox.png"></td>
        <td><a href="https://www.proxmox.com/">Proxmox VE</a></td>
        <td>Hypervisor on three hosts, with Ceph for storage.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/talos.png"></td>
        <td><a href="https://www.talos.dev/">Talos Linux</a></td>
        <td>Immutable, API-driven Linux for the Kubernetes nodes.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/opentofu.png"></td>
        <td><a href="https://opentofu.org/">OpenTofu</a></td>
        <td>Provisions VMs, Talos, DNS and VPN as code.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/argo-cd.png"></td>
        <td><a href="https://argo-cd.readthedocs.io/">Argo CD</a></td>
        <td>GitOps delivery with ApplicationSets and one project per layer.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/renovate.png"></td>
        <td><a href="https://docs.renovatebot.com/">Renovate</a></td>
        <td>Automated dependency updates.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cilium.png"></td>
        <td><a href="https://cilium.io/">Cilium</a></td>
        <td>eBPF networking, network policies and Hubble flow visibility.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/30125649?s=200&v=4"></td>
        <td><a href="https://gateway.envoyproxy.io/">Envoy Gateway</a></td>
        <td>Gateway API ingress with TLS, rate limiting and OIDC at the edge.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cloudflare.png"></td>
        <td><a href="https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/">Cloudflare Tunnel</a></td>
        <td>Public services without open ports.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/netbird.png"></td>
        <td><a href="https://netbird.io/">NetBird</a></td>
        <td>Zero-trust VPN for private access.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/istio.png"></td>
        <td><a href="https://istio.io/">Istio</a></td>
        <td>Service mesh in ambient mode.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/rook.png"></td>
        <td><a href="https://rook.io/">Rook-Ceph</a></td>
        <td>Block and S3 object storage from the external Ceph cluster.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/velero.png"></td>
        <td><a href="https://velero.io/">Velero</a></td>
        <td>Tiered backups and restore tests.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/cert-manager.png"></td>
        <td><a href="https://cert-manager.io/">cert-manager</a></td>
        <td>Certificate automation.</td>
    </tr>
</table>

## 📊 Observability

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/prometheus.png"></td>
        <td><a href="https://prometheus.io/">Prometheus</a></td>
        <td>Metrics and alerting with Alertmanager.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/grafana.png"></td>
        <td><a href="https://grafana.com/">Grafana</a></td>
        <td>Dashboards as code via the Grafana operator.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/loki.png"></td>
        <td><a href="https://grafana.com/oss/loki/">Loki</a></td>
        <td>Log storage, fed by Alloy.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/tempo.png"></td>
        <td><a href="https://grafana.com/oss/tempo/">Tempo</a></td>
        <td>Trace storage.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/jaeger.png"></td>
        <td><a href="https://www.jaegertracing.io/">Jaeger</a></td>
        <td>Tracing UI backed by Elasticsearch.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://opentelemetry.io/img/logos/opentelemetry-icon-color.png"></td>
        <td><a href="https://opentelemetry.io/">OpenTelemetry</a></td>
        <td>Collectors for traces, metrics and logs.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/elasticsearch.png"></td>
        <td><a href="https://www.elastic.co/elasticsearch">Elasticsearch</a></td>
        <td>Search and log analytics with Kibana, fed by Vector.</td>
    </tr>
</table>

## 🗄️ Platform Services

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/postgresql.png"></td>
        <td><a href="https://cloudnative-pg.io/">CloudNativePG</a></td>
        <td>HA PostgreSQL with backups and connection pooling.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/kafka.png"></td>
        <td><a href="https://strimzi.io/">Strimzi</a></td>
        <td>Apache Kafka in KRaft mode.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/redis.png"></td>
        <td><a href="https://redis.io/">Redis</a></td>
        <td>Queues, sessions and the rate-limit backend.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/keycloak.png"></td>
        <td><a href="https://www.keycloak.org/">Keycloak</a></td>
        <td>Single sign-on with OpenID Connect.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/lldap.png"></td>
        <td><a href="https://github.com/lldap/lldap">LLDAP</a></td>
        <td>Lightweight user directory behind Keycloak.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/argo-cd.png"></td>
        <td><a href="https://argoproj.github.io/rollouts/">Argo Rollouts</a></td>
        <td>Progressive delivery with canary analysis.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/keda.png"></td>
        <td><a href="https://keda.sh/">KEDA</a></td>
        <td>Event-driven autoscaling.</td>
    </tr>
</table>

## 🔐 Security

<table>
    <tr><th>Logo</th><th>Name</th><th>Description</th></tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/openbao.png"></td>
        <td><a href="https://openbao.org/">OpenBao</a></td>
        <td>Secrets management.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://github.com/external-secrets.png?size=64"></td>
        <td><a href="https://external-secrets.io/">External Secrets</a></td>
        <td>Syncs secrets from OpenBao into Kubernetes.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://github.com/bitnami-labs.png?size=64"></td>
        <td><a href="https://github.com/bitnami-labs/sealed-secrets">Sealed Secrets</a></td>
        <td>Encrypted secrets in Git for tenants.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/kyverno.png"></td>
        <td><a href="https://kyverno.io/">Kyverno</a></td>
        <td>Policy as code.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://tetragon.io/favicons/android-192x192.png"></td>
        <td><a href="https://tetragon.io/">Tetragon</a></td>
        <td>eBPF-based runtime security.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/trivy.png"></td>
        <td><a href="https://trivy.dev/">Trivy</a></td>
        <td>Vulnerability scanning for running images.</td>
    </tr>
    <tr>
        <td><img width="32" src="https://avatars.githubusercontent.com/u/12783832?s=200&v=4"></td>
        <td><a href="https://github.com/aquasecurity/kube-bench">kube-bench</a></td>
        <td>CIS benchmark checks.</td>
    </tr>
</table>

## 🗃️ Folder Structure

```
.
├── docs/                    architecture diagrams, runbooks, kubectl OIDC config
├── tofu/
│   ├── stacks/              one root module per state: cluster, proxmox, netbird, uptime-kuma, state
│   └── modules/             talos, openbao, rook-external
└── kubernetes/
    ├── argocd/              control plane: bootstrap (Argo CD itself, root), projects, clusters, applicationsets, crds
    ├── infrastructure/      what the cluster runs on: network, storage, security, monitoring, cluster
    ├── platform/            what teams and apps consume: identity, observability (dashboards, logs, traces), data, delivery, automation
    ├── apps/                self-hosted services: forgejo, uptime-kuma, pgadmin, homepage, n8n, excalidraw
    └── tenants/             one namespace, one AppProject, own repository: drova
```
