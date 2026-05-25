# Cloudflare Access für Internal Apps

Schritt-für-Schritt-Setup um internal-tools (Grafana, ArgoCD, Jaeger, Hubble UI,
Velero UI, Ceph Dashboard) vor unauthorized public access zu schützen.

## Warum

Aktuell: `argo.timourhomelab.org`, `grafana.timourhomelab.org`, etc. sind über
Cloudflare Tunnel erreichbar. ArgoCD/Grafana haben eigene OIDC-Logins → User
muss sich einloggen. ABER: die Login-Page selbst ist public erreichbar.

Mit CF Access davor: Login-Page selbst gated → Brute-force-attempts auf die
App-Login-Page sind nicht möglich.

## Setup-Schritte (1× im Cloudflare Dashboard)

### Phase A — One-Time CF Access Activation

1. https://one.dash.cloudflare.com/
2. Wähle dein Tailnet (timourhomelab.org)
3. Access → Applications → Add an application → Self-hosted

### Phase B — Identity Provider verbinden (Keycloak)

```
Settings → Authentication → Login methods → Add
  Type: OIDC
  Name: Keycloak
  App ID:      cf-access (KC client-id)
  Client Secret: <SealedSecret>
  Auth URL:    https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/auth
  Token URL:   https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/token
  Cert URL:    https://iam.timourhomelab.org/realms/kubernetes/protocol/openid-connect/certs
  Scopes:      openid email profile groups
```

In KC: neuen client `cf-access` erstellen:
```bash
kubectl exec -n keycloak keycloak-0 -- bash -c "
/opt/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080 --realm master --user admin --password <ADMIN_PASS>
/opt/keycloak/bin/kcadm.sh create clients -r kubernetes \
  -s clientId=cf-access \
  -s enabled=true \
  -s clientAuthenticatorType=client-secret \
  -s 'secret=<RANDOM>' \
  -s standardFlowEnabled=true \
  -s 'redirectUris=[\"https://timour.cloudflareaccess.com/cdn-cgi/access/callback\"]' \
  -s 'webOrigins=[\"+\"]'
"
```

### Phase C — Application-Policies pro Service

Für jeden internal-service eine Application:

```
Add Application → Self-hosted
  Name: Grafana
  Application Domain: grafana.timourhomelab.org
  Session Duration: 24h
  
  Policy 1 (Allow):
    Action: Allow
    Include: Emails ending in @timourhomelab.org
    OR: Groups: cluster-admins (via Keycloak OIDC)
  
  Policy 2 (Block):
    Action: Block
    Include: Everyone (default)
```

Wiederhole für:
- `grafana.timourhomelab.org` → cluster-admins + grafana-* Gruppen
- `argo.timourhomelab.org` → cluster-admins + argocd-* Gruppen
- `jaeger.timourhomelab.org` → cluster-admins
- `hubble.timourhomelab.org` → cluster-admins
- `prometheus.timourhomelab.org` → cluster-admins
- `alertmanager.timourhomelab.org` → cluster-admins
- `velero.timourhomelab.org` → cluster-admins

NICHT gaten:
- `iam.timourhomelab.org` (Keycloak selbst — würde Login-Loop verursachen)
- `drova.timourhomelab.org` (Customer-Facing, public OK)

### Phase D — Test-Login-Flow

```
Inkognito → https://grafana.timourhomelab.org/
→ CF Access Login-Page (statt Grafana)
→ Klick "Login with Keycloak"
→ KC zeigt Login-Form
→ User+Pass+TOTP
→ Redirect zu Grafana
→ Grafana zeigt OWN Login → klick "Sign in with Keycloak"
→ Bereits-eingeloggte KC-Session → direkter Login
→ Grafana Dashboard

Doppel-OIDC ist normal — CF Access prüft "darf ich rein", App-OIDC prüft "wer bin ich".
```

## Was du dann hast

```
Browser-Anfrage zu grafana.timourhomelab.org
  ↓
Cloudflare-Edge (DDoS-filter)
  ↓
Cloudflare Access (NEU — OIDC-gated)
  ├─ Hat User valid CF-Access-Session? → pass
  └─ Nein → redirect zu KC-Login → check groups → pass/block
  ↓
Cloudflare Tunnel
  ↓
cloudflared pod → envoy-gateway
  ↓
Grafana Pod (Login-Page jetzt geschützt)
```

→ Unauthenticated Brute-Force-Attempts werden bei CF Edge gedroppt,
   erreichen Grafana NIE.

## Was du NICHT brauchst zu commit

```
Alle CF Access settings sind Web-UI-Settings im CF Dashboard.
Sind NICHT in IaC (CF hat keine Terraform-managed-API für Access).

Was du WOHL committest:
  - KC-realm-import.yaml: cf-access client hinzufügen
  - SealedSecret: cf-access-client-secret
```

## Verifizieren

```bash
# Anonymous request muss CF Access Login zeigen
curl -sk https://grafana.timourhomelab.org/ -L 2>&1 | grep -iE "cloudflare|access" | head -3
# Expected: CF Access redirect to login.cloudflareaccess.com OR identity-broker
```

## FAQ

- "CF Access für neue App?" → Phase C kopieren
- "User soll auch Grafana erreichen?" → KC-group `grafana-users` adden + CF-Policy include
- "Wie viele Apps kann ich gaten?" → CF Free-tier 50 users, then $7/user/Mo
- "Statt CF Access self-hosted?" → Pomerium / Authentik
