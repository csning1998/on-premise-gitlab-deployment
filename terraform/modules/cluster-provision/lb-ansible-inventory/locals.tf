
locals {
  lb_service_segments = [
    for seg in var.network_service_segments : {
      name            = seg.name
      vip             = seg.vip
      cidr            = seg.cidr
      vrid            = seg.vrid
      runtime         = seg.runtime
      mtu             = seg.mtu
      mss             = seg.mss
      interface_alias = seg.interface_name
      tags            = seg.tags
      ports = {
        for p_key, p_val in coalesce(seg.ports, {}) : p_key => {
          frontend                 = p_val.frontend_port
          backend                  = p_val.backend_port
          health_check_type        = p_val.health_check_type
          health_check_http_path   = p_val.health_check_http_path
          health_check_http_expect = p_val.health_check_http_expect
          health_check_ssl         = p_val.health_check_ssl
          health_check_sni         = p_val.health_check_sni
          health_check_port        = p_val.health_check_port
          send_proxy_v2            = p_val.send_proxy_v2
        }
      }
      backend_servers = [
        for srv in coalesce(seg.backend_servers, []) : {
          name = srv.name
          ip   = srv.ip
        }
      ]
    }
  ]
}

locals {
  lb_hosts = {
    for name, node in var.vm_nodes : name => {
      ansible_host = split("/", node.interfaces[1].addresses[0])[0]
      advertise_ip = split("/", node.interfaces[1].addresses[0])[0]
      node_id      = name
      node_role    = "load_balancer"
      service_ips = {
        for seg in var.network_service_segments : seg.name => try(seg.node_ips[name], null)
      }
    }
  }
}

locals {
  ansible_inventory_data = {
    all = {
      vars = merge(
        var.template_vars_base,
        {
          service_identifier  = var.svc_identity.service_name
          service_domain      = var.svc_identity.domain_suffix
          lb_service_segments = local.lb_service_segments
        }
      )
      children = {
        lb = { hosts = local.lb_hosts }
      }
    }
  }
}
