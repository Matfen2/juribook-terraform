# ═══════════════════════════════════════════════════════════
#  Outputs — informations utiles après un terraform apply
# ═══════════════════════════════════════════════════════════

output "k8s_cluster_id" {
  description = "ID complet du cluster Kapsule (format region/uuid)"
  value       = scaleway_k8s_cluster.juribook.id
}

output "kubeconfig_install_command" {
  description = "Commande Scaleway CLI pour configurer kubectl (⚠️ utilise seulement l'UUID, pas le préfixe région — voir next_steps)"
  value       = "scw k8s kubeconfig install ${split("/", scaleway_k8s_cluster.juribook.id)[1]} region=${var.scw_region}"
}

output "rdb_private_ip" {
  description = "IP privée de RDB sur le Private Network — à utiliser dans SPRING_DATASOURCE_URL des microservices et dans le Job de création des extensions SQL"
  value       = scaleway_rdb_instance.juribook.private_network[0].ip
}

output "next_steps" {
  description = "Rappel des étapes suivantes après ce terraform apply"
  value       = <<-EOT
    1. Installer le Scaleway CLI si pas déjà fait, puis configurer kubectl :
       scw k8s kubeconfig install ${split("/", scaleway_k8s_cluster.juribook.id)[1]} region=${var.scw_region}
       (⚠️ UUID seul, sans le préfixe "fr-par/" — le CLI le rejette sinon avec une 404)

    2. Vérifier la connexion :
       kubectl get nodes

    3. Déployer l'application (dépôt juribook-kubernetes) :
       kubectl apply -f 00-namespace.yaml
       ... (voir README.md de juribook-kubernetes, section "Adapter pour un
       déploiement cloud" — adapter SPRING_DATASOURCE_URL vers
       ${scaleway_rdb_instance.juribook.private_network[0].ip}
       et NE PAS appliquer le dossier postgres/, RDB le remplace)

    4. Installer l'Ingress Controller nginx :
       kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

    5. Créer les extensions SQL (uuid-ossp, pgcrypto, unaccent) via
       le Job Kubernetes ponctuel (rdb-extensions-job.yaml, dépôt
       juribook-kubernetes) — RDB n'a pas d'endpoint public, la
       connexion doit se faire depuis l'intérieur du cluster.

    6. Récupérer l'IP publique du Load Balancer :
       kubectl get svc -n ingress-nginx ingress-nginx-controller

    7. Renseigner cette IP dans terraform.tfvars (ingress_lb_ip)
       et relancer terraform apply pour créer l'enregistrement DNS.
  EOT
}
