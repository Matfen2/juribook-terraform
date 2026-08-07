# ═══════════════════════════════════════════════════════════
#  Base de données managée - Scaleway RDB (PostgreSQL)
#
#  Une seule instance héberge les 5 bases applicatives (authdb,
#  lawyerdb, bookingdb, notificationdb, auditdb), même principe
#  que le docker-compose local mais sur une instance managée
#  mutualisée, chaque microservice garde sa base dédiée
#  (principe microservices respecté), seul le serveur physique
#  est mutualisé.
#
#  ⚠️ Cette instance n'a AUCUN endpoint public. Attacher un
#  private_network à une instance RDB Scaleway supprime son
#  endpoint public par défaut (comportement documenté du
#  produit, vérifié en pratique). RDB est donc injoignable
#  depuis l'extérieur du cluster, plus sécurisé que l'inverse,
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

# ═══════════════════════════════════════════════════════════
#  Bases de PRODUCTION
#
#  Même instance RDB que le staging (isolation partielle,
#  compromis coût assumé pour ce projet), mais bases et
#  utilisateur applicatif SÉPARÉS du staging. Un incident ou
#  une erreur de manipulation sur les données de staging ne
#  peut pas toucher les données de production, et inversement
#  — seule la ressource physique (l'instance RDB elle-même)
#  est mutualisée.
# ═══════════════════════════════════════════════════════════

resource "scaleway_rdb_database" "authdb_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "authdb_prod"
}

resource "scaleway_rdb_database" "lawyerdb_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "lawyerdb_prod"
}

resource "scaleway_rdb_database" "bookingdb_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "bookingdb_prod"
}

resource "scaleway_rdb_database" "notificationdb_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "notificationdb_prod"
}

resource "scaleway_rdb_database" "auditdb_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "auditdb_prod"
}

# Utilisateur applicatif dédié à la production, distinct de
# l'utilisateur "juribook" du staging — une fuite ou une
# mauvaise config d'un environnement ne donne pas accès à
# l'autre.
resource "scaleway_rdb_user" "app_prod" {
  instance_id = scaleway_rdb_instance.juribook.id
  name        = "juribook_prod"
  password    = var.db_prod_app_password
  is_admin    = false
}

resource "scaleway_rdb_privilege" "authdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app_prod.name
  database_name = scaleway_rdb_database.authdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "lawyerdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app_prod.name
  database_name = scaleway_rdb_database.lawyerdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "bookingdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app_prod.name
  database_name = scaleway_rdb_database.bookingdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "notificationdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app_prod.name
  database_name = scaleway_rdb_database.notificationdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "auditdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = scaleway_rdb_user.app_prod.name
  database_name = scaleway_rdb_database.auditdb_prod.name
  permission    = "all"
}

# ═══════════════════════════════════════════════════════════
#  Privilège explicite pour l'admin RDB sur toutes les bases
#
#  Découverte en pratique : même l'utilisateur admin de
#  l'instance (var.db_admin_username) n'a pas automatiquement
#  le droit CONNECT sur les bases créées ensuite via l'API de
#  gestion Scaleway ("permission denied for database ... User
#  does not have CONNECT privilege"). Nécessaire pour que les
#  Jobs de création d'extensions SQL (rdb-extensions-job*.yaml,
#  dépôt juribook-kubernetes) puissent s'y connecter.
# ═══════════════════════════════════════════════════════════

resource "scaleway_rdb_privilege" "admin_authdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.authdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_lawyerdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.lawyerdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_bookingdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.bookingdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_notificationdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.notificationdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_auditdb" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.auditdb.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_authdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.authdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_lawyerdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.lawyerdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_bookingdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.bookingdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_notificationdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.notificationdb_prod.name
  permission    = "all"
}

resource "scaleway_rdb_privilege" "admin_auditdb_prod" {
  instance_id   = scaleway_rdb_instance.juribook.id
  user_name     = var.db_admin_username
  database_name = scaleway_rdb_database.auditdb_prod.name
  permission    = "all"
}