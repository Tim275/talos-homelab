# Identity / User Lifecycle

Self-Service-Workflow für Mitarbeiter via Keycloak + LLDAP + Resend SMTP.

## Architektur

```
Admin                LLDAP              Keycloak             Mitarbeiter
  │                    │                   │                      │
  │ onboard-user.sh    │                   │                      │
  ├───────────────────▶│ User erstellen    │                      │
  │                    │ + Group           │                      │
  │                                        │                      │
  │ trigger sync       │                   │                      │
  ├────────────────────────────────────────▶│ Federation pulls    │
  │                                        │                      │
  │ set requiredActions: UPDATE_PASSWORD,  │                      │
  │   CONFIGURE_TOTP, VERIFY_EMAIL         │                      │
  ├────────────────────────────────────────▶│                      │
  │                                        │                      │
  │ execute-actions-email                  │                      │
  ├────────────────────────────────────────▶│ via Resend SMTP     │
  │                                        │ Magic-Link-Email ───▶│
  │                                        │                      │
  │                                        │  ◀── User klickt Link │
  │                                        │                      │
  │                                        │ KC führt User durch:  │
  │                                        │  1. Passwort setzen   │
  │                                        │  2. TOTP scannen      │
  │                                        │  3. Email verify      │
  │                                        │                      │
  │                                        │  ◀── Login zur App   │
```

## Resend Setup (One-Time, ~10min)

### 1. Account anlegen
1. https://resend.com → Sign up (Free-Tier 3000/mo, 100/d)
2. Settings → API Keys → Create API Key → Name `keycloak-prod` → Permission `Send`
3. **API Key kopieren** (wird nur EINMAL angezeigt)

### 2. Domain verifizieren (`timourhomelab.org`)
1. Resend Dashboard → Domains → Add Domain → `timourhomelab.org`
2. Resend zeigt 3 DNS-Records (TXT für SPF/DKIM, optional MX für DMARC):
   ```
   resend._domainkey.timourhomelab.org   TXT   "p=MIGfMA0GCSqG..."
   timourhomelab.org                     TXT   "v=spf1 include:_spf.resend.com ~all"
   _dmarc.timourhomelab.org              TXT   "v=DMARC1; p=none;"
   ```
3. In Cloudflare Dashboard → DNS → 3 Records adden (Proxy: DNS only, NICHT proxied)
4. In Resend "Verify DNS Records" klicken → wartet ~2min auf Propagation
5. Status: **Verified ✓**

### 3. SealedSecret erstellen
```bash
CERT=tofu/bootstrap/sealed-secrets/certificate/sealed-secrets.crt
RESEND_KEY="re_xxxxxxxxxxxx"  # ← deine API-Key aus Step 1.3

kubectl create secret generic keycloak-smtp \
  --namespace=keycloak \
  --from-literal=user="resend" \
  --from-literal=password="$RESEND_KEY" \
  --from-literal=from="noreply@timourhomelab.org" \
  --from-literal=replyTo="noreply@timourhomelab.org" \
  --dry-run=client -o yaml | \
kubeseal --cert "$CERT" --format yaml --scope strict \
  > kubernetes/platform/identity/keycloak/base/smtp-sealed-secret.yaml
```

### 4. In Kustomization eintragen
`kubernetes/platform/identity/keycloak/base/kustomization.yaml`:
```yaml
resources:
  # ... existing ...
  - smtp-sealed-secret.yaml
```

### 5. Commit + push
```bash
git add kubernetes/platform/identity/keycloak/base/
git commit -m "kc smtp resend"
git push
```

ArgoCD synct → Keycloak-Pod restart (KC liest SMTP env-vars) → Realm-Import-Operator reconciliert SMTP-Block.

### 6. Verify
Im KC Admin-UI: `iam.timourhomelab.org/admin/master/console/` → Realm `kubernetes` → Realm Settings → Email Tab → `Test connection`. Test-Email an dich → muss in Postfach ankommen.

## Onboarding eines Mitarbeiters

```bash
./kubernetes/scripts/identity/onboard-user.sh max max@firma.de "Max Mustermann" engineers
```

Was passiert:
1. User in LLDAP erstellt
2. KC LDAP-Federation Sync
3. KC requiredActions: UPDATE_PASSWORD + CONFIGURE_TOTP + VERIFY_EMAIL
4. Resend sendet Welcome-Email an `max@firma.de`
5. Max klickt Link → führt durch Setup → kann sich einloggen

Email-Link ist **12h gültig**. Falls abgelaufen: Script nochmal laufen lassen.

## Self-Service-URLs für Mitarbeiter

| URL | Was |
|---|---|
| `https://iam.timourhomelab.org/realms/kubernetes/account/` | Account-Console: Passwort, MFA, Profile, Sessions |
| `https://argo.timourhomelab.org` | ArgoCD Login |
| `https://grafana.timourhomelab.org` | Grafana Login |
| `https://drova.timourhomelab.org` | Drova App Login |

**Forgot-Password-Flow** (resetPasswordAllowed=true):
1. Login-Seite → "Forgot Password?"
2. Email eingeben → KC sendet Reset-Link via Resend
3. User klickt → setzt neues Passwort

## Offboarding (Mitarbeiter verlässt Firma)

```bash
./kubernetes/scripts/identity/offboard-user.sh max
# (TODO: not yet implemented — disable in LLDAP + revoke KC sessions)
```

Bis Script existiert manuell:
```bash
# 1. LLDAP UI: User → Disable
# 2. KC: invalidate all sessions
kubectl exec -n keycloak keycloak-0 -- /opt/keycloak/bin/kcadm.sh delete \
  realms/kubernetes/users/<KCID>/logout
```

## Troubleshooting

### Email kommt nicht an
1. KC-Logs: `kubectl logs -n keycloak keycloak-0 | grep -i smtp`
2. Resend Dashboard → Logs → Error?
3. Cloudflare DNS-Records korrekt? (https://mxtoolbox.com/dkim.aspx)
4. Test in KC: Admin-UI → Realm Settings → Email → Test connection

### "Invalid action token"
Link abgelaufen (>12h). Onboarding-Script nochmal laufen lassen.

### User loggt sich ein OHNE TOTP (Bug 2026-05-09)
LDAP-Federation re-importiert hat TOTP-credential gewiped:
```bash
# Force CONFIGURE_TOTP requiredAction:
TID=$(kubectl exec -n keycloak keycloak-0 -- /opt/keycloak/bin/kcadm.sh \
  get users -r kubernetes -q username=$USERNAME --fields id 2>&1 | grep '"id"' | cut -d'"' -f4)
kubectl exec -n keycloak keycloak-0 -- /opt/keycloak/bin/kcadm.sh \
  update users/$TID -r kubernetes -s 'requiredActions=["CONFIGURE_TOTP"]'
```
