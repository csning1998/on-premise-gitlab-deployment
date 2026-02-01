
locals {
  # Identity variables
  svc  = var.topology_config.cluster_identity.service_name
  comp = var.topology_config.cluster_identity.component

  # Auto derive infrastructure names
  storage_pool_name = "iac-${local.svc}-${local.comp}"
  nat_net_name      = "iac-${local.svc}-${local.comp}-nat"
  hostonly_net_name = "iac-${local.svc}-${local.comp}-hostonly"

  # Bridge names (limit length < 15 chars)
  svc_abbr             = substr(local.svc, 0, 3)
  comp_abbr            = substr(local.comp, 0, 3)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"

  # 1. Inject MinIO Base Image Path
  minio_nodes_with_img = {
    for k, v in var.topology_config.minio_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.minio_config.base_image_path
    })
  }

  # 2. Inject HAProxy Base Image Path
  haproxy_nodes_with_img = {
    for k, v in var.topology_config.haproxy_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.haproxy_config.base_image_path
    })
  }

  # 3. Convert standard structure to Module 81 vm_config
  all_nodes_map = merge(
    local.minio_nodes_with_img,
    local.haproxy_nodes_with_img
  )

  # Ansible path and network prefix calculation
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))
}
