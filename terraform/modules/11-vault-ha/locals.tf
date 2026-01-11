
locals {
  # Identity variables
  svc  = var.topology_config.cluster_identity.service_name
  comp = var.topology_config.cluster_identity.component

  # Auto derive infrastructure names
  storage_pool_name = "iac-${local.svc}-${local.comp}"
  # Network Names
  nat_net_name      = "iac-${local.svc}-${local.comp}-nat"
  hostonly_net_name = "iac-${local.svc}-${local.comp}-hostonly"

  svc_abbr  = substr(local.svc, 0, 4)  # "vault" (5 chars) -> "vaul"
  comp_abbr = substr(local.comp, 0, 3) # "core" (4 chars) -> "cor"

  # Bridge Names (limit length < 15 chars)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"

  # Convert standard structure to Module 81 vm_config
  all_nodes_map = merge(
    var.topology_config.nodes,
    var.topology_config.ha_config.haproxy_nodes
  )

  # Ansible path and network prefix calculation
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))
}
