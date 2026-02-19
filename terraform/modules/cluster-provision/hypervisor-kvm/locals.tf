
locals {
  tier_nat_prefixes = {
    for k, v in var.libvirt_infrastructure : k => join(".", slice(split(".", v.network.nat.ips.address), 0, 3))
  }

  nodes_config = {
    for node_name, node_config in var.vm_config.all_nodes_map :
    node_name => {
      node_index = index(keys(var.vm_config.all_nodes_map), node_name)

      # Perform MD5 hash on the "complete IP" and extract the first 6 bytes (3 bytes) as MAC suffix
      # This ensures that MAC addresses do not collide when using the same bridge for different subnets (e.g. 172.16.136.x and 172.16.131.x)
      ip_md5_hash = md5(node_config.ip)

      # Combine MAC: KVM default OUI (52:54:00) + MD5 Hex String's first 6 bytes
      # format function is used to insert colons
      nat_mac = format("52:54:00:%s:%s:%s",
        substr(md5(node_config.ip), 0, 2),
        substr(md5(node_config.ip), 2, 2),
        substr(md5(node_config.ip), 4, 2)
      )

      # HostOnly interface can use different offsets (e.g. take MD5's 6~12 bytes) to avoid collision with NAT interface
      hostonly_mac = format("52:54:00:%s:%s:%s",
        substr(md5(node_config.ip), 6, 2),
        substr(md5(node_config.ip), 8, 2),
        substr(md5(node_config.ip), 10, 2)
      )

      last_ip_octet = split(".", node_config.ip)[3]

      # NAT IP Calculation
      nat_ip      = "${local.tier_nat_prefixes[node_config.network_tier]}.${split(".", node_config.ip)[3]}"
      nat_ip_cidr = "${local.tier_nat_prefixes[node_config.network_tier]}.${split(".", node_config.ip)[3]}/${var.libvirt_infrastructure[node_config.network_tier].network.nat.ips.prefix}"

      # HostOnly IP Calculation
      hostonly_ip_cidr = "${node_config.ip}/${var.libvirt_infrastructure[node_config.network_tier].network.hostonly.ips.prefix}"
    }
  }
}
