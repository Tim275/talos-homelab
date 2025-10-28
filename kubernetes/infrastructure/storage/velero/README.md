# Velero Enterprise Backup System

**Status**: ✅ **PRODUCTION READY**
**Last Updated**: 2025-10-28
**Implementation**: 40+ hours to perfection

---

## 🎯 **Quick Status**

```
✅ Restic File System Backup (Production-Approved)
✅ 3-Tier Schedule Active (6h / 24h / 168h)
✅ Client-Side AES-256 Encryption
✅ Latest Backup: 2025-10-28T06:00:11Z
✅ Errors: 0 | Warnings: 0 | Items: 316
```

---

## 📚 **Documentation**

### **🔥 PRIMARY DOCS (READ THIS FIRST!)**
**[PRODUCTION_RESTIC_BACKUP.md](./PRODUCTION_RESTIC_BACKUP.md)** - Complete production setup guide
- Architecture & data flow
- Why Restic (not Kopia)
- Why NO CephFS needed
- 3-Tier schedule details
- Troubleshooting (40h lessons learned)
- Restore procedures

### **Supporting Docs:**
- `VELERO.md` - Original architecture overview (outdated, kept for reference)
- `CURRENT_BACKUP_STATUS.md` - Previous status (pre-Restic implementation)
- `BACKUP_STRATEGY.md` - Strategy planning
- `RESTORE_GUIDE.md` - Restore procedures

---

## ⚡ **Quick Commands**

### **Check Backup Status:**
```bash
# Schedules
kubectl get schedules.velero.io -n velero

# Latest backups
kubectl get backups.velero.io -n velero --sort-by=.metadata.creationTimestamp | tail -10

# Pod volume backups (Restic)
kubectl get podvolumebackups.velero.io -n velero | grep Completed
```

### **Trigger Manual Backup:**
```bash
# n8n-prod full backup
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-n8n-prod-$(date +%Y%m%d-%H%M)
  namespace: velero
spec:
  includedNamespaces:
    - n8n-prod
  storageLocation: cluster-backups
  defaultVolumesToFsBackup: true
  ttl: 24h
EOF
```

### **Restore from Backup:**
```bash
# List backups
kubectl get backups.velero.io -n velero

# Restore n8n-prod
velero restore create n8n-restore-$(date +%Y%m%d-%H%M) \
  --from-backup tier0-n8n-prod-<timestamp> \
  --wait
```

---

## 🔐 **Security**

**Multi-Layer Encryption:**
1. **Client-Side** (Restic AES-256) - BEFORE upload
2. **Network** (Kubernetes internal mesh)
3. **At-Rest** (Ceph wire encryption)

**Result**: S3 bucket könnte public sein - data bleibt encrypted!

---

## 📊 **Current Deployment**

### **Active Schedules:**

| Tier | Application | Schedule | Retention |
|------|-------------|----------|-----------|
| 🔴 **Tier-0** | n8n-prod, Keycloak, Infisical, Authelia, LLDAP | Every 6h | 7 days |
| 🟡 **Tier-1** | n8n-dev, Grafana | Daily | 30 days |
| 🟢 **Tier-2** | Sealed Secrets, Cert Manager | Weekly | 90 days |

### **Storage:**
- **Backend**: Ceph RGW S3 (on-premises)
- **Bucket**: `velero-cluster-backups`
- **Size**: ~10.5 GB (incremental with deduplication)
- **Replication**: 3x within Ceph

---

## 🚫 **What We DON'T Use (And Why)**

### **❌ Kopia**
**Why**: Bug #8067 - Permission denied with random UIDs (unresolved since 2023)

### **❌ CSI Volume Snapshots**
**Why**: CSI triggers Kopia instead of Restic (workaround: disable CSI completely)

### **❌ CephFS**
**Why**: NOT NEEDED! Restic works with Ceph RBD block storage

---

## 🛠️ **Configuration Files**

```
kubernetes/infrastructure/storage/velero/
├── kustomization.yaml                    # Main Velero config (CSI disabled, Restic enabled)
├── sealed-secret-s3.yaml                 # S3 credentials
├── velero-restic-credentials-sealedsecret.yaml  # Restic encryption key
└── patches/
    └── upgrade-job-initcontainer-resources.yaml

kubernetes/infrastructure/storage/velero-schedules/
├── backup-schedules.yaml                 # Tier-0/1/2 schedules
├── kustomization.yaml
└── velero-schedules-app.yaml            # ArgoCD Application
```

---

## 🎓 **Key Lessons (40+ Hours)**

1. ✅ **Restic > Kopia** for production (no permission issues)
2. ✅ **Disable CSI** when using Restic (avoid conflicts)
3. ✅ **No CephFS needed** (works with RBD block storage)
4. ✅ **Tier-based schedules** better than frequency-based
5. ✅ **Remove snapshotMoveData** from schedules (requires CSI)

---

## 📈 **Success Metrics**

- ✅ 8 schedules enabled and running
- ✅ Latest backup: Completed (0 errors, 0 warnings)
- ✅ 7 pod volumes backed up for n8n-prod
- ✅ S3 bucket receiving encrypted data
- ✅ Production-approved method (VMware Tanzu official)
- ✅ GitOps managed (ArgoCD IaC)

---

## 🔗 **Related Systems**

- **Storage Backend**: [Rook-Ceph](../rook-ceph/) (RBD block storage)
- **GitOps**: [ArgoCD](../../argocd/) (automated sync)
- **Monitoring**: Velero metrics → Prometheus (future)

---

## 🚀 **Next Steps (Optional)**

- [ ] Add Prometheus alerts for backup failures
- [ ] Implement monthly restore testing CronJob
- [ ] Add Grafana dashboard (Velero official #11055)
- [ ] Consider offsite DR (AWS S3) - ~$50/month

---

## 📞 **Support**

**Issues?** Check `PRODUCTION_RESTIC_BACKUP.md` → Troubleshooting section

**Questions?**
- [Velero Official Docs](https://velero.io/docs/)
- [Restic Documentation](https://restic.net/)
- [GitHub Discussions](https://github.com/vmware-tanzu/velero/discussions)

---

**Maintainer**: Tim275
**Repo**: [talos-homelab](https://github.com/Tim275/talos-homelab)
**Status**: 🚀 **LIVE & BACKING UP!**
