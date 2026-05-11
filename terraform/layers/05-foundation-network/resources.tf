
# NAT Networks (one per segment, including CLB itself)
resource "libvirt_network" "nat_networks" {
  for_each = local.net_infrastructure

  name      = each.value.nat.name
  autostart = true

  mtu = {
    size = each.value.nat.mtu
  }

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
      ranges = each.value.nat.dhcp != null ? [{ start = each.value.nat.dhcp.start, end = each.value.nat.dhcp.end }] : []
    }
  }]

  domain = {
    name       = "${each.value.nat.stage}.${local.state.metadata.global_domain_suffix}"
    local_only = "yes"
  }

  # Global Infrastructure DNS SSoT (Requires Libvirt Provider >= 0.9.7)
  dns = {
    enable = "yes"

    host = [
      for record in local.state.metadata.global_dns_records : {
        ip = record.ip
        hostnames = [{
          hostname = record.hostname
        }]
      }
    ]
  }
}

# HostOnly Networks (one per segment, including CLB itself)
resource "libvirt_network" "hostonly_networks" {
  for_each = local.net_infrastructure

  name      = each.value.hostonly.name
  autostart = true

  mtu = {
    size = each.value.hostonly.mtu
  }

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
