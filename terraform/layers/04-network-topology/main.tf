
# NAT Networks (one per segment, including CLB itself)
resource "libvirt_network" "nat_networks" {
  for_each = local.net_infrastructure

  name      = each.value.nat.name
  bridge    = each.value.nat.bridge_name
  mode      = "nat"
  autostart = true

  ips = [{
    address = each.value.nat.gateway
    prefix  = each.value.nat.prefix
    dhcp = {
      enabled = true
      ranges  = each.value.nat.dhcp != null ? [{ start = each.value.nat.dhcp.start, end = each.value.nat.dhcp.end }] : []
    }
  }]
}

# HostOnly Networks (one per segment, including CLB itself)
resource "libvirt_network" "hostonly_networks" {
  for_each = local.net_infrastructure

  name      = each.value.hostonly.name
  bridge    = each.value.hostonly.bridge_name
  mode      = "route"
  autostart = true

  ips = [{
    address = each.value.hostonly.gateway
    prefix  = each.value.hostonly.prefix
  }]
}
