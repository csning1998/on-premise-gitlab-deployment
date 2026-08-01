# Application Metrics Platform

## Section 0: Context

The LGTM stack collects OS-level metrics for every VM (see [Node Exporter Rollout](node-exporter-rollout.md)) and service-level exporter metrics for databases and infrastructure components. This document covers the application layer on top of that: GitLab's own Rails/Sidekiq/Workhorse/gitlab-exporter metrics, Harbor's registry-side metrics, GitLab Runner's metrics, the LGTM stack's own self-monitoring metrics, and the Mimir per-tenant series limits that bound the cost of all of it.

## Section 1: Alloy Pod-Annotation Discovery

Every cluster's Alloy instance runs a single, uniform discovery mechanism that any pod can opt into, regardless of which chart deployed it or which tenant the cluster belongs to.

1. `modules/kubernetes-addons/helm-chart-alloy/templates/river_config.tftpl` defines an unconditional `discovery.kubernetes "pods"` component (role `pod`), scoped to the whole cluster, alongside the existing node-level `discovery.kubernetes "nodes"` used for kubelet and cadvisor.
2. `discovery.relabel "annotated_pods"` keeps only pods carrying `prometheus.io/scrape: "true"`, and reads `prometheus.io/port` and `prometheus.io/path` to build the scrape address and metrics path, following the same convention used by the kube-prometheus-stack ecosystem.
3. The resulting target set feeds `prometheus.scrape "pods"`, which forwards into the same `prometheus.remote_write.mimir` receiver used by every other scrape component in the file.
4. This mechanism is intentionally unconditional (not gated behind a Terraform variable) because it is a baseline capability every cluster should have, the same way kubelet/cadvisor scraping already is. A pod becomes visible to Alloy purely by carrying the right annotations; no per-service Alloy change is required to onboard a new scrape target.
5. Annotations reach a pod through two different paths depending on the chart: some charts (GitLab's webservice, sidekiq, and gitlab-exporter subcharts) set `prometheus.io/*` annotations by their own default, so no Helm values change is needed for them. Other charts (Harbor, GitLab Runner, Mimir, Loki, Grafana) do not annotate their pods by default, so the platform sets `podAnnotations` explicitly in each chart's Terraform module.

## Section 2: Job Label Resolution

Charts disagree on which Kubernetes label identifies a pod's component, so a uniform relabeling chain derives a consistent `job` label regardless of chart convention.

1. In `discovery.relabel "annotated_pods"`, three rules apply in increasing priority, each overriding the last only when its source label is present on the pod: `app.kubernetes.io/name` sets the lowest-priority baseline (near-universal across charts, though often chart-wide rather than per-component, e.g. `gitlab`, `harbor`, `mimir`); `app` overrides it when present (per-component for GitLab's own pods, e.g. `webservice`/`sidekiq`/`gitlab-exporter`; chart-wide `harbor` for Harbor); `app.kubernetes.io/component` has the highest priority and overrides both when present (per-component for Harbor and the LGTM stack, e.g. `core`/`registry`/`ingester`/`single-binary`).
2. This chain exists because no single label works across every chart observed in this platform: GitLab differentiates its components through the plain `app` label and does not set `app.kubernetes.io/component`; Harbor and Mimir differentiate through `app.kubernetes.io/component` while leaving `app` either chart-wide or unset; Alloy and Grafana set neither `app` nor `app.kubernetes.io/component`, so they fall through to the `app.kubernetes.io/name` baseline.

## Section 3: GitLab Application Metrics

1. GitLab's webservice (`:8083`), sidekiq (`:3807`), and gitlab-exporter (`:9168`) subcharts carry `prometheus.io/*` annotations by chart default; no `helm-chart-gitlab` values changes were needed for them.
2. `gitlab-workhorse` runs as a second container inside the webservice pod but exposes its own metrics on a separate port (`:9229`), which cannot share the webservice container's `prometheus.io/*` annotation set since a pod carries only one such set. `terraform/modules/kubernetes-addons/helm-chart-gitlab/helm-chart-official.tf` sets `webservice.workhorse.metrics.enabled = true` to turn the endpoint on, and `helm-chart-alloy` gains a `workhorse_targets` boolean variable (default `false`, enabled only by `platform-gitlab-frontend`) that adds a dedicated `discovery.relabel "workhorse"` pipeline in the river config template. That pipeline reuses the same `discovery.kubernetes.pods` target list but selects by the `app: webservice` pod label instead of by annotation, and rewrites the port to `9229`.
3. `gitlab-shell` metrics are not enabled. The chart's `metrics.enabled` defaults to `false` and the endpoint requires the Go-based `gitlab-sshd` daemon; this deployment runs the default `openssh` daemon, which does not expose metrics at all. Enabling this would require an SSH daemon migration, a separate architectural decision from turning on a metrics flag.

## Section 4: Harbor and GitLab Runner Metrics

1. `terraform/modules/kubernetes-addons/helm-chart-harbor/helm-chart-official.tf` sets the chart's top-level `metrics.enabled = true`, which opens the `:8001` metrics port on the `core`, `registry`, `jobservice`, and `exporter` components. That flag alone does not add scrape annotations (the chart's only annotation path is its optional `serviceMonitor`, unused here), so each of those four components' `podAnnotations` is set explicitly from a shared `local.harbor_metrics_annotations` map. Trivy is excluded; the chart does not expose a metrics port for it.
2. `terraform/layers/platform-gitlab-runner/resources.tf` sets `metrics.enabled = true` and an explicit `podAnnotations` block (port `9252`) on the `gitlab_runner` Helm release. The chart does not annotate its pod by default and recommends a Prometheus Operator `podMonitor`, which this platform does not use. `service_catalog["runner"].ports["metrics"]` in `foundation-metadata` predates this MR and reserves the same port `9252` for HAProxy-level external access; it is unrelated to Alloy's in-cluster pod discovery, since the Runner's manager pod runs inside its own microk8s cluster rather than on a bare-metal VM.

## Section 5: LGTM Self-Monitoring

1. Mimir, Loki, and Grafana are annotated the same way Harbor and Runner are, since none of their charts annotate pods by default.
2. Mimir's `mimir-distributed` chart has no working chart-wide `podAnnotations` passthrough (attempting one has no effect on the rendered pod specs), so `terraform/modules/kubernetes-addons/helm-chart-mimir/helm-chart-official.tf` sets `podAnnotations` individually on each of the chart's per-component blocks (`ingester`, `store_gateway`, `compactor`, `alertmanager`, `ruler`, `querier`, `distributor`, `query_frontend`, `query_scheduler`, `overrides_exporter`) from a shared `local.metrics_annotations` map, all pointing at port `8080`.
3. Loki runs in `SingleBinary` deployment mode in this platform, so `podAnnotations` is set on the `singleBinary` block (port `3100`) in `helm-chart-loki/helm-chart-official.tf`. The `read`/`write`/`backend` blocks are unused (`replicas = 0`) and are not annotated.
4. Grafana is annotated at the chart's top-level `podAnnotations` field (port `3000`) in `helm-chart-grafana/helm-chart-official.tf`, which does apply chart-wide for this single-pod chart.
5. Alloy annotates itself the same way, under `controller.podAnnotations` (port `12345`, the same port its own debug/API HTTP server listens on) in `helm-chart-alloy/helm-chart-official.tf`. Every cluster's Alloy instance therefore appears as its own scrape target within that cluster's tenant.

## Section 6: Mimir Per-Tenant Series Limits

1. `helm-chart-mimir`'s `mimir.structuredConfig.limits.max_global_series_per_user` sets the default active-series ceiling applied to every tenant, currently `100000`. This value was set from the observability tenant's measured baseline (kubelet alone accounts for roughly two-thirds of it), not from an a priori guess, to leave headroom for growth without silently dropping samples.
2. `runtimeConfig.overrides` in the same chart sets a per-tenant override on top of that default; the `gitlab` tenant is set to `150000`. The `mimir-distributed` chart wires this into a reloadable Mimir `runtime_config` file automatically, so overrides take effect within Mimir's default 10-second reload interval, without a restart.
3. A tenant exceeding its limit does not fail the whole scrape; Mimir rejects the specific samples that would push it over the ceiling and returns `err-mimir-max-series-per-user` for those, visible in Alloy's `prometheus.remote_write` logs.

## Section 7: Verification

1. `sum by (job) (up{job=~"webservice|sidekiq|gitlab-exporter|workhorse"})` on the `gitlab` tenant datasource should return `1` for each job.
2. `sum by (job) (up{job=~"core|registry|jobservice|exporter"})` on the `harbor` tenant datasource should return `1` for each job.
3. `up{job="gitlab-runner"}` on the `gitlab-runner` tenant datasource should return `1`.
4. `up{job=~"ingester|distributor|compactor|alertmanager|ruler|querier|query-frontend|query-scheduler|store-gateway|overrides-exporter|single-binary|alloy|grafana"}` on the `observability` tenant datasource should return `1` for each job.
5. `count({__name__=~".+"})` on the `observability` tenant datasource should stay below the `100000` default limit; the same query with an `X-Scope-OrgID: gitlab` header should stay below `150000`.
6. `terraform validate` and `terraform fmt -diff` should be clean on `platform-gitlab-frontend`, `platform-harbor-frontend`, `platform-gitlab-runner`, and `platform-observability-frontend`.

## Section 8: Out of Scope

Recording rules, Alertmanager configuration, kube-state-metrics, blackbox probing, Loki log ingestion, and the remaining Day-2 dashboard catalog are tracked separately and are not covered by this document. High-cardinality drop rules for GitLab's own metrics were evaluated and found unnecessary at this platform's current traffic level (measured well below the cardinality that justified the existing gRPC bucket drop rule for Gitaly/Praefect); this can be revisited if usage grows.
