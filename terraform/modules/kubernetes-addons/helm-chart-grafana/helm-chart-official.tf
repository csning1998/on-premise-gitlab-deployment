
resource "helm_release" "grafana" {
  name             = "grafana"
  chart            = "oci://${var.helm_config.image_registry}/${var.helm_config.chart_project}/grafana"
  version          = var.helm_config.version
  namespace        = var.helm_config.namespace
  create_namespace = false
  timeout          = var.helm_config.timeout

  values = [yamlencode({
    adminPassword = var.grafana_config.admin_password

    image = {
      registry   = var.helm_config.image_registry
      repository = "${var.helm_config.image_repository}/grafana/grafana"
    }

    ingress = {
      enabled          = true
      ingressClassName = var.ingress_config.class_name
      hosts            = [var.grafana_config.fqdn]
      tls = [{
        secretName = var.ingress_config.tls_secret_name
        hosts      = var.grafana_config.dns_sans
      }]
      annotations = {
        (var.ingress_config.issuer_kind == "ClusterIssuer"
          ? "cert-manager.io/cluster-issuer"
        : "cert-manager.io/issuer")                 = var.ingress_config.issuer_name
        "cert-manager.io/common-name"               = var.grafana_config.fqdn
        "cert-manager.io/subject-alternative-names" = join(",", var.grafana_config.dns_sans)
        "cert-manager.io/duration"                  = var.certificate_config.duration
        "cert-manager.io/renew-before"              = var.certificate_config.renew_before
      }
    }

    extraSecretMounts = [{
      name       = "ca-bundle"
      secretName = var.ca_bundle.secret_name
      mountPath  = "/etc/ssl/certs/custom-ca.crt"
      subPath    = "ca.crt"
      readOnly   = true
    }]

    datasources = {
      "datasources.yaml" = {
        apiVersion = 1
        datasources = [
          {
            name      = "Mimir"
            type      = "prometheus"
            url       = var.datasources_config.mimir_url
            access    = "proxy"
            isDefault = true
          },
          {
            name   = "Loki"
            type   = "loki"
            url    = var.datasources_config.loki_url
            access = "proxy"
          }
        ]
      }
    }
  })]
}
