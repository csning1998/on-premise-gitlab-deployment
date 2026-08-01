# Fleet Lifecycle Collectors and Availability Probing

## Section 0: Context

This document covers the lifecycle and availability collectors that sit alongside the metrics platform described in [Application Metrics Platform](application-metrics-platform.md) and the object-state and probing collectors in [Kubernetes State and Availability Monitoring](kubernetes-state-and-blackbox-monitoring.md). It adds four things: keepalived VRRP state visibility, the Node Exporter textfile collector that carries it, a bare-metal Grafana Alloy log agent baked into the golden image, and an extension of the embedded blackbox exporter to cover external upstream registries and cross-route reachability. The base blackbox mechanism (the embedded exporter, the `http_2xx` module, the certificate expiry byproduct, and the `probe_success` semantics) is established in the Kubernetes State document and is not repeated here.

## Section 1: keepalived VRRP Visibility

1. The Central Load Balancer runs a single keepalived instance whose `vrrp_sync_group VG_ALL` covers every service VIP, so all segments fail over together. A `notify` hook on that sync group runs a script on each VRRP state transition, including the initial transition when keepalived first enters a state at boot.
2. The notify script writes a `node_keepalived_vrrp_state{segment, state}` gauge for every segment, emitting one series per state (`master`, `backup`, `fault`) with the value set to `1` for the active state. It writes to a temporary file and renames it into place, so the Node Exporter textfile collector never reads a half-written file.
3. The metric reaches Mimir through the existing Node Exporter scrape (the Central LB is already scraped as `observability-node`), so no dedicated scrape target is added. A silent VIP flap becomes visible as a change in the gauge without any application-level symptom.
4. Only the Central LB keepalived is live. The keepalived template in the kubeadm role is dead code, since the Kubernetes control plane HA VIP was migrated to the Central LB.

## Section 2: Node Exporter Textfile Collector

1. The `00-base-common` role enables the Node Exporter textfile collector fleet-wide by creating the collector directory and writing the `--collector.textfile.directory` flag into `/etc/default/prometheus-node-exporter`. This is a golden-image change applied to every host.
2. The textfile collector is the substrate the VRRP notify script writes into. It is the general mechanism for exposing metrics from producers that have no native exporter, so later collectors (for example scheduled jobs) can publish gauges the same way without a new scrape path.

## Section 3: Bare-Metal Alloy Log Agent

1. The `00-base-common` role bakes the Grafana Alloy binary into the golden image, mirroring the Vault binary install pattern (versioned download, install to `/usr/local/bin`, a dedicated system user, a systemd unit). The `alloy` user is added to the `systemd-journal` group so the agent can read the journal, and the config and data directories are created.
2. The systemd unit is deliberately left disabled. The binary is present on every host so the future log pipeline can ship selected journald units to Loki without another golden-image rebuild, while the actual `config.alloy` content and service enablement are deferred to the log pipeline work.
3. This single agent is the shared substrate for the journald log sources needed later, covering authentication events, sudo activity, Vault audit logs, and VRRP transition history.

## Section 4: Blackbox Module Extension

1. The embedded blackbox exporter config is extended from a single module to three. `http_2xx` probes internally issued HTTPS against the ca-bundle mount (unchanged from the Kubernetes State document). `http_2xx_public` probes external HTTPS against the system trust store with no `ca_file`, since public upstreams use public certificate authorities. `tcp_connect` checks L4 reachability for VIPs that do not serve HTTPS.
2. The `blackbox_targets` variable gains a per-entry `module` field, defaulting to `http_2xx` so existing callers are unchanged. Each target selects its own module.
3. `http_2xx_public` sets `preferred_ip_protocol: ip4`. The blackbox http prober defaults to preferring IPv6, and its `ip_protocol_fallback` only retries IPv4 when DNS returns no AAAA record, not when an IPv6 connection fails. In an IPv4-only environment, upstream hosts that publish AAAA records would otherwise fail immediately with a status code of `0`, well below the timeout.

## Section 5: External Upstream Probing

1. `platform-harbor-frontend` derives external probe targets from the Harbor proxy-cache upstream list (`proxy_caches`), producing one `http_2xx_public` target per upstream registry. Any proxy cache added to that list is probed automatically.
2. The probes run from the harbor tenant's Alloy, matching the egress path Harbor itself uses to reach these registries. A Docker Hub rate limit or an upstream outage becomes visible from Harbor's own vantage point before continuous integration jobs feel it.
3. Six upstreams are probed today: `hub.docker.com`, `registry.k8s.io`, `quay.io`, `registry.gitlab.com`, `gcr.io`, and `ghcr.io`. The HTTPS probes also surface `probe_ssl_earliest_cert_expiry` for the public certificates.

## Section 6: Cross-Route L4 Probing

1. `platform-observability-frontend` probes the VIPs of the segments the observability cluster maintains static routes to, using the `tcp_connect` module. This gives an L4 route-health signal that isolates routing and policy-based routing failures from application-layer failures, since a routing failure drops `tcp_connect` while an application or TLS issue drops only the HTTPS probe.
2. The observability cluster can only reach the four segments it holds static routes for, so those four are the complete set of cross-route paths it can probe. Three of them are also covered by the ingress HTTPS probes, where `tcp_connect` adds the L4 signal, and one (the observability object store) is new coverage.
3. The target coordinates are threaded through the canonical layer chain with no skip-level reads. The `infra-*` layer derives them from `infrastructure_map`, the `provision-*` layer passes them through, and the `platform-*-frontend` layer merges them with the ingress HTTPS targets into a single `blackbox_targets` list. Each cross-route target name carries a `-route` suffix so it does not collide with the ingress probe of the same segment.

## Section 7: Verification

1. Alloy names each blackbox probe job `integrations/blackbox/<target-name>`, one job per target, so `probe_success{job=~"integrations/blackbox/.*"}` lists every probe. A filter on `job="blackbox"` returns nothing.
2. On the `observability` tenant, `probe_success` returns `1` for ten targets: six ingress `http_2xx` probes and four cross-route `tcp_connect` probes suffixed `-route`.
3. On the `harbor` tenant, `probe_success` returns `1` for the six external upstreams, and `probe_ip_protocol` returns `4` for each, confirming the IPv4 preference.
4. On a rebuilt host, `/etc/default/prometheus-node-exporter` carries the textfile flag, `keepalived_vrrp_state.prom` exists in the collector directory on the Central LB, and the `alloy` binary is present with its service disabled.

## Section 8: Out of Scope

The Alloy log pipeline configuration and service enablement, journald shipping to Loki, the full cross-segment probe matrix beyond the routed segments, and the remediation of unmounted data disks are tracked separately and are not covered by this document.
