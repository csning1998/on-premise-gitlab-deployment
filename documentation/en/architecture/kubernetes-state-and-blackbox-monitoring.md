# Kubernetes State and Availability Monitoring

## Section 0: Context

This document covers two collection-layer pieces that sit alongside the application metrics covered in [Application Metrics Platform](application-metrics-platform.md): Kubernetes object-level state (Pod restarts, Deployment availability, PVC usage) via kube-state-metrics, and external HTTPS availability probing via Grafana Alloy's embedded blackbox exporter, including certificate expiration data as a byproduct. Both rely on the pod-annotation discovery mechanism and the job label resolution chain documented in that same file, and are not re-explained here.

## Section 1: kube-state-metrics Deployment

1. A `helm-chart-kube-state-metrics` Terraform module deploys the chart to all four clusters (`gitlab-frontend`, `harbor-frontend`, `gitlab-runner`, `observability-frontend`), following the same three-file convention (`variables.tf`, `helm-chart-official.tf`, `outputs.tf`) as the other `helm-chart-*` modules.
2. The chart's image comes from `registry.k8s.io`, not Docker Hub, so each calling layer passes `harbor_k8s_proxy` (the existing `k8s_io` Harbor proxy cache project) as `image_repository`, instead of the `harbor_docker_proxy` used by the LGTM stack's own modules.
3. `platform-gitlab-runner` was previously the only one of the four platform layers without OCI registry authentication configured on its `helm` provider, since it had no prior need to pull an OCI chart directly. It now reads the same `harbor_bootstrapper_robot` ephemeral secret and sets the same `registries` block already used by the other three layers.
4. The chart does not annotate its pods for scraping by default, so `podAnnotations` is set explicitly, pointing at the chart's metrics port. The chart manages its own ServiceAccount and ClusterRole, independent of Alloy's own RBAC.
5. kube-state-metrics sets `app.kubernetes.io/name: kube-state-metrics` (a specific identifier) but also `app.kubernetes.io/component: metrics` (a generic Kubernetes-recommended-labels example value, not specific to this exporter). The job label resolution chain in `river_config.tftpl` treats `app.kubernetes.io/component` as the highest-priority source, so the resulting job label is `metrics`, not `kube-state-metrics`. No other chart across the four clusters currently sets `component: metrics`, so this does not collide with anything today.

## Section 2: Ingress-Aware Target Discovery

1. `foundation-metadata` computes a `has_ingress` boolean for every entry in `component_roles`, and exposes it as part of `global_pki_map`. The field is `true` only when a component declares a real `ingress` block in `service_catalog`.
2. This field exists because `dns_san` alone cannot distinguish an externally routed component from an internal-only one: every component gets a `dns_san` entry regardless of ingress, since an internal mTLS SAN (`<cluster_name>.<stage>.<domain_suffix>`) is appended unconditionally for internal certificate validation. Filtering on `dns_san` being non-empty, or on its length, both include internal-only components such as database or cache nodes.
3. `platform-observability-frontend` filters `global_pki_map` down to entries where `has_ingress` is true, then builds a `blackbox_targets` list of `{name, address}` pairs, using each entry's first `dns_san` value as the address. That first value is guaranteed to come from the ingress-derived portion of the SAN list rather than the internal mTLS SAN, because the concatenation that builds `dns_san` always places ingress-derived entries first, and `has_ingress` being true guarantees that portion is non-empty.
4. Six services currently match: `vault-frontend`, `keycloak-frontend`, `gitlab-frontend`, `harbor-bootstrapper-frontend`, `harbor-frontend`, `observability-frontend`. Any future service that gains a real ingress block is picked up automatically, with no change needed at this layer.

## Section 3: Blackbox Probing

1. Grafana Alloy embeds a blackbox exporter component directly, so no separate exporter deployment is needed. `helm-chart-alloy` exposes a `blackbox_targets` variable (default empty), and `river_config.tftpl` adds a `prometheus.exporter.blackbox` component paired with a `prometheus.scrape` component, both gated behind that variable being non-empty. Only `platform-observability-frontend` passes a non-empty list.
2. The `http_2xx` module probes each target over HTTPS, verified against the same ca-bundle mount already used by the Vault and Keycloak metrics scrape blocks, and accepts `200`, `301`, or `302` as successful responses to tolerate ingress-level redirects.
3. `probe_ssl_earliest_cert_expiry` is a byproduct of every HTTPS probe, requiring no separate configuration. This is where certificate expiration data lands for this platform.
4. The blackbox scrape forwards through the same `vm_cardinality` relabel component that VM-level static targets and Vault metrics already route through, keeping every scrape path in this Alloy instance consistent even though blackbox's own metrics are not currently high-cardinality.
5. River, Alloy's configuration language, does not support HCL-style heredoc syntax. Multi-line string values (such as the blackbox module's inline YAML configuration) use River's own backtick-delimited raw string syntax instead.

## Section 4: Verification

1. In Grafana, per tenant datasource, `up{job="metrics"}` should return `1` for kube-state-metrics on each of the four clusters, with `kube_pod_status_phase` and `kube_deployment_status_replicas` queryable.
2. On the `observability` tenant, `probe_success` should return `1` for each of the six blackbox targets, and `probe_ssl_earliest_cert_expiry` should return a timestamp in the future.
3. `terraform validate` should be clean on all four platform layers and the new module.

## Section 5: Out of Scope

Network-level access restrictions on unauthenticated metrics endpoints, an explicit Mimir series limit override for the `observability` tenant, and the remaining Day-2 dashboard and alerting catalog are tracked separately and are not covered by this document.
