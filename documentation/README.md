# Documentation

> English documentation is in [en/](en/). Traditional Chinese (zh-TW) is planned.

## Getting Started

| Document                                                        | Description                                       |
| --------------------------------------------------------------- | ------------------------------------------------- |
| [Prerequisites](en/getting-started/01-prerequisites.md)         | Hardware, software, and system requirements       |
| [Environment Setup](en/getting-started/02-environment-setup.md) | Podman, Libvirt permissions, container vs. native |
| [Initialization](en/getting-started/03-initialization.md)       | First-run order, GitHub PAT setup                 |
| [Deployment Order](en/getting-started/04-deployment-order.md)   | Phase-by-phase Terraform layer apply sequence     |

## Configuration

| Document                                                       | Description                                                 |
| -------------------------------------------------------------- | ----------------------------------------------------------- |
| [Vault Secrets](en/configuration/vault-secrets.md)             | Bootstrapper Vault and Production Vault secret injection    |
| [Terraform Variables](en/configuration/terraform-variables.md) | `.tfvars` init, HA node count rules, Guest OS, cleanup      |
| [Kernel Tuning](en/configuration/kernel-tuning.md)             | `rp_filter`, `ip_forward`, `bridge-nf-call`, conntrack, MSS |
| [Trust Store](en/configuration/trust-store.md)                 | `/etc/hosts` entries, CA bundle import, verification        |

## Architecture

| Document                                                                   | Description                                                                 |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [Overview](en/architecture/overview.md)                                    | Toolchain roles, layer map, ADR index                                       |
| [Deployment Workflow](en/architecture/deployment-workflow.md)              | Stage-by-stage Mermaid diagrams                                             |
| [Network Topology](en/architecture/network-topology.md)                    | Asymmetric routing, PBR, bridge isolation, MTU/MSS                          |
| [Terraform Layers](en/architecture/terraform-layers.md)                    | Layer 00 SSoT deep dive                                                     |
| [PKI and Vault](en/architecture/pki-and-vault.md)                          | Certificate rotation rules, Vault Agent sidecar                             |
| [Node Exporter Rollout](en/architecture/node-exporter-rollout.md)          | VM fleet metrics wiring, observability dashboard platform bootstrap         |
| [Physical Hypervisor Monitoring](en/architecture/hypervisor-monitoring.md) | Host baseline automation, node/libvirt exporters, DAG-derived scrape target |

## Operations

| Document                                                                         | Description                                                   |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [Packer Build](en/operations/packer-build.md)                                    | `entry.sh` menu, two-stage image build                        |
| [GitHub Meta](en/operations/github-meta.md)                                      | Terraform GitHub provider, Shell Bridge Pattern               |
| [Harbor Bootstrapper: Helm Sync](en/operations/harbor-bootstrapper-helm-sync.md) | `helm pull` + `helm push` to Bootstrapper Harbor OCI registry |
| [Troubleshooting](en/operations/troubleshooting.md)                              | Symptom index linking to all layer-specific READMEs           |

## Architecture Decision Records (ADRs)

| ADR                                                        | Title                                |
| ---------------------------------------------------------- | ------------------------------------ |
| [ADR 001](en/adr/001-two-stage-vault.md)                   | Two-Stage Vault Architecture         |
| [ADR 002](en/adr/002-centralized-load-balancer.md)         | Centralized Load Balancer with PBR   |
| [ADR 003](en/adr/003-layer-00-ssot.md)                     | Layer 00 as Single Source of Truth   |
| [ADR 004](en/adr/004-podman-over-docker.md)                | Podman Over Docker                   |
| [ADR 005](en/adr/005-harbor-bootstrapper-seed-registry.md) | Harbor Bootstrapper as Seed Registry |
| [ADR 006](en/adr/006-packer-two-stage-image.md)            | Two-Stage Packer Image Build         |

---

## Doc Arch

