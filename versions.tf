# ═══════════════════════════════════════════════════════════
#  Versions et providers
#
#  Un seul provider : scaleway. Pas de provider "postgresql" —
#  voir README section "Leçons apprises" : une instance RDB
#  attachée à un Private Network n'a PLUS d'endpoint public,
#  donc rien n'est joignable en SQL direct depuis l'extérieur
#  pour créer les extensions. Cette étape se fait après coup,
#  depuis l'intérieur du cluster (voir juribook-kubernetes).
#
#  ⚠️ Backend local par défaut (state stocké dans le dossier,
#  jamais commité — voir .gitignore).
# ═══════════════════════════════════════════════════════════
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.50"
    }
  }
}

# Authentification via variables d'environnement (recommandé,
# jamais dans ce fichier ni dans terraform.tfvars) :
#   $env:SCW_ACCESS_KEY = "SCWXXXXXXXXXXXXXXXXX"
#   $env:SCW_SECRET_KEY = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   $env:SCW_DEFAULT_PROJECT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
provider "scaleway" {
  region = var.scw_region
  zone   = var.scw_zone
}
