# juribook-terraform (Scaleway)

Sprint 8.3 — reconstruit intégralement après une première phase de test réel, avec chaque problème rencontré déjà corrigé dans les fichiers ci-dessous. Provisionne VPC + Private Network, cluster Kubernetes managé (Kapsule), base PostgreSQL managée (RDB), et DNS (Scaleway Domains). Ce dépôt gère l'**infrastructure** ; les manifestes applicatifs vivent dans `juribook-kubernetes`.

## Pourquoi Scaleway plutôt qu'AWS

Le **control plane Kapsule est gratuit** — contrairement à EKS chez AWS (~0,10 $/heure incompressibles). Seuls les nœuds du pool et l'instance RDB sont facturés.

---

## ⚠️ Leçons apprises — déjà corrigées ici, à ne pas redécouvrir

Six problèmes réels rencontrés en testant ce Terraform, tous déjà résolus dans les fichiers de ce dépôt.

### 1. `volume_type` — "bssd" déprécié
L'API Scaleway rejette `bssd` ("this action is no longer supported"), mais le schéma du provider Terraform (v2.78) n'accepte pas non plus le générique `sbs` — seulement `lssd`, `bssd`, `sbs_5k`, `sbs_15k`.
**Fix** (déjà dans `database.tf`/`variables.tf`) : `db_volume_type = "sbs_5k"`.

### 2. RDB + Private Network — `enable_ipam` obligatoire
Le bloc `private_network` sur `scaleway_rdb_instance` exige explicitement `ip_net` ou `enable_ipam = true`, sinon erreur `at least one of ip_net or enable_ipam must be set`.
**Fix** (déjà dans `database.tf`) : `enable_ipam = true`.

### 3. RDB + Private Network — plus d'endpoint public du tout
Attacher un `private_network` à une instance RDB Scaleway **supprime son endpoint public par défaut** (comportement documenté du produit). Toute tentative de connexion SQL directe depuis Terraform (ex: provider `postgresql` pour créer des extensions) échoue avec une liste d'endpoints vide.
**Fix** (architecture du dépôt) : pas de provider `postgresql` ici du tout. Les 5 bases, l'utilisateur et les privilèges sont créés via l'API de gestion Scaleway (`scaleway_rdb_database`/`user`/`privilege`, pas de SQL direct nécessaire). Les extensions SQL, elles, doivent être créées après coup depuis l'intérieur du cluster (Job Kubernetes, voir `juribook-kubernetes`).

### 4. Version Kubernetes — format et disponibilité contradictoires selon `auto_upgrade`
Avec `auto_upgrade.enable = true`, l'API exige un format `x.y` (sans patch). Avec `auto_upgrade.enable = false`, elle exige au contraire le patch complet `x.y.z`. Les deux se sont contredits en test selon l'état de cette option, en plus d'une liste de versions disponibles qui évolue et rejette silencieusement les versions obsolètes.
**Fix** (déjà dans `kubernetes.tf`) : `auto_upgrade.enable = false`, ce qui lève l'ambiguïté de format. **Reste à vérifier à chaque usage** : la version doit être copiée depuis la console (Containers > Kubernetes > Create Cluster > menu déroulant), pas devinée.

### 5. Nœud `DEV1-M` — `OOMKilled` sous charge réelle
`DEV1-M` (4 Go RAM) est techniquement accepté par Kapsule, mais Kafka + 6 microservices Java + MailHog tournant simultanément dépassent 4 Go cumulés en pratique, causant des redémarrages en boucle (`Exit Code 137`, jusqu'à 193 restarts observés sur un pod avant diagnostic).
**Fix** (déjà dans `variables.tf`) : `DEV1-L` (8 Go RAM) par défaut.

### 6. `scw k8s kubeconfig install` — format d'ID erroné
Terraform expose l'ID du cluster au format `région/uuid` (ex: `fr-par/7685f5e5-...`), mais le CLI Scaleway attend l'UUID seul avec la région passée séparément — sinon erreur `404 Not Found`.
**Fix** (déjà dans `outputs.tf`) : `kubeconfig_install_command` extrait automatiquement l'UUID via `split("/", ...)[1]`, prêt à copier-coller sans erreur manuelle.

---

## Prérequis

```powershell
# Clés d'accès API Scaleway : Organization Dashboard > Settings > API Keys
$env:SCW_ACCESS_KEY = "SCWXXXXXXXXXXXXXXXXX"
$env:SCW_SECRET_KEY = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:SCW_DEFAULT_PROJECT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

terraform version   # >= 1.7.0
```

Crée un Project dédié dans la console Scaleway (Organization Dashboard → Projects → Create Project), nomme-le `juribook`.

## Mise en route

```powershell
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars : project_id, mots de passe RDB (respecter les contraintes),
# et VÉRIFIER k8s_version dans la console avant de continuer

terraform init
terraform plan
terraform apply
```

Compte 8-10 minutes (RDB et Kapsule sont les ressources les plus lentes).

## Workflow complet (infra → cluster → app → DNS)

```powershell
# 1. Provisionner l'infrastructure
terraform apply

# 2. Configurer kubectl (commande donnée par l'output, UUID déjà extrait)
terraform output kubeconfig_install_command
# copie-colle la commande affichée

kubectl get nodes

# 3. Déployer l'application (dépôt juribook-kubernetes)
#    Voir son README, section "Adapter pour un déploiement cloud" :
#    - NE PAS appliquer le dossier postgres/
#    - Adapter SPRING_DATASOURCE_URL vers l'IP de : terraform output rdb_private_ip
#    - Adapter l'image vers ton registre (Scaleway Container Registry)

# 4. Installer l'Ingress Controller nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 5. Créer les extensions SQL via le Job ponctuel (voir juribook-kubernetes/rdb-extensions-job.yaml)

# 6. Récupérer l'IP du Load Balancer et créer le DNS
kubectl get svc -n ingress-nginx ingress-nginx-controller
# renseigner ingress_lb_ip dans terraform.tfvars, puis :
terraform apply
```

## Nettoyage

```powershell
terraform destroy
```

Comme `delete_additional_resources = true` est activé sur le cluster, les ressources créées indirectement (comme le Load Balancer de l'Ingress) sont aussi supprimées automatiquement.

## Différences par rapport à l'environnement local

| Aspect | Docker Compose / Minikube | Ce Terraform (Scaleway) |
|---|---|---|
| Kubernetes | Minikube (1 nœud, local) | Kapsule (managé, control plane gratuit) |
| PostgreSQL | 5 conteneurs séparés | 1 instance RDB, 5 bases, aucun accès public |
| Réseau interne | réseau Docker local | Private Network Scaleway (Kapsule + RDB) |
| Coût | Gratuit (ta machine) | Quelques €/mois (control plane gratuit, nœuds + RDB payants) |
