# ═══════════════════════════════════════════════════════════
#  Kubernetes — Kapsule (managé, control plane gratuit)
#
#  auto_upgrade DÉSACTIVÉ délibérément : quand il est activé,
#  Scaleway exige un format de version x.y (sans patch) ; quand
#  il est désactivé, il exige au contraire le patch complet
#  x.y.z. Les deux contraintes se sont contredites en test
#  réel selon l'état d'auto_upgrade. Le désactiver lève
#  l'ambiguïté et laisse le contrôle explicite de la version —
#  suffisant pour un usage portfolio où les mises à jour
#  automatiques ne sont pas critiques.
# ═══════════════════════════════════════════════════════════

resource "scaleway_k8s_cluster" "juribook" {
  name    = "${var.project_name}-kapsule"
  type    = "kapsule"
  version = var.k8s_version
  cni     = "cilium"

  private_network_id = scaleway_vpc_private_network.juribook.id

  delete_additional_resources = true

  autoscaler_config {
    ignore_daemonsets_utilization = true
    balance_similar_node_groups   = true
  }

  auto_upgrade {
    enable                        = false
    maintenance_window_day        = "sunday"
    maintenance_window_start_hour = 2
  }
}

resource "scaleway_k8s_pool" "default" {
  cluster_id = scaleway_k8s_cluster.juribook.id
  name       = "${var.project_name}-pool"

  # ⚠️ DEV1-M s'est révélé insuffisant en pratique (OOMKilled) —
  # voir variables.tf pour le détail. DEV1-L par défaut.
  node_type = var.k8s_node_type

  size        = var.k8s_pool_size
  min_size    = var.k8s_pool_min_size
  max_size    = var.k8s_pool_max_size
  autoscaling = true
  autohealing = true

  wait_for_pool_ready = true
}
