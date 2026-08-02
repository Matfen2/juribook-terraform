# ═══════════════════════════════════════════════════════════
#  Variables d'entrée
#  Copie terraform.tfvars.example en terraform.tfvars et adapte
#  les valeurs. Ne jamais committer terraform.tfvars (secrets).
# ═══════════════════════════════════════════════════════════

variable "scw_region" {
  description = "Région Scaleway"
  type        = string
  default     = "fr-par"
}

variable "scw_zone" {
  description = "Zone Scaleway. fr-par-1 recommandée pour la compatibilité RDB + Private Network."
  type        = string
  default     = "fr-par-1"
}

variable "project_id" {
  description = "ID du Project Scaleway (Organization Dashboard > Projects > crée un Project \"juribook\" si besoin, copie son ID)."
  type        = string
}

variable "environment" {
  description = "Nom de l'environnement (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment doit être l'un de : dev, staging, production."
  }
}

variable "project_name" {
  description = "Préfixe utilisé pour nommer les ressources"
  type        = string
  default     = "juribook"
}

# ── Kubernetes (Kapsule) ──────────────────────────────────────
# Le control plane Kapsule est gratuit chez Scaleway (contrairement
# à EKS chez AWS, facturé à l'heure) — seul le coût des nœuds
# du pool s'applique.

variable "k8s_version" {
  description = "Version de Kubernetes pour le cluster Kapsule (format complet x.y.z). ⚠️ Vérifie la liste réelle des versions disponibles dans la console AVANT d'appliquer (Containers > Kubernetes > Create Cluster > menu déroulant de version) — l'API rejette les versions non listées, et la liste évolue régulièrement. La valeur par défaut ci-dessous peut être obsolète au moment où tu lis ceci."
  type        = string
  default     = "1.36.1"
}

variable "k8s_node_type" {
  description = "Type d'instance pour les nœuds du pool. ⚠️ DEV1-S, PLAY2-PICO et STARDUST sont explicitement exclus par Scaleway (mémoire insuffisante). DEV1-M (4 Go RAM) est techniquement accepté mais s'est révélé insuffisant en pratique : Kafka + 6 microservices Java + MailHog tournant simultanément dépassent 4 Go cumulés, causant des OOMKilled aléatoires observés en test réel. DEV1-L (8 Go RAM, ~30€/mois) est le minimum recommandé pour ce projet."
  type        = string
  default     = "DEV1-L"
}

variable "k8s_pool_size" {
  description = "Nombre de nœuds au démarrage"
  type        = number
  default     = 1
}

variable "k8s_pool_min_size" {
  description = "Nombre minimum de nœuds (autoscaling)"
  type        = number
  default     = 1
}

variable "k8s_pool_max_size" {
  description = "Nombre maximum de nœuds (autoscaling)"
  type        = number
  default     = 3
}

# ── Base de données managée (RDB) ─────────────────────────────

variable "db_node_type" {
  description = "Type d'instance RDB. DB-DEV-S est le plus économique, adapté à un environnement de dev/portfolio."
  type        = string
  default     = "DB-DEV-S"
}

variable "db_engine" {
  description = "Moteur et version PostgreSQL"
  type        = string
  default     = "PostgreSQL-16"
}

variable "db_volume_type" {
  description = "Type de volume RDB. ⚠️ 'bssd' est déprécié par Scaleway (l'API le rejette). Valeurs acceptées par le provider : lssd, bssd, sbs_5k, sbs_15k. sbs_5k est le tier économique recommandé."
  type        = string
  default     = "sbs_5k"
}

variable "db_volume_size_gb" {
  description = "Taille du volume de stockage en Go"
  type        = number
  default     = 10
}

variable "db_admin_username" {
  description = "Utilisateur administrateur de l'instance RDB (créé à la création de l'instance)"
  type        = string
  default     = "juribook_admin"
}

variable "db_admin_password" {
  description = "Mot de passe administrateur RDB. ⚠️ Contraintes Scaleway : 8-128 caractères, au moins 1 chiffre, 1 majuscule, 1 minuscule, 1 caractère spécial. Fournir via terraform.tfvars, jamais en dur ici."
  type        = string
  sensitive   = true
}

variable "db_app_password" {
  description = "Mot de passe de l'utilisateur applicatif partagé par les microservices (équivalent du POSTGRES_PASSWORD du docker-compose local). Mêmes contraintes que db_admin_password. Doit être IDENTIQUE à POSTGRES_PASSWORD dans le secret K8s postgres-credentials du dépôt juribook-kubernetes."
  type        = string
  sensitive   = true
}

# ── DNS ──────────────────────────────────────────────────────
# Le domaine doit déjà être enregistré via Scaleway Domains, ou
# transféré/délégué chez Scaleway pour que scaleway_domain_record
# fonctionne. Sinon laisser domain_name vide.

variable "domain_name" {
  description = "Nom de domaine racine géré par Scaleway Domains (ex: juribook.fr). Laisser vide pour ignorer le DNS."
  type        = string
  default     = ""
}

variable "ingress_lb_ip" {
  description = "IP publique du Load Balancer créé par l'Ingress Controller (récupérée après coup via `kubectl get svc -n ingress-nginx`). Laisser vide au premier apply, renseigner ensuite pour créer l'enregistrement DNS."
  type        = string
  default     = ""
}
