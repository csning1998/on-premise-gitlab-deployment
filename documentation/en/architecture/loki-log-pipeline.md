# Loki Log Pipeline

## Section 0: Context

This document covers the log collection pipeline that completes the LGTM stack alongside the metrics platform described in [Application Metrics Platform](application-metrics-platform.md) and the probing collectors in [Kubernetes State and Availability Monitoring](kubernetes-state-and-blackbox-monitoring.md). Loki was deployed as part of the original collection phases but had no producers and no multi-tenant boundary. This work adds four things: a Loki tenant boundary that mirrors Mimir's, a cross-cluster mTLS ingress so the three non-observability clusters can ship logs the same way they already ship metrics, Alloy components that collect every pod's log output, and a retention policy that gives GitLab's audit trail a longer lifespan than general application logs. Bare-metal journald collection (authentication events, sudo activity, Vault audit logs) is deferred to a future MR and is not covered here.

## Section 1: Multi-Tenancy

1. Loki was deployed single-tenant (`auth_enabled: false`). It is switched to multi-tenant, reusing the same four tenant identities Mimir already writes under: `observability`, `gitlab`, `harbor`, and `gitlab-runner`. No new tenant boundary is introduced; log queries and retention isolate along the same lines metrics already do.
2. `singleBinary.replicas` stays at `1`, but the chart's default `replication_factor` of `3` assumes a multi-replica ring. With only one replica, the ring can never reach the quorum a replication factor of three requires, and every read and write fails with `too many unhealthy instances in the ring`. `commonConfig.replication_factor` is set to `1` to match the actual replica count.

## Section 2: Cross-Cluster mTLS Ingress

1. Mimir's cross-cluster write path already runs through a dedicated ingress (`mimir-gateway`) that terminates mutual TLS, using a client certificate each remote cluster's Alloy presents. Loki had no equivalent; its service URL was consumed only inside the observability cluster. A parallel `loki-gateway` ingress and network policy are added, following the same shape: a `loki` ingress hostname added to the observability-frontend certificate's subject alternative names, a network policy restricting access to the observability namespace's Alloy and Grafana pods plus the ingress controller namespace, and an ingress annotated with `nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"` against the shared CA bundle.
2. The Loki chart deploys a `loki-gateway` component (an nginx reverse proxy) even with `read`/`write`/`backend` replicas set to zero. The new cross-cluster ingress targets this gateway service on port 80, the same architectural choice Mimir makes, rather than the `loki` service on port 3100 that the in-cluster Grafana datasource uses directly.
3. The observability cluster's own Alloy pushes to Loki's internal Kubernetes service URL and does not need a client certificate. The three remote clusters push through the external ingress hostname using the client certificate already issued for their Mimir remote-write path.

## Section 3: Alloy Log Collection

1. Every cluster's Alloy gains a `discovery.relabel` component that consumes the same pod discovery already used for metrics scraping, but without the `prometheus.io/scrape` annotation filter, since that annotation is a metrics-only convention. Every pod's log output is collected, with `namespace`, `pod`, and `container` labels attached.
2. A `loki.source.kubernetes` component reads the discovered targets and a `loki.write` component pushes to the tenant's Loki endpoint, carrying the tenant ID inside the `endpoint` block (not as a top-level attribute of `loki.write`) and the same mutual TLS configuration already used for the Mimir remote-write path when one is configured.
3. GitLab's `production_json.log`, `api_json.log`, `audit_json.log`, and related structured log files are not written to separate files inside the container; the webservice and sidekiq processes multiplex all of them onto a single stdout stream, with each line carrying a `subcomponent` field identifying its source. Because log collection covers every pod's stdout unconditionally, these lines reach Loki with no GitLab-chart-side change required.

## Section 4: Per-Tenant Grafana Datasources

1. Grafana's bootstrap Loki datasource (defined directly in the Helm chart values, present before any tenant-scoped provisioning runs) gains the same `X-Scope-OrgID` header pattern already used for its bootstrap Mimir datasource, scoped to the `observability` tenant. Without this, enabling multi-tenancy on Loki would leave the bootstrap datasource unable to query anything.
2. `platform-observability-governance` gains a `grafana_data_source` resource for Loki, iterating over the same four-tenant map already used to provision the four Mimir datasources. Each tenant gets its own named Loki datasource with the matching `X-Scope-OrgID` header, so a user browsing Explore selects a tenant-scoped source the same way they already do for metrics.

## Section 5: Retention Differentiation

1. A global `retention_period` of 14 days applies to all log streams by default.
2. GitLab's `subcomponent` field is extracted into a Loki label by a `loki.process` stage inserted between log discovery and the write component, using a JSON stage to pull the field and a labels stage to attach it. Streams without this field (every non-GitLab tenant, and any GitLab line that is not valid JSON) simply produce no match and are labeled the same as any other log line.
3. A `retention_stream` override matches `{subcomponent="audit_json"}` and extends its retention to 90 days, reflecting the longer compliance value of an audit trail relative to general application and pod logs. The compactor's retention enforcement is enabled with the delete-request store pointed at the same S3 backend Loki already uses for chunk storage; without this, neither the default period nor the stream override would actually delete anything.

## Section 6: Verification

1. Querying the Loki HTTP API directly with an `X-Scope-OrgID` header set, bypassing the Grafana UI, confirms tenant isolation at the API layer: the `namespace` label's value set for the `gitlab` tenant contains only that cluster's namespaces, and the same holds independently for `harbor`, `gitlab-runner`, and `observability`.
2. The `subcomponent` label's value set for the `gitlab` tenant includes `production_json`, `api_json`, `application_json`, `ssh`, and `web_exporter`, confirming the extraction stage runs correctly against live traffic. `audit_json` appears only once an actual auditable action occurs; its absence during a quiet window is not a fault.
3. After the replication factor correction, Grafana Explore against any tenant's Loki datasource returns log volume and log lines with no ring error.

## Section 7: Out of Scope

Bare-metal journald collection (authentication events, sudo activity, Vault audit logs, VRRP transition history) is deferred to a future MR at fleet-wide scope. It requires combining two mechanisms that have not previously been combined: Vault Agent's certificate rendering, currently used only for VM-to-VM and VM-to-Vault mutual TLS, and ingress-based mutual TLS, currently used only by Kubernetes pods with certificates issued through cert-manager. Several fleet nodes (the Central Load Balancer, Vault itself) also have no existing Vault Agent deployment to extend.
