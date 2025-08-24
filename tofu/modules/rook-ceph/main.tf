terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
    }
  }
}

# Rook-Ceph Operator Helm Release
resource "helm_release" "rook_ceph" {
  name             = "rook-ceph"
  namespace        = "rook-ceph"
  create_namespace = true
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  version          = var.rook_version

  values = [
    templatefile("${path.module}/values.yaml", {
      ceph_version     = var.ceph_version
      node_selector    = var.node_selector
      resource_limits  = var.resource_limits
      monitoring       = var.enable_monitoring
    })
  ]

  set {
    name  = "csi.enableRbdDriver"
    value = "true"
  }

  set {
    name  = "csi.enableCephfsDriver"
    value = "true"
  }

  set {
    name  = "enableDiscoveryDaemon"
    value = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CephCluster CRD
resource "kubernetes_manifest" "ceph_cluster" {
  depends_on = [helm_release.rook_ceph]

  manifest = {
    apiVersion = "ceph.rook.io/v1"
    kind       = "CephCluster"
    metadata = {
      name      = var.cluster_name
      namespace = "rook-ceph"
      labels = {
        "app.kubernetes.io/name"       = "rook-ceph"
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "storage"
      }
    }
    spec = {
      cephVersion = {
        image            = "quay.io/ceph/ceph:v${var.ceph_version}"
        allowUnsupported = false
      }
      
      dataDirHostPath = "/var/lib/rook"
      
      mon = {
        count                = var.mon_count
        allowMultiplePerNode = false
      }
      
      mgr = {
        count                = 2
        allowMultiplePerNode = false
        modules = [
          { name = "pg_autoscaler", enabled = true },
          { name = "balancer", enabled = true },
          { name = "prometheus", enabled = var.enable_monitoring }
        ]
      }
      
      dashboard = {
        enabled = var.enable_dashboard
        ssl     = false
      }
      
      monitoring = {
        enabled = var.enable_monitoring
      }
      
      network = {
        provider = "host"
      }
      
      crashCollector = {
        disable = false
      }
      
      cleanupPolicy = {
        confirmation = ""
      }
      
      resources = {
        mgr = {
          limits = {
            cpu    = "${var.resource_limits.mgr.cpu}"
            memory = "${var.resource_limits.mgr.memory}"
          }
          requests = {
            cpu    = "100m"
            memory = "512Mi"
          }
        }
        mon = {
          limits = {
            cpu    = "${var.resource_limits.mon.cpu}"
            memory = "${var.resource_limits.mon.memory}"
          }
          requests = {
            cpu    = "100m"
            memory = "512Mi"
          }
        }
        osd = {
          limits = {
            cpu    = "${var.resource_limits.osd.cpu}"
            memory = "${var.resource_limits.osd.memory}"
          }
          requests = {
            cpu    = "500m"
            memory = "2Gi"
          }
        }
      }
      
      removeOSDsIfOutAndSafeToRemove = true
      
      storage = {
        useAllNodes   = false
        useAllDevices = false
        nodes         = var.storage_nodes
      }
      
      healthCheck = {
        daemonHealth = {
          mon = {
            disabled = false
            interval = "45s"
          }
          osd = {
            disabled = false
            interval = "60s"
          }
          status = {
            disabled = false
            interval = "60s"
          }
        }
      }
      
      disruptionManagement = {
        managePodBudgets       = true
        osdMaintenanceTimeout  = 30
        pgHealthCheckTimeout   = 0
      }
      
      placement = {
        all = {
          tolerations = [
            { effect = "NoSchedule", operator = "Exists" },
            { effect = "NoExecute", operator = "Exists" }
          ]
        }
        mon = {
          podAntiAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = [{
              labelSelector = {
                matchLabels = {
                  app = "rook-ceph-mon"
                }
              }
              topologyKey = "kubernetes.io/hostname"
            }]
          }
        }
        mgr = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [{
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    app = "rook-ceph-mgr"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }]
          }
        }
        osd = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [{
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    app = "rook-ceph-osd"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }]
          }
        }
      }
    }
  }
}

# Storage Classes
resource "kubernetes_storage_class" "ceph_block" {
  metadata {
    name = "ceph-block"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  
  storage_provisioner    = "rook-ceph.rbd.csi.ceph.com"
  reclaim_policy        = "Delete"
  allow_volume_expansion = true
  volume_binding_mode   = "Immediate"
  
  parameters = {
    clusterID                                       = var.cluster_name
    pool                                           = "replicapool"
    imageFormat                                    = "2"
    imageFeatures                                  = "layering"
    "csi.storage.k8s.io/provisioner-secret-name"      = "rook-csi-rbd-provisioner"
    "csi.storage.k8s.io/provisioner-secret-namespace" = "rook-ceph"
    "csi.storage.k8s.io/controller-expand-secret-name" = "rook-csi-rbd-provisioner"
    "csi.storage.k8s.io/controller-expand-secret-namespace" = "rook-ceph"
    "csi.storage.k8s.io/node-stage-secret-name"      = "rook-csi-rbd-node"
    "csi.storage.k8s.io/node-stage-secret-namespace" = "rook-ceph"
    "csi.storage.k8s.io/fstype"                      = "ext4"
  }
}

# CephBlockPool
resource "kubernetes_manifest" "ceph_block_pool" {
  depends_on = [kubernetes_manifest.ceph_cluster]

  manifest = {
    apiVersion = "ceph.rook.io/v1"
    kind       = "CephBlockPool"
    metadata = {
      name      = "replicapool"
      namespace = "rook-ceph"
    }
    spec = {
      failureDomain = "host"
      replicated = {
        size                   = var.replication_factor
        requireSafeReplicaSize = true
      }
      parameters = {
        min_size              = "2"
        pg_num                = "32"
        pgp_num               = "32"
        compression_algorithm = "lz4"
        compression_mode      = "aggressive"
      }
    }
  }
}