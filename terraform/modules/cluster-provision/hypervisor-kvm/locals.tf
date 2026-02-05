
locals {
  nat_net_prefixlen      = var.libvirt_infrastructure.network.nat.ips.prefix
  hostonly_net_prefixlen = var.libvirt_infrastructure.network.hostonly.ips.prefix

  #  e.g. Gateway (172.16.86.1) -> split -> first three segments -> join -> "172.16.86"
  nat_subnet_prefix = join(".", slice(split(".", var.libvirt_infrastructure.network.nat.ips.address), 0, 3))

  nodes_config = {
    for node_name, node_config in var.vm_config.all_nodes_map :
    node_name => {
      node_index    = index(keys(var.vm_config.all_nodes_map), node_name)
      last_ip_octet = split(".", node_config.ip)[3]

      nat_mac      = "52:54:00:00:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"
      hostonly_mac = "52:54:00:10:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"

      nat_ip           = "${local.nat_subnet_prefix}.${split(".", node_config.ip)[3]}"
      nat_ip_cidr      = "${local.nat_subnet_prefix}.${split(".", node_config.ip)[3]}/${local.nat_net_prefixlen}"
      hostonly_ip_cidr = "${node_config.ip}/${local.hostonly_net_prefixlen}"
    }
  }
}
