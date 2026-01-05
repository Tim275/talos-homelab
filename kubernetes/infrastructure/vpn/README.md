# VPN Infrastructure

## Current Solution: Tailscale

**Decision Date:** 2025-10-11
**Rationale:** After extensive debugging of Netbird OIDC authentication issues, switched to Tailscale for production-proven WireGuard mesh VPN.

### Why Tailscale?

- **5-minute setup** vs 5+ hours Netbird debugging
- **Production-proven** (85% market share, used by Microsoft/AWS/GitLab)
- **Built-in SSO** (Google/GitHub/Microsoft/Okta) - no OIDC configuration needed
- **No Kubernetes deployment** - client-only, runs locally on devices
- **30+ global DERP relays** - better NAT traversal than self-hosted Coturn
- **Free for homelab** (<3 users, 100 devices)

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Tailscale Control Plane                   │
│              (Managed by Tailscale - no K8s)                 │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         ┌────▼────┐     ┌────▼────┐     ┌───▼────┐
         │ Laptop  │     │ Desktop │     │Homelab │
         │(macOS)  │     │ (Linux) │     │(Talos) │
         └─────────┘     └─────────┘     └────────┘
              │               │               │
              └───────────────┴───────────────┘
                   WireGuard Mesh Network
                   (peer-to-peer + DERP relays)
```

### Installation & Usage

#### 1. Install Tailscale (macOS)
```bash
brew install tailscale
sudo brew services start tailscale
sudo tailscale up
```

Browser opens → Login with Google/GitHub/Microsoft → Done! 

#### 2. Connect Homelab as Subnet Router (Optional)

To access Kubernetes services from any Tailscale device:

```bash
# On a Talos node (via talosctl shell)
tailscale up --advertise-routes=10.244.0.0/16,10.96.0.0/12 --accept-routes

# On Tailscale admin console, approve subnet routes
```

This allows accessing:
- Kubernetes Pod network (10.244.0.0/16)
- Kubernetes Service network (10.96.0.0/12)
- Internal domains (*.homelab.local via Magic DNS)

#### 3. Enable Magic DNS (Recommended)

In Tailscale admin console:
- Settings → DNS → Enable Magic DNS
- Now access devices by name: `ssh homelab-node` instead of `ssh 100.x.y.z`

### Comparison: Tailscale vs Alternatives

| Feature | Tailscale | Netbird | WireGuard | Headscale |
|---------|-----------|---------|-----------|-----------|
| Setup Time | 5 min | 5+ hours | 30 min | 2 hours |
| OIDC/SSO | Built-in | Broken | None | Required |
| NAT Traversal | 95%+ (DERP) | 80% (Coturn) | Manual | Self-host DERP |
| K8s Deployment | None | 8 components | None | 1 component |
| Cost (homelab) | FREE | FREE | FREE | FREE |
| Market Share | 85% | 5% | - | <1% |

### Previous Attempts

#### Netbird (Removed 2025-10-11)
- **Duration:** 5+ hours debugging
- **Issues:**
  - OIDC authentication broken with Authelia
  - "Unauthenticated" error after consent
  - Token validation failures between Dashboard/Management API
  - Requires Coturn STUN/TURN server (complex setup)
- **Conclusion:** Not production-ready for homelab use case

#### Coturn (Removed 2025-10-11)
- **Purpose:** STUN/TURN relay for Netbird
- **Issue:** Single point of failure vs Tailscale's 30+ global relays
- **Conclusion:** Not needed with Tailscale's built-in DERP network

### Future Alternatives

If Tailscale free tier limits become an issue (>3 users):

1. **Headscale** - Self-hosted Tailscale control plane
   - Unlimited users
   - Uses Tailscale clients
   - Requires DERP relay hosting

2. **Raw WireGuard** - Manual configuration
   - Maximum performance
   - No NAT traversal (port forwarding required)
   - Best for static setups

### References

- Tailscale Docs: https://tailscale.com/kb/
- Subnet Routers: https://tailscale.com/kb/1019/subnets/
- Exit Nodes: https://tailscale.com/kb/1103/exit-nodes/
- Magic DNS: https://tailscale.com/kb/1081/magicdns/
