
locals {
  global_topology    = data.terraform_remote_state.topology.outputs
  central_lb_outputs = data.terraform_remote_state.central_lb.outputs
  hydrated_topology  = local.central_lb_outputs.hydrated_topology
  service_meta       = local.global_topology.service_structure[var.service_catalog_name]
  domain_suffix      = local.global_topology.domain_suffix
  cluster_name       = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  network_segment    = local.global_topology.network_segments[var.service_catalog_name]
  vault_pki          = try(data.terraform_remote_state.topology.outputs.vault_pki, null)

  # Extract the Bridge Network Info for Service with Salted Hash Name
  my_segment_info = [
    for seg in local.hydrated_topology : seg
    if seg.name == var.service_catalog_name
  ][0]
}

locals {
  # 1. Lookup Service Metadata and Extract Network Facts from SSoT
  service_vip = local.service_meta.network.vip

  # 2. Network Identity & Specs (Corrected Source)
  # Use unique network names for this service cluster to avoid conflict with LB infra
  network_identity = {
    nat_net_name         = local.central_lb_outputs.infra_network.nat.name_network
    nat_bridge_name      = local.central_lb_outputs.infra_network.nat.name_bridge
    hostonly_net_name    = var.service_catalog_name
    hostonly_bridge_name = local.my_segment_info.bridge_name
  }

  # 3. Subnet Prefix (Based on the Vault NAT gateway)
  nat_network_subnet_prefix = join(".", slice(split(".", local.my_segment_info.nat_gateway), 0, 3))
}

locals {
  # Extract Gateways and CIDRs from the Service Segment Info (Vault Specific), NOT Central LB
  network_config = {
    network = {
      nat = {
        gateway = local.my_segment_info.nat_gateway # e.g. 172.16.12.1
        cidrv4  = local.my_segment_info.nat_cidr    # e.g. 172.16.12.0/24
        dhcp    = local.network_segment.nat_dhcp    # e.g. 172.16.12.100 - 172.16.12.199
      }
      hostonly = {
        gateway = cidrhost(local.my_segment_info.cidr, 1) # Implied Gateway for HostOnly is typically the .1 of the CIDR
        cidrv4  = local.my_segment_info.cidr              # e.g. 172.16.136.0/24
      }
    }
    allowed_subnet = local.my_segment_info.cidr
  }
}

locals {
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}

locals {
  # 1. Cluster Identity Construction
  node_name_prefix  = "${local.cluster_name}-node"
  storage_pool_name = "iac-${local.service_meta.meta.project_code}-${local.service_meta.meta.name}"

  # 2. Inject Base Image Path
  nodes_configuration = {
    for k, v in var.vault_config.nodes : "${local.node_name_prefix}-${k}" => {
      ip              = cidrhost(local.network_config.network.hostonly.cidrv4, v.ip_suffix)
      vcpu            = v.vcpu
      ram             = v.ram
      base_image_path = var.base_image_path
    }
  }
  # 3. Final Node Map
  nodes_map = local.nodes_configuration
}
