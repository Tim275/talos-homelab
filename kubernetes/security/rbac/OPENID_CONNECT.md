# 🔐 OpenID Connect (OIDC) - Simple Erklärt

**Was ist OIDC?** Ein moderner Standard für **Login & Identity Management**

---

## 🤔 **Das Problem ohne OIDC**

### **Alte Methode: X.509 Certificates**

```bash
# User braucht Zugriff auf Kubernetes:
1. User erstellt Private Key
2. User erstellt Certificate Signing Request (CSR)
3. Admin signiert CSR manuell
4. User bekommt Certificate (gültig 1 Jahr)
5. User nutzt Certificate für kubectl

# Probleme:
❌ Manueller Prozess für jeden User
❌ Keine 2FA möglich
❌ Schwer zu widerrufen (Certificate läuft 1 Jahr)
❌ Keine zentrale User-Verwaltung
❌ Keine Gruppen-Mappings
```

### **Mit OIDC:**

```bash
# User braucht Zugriff auf Kubernetes:
1. User öffnet Browser
2. User loggt sich bei Authelia ein (Username + Password + 2FA)
3. Authelia gibt Token (gültig 1 Stunde)
4. kubectl nutzt Token automatisch

# Vorteile:
✅ Automatischer Login via Browser
✅ 2FA Support (TOTP, WebAuthn)
✅ Einfach widerrufen (User in LDAP deaktivieren)
✅ Zentrale User-Verwaltung (LLDAP)
✅ Automatische Gruppen-Mappings (LDAP → RBAC)
```

---

## 🏗️ **Wie OIDC funktioniert - Simple Version**

### **Die 3 Hauptkomponenten:**

```
┌─────────────┐         ┌──────────────┐         ┌────────────┐
│   Browser   │────────▶│   Authelia   │────────▶│ Kubernetes │
│   (User)    │         │ (OIDC Server)│         │ API Server │
└─────────────┘         └──────────────┘         └────────────┘
                               │
                               │
                         ┌─────▼──────┐
                         │   LLDAP    │
                         │ (Users DB) │
                         └────────────┘
```

#### **1. Browser (User Interface)**
- User sieht Login-Seite
- Gibt Username + Password ein
- Macht 2FA (z.B. Authenticator App)

#### **2. Authelia (OIDC Provider)**
- Prüft Username + Password gegen LLDAP
- Prüft 2FA Code
- Schaut welche LDAP-Gruppen User hat
- Erstellt **JWT Token** mit User-Info

#### **3. LLDAP (User Database)**
- Speichert alle Users (tim275, alice, bob)
- Speichert Gruppen (admins, developers)
- Speichert wer in welcher Gruppe ist

#### **4. Kubernetes API Server**
- Bekommt Token von kubectl
- Validiert Token gegen Authelia
- Extrahiert Username + Gruppen aus Token
- Prüft RBAC (darf User das?)
- Gibt Zugriff oder lehnt ab

---

## 🎫 **Was ist ein JWT Token?**

**JWT** = JSON Web Token = Digitaler Ausweis

### **Beispiel Token (vereinfacht):**

```json
{
  "iss": "https://authelia.homelab.local",  // Wer hat Token ausgestellt?
  "sub": "tim275",                           // Wer ist der User?
  "aud": "kubernetes",                       // Für welche App?
  "exp": 1727890800,                         // Wann läuft Token ab?
  "iat": 1727887200,                         // Wann wurde Token erstellt?

  // User-Informationen:
  "preferred_username": "tim275",
  "email": "tim275@homelab.local",
  "groups": ["admins", "developers"]
}
```

### **Token ist signiert:**
- Authelia signiert Token mit privatem Key
- Kubernetes prüft Signatur mit öffentlichem Key
- **Niemand kann Token fälschen!**

### **Token Ablauf:**
1. User loggt sich ein → bekommt Token
2. Token ist **1 Stunde** gültig
3. Nach 1 Stunde: kubelogin öffnet Browser automatisch
4. User loggt sich erneut ein → bekommt neuen Token

---

## 🔄 **Der komplette Login-Flow**

### **Step-by-Step was passiert:**

```bash
# Terminal:
$ kubectl get nodes
```

