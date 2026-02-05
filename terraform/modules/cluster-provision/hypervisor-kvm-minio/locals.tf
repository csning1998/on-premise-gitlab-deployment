
locals {
  nat_net_prefixlen      = var.libvirt_infrastructure.network.nat.ips.prefix
  hostonly_net_prefixlen = var.libvirt_infrastructure.network.hostonly.ips.prefix
  nat_subnet_prefix      = join(".", slice(split(".", var.libvirt_infrastructure.network.nat.ips.address), 0, 3))

  # Flatten all the data disks of all nodes into a list for use by libvirt_volume.
  data_disks_flat = merge([
    for vm_key, vm_conf in var.vm_config.all_nodes_map : {
      for disk in vm_conf.data_disks :
      "${vm_key}-${disk.name_suffix}" => {
        vm_key      = vm_key
        capacity    = disk.capacity
        name_suffix = disk.name_suffix
      }
    }
  ]...)

  nodes_config = {
    for node_name, node_config in var.vm_config.all_nodes_map :
    node_name => {
      nat_mac          = "52:54:00:00:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"
      hostonly_mac     = "52:54:00:10:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"
      nat_ip_cidr      = "${local.nat_subnet_prefix}.${split(".", node_config.ip)[3]}/${local.nat_net_prefixlen}"
      hostonly_ip_cidr = "${node_config.ip}/${local.hostonly_net_prefixlen}"
    }
  }
}
