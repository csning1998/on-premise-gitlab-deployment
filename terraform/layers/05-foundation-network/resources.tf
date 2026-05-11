
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
  # Groups hostnames by IP to prevent duplicate IP entries and potential SERVFAIL issues.
  dns = {
    enable = "yes"

    host = [
      for ip in sort(distinct([for r in local.state.metadata.global_dns_records : r.ip])) : {
        ip = ip
        hostnames = [
          for h in sort(distinct([for r in local.state.metadata.global_dns_records : r.hostname if r.ip == ip])) : {
            hostname = h
          }
        ]
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

  # Inject same DNS registry into hostonly networks to ensure internal consistency.
  dns = {
    enable = "yes"
    host = [
      for ip in sort(distinct([for r in local.state.metadata.global_dns_records : r.ip])) : {
        ip = ip
        hostnames = [
          for h in sort(distinct([for r in local.state.metadata.global_dns_records : r.hostname if r.ip == ip])) : {
            hostname = h
          }
        ]
      }
    ]
  }
}