### 1. Infrastructure Bootstrapping & Secrets Lifecycle

#### 1.1 Packer Two-Stage Image Building

- **Stage 1 (Base OS)**: Custom Packer configurations in `packer/00-base-os` automate Ubuntu 24.04 server provisioning. This stage handles OS package updates, initial security hardening (SSH disable root password, basic UFW configuration), and outputs a pristine golden image.
- **Stage 2 (Service Layer)**: Built upon the Stage 1 golden image via `packer/10-services`. Using QEMU backing-store storage overlays (backing files), this stage allows rapid configuration without modifying the base image disk. Ansible playbooks (e.g., `playbooks/00-provision-base-image.yaml`) execute pre-installations of target binaries (Patroni, Redis Sentinel, MinIO, Vault) and pre-configure service daemon configs, reducing bootstrap time.

#### 1.2 Single Source of Truth (SSoT) Metadata Paradigm

- **Metadata SSoT**: The `00-foundation-metadata` layer acts as the centralized source of truth. It defines the global HCL configuration schema (`service_catalog`) which lists all infrastructure services.
- **HCL Computations**: Through Terraform local values, it dynamically calculates IP network allocations, non-overlapping subnet CIDRs, virtual MAC addresses (to prevent Libvirt duplication), DNS SANs (Subject Alternative Names), and VIPs. This configuration drives all subsequent layers, ensuring no state drift or configuration overlap.

#### 1.3 Double-Stage Vault Bootstrapping

- **Bootstrap Phase**: A containerized Vault instance is spun up locally (Layer `00-foundation-vault-bootstrapper`) using self-signed root certificates. This instance stores early-stage IaC credentials, SSH keys, and VM passwords securely.
- **Production Phase**: Layer `15-shared-vault-frontend` boots a bare-metal, high-availability Vault cluster. The production credentials are dynamically migrated from the bootstrap Vault. During migration, Terraform outputs `RoleID` and `SecretID` AppRoles which target VM services use to authenticate securely.

#### 1.4 Production Secrets & PKI Automation

- **Credential Isolation**: Layer `25-security-credentials` auto-generates separate database passwords, S3 credentials, and internal gRPC tokens, writing them directly into the production Vault KV-v2 engine.
- **Hierarchical PKI**: Layer `25-security-pki` establishes an Intermediate CA within Vault. Vault mounts and configures PKI roles that define Allowed Domains and IP SANs.
- **Vault Agent & Consul-Template**: Bare-metal database nodes utilize the `vault-agent` daemon. It handles AppRole dynamic authentication (Auto-Auth) and maps templates in `vault-agent.hcl` using Consul-Template syntax to listen to PKI certificate paths. When a certificate's TTL is near expiration, the agent fetches new credentials, writes them to `/etc/ssl/`, and executes a post-run reload script (`deploy-certs.sh`) to reload daemons (HAProxy, Postgres) with zero downtime.

### 2. Virtualization & Network Topology

#### 2.1 Libvirt Workload Lifecycle

- **Dual NIC Topologies**: VM instances are configured with two network interfaces: a private `HostOnly` network (for secure inter-service communications, isolated from the public network) and a `NAT` bridge network (providing outbound access to external registries and proxy mirrors).
- **Direct Storage Pools**: Dynamic block volumes are created at Layer `05-foundation-volume` and attached as raw `/dev/vdb` devices on database and storage nodes. This decouples the OS partition (`/dev/vda`) from persistent application data.

#### 2.2 Asymmetric Routing & Kernel Tuning