**1. kubectl prüft:** Habe ich ein Token? (schaut in `~/.kube/cache/`)
   - ❌ Nein → kubelogin starten
   - ✅ Ja, aber abgelaufen → kubelogin starten
   - ✅ Ja, noch gültig → direkt zu Step 9

**2. kubelogin öffnet Browser:**
   ```
   Opening browser at: https://authelia.homelab.local/api/oidc/authorization?...
   ```

**3. Browser zeigt Authelia Login:**
   ```
   Username: [tim275        ]
   Password: [**********    ]
   [Login]
   ```

**4. User gibt Credentials ein** und klickt Login

**5. Authelia fragt LLDAP:**
   ```
   Authelia → LLDAP: "Ist Password für tim275 korrekt?"
   LLDAP → Authelia: "Ja! User ist in Gruppen: [admins, developers]"
   ```

**6. Authelia zeigt 2FA Prompt:**
   ```
   Enter 2FA Code: [______]
   ```

**7. User gibt 2FA Code ein** (von Authenticator App)

**8. Authelia erstellt JWT Token:**
   ```json
   {
     "preferred_username": "tim275",
     "groups": ["admins", "developers"],
     "exp": 1727890800
   }
   ```

   Authelia sendet Token zurück zu kubelogin

**9. kubelogin speichert Token:**
   ```bash
   ~/.kube/cache/oidc-login/
   └── token-cache-kubernetes.json
   ```

**10. kubectl sendet Request:**
   ```http
   GET /api/v1/nodes
   Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

**11. Kubernetes API Server empfängt Request:**
   - Extrahiert Token aus `Authorization` header
   - Validiert Token gegen Authelia (Signatur prüfen)
   - Extrahiert Claims aus Token:
     ```
     Username: tim275
     Groups: [admins, developers]
     ```

**12. API Server macht Prefix Mapping:**
   ```
   Username: tim275      → oidc:tim275
   Groups: [admins]      → [oidc:admins]
   ```

**13. API Server prüft RBAC:**
   ```bash
   # Sucht ClusterRoleBindings für:
   - User: oidc:tim275
   - Group: oidc:admins

   # Findet:
   ClusterRoleBinding "oidc-admins-group-cluster-admin"
   → grants role: cluster-admin
   ```

**14. RBAC erlaubt Zugriff:**
   ```
   User oidc:tim275 (via group oidc:admins)
   → has cluster-admin role
   → can list nodes ✅
   ```

**15. kubectl zeigt Ergebnis:**
   ```
   NAME     STATUS   ROLES           AGE
   cp-01    Ready    control-plane   30d
   w-01     Ready    <none>          30d
   ...
   ```

---

## 🔑 **OIDC vs Certificates - Vergleich**

| Feature | X.509 Certificates | OIDC (Authelia) |
|---------|-------------------|-----------------|
| **Login-Methode** | Certificate File | Browser Login |
| **Username** | CN im Certificate | LDAP Username |
| **Passwort** | Kein Passwort | LDAP Passwort |
| **2FA** | ❌ Nicht möglich | ✅ TOTP, WebAuthn |
| **Token Dauer** | 1 Jahr | 1 Stunde |
| **Automatische Erneuerung** | ❌ Manuell | ✅ Browser re-auth |
| **Widerrufen** | ❌ Schwierig (CRL) | ✅ LDAP User disable |
| **Gruppen** | ❌ Manuell in CN | ✅ Automatisch (LDAP) |
| **Zentrale Verwaltung** | ❌ Pro User CSR | ✅ LLDAP Dashboard |
| **Audit Log** | Nur kubectl | Authelia + kubectl |
| **Best For** | CI/CD, Automation | Human Users |

---

## 🎯 **Die wichtigsten OIDC Begriffe**

### **1. Issuer (Aussteller)**
- **Was**: Der OIDC Server (bei uns: Authelia)
- **URL**: `https://authelia.homelab.local`
- **Aufgabe**: Token ausstellen & validieren

### **2. Client (Anwendung)**
- **Was**: Die App die OIDC nutzt (bei uns: Kubernetes)
- **Client ID**: `kubernetes`
- **Aufgabe**: Token von Issuer anfordern

