# ═══════════════════════════════════════════════════════════
#  Réseau — VPC + Private Network
#
#  Le Private Network permet à Kapsule et à RDB de communiquer
#  en interne (IP privée), sans passer par Internet.
# ═══════════════════════════════════════════════════════════

resource "scaleway_vpc" "juribook" {
  name = "${var.project_name}-vpc"
}

resource "scaleway_vpc_private_network" "juribook" {
  name   = "${var.project_name}-pn"
  vpc_id = scaleway_vpc.juribook.id
  region = var.scw_region
}