- **Asymmetric Drops**: Multi-homed VMs often experience packet drops due to asymmetric routing. When packets enter via interface B but exit through the default route on interface A, the host bridge's stateful firewall drops the traffic because it fails TCP conntrack checks.
- **Kernel Tuning**: The kernel parameters `net.ipv4.conf.all.rp_filter=2` (Loose Reverse Path Filtering) and `net.bridge.bridge-nf-call-iptables=0` are applied to allow asymmetric paths and prevent raw host bridge iptables rules from intercepting virtual machine container interfaces (vital for Kubernetes mTLS traffic).
- **MTU/MSS Clamping**: The physical virtual NIC interfaces (`vbr*` and VM interfaces) clamp MTU to `1450` due to encapsulation protocols (like VXLAN or Geneve overlay) inside the Libvirt bridge network. To prevent packet fragmentation and TCP timeouts during SSL/TLS handshakes (especially during large payload transfers like the TLS Client Hello), the routing engine clamps the TCP Maximum Segment Size (MSS) to `1360` (`advmss 1360`), forcing clients to negotiate compliant packet sizes.

#### 2.3 Central LB Policy-Based Routing (PBR)

- **PBR Routing Tables**: The Central Load Balancer (CLB) runs Keepalived and HAProxy. Since the CLB is bridged to all subnets to route client traffic, it implements Policy-Based Routing to handle multi-subnet return paths. Custom routing tables (e.g., `rt_core_vault_frontend`) are registered in `/etc/iproute2/rt_tables`.
- **Rule Injection**: Dynamic scripts inject routing rules (replace `<VIP_ADDRESS>`, `<SUBNET_CIDR>`, and `<INTERFACE_NAME>` with environment-specific values):

    ```bash
    ip rule add from <VIP_ADDRESS> table rt_core_vault_frontend
    ```

    Within this table, `scope link` routes direct packets back through their entering interface:

    ```bash
    ip route replace <SUBNET_CIDR> dev <INTERFACE_NAME> scope link table rt_core_vault_frontend
    ```

    This forces all return packets originating from the VIP to bypass the default gateway and egress directly out of the L2 bridge interface on which the request arrived.

- **Keepalived Failover**: Keepalived manages L2 high availability using VRRP (Virtual Router Redundancy Protocol). Master and Backup nodes coordinate on a shared Virtual Router ID (VRID). If the active node crashes, the Backup assumes the VIP and broadcasts Gratuitous ARPs (GARP) to update L2 switch tables instantly.
- **HAProxy Traffic Routing**: HAProxy operates on L4 (mode tcp) for Vault (`8200`) and K8s Ingress (`443`/`80`). It uses the PROXY protocol v2 (`send-proxy-v2`) to inject real client source IPs into downstream Kubernetes controllers. L7 HTTP/REST checking is utilized to route requests:
    - _Vault_: GET `/v1/sys/health` probes active (`200 OK`) and standby (`429 Too Many Requests`) nodes.
    - _Postgres_: GET `/primary` and `/replica` checks on port `8008` determine read-write and read-only nodes.

### 3. Shared Database & Storage High Availability

#### 3.1 Postgres High Availability (Patroni/etcd)

- **etcd DCS Lock**: etcd manages distributed consensus state for Patroni. The primary Patroni node acquires a TTL leader lock (e.g., `/service/gitlab-postgres/leader`) in etcd.
- **Patroni Failover**: Standby nodes replication targets dynamically follow the etcd leader lock. If the primary crashes, the lock expires, and standby nodes initiate an etcd transaction election. The promoted node executes `pg_promote()` (or triggers the promotion trigger file) and the remaining nodes run `pg_rewind` to stream replication from the new primary.
- **Traffic Partitioning**: HAProxy routes read-write traffic (port `5000`) to nodes matching `/primary` health checks (port `8008`), and read-only traffic (port `5001`) to nodes matching `/replica`. Connections from Kubernetes enforce client certificate validation (`clientcert=verify-ca`), while Harbor and Praefect bypass mTLS due to client limits.

#### 3.2 Redis Cache High Availability