### **3. Claims (Behauptungen)**
- **Was**: Informationen im Token
- **Beispiele**:
  - `preferred_username`: tim275
  - `email`: tim275@homelab.local
  - `groups`: [admins]
- **Aufgabe**: Kubernetes weiß wer der User ist

### **4. Scopes (Berechtigungen)**
- **Was**: Welche Claims darf Client sehen?
- **Beispiele**:
  - `openid`: Basis-Info (Sub, Issuer)
  - `profile`: Username, Name
  - `email`: Email-Adresse
  - `groups`: LDAP-Gruppen
- **Aufgabe**: Datenschutz (nur nötige Infos)

### **5. Redirect URI**
- **Was**: Wohin geht User nach Login?
- **Beispiel**: `urn:ietf:wg:oauth:2.0:oob`
- **Bedeutung**: "Out of Band" = zeige Token im Browser
- **Aufgabe**: kubelogin kann Token abholen

---

## 🛡️ **Sicherheit - Wie sicher ist OIDC?**

### **✅ Was macht OIDC sicher:**

**1. Token Signatur:**
- Token ist mit RSA oder ECDSA signiert
- Nur Authelia hat private Key
- Kubernetes prüft mit public Key
- → **Fälschen unmöglich**

**2. Token Expiration:**
- Token läuft nach 1 Stunde ab
- Auch wenn Token geklaut wird: nur 1 Stunde gültig
- → **Zeitlich begrenzte Gefahr**

**3. HTTPS Pflicht:**
- Authelia MUSS HTTPS nutzen
- Token wird verschlüsselt übertragen
- → **Kein Mithören möglich**

**4. 2FA Support:**
- Zusätzlicher Code vom Handy
- Auch wenn Passwort geklaut: 2FA schützt
- → **Zwei Faktoren nötig**

**5. Zentrale User-Verwaltung:**
- User in LLDAP deaktivieren → sofort kein Zugriff
- Keine veralteten Certificates (1 Jahr gültig)
- → **Schnelles Widerrufen**

### **⚠️ Was du beachten musst:**

**1. Authelia TLS Certificate:**
- ❌ Self-signed = unsicher
- ✅ Let's Encrypt via cert-manager = sicher

**2. Token Caching:**
- Tokens in `~/.kube/cache/` gespeichert
- → **Laptop verschlüsseln!** (FileVault, LUKS)

**3. Browser Security:**
- Öffentlicher Computer = **NICHT** kubectl nutzen
- Token bleibt im Browser Cache
- → **Nur eigener Computer**

**4. LLDAP Admin Password:**
- Starkes Password nutzen
- LLDAP Admin = Zugriff auf alle User
- → **Passwort-Manager**

---

## 🔧 **Praktisches Beispiel**

### **Szenario: Neuer Developer "Alice" braucht Zugriff**

**Mit Certificates (Alter Weg):**
```bash
# Alice macht:
openssl genrsa -out alice.key 2048
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice"

# Alice schickt alice.csr an Admin

# Admin macht:
openssl x509 -req -in alice.csr -CA ca.crt -CAkey ca.key -out alice.crt
# Admin schickt alice.crt zurück an Alice

# Alice macht:
kubectl config set-credentials alice --client-certificate=alice.crt --client-key=alice.key

# Problem: Kein 2FA, kein LDAP, läuft 1 Jahr, manueller Prozess
```

**Mit OIDC (Neuer Weg):**
```bash
# Admin macht (in LLDAP Dashboard):
1. User "alice" erstellen
2. User zu Gruppe "developers" hinzufügen
3. Fertig!

# Alice macht:
brew install int128/kubelogin/kubelogin
kubectl config set-credentials oidc-user --exec-command=kubectl --exec-arg=oidc-login ...
kubectl get pods
# Browser öffnet → Login → 2FA → Fertig!

# Vorteile: 2FA, LDAP-managed, 1h Token, automatisch
```

### **Szenario: Alice verlässt Firma**

**Mit Certificates:**
```bash
# Admin muss:
1. Certificate Revocation List (CRL) erstellen
2. CRL auf allen Nodes verteilen
3. kube-apiserver neu starten
# Oder: 1 Jahr warten bis Certificate abläuft

# Problem: Kompliziert, Alice hat noch Zugriff!
```

