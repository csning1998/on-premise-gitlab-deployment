
resource "kubernetes_manifest" "coredns_custom_config" {
  field_manager {
    name            = "terraform-dns-manager"
    force_conflicts = true
  }

  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "coredns"
      namespace = "kube-system"
      labels = {
        "addonmanager.kubernetes.io/mode" = "EnsureExists"
        "k8s-app"                         = "kube-dns"
      }
    }
    data = {
      Corefile = <<EOT
.:53 {
    errors
    health {
      lameduck 5s
    }
    ready
    log . {
      class error
    }
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    hosts {
      %{for ip, host in local.dns_hosts~}
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
    }
  }
}