- **Sentinel Quorum**: Redis nodes run master-replica configurations. Sentinel processes monitor Redis on port `26379`. If a master fails to PING within the timeout, a Sentinel triggers Subjective Down (SDOWN). If a quorum (e.g., 2 out of 3 Sentinels) agrees on Objective Down (ODOWN), Sentinels elect a leader Sentinel to execute the failover, promoting a replica and reconfiguring other slaves.
- **Dynamic Discovery**: GitLab Rails clients do not connect to a static Redis VIP. Instead, the application queries Sentinel endpoints for `SENTINEL get-master-addr-by-name <master>` to resolve the active Master's IP and establish TCP connections.

#### 3.3 MinIO Object Storage

- **Erasure Coding**: MinIO protects data against hardware failure by stripping objects using the Reed-Solomon algorithm. In our $4+4$ configuration, MinIO splits objects into 4 data blocks and 4 parity blocks distributed across 8 separate drives.
- **Drive Layout**: Local NVMe/SSD block devices are mapped to the VMs, formatted with XFS, and directly mounted as `/data1` and `/data2`. GitLab pods access these buckets securely using Vault-managed S3 credentials.

### 4. Identity & OCI Engineering

#### 4.1 Keycloak Realm & OIDC Mapping

- **OIDC Authentication**: Keycloak acts as the SSoT Identity Provider. When users authenticate, Keycloak manages the OIDC Authorization Code Flow. The client application redirects users to Keycloak's `/auth` endpoint, and after authentication, exchanges the returned authorization code via a secure backchannel request to Keycloak's `/token` endpoint for ID and Access tokens.
- **Token Claim Mapping**: Keycloak client scopes map internal groups (e.g., `/admin`, `/developer`) into the OIDC ID Token `groups` claim.

#### 4.2 Vault OIDC Group Aliases

- **RBAC Mapping**: Vault mounts the OIDC auth backend pointing to the Keycloak realm. It configures OIDC roles with designated audiences.
- **Group Aliases**: Keycloak groups are bound to Vault internal groups using group aliases. When a user authenticates, Vault parses the ID Token's `groups` claim and dynamically attaches the correct Vault ACL policies to the user's session.

#### 4.3 Harbor Two-Stage Registry Architecture

- **Standalone Harbor Bootstrapper**: To resolve the "chicken-and-egg" issue of pulling control plane images (Calico CNI, Ingress Nginx) during cluster bootstrapping, a standalone Harbor instance is deployed via Docker Compose on a single VM. Local `vault-agent` provides dynamic TLS certificate rotation for Harbor's Nginx frontend.
- **Pull-Through Proxy Cache**: Harbor Bootstrapper configures Proxy Cache projects that mirror external registries (Quay, Docker Hub, GHCR). Workloads pull from these proxy paths, reducing external bandwidth and bypassing rate-limiting issues.
- **Production Sync Replication**: The production Harbor cluster deployed inside the Kubernetes environment (L50) uses Harbor Replication rules to automatically pull images from the bootstrapper registry, securing a completely air-gapped image distribution pipeline.

### 5. Distributed GitLab HA Architecture

#### 5.1 GitLab Distributed Data Flows

- **Decoupled Workloads**: External client traffic passes through the CLB to the Kubernetes Ingress Controller. The Ingress forwards traffic to GitLab Rails pods (`webservice`).
- **Service Integration**: Rails pods query Vault via External Secrets (ESO) for runtime credentials, fetch Redis Sentinel for caching paths, connect to Postgres VIPs (routed via HAProxy to the Patroni leader), push persistent artifacts to MinIO, and route Git data via gRPC to Praefect/Gitaly nodes.

#### 5.2 Praefect & Gitaly Cluster

- **Praefect Router**: Praefect sits as a reverse-proxy router in front of Gitaly storage nodes. It records repo metadata (transaction logs, replication generation state) in a dedicated Postgres database.
- **Strong Consistency Voting**: Write operations (like git push) require Praefect to coordinate voting. The write transaction is broadcast to Gitaly nodes, which compute a vote hash over the mutated reference set via the reference-transaction hook. Praefect commits the transaction only if the majority of Gitaly replicas report matching votes, scheduling divergent nodes for asynchronous replication.
- **Gitaly Storage**: Replicas host the raw `.git` directories on dedicated storage devices, validating inbound gRPC traffic using a shared token.