**Mit OIDC:**
```bash
# Admin macht (in LLDAP Dashboard):
1. User "alice" deaktivieren
2. Fertig!

# Alice kann sofort nicht mehr einloggen
# Alter Token läuft nach max 1 Stunde ab

# Vorteil: Sofortige Wirkung, einfach
```

---

## 📊 **OIDC Architecture in diesem Homelab**

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                   │
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │           kube-apiserver (Control Plane)       │    │
│  │                                                │    │
│  │  OIDC Config:                                  │    │
│  │  - issuer-url: https://authelia.homelab.local │    │
│  │  - client-id: kubernetes                      │    │
│  │  - username-claim: preferred_username         │    │
│  │  - groups-claim: groups                       │    │
│  │  - username-prefix: oidc:                     │    │
│  │  - groups-prefix: oidc:                       │    │
│  └────────────────────────────────────────────────┘    │
│                          │                             │
│                          │ validates JWT               │
│                          │                             │
│  ┌───────────────────────▼──────────────────────┐      │
│  │         RBAC (ClusterRoleBindings)          │      │
│  │                                             │      │
│  │  subjects:                                  │      │
│  │  - kind: User                               │      │
│  │    name: oidc:tim275                        │      │
│  │  roleRef:                                   │      │
│  │    kind: ClusterRole                        │      │
│  │    name: cluster-admin                      │      │
│  └─────────────────────────────────────────────┘      │
│                                                        │
└────────────────────────────────────────────────────────┘
                          ▲
                          │ JWT Token
                          │
┌─────────────────────────┴──────────────────────────────┐
│                   kubectl (User's Laptop)              │
│                                                        │
│  kubelogin:                                            │
│  - Opens browser for login                             │
│  - Receives JWT token from Authelia                    │
│  - Caches token locally (~/.kube/cache/)               │
│  - Sends token with kubectl requests                   │
│                                                        │
└────────────────────────────────────────────────────────┘
                          ▲
                          │ Login via Browser
                          │
┌─────────────────────────┴──────────────────────────────┐
│         Authelia (OIDC Provider) - Platform Layer      │
│                                                        │
│  - Receives login request                              │
│  - Shows login page (username + password)              │
│  - Validates credentials against LLDAP                 │
│  - Shows 2FA prompt (TOTP)                             │
│  - Queries LDAP groups for user                        │
│  - Creates JWT token with claims                       │
│  - Signs token with private key                        │
│  - Returns token to kubelogin                          │
│                                                        │
└────────────────────────────────────────────────────────┘
                          ▲
                          │ LDAP Query
                          │
┌─────────────────────────┴──────────────────────────────┐
│              LLDAP (User Directory) - Platform Layer   │
│                                                        │
│  Users:                                                │
│  - tim275 (password hash, 2FA secret)                  │
│  - alice (password hash, 2FA secret)                   │
│                                                        │
│  Groups:                                               │
│  - admins: [tim275]                                    │
│  - developers: [alice]                                 │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 🚀 **TL;DR - Das Wichtigste**

### **Was ist OIDC?**
Moderner Login-Standard für Kubernetes (statt Certificates)

### **Warum OIDC nutzen?**
- ✅ Browser-Login statt Certificate-Files
- ✅ 2FA Support
- ✅ Zentrale User-Verwaltung (LLDAP)
- ✅ Automatische Gruppen (LDAP → RBAC)
- ✅ Einfach widerrufen (User deaktivieren)

### **Wie funktioniert's?**
1. User öffnet kubectl
2. Browser öffnet → Authelia Login
3. User gibt Username + Password + 2FA ein
4. Authelia fragt LLDAP nach User-Gruppen
5. Authelia gibt JWT Token zurück
6. kubectl nutzt Token für API-Requests
7. Kubernetes validiert Token & prüft RBAC

### **3-Layer Architecture:**
- **Infrastructure**: kube-apiserver OIDC config
- **Platform**: Authelia + LLDAP services
- **Security**: RBAC ClusterRoleBindings

### **Token Lifetime:**
- 1 Stunde gültig
- Automatische Browser-Erneuerung
- Cached in `~/.kube/cache/`

---

**That's it!** OIDC ist einfach moderner Login für Kubernetes 🎉
