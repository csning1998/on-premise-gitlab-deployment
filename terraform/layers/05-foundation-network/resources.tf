
# NAT Networks (one per segment, including CLB itself)
resource "libvirt_network" "nat_networks" {
  for_each = local.net_infrastructure

  name      = each.value.nat.name
  autostart = true

  bridge = {
    name = each.value.nat.bridge_name
  }

  forward = {
    mode = "nat"
  }

  ips = [{
    address = each.value.nat.gateway
    prefix  = each.value.nat.prefix
    dhcp = {
      enabled = true
      ranges  = each.value.nat.dhcp != null ? [{ start = each.value.nat.dhcp.start, end = each.value.nat.dhcp.end }] : []
    }
  }]

  # Global Infrastructure DNS SSoT (Requires Libvirt Provider >= 0.9.7)
  dns = {
    enabled    = true
    local_only = true

    hosts = [
      for record in local.state.metadata.global_dns_records : {
        hostname = record.hostname
        ip       = record.ip
      }
    ]
  }
}

# HostOnly Networks (one per segment, including CLB itself)
resource "libvirt_network" "hostonly_networks" {
  for_each = local.net_infrastructure

  name      = each.value.hostonly.name
  autostart = true

  bridge = {
    name = each.value.hostonly.bridge_name
  }

  forward = {
    mode = "route"
  }

  ips = [{
    address = each.value.hostonly.gateway
    prefix  = each.value.hostonly.prefix
  }]
}
