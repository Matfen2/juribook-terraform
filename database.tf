# ═══════════════════════════════════════════════════════════
#  Base de données managée — Scaleway RDB (PostgreSQL)
#
#  Une seule instance héberge les 5 bases applicatives (authdb,
#  lawyerdb, bookingdb, notificationdb, auditdb), même principe
#  que le docker-compose local mais sur une instance managée
#  mutualisée — chaque microservice garde sa base dédiée
#  (principe microservices respecté), seul le serveur physique
#  est mutualisé.
#
#  ⚠️ Cette instance n'a AUCUN endpoint public. Attacher un
#  private_network à une instance RDB Scaleway supprime son
#  endpoint public par défaut (comportement documenté du
#  produit, vérifié en pratique). RDB est donc injoignable
#  depuis l'extérieur du cluster — plus sécurisé que l'inverse,
#  mais ça veut dire que la création des extensions SQL
#  (uuid-ossp, pgcrypto, unaccent) doit se faire depuis
#  l'intérieur du cluster une fois déployé, pas depuis Terraform.
#  Voir le dépôt juribook-kubernetes (rdb-extensions-job.yaml).
# ═══════════════════════════════════════════════════════════

resource "scaleway_rdb_instance" "juribook" {
  name           = "${var.project_name}-postgres"
  node_type      = var.db_node_type
  engine         = var.db_engine
  is_ha_cluster  = false
  disable_backup = false

  user_name = var.db_admin_username
  password  = var.db_admin_password

  # ⚠️ "bssd" est déprécié côté API Scaleway (rejeté à l'apply).
  # Valeurs valides du provider : lssd, bssd, sbs_5k, sbs_15k.
  volume_type       = var.db_volume_type
  volume_size_in_gb = var.db_volume_size_gb

  private_network {
    pn_id = scaleway_vpc_private_network.juribook.id
    # ⚠️ Obligatoire : le provider exige explicitement soit
    # ip_net soit enable_ipam=true sur ce bloc, sinon erreur
    # "at least one of ip_net or enable_ipam must be set".
    enable_ipam = true
  }
}

# ── Bases applicatives ───────────────────────────────────────

resource "scaleway_rdb_database" "authdb" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "authdb"
}

resource "scaleway_rdb_database" "lawyerdb" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "lawyerdb"
}

resource "scaleway_rdb_database" "bookingdb" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "bookingdb"
}

resource "scaleway_rdb_database" "notificationdb" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "notificationdb"
}

resource "scaleway_rdb_database" "auditdb" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "auditdb"
}

# ── Utilisateur applicatif partagé (miroir du POSTGRES_USER local) ──

resource "scaleway_rdb_user" "app" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "juribook"
  password    = var.db_app_password
  is_admin    = false
}

resource "scaleway_rdb_privilege" "authdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app.name
  database_name = scaleway_rdb_database.authdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "lawyerdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app.name
  database_name = scaleway_rdb_database.lawyerdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "bookingdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app.name
  database_name = scaleway_rdb_database.bookingdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "notificationdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app.name
  database_name = scaleway_rdb_database.notificationdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "auditdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app.name
  database_name = scaleway_rdb_database.auditdb.name
  permission    = "all"
}
