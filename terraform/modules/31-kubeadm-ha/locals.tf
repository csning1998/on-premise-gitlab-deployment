
locals {
  # Identity variables
  svc  = var.topology_config.cluster_identity.service_name
  comp = var.topology_config.cluster_identity.component

  # Auto derive infrastructure names
  storage_pool_name = "iac-${local.svc}-${local.comp}"

  # Network Names
  nat_net_name      = "iac-${local.svc}-${local.comp}-nat"
  hostonly_net_name = "iac-${local.svc}-${local.comp}-hostonly"

  # Bridge Names (limit length < 15 chars)
  svc_abbr             = substr(local.svc, 0, 3)
  comp_abbr            = substr(local.comp, 0, 3)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"

  # Convert standard structure to Module 81 vm_config
  # 1. Inject Master Node Base Image Path
  master_nodes_with_img = {
    for k, v in var.topology_config.kubeadm_config.master_nodes : k => merge(v, {
      base_image_path = var.topology_config.kubeadm_config.base_image_path
    })
  }

  # 2. Inject Worker Node Base Image Path
  worker_nodes_with_img = {
    for k, v in var.topology_config.kubeadm_config.worker_nodes : k => merge(v, {
      base_image_path = var.topology_config.kubeadm_config.base_image_path
    })
  }

  # 3. Inject HAProxy Base Image Path
  haproxy_nodes_with_img = {
    for k, v in var.topology_config.haproxy_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.haproxy_config.base_image_path
    })
  }

  # 4. Convert standard structure to Module 81 vm_config
  all_nodes_map = merge(
    local.master_nodes_with_img,
    local.worker_nodes_with_img,
    local.haproxy_nodes_with_img
  )
  # For generating inventory file
  masters_node_map   = local.master_nodes_with_img
  workers_node_map   = local.worker_nodes_with_img
  kubeadm_master_ips = [for k, v in local.master_nodes_with_img : v.ip]

  # Ansible path and network prefix calculation
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))
}