#### 5.3 Kubernetes (Kubeadm) Infrastructure Add-ons

- **Deployment Sequence**: Control plane VMs boot -> Patroni, Sentinel, and MinIO clusters initialize -> `kubeadm init` bootstraps the control plane -> workers join -> Calico CNI configures pod routing -> local-path-provisioner allocates storage -> ESO, Ingress-Nginx, and Reloader deploy -> GitLab and Harbor Helm charts are applied.
- **Calico MTU Clamping**: Calico's `veth` interfaces in Pods are aligned with the underlying network, clamping MTU to `1400` (`mtu = local.pod_network_mtu - 50` where `pod_network_mtu` is `1450`). This accommodates the 50-byte VXLAN tunnel header overhead, ensuring that Pod-to-Pod and Pod-to-Service traffic does not exceed the VM NIC MTU threshold of `1450`.
- **Vault Kubernetes Auth Method & cert-manager PKI Provisioning**:
    - **Reviewer Delegation**: A `vault-reviewer` Kubernetes ServiceAccount is granted the ClusterRole `system:auth-delegator`. A long-lived SA token is mapped to a Vault backend configuration (`vault_kubernetes_auth_backend_config`). This allows the production Vault to delegate authentication requests back to the Kubernetes API server via the TokenReview API.
    - **ClusterIssuer Binding**: A cert-manager `ClusterIssuer` is registered, referencing the Vault PKI endpoint (`pki_prod/sign/<role>`) and configured to authenticate via the `kubernetes` auth method using a dedicated `issuer` ServiceAccount token.
    - **PKI Sign Flow**: When a Pod requests a certificate:
        1. cert-manager submits the `issuer` SA JWT token to Vault.
        2. Vault validates this token against the Kubernetes API Server TokenReview API using the `vault-reviewer` credentials.
        3. Upon verification, Vault generates a transient Vault token and signs the Certificate Signing Request (CSR) against the PKI backend.
        4. cert-manager writes the signed leaf certificate, key, and CA chain back to the Kubernetes namespace as a standard `Secret`.
- **External Secrets Operator (ESO)**: Interacts with Vault using a `SecretStore` that uses K8s SA Token authentication against Vault's `/v1/auth/kubernetes` path. The `ExternalSecret` resource references Vault KV paths to automatically sync and generate native K8s Secrets.
- **Reloader & Ingress Nginx**: Reloader monitors Kubernetes Secrets, rolling out target deployment pods (e.g., GitLab Rails) when secrets update. Ingress Nginx is deployed with `use-proxy-protocol=true` to process incoming TCP traffic forwarded by HAProxy.
- **Kubelet CSR Approval**: The `kubelet-csr-approver` container runs on the cluster to automatically validate and sign internal Kubelet node serving certificates, preventing node expiration issues.

#### 5.4 GitLab Runner Lifecycle

- **Runner Registration**: Runners register using a persistent `runner_authentication_token` generated by the GitLab Provider and stored in Vault, replacing deprecated registration tokens.
- **Kubernetes Executor**: The Runner Manager watches GitLab jobs via long polling and schedules a temporary build Pod on the MicroK8s cluster for each job. Image pull policies force the executor pod to pull images from the Harbor Proxy Cache VIP, securing completely offline build capabilities.

### 6. Governance & Meta Operations

#### 6.1 GitHub & GitLab.com Provider Automation

- **State Control**: Layer `90-meta-github` and `90-meta-gitlab` utilize Terraform Providers to manage remote repositories, branch protection, webhook configurations, and secret synchronization.
- **Terraform Import**: Existing public projects are imported into the state using `terraform import` commands to prevent drift and establish centralized governance.
