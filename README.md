# juribook-terraform (Scaleway)

```
juribook-terraform/
├── versions.tf              ← provider + backend
├── variables.tf              ← variables
├── network.tf                 ← VPC + réseau privé
├── kubernetes.tf               ← cluster Kapsule
├── database.tf                  ← PostgreSQL RDB
├── dns.tf                        ← DNS Scaleway Domains
├── outputs.tf                     ← outputs (kubeconfig, IP RDB...)
├── terraform.tfvars.example        ← à copier en terraform.tfvars
└── .gitignore                       ← protège le state et les secrets
```

Provisionne l'infrastructure cloud : VPC + Private Network, cluster Kubernetes managé (Kapsule), base PostgreSQL managée (RDB), et DNS (Scaleway Domains). Ce dépôt gère l'**infrastructure** ; les manifestes applicatifs et le déploiement vivent dans `juribook-kubernetes` ; les pipelines CI/CD vivent dans chacun des 6 dépôts de microservices.

**Statut : ✅ provisionné et stable.** Cluster Kapsule + RDB fonctionnels, application déployée dessus, testée de bout en bout (`curl /actuator/health` → `{"status":"UP"}`).

## Pourquoi Scaleway plutôt qu'AWS

Le **control plane Kapsule est gratuit**, contrairement à EKS chez AWS (~0,10 $/heure incompressibles). Seuls les nœuds du pool et l'instance RDB sont facturés.

---

## ⚠️ Leçons apprises, déjà corrigées ici, à ne pas redécouvrir

Six problèmes réels rencontrés en testant ce Terraform, tous déjà résolus dans les fichiers de ce dépôt.

### 1. `volume_type` - "bssd" déprécié
L'API Scaleway rejette `bssd` ("this action is no longer supported"), et le schéma du provider Terraform n'accepte pas non plus le générique `sbs`, seulement `lssd`, `bssd`, `sbs_5k`, `sbs_15k`.
**Fix** (déjà dans `database.tf`/`variables.tf`) : `db_volume_type = "sbs_5k"`.

### 2. RDB + Private Network - `enable_ipam` obligatoire
Le bloc `private_network` sur `scaleway_rdb_instance` exige explicitement `ip_net` ou `enable_ipam = true`, sinon erreur `at least one of ip_net or enable_ipam must be set`.
**Fix** (déjà dans `database.tf`) : `enable_ipam = true`.

### 3. RDB + Private Network - plus d'endpoint public du tout
Attacher un `private_network` à une instance RDB Scaleway **supprime son endpoint public par défaut**. Toute connexion SQL directe depuis Terraform échoue avec une liste d'endpoints vide.
**Fix** (architecture du dépôt) : pas de provider `postgresql` ici. Les 5 bases, l'utilisateur et les privilèges sont créés via l'API de gestion Scaleway (`scaleway_rdb_database`/`user`/`privilege`, pas de SQL direct nécessaire). Les extensions SQL sont créées après coup depuis l'intérieur du cluster, voir `rdb-extensions-job.yaml` dans `juribook-kubernetes`.

### 4. Version Kubernetes - format et disponibilité contradictoires selon `auto_upgrade`
Avec `auto_upgrade.enable = true`, l'API exige un format `x.y` (sans patch). Avec `auto_upgrade.enable = false`, elle exige au contraire le patch complet `x.y.z`.
**Fix** (déjà dans `kubernetes.tf`) : `auto_upgrade.enable = false`. **Reste à vérifier à chaque usage** : copie la version depuis la console (Containers > Kubernetes > Create Cluster), ne la devine jamais, la liste change régulièrement et une version obsolète est rejetée silencieusement.

### 5. Nœud `DEV1-M` - `OOMKilled` sous charge réelle
`DEV1-M` (4 Go RAM) est techniquement accepté par Kapsule, mais Kafka + 6 microservices Java + MailHog tournant simultanément dépassent 4 Go cumulés en pratique (jusqu'à 193 restarts observés sur un pod avant diagnostic).

### 6. `scw k8s kubeconfig install` - format d'ID erroné
Terraform expose l'ID du cluster au format `région/uuid` (ex: `fr-par/36b41b59-...`), mais le CLI Scaleway attend l'UUID seul avec la région passée séparément, sinon `404 Not Found`.
**Fix** (déjà dans `outputs.tf`) : `kubeconfig_install_command` extrait l'UUID automatiquement via `split("/", ...)[1]`.

**Point additionnel découvert en CI/CD** : `scw k8s kubeconfig install` a aussi besoin de `default-organization-id` en plus de `default-project-id`, sinon `Organization ID is required`. Vu depuis un contexte CI où le CLI est reconfiguré à chaque run - voir le README de CI/CD pour le détail.

---

## Prérequis

```powershell
$env:SCW_ACCESS_KEY = "SCWXXXXXXXXXXXXXXXXX"
$env:SCW_SECRET_KEY = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$env:SCW_DEFAULT_PROJECT_ID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

terraform version   # >= 1.7.0
```

Astuce : place ces valeurs dans un fichier `.env` local (jamais committé, voir `.gitignore`) et charge-les avec un petit script `load-env.ps1` plutôt que de les retaper à chaque session — voir la doc interne du projet pour l'exemple.

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
#    Voir son README, section "Déploiement cloud" :
#    - NE PAS appliquer le dossier postgres/
#    - SPRING_DATASOURCE_URL pointe déjà vers : terraform output rdb_private_ip
#    - Les images pointent déjà vers le registre Scaleway

# 4. Installer l'Ingress Controller nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 5. Créer les extensions SQL via le Job ponctuel (juribook-kubernetes/rdb-extensions-job.yaml)

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

## Dépôts liés

| Dépôt | Rôle |
|---|---|
| `juribook-docker` | Environnement local (Docker Compose) |
| `juribook-kubernetes` | Manifestes K8s (Deployment/Service/Ingress), applicables en local (Minikube) ou sur ce cluster cloud |
| `juribook-terraform` | Ce dépôt - infrastructure cloud |
| `juribook-auth-service` et 5 autres | Code applicatif + pipeline CI/CD qui build/teste/déploie automatiquement sur ce cluster à chaque merge sur `develop` |
