# ═══════════════════════════════════════════════════════════
#  DNS — Scaleway Domains
#
#  ⚠️ Prérequis : le domaine doit déjà être enregistré via
#  Scaleway Domains, ou son zone DNS transférée/déléguée chez
#  Scaleway. Sans ça, scaleway_domain_record échoue.
#
#  L'IP réelle du Load Balancer de l'Ingress Controller n'existe
#  qu'après le déploiement K8s — workflow en deux temps :
#  1. terraform apply (crée VPC + Kapsule + RDB)
#  2. kubectl apply -f k8s/ (déploie l'app + l'Ingress Controller,
#     qui provisionne un Load Balancer Scaleway)
#  3. kubectl get svc -n ingress-nginx → récupérer l'IP externe
#  4. Renseigner cette IP dans var.ingress_lb_ip et relancer
#     terraform apply pour créer l'enregistrement DNS
# ═══════════════════════════════════════════════════════════

resource "scaleway_domain_record" "app" {
  count = var.domain_name != "" && var.ingress_lb_ip != "" ? 1 : 0

  dns_zone = var.domain_name
  name     = ""
  type     = "A"
  data     = var.ingress_lb_ip
  ttl      = 300
}

resource "scaleway_domain_record" "www" {
  count = var.domain_name != "" && var.ingress_lb_ip != "" ? 1 : 0

  dns_zone = var.domain_name
  name     = "www"
  type     = "A"
  data     = var.ingress_lb_ip
  ttl      = 300
}
