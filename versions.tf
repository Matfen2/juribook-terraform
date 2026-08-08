# ═══════════════════════════════════════════════════════════
#  Versions et providers
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
  project_id = var.project_id
}
