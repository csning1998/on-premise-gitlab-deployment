
locals {
  default_corefile = <<EOT
.:53 {
    errors
    health {
      lameduck 5s
    }
    ready
    log . {
      class error
    }
    kubernetes ${var.cluster_domain} in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    hosts {
      %{for ip, host in var.hosts~}
      ${ip} ${host}
      %{endfor~}
      fallthrough
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
EOT

  final_corefile = var.custom_corefile != null ? var.custom_corefile : local.default_corefile
}
