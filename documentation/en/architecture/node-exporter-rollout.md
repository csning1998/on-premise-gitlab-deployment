# Node Exporter Rollout & Observability Platform

## Section 0: Context

The LGTM stack (Mimir, Loki, Grafana, Alloy) collects service-level exporter metrics (postgres_exporter, redis_exporter, etc.) for every managed database and application component. Node Exporter extends this with OS-level metrics (CPU, memory, disk, inode) for every VM in the fleet, and Grafana is provisioned with per-tenant dashboards to query all of it.

## Section 1: Node Exporter Deployment (Ansible)

1. `ansible/roles/00-base-common` installs the `prometheus-node-exporter` package (Debian/Ubuntu native package, default port `9100`) and enables the service. This role runs on every VM via `hosts: all` in `00-provision-base-image.yaml`, so every golden image carries it.
2. `ansible/playbooks/90-operation-playbook.yaml` exposes a `node-exporter-install` tag so an already-provisioned fleet can receive the same task without a full re-provision.
3. Unlike `postgres_exporter`/`redis_exporter`, node_exporter only reads `/proc` and `/sys` and needs no credentials, so it runs unconditionally from install time rather than waiting on a database connection.

## Section 2: Terraform SSoT & Interface Wiring

The port and per-VM IP lists are threaded through the layer chain using the same conventions already used for ``postgres_exporter` / `redis_exporter` / etcd / gitaly targets.

1. `00-foundation-metadata` defines `network_baseline.node_exporter_port` (9100) as a global constant, alongside `global_mtu`/`global_mss`. Node exporter's port is uniform across every VM regardless of service, so it lives in the global baseline rather than duplicated into all 16 `service_catalog` port maps.
2. `modules/layer-context` passes `node_exporter_port` through to every layer that instantiates the context module, alongside the existing `global_mtu`/`global_mss` outputs.
3. 16 VM-owning layers (`10-shared-load-balancer-frontend`, `15-shared-vault-frontend`, and 14 `30-infra-*` layers) each expose their own node IPs and the port, either inside an existing `observability_targets` output or as a dedicated `node_exporter_targets` output, following each layer's own established naming style.
4. 9 `40-provision-*` layers aggregate or pass through the L30 node exporter data toward L50.
5. 4 `50-platform-*` layers (`gitlab-frontend`, `harbor-frontend`, `gitlab-runner`, `observability-frontend`) build `vm_static_targets` for each tenant's Alloy `module` from a `flatten` loop over every service group's node IPs, paired with the global port.
6. `harbor-bootstrapper`'s node exporter is scraped only by the `observability` Mimir tenant, co-located with its other metrics there, and is excluded from the `gitlab`/`harbor`/`gitlab-runner` tenants' target lists so the same VM's series are not stored twice under different tenants.
7. All reads follow the canonical layer chain, in order: L00, L05, L10/L15/L20/L25, L30, L40, L50. Vault frontend's node exporter reaches the `observability` tenant through a pass-through output on `25-security-pki`, which already legitimately reads `15-shared-vault-frontend`, rather than a read from L50 down to L15 that would skip several levels.

## Section 3: Observability Dashboard Platform

`terraform/layers/60-provision-observability-platform` provisions Grafana's dashboard and datasource configuration.

1. It provisions a Grafana folder and one `grafana_data_source` per Mimir tenant (`observability`, `gitlab`, `harbor`, `gitlab-runner`), named `Mimir / <Tenant>`, each scoped via the `X-Scope-OrgID` header.
2. It provisions Terraform-managed dashboards, starting with `dashboards/k8s-cluster-overview.json` (6 panels).
3. It reads `15-shared-vault-frontend` (via `vault_api_port`) and `25-security-credentials` for its Vault provider configuration, matching the pattern used by `60-provision-gitlab-platform` and `60-provision-harbor-platform`.

## Section 4: Verification

1. Confirm `prometheus-node-exporter` is installed, enabled, and serving metrics on any target VM: `systemctl status prometheus-node-exporter` and `curl -s http://127.0.0.1:9100/metrics`. Confirm a scrape from another VM in the same tenant also succeeds, to rule out a firewall gap.
2. In Grafana, per Mimir tenant datasource, `up{job=~".*-node"}` should return `1` for every fleet member. `count(up{job=~".*-node"}) by (component)` cross-checks the count against the expected node inventory per component.
3. `terraform validate` and `terraform fmt -diff` should be clean on every layer in the chain described in Section 2.

## Section 5: Out of Scope

SLI recording rules, Alertmanager configuration, and the remaining Day-2 dashboard catalog are tracked separately and are not covered by this document.
