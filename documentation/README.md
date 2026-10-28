# Documentation

> English documentation is in [en/](en/). Traditional Chinese (zh-TW) is planned.

## Getting Started

| Document                                                      | Description                                                 |
| ------------------------------------------------------------- | ----------------------------------------------------------- |
| [Prerequisites](en/getting-started/01-prerequisites.md)       | Hardware, software, and system requirements                 |
| [Initialization](en/getting-started/02-initialization.md)     | First-run order, GitLab.com project governance credentials  |
| [Deployment Order](en/getting-started/03-deployment-order.md) | Upstream prerequisites and phase-by-phase layer apply order |

## Configuration

| Document                                                       | Description                                                        |
| -------------------------------------------------------------- | ------------------------------------------------------------------ |
| [Vault Secrets](en/configuration/vault-secrets.md)             | Bastion Vault and Downstream Vault secrets read by this repository |
| [Terraform Variables](en/configuration/terraform-variables.md) | `.tfvars` init, HA node count rules, Guest OS, cleanup             |
| [Trust Store](en/configuration/trust-store.md)                 | `/etc/hosts` entries, platform trust bundle import, verification   |

## Architecture

| Document                                                      | Description                                   |
| ------------------------------------------------------------- | --------------------------------------------- |
| [Overview](en/architecture/overview.md)                       | Toolchain roles, layer map, ADR index         |
| [Deployment Workflow](en/architecture/deployment-workflow.md) | Stage-by-stage Mermaid diagrams               |
| [Terraform Layers](en/architecture/terraform-layers.md)       | `foundation-libvirt-resources` SSoT deep dive |

## Operations

| Document                                                | Description                                                          |
| ------------------------------------------------------- | -------------------------------------------------------------------- |
| [Packer Build](en/operations/packer-build.md)           | `entry.sh` menu, Gitaly and Praefect image build                     |
| [Production Harbor](en/operations/harbor-production.md) | Project access, OIDC login, admin account, Harbor Origin replication |
| [Troubleshooting](en/operations/troubleshooting.md)     | Symptom index linking to all layer-specific READMEs                  |

## Architecture Decision Records (ADRs)

| ADR                                                   | Title                                                    |
| ----------------------------------------------------- | -------------------------------------------------------- |
| [ADR 003](en/adr/003-foundation-libvirt-resources.md) | `foundation-libvirt-resources` as Single Source of Truth |
| [ADR 006](en/adr/006-packer-two-stage-image.md)       | Two-Stage Packer Image Build                             |

## Upstream Documentation

Shared services and their design records are documented in the upstream projects.

| Project                                                                                                       | Topics                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`parent-group-governance`](https://gitlab.com/csning1998-lab/parent-group-governance)                        | Bastion Vault, GitLab group topology, AI provider federation                                                                                      |
| [`platform-foundation`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation)       | Downstream Vault and PKI, Harbor Origin, Keycloak and OIDC, HAProxy tier, hypervisor baseline and kernel tuning, distro and shared service images |
| [`platform-observability`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-observability) | LGTM stack, node and hypervisor metrics, application metrics, Loki log pipeline, availability probing                                             |

---

## Doc Arch

### 1. Infrastructure Bootstrapping & Secrets Lifecycle

#### 1.1 Packer Two-Stage Image Building

- **Stage 1 (Distro)**: `platform-foundation` builds the `ubuntu-24-updated` distro image in its `packer/distro`. This stage handles OS package updates, initial security hardening (SSH disable root password, basic UFW configuration), and outputs a pristine golden image.
- **Stage 2 (Service Layer)**: Built upon the Stage 1 golden image. Using QEMU backing-store storage overlays (backing files), this stage allows rapid configuration without modifying the base image disk. `platform-foundation` builds the shared service images for Patroni, Redis Sentinel, MinIO, Kubeadm, and MicroK8s. This repository builds only the Gitaly and Praefect image via `packer/services` and `playbooks/provision_base_image.yaml`.

#### 1.2 Single Source of Truth (SSoT) Metadata Paradigm

- **Metadata SSoT**: The `foundation-libvirt-resources` layer acts as the centralized source of truth. The layer defines the global HCL configuration schema (`service_catalog`) which lists all infrastructure services, and reads the network baseline and the domain suffix from `platform-foundation`.
- **HCL Computations**: Through the `foundation-resources` module of `platform-foundation`, the layer dynamically calculates IP network allocations, non-overlapping subnet CIDRs, virtual MAC addresses (to prevent Libvirt duplication), DNS SANs (Subject Alternative Names), and VIPs. This configuration drives all subsequent layers, ensuring no state drift or configuration overlap.

#### 1.3 Secrets & PKI from Upstream

- **Bastion Vault**: The Bastion Vault of `parent-group-governance` stores the bootstrap credentials, such as the guest VM credentials which Packer reads.
- **Downstream Vault**: The Downstream Vault of `platform-foundation` stores the database passwords, S3 credentials, and internal gRPC tokens of this repository under its tenant prefix, and issues the leaf certificates of every service.
- **Vault Agent & Consul-Template**: Bare-metal database nodes utilize the `vault-agent` daemon. It handles dynamic authentication (Auto-Auth) and maps templates in `vault-agent.hcl` using Consul-Template syntax to listen to PKI certificate paths. When a certificate's TTL is near expiration, the agent fetches new credentials, writes them to `/etc/ssl/`, and executes a post-run reload script (`deploy-certs.sh`) to reload daemons (HAProxy, Postgres) with zero downtime.

### 2. Virtualization & Network Topology

#### 2.1 Libvirt Workload Lifecycle

- **Dual NIC Topologies**: VM instances are configured with two network interfaces: a private `HostOnly` network (for secure inter-service communications, isolated from the public network) and a `NAT` bridge network (providing outbound access to external registries and proxy mirrors).
- **Direct Storage Pools**: Dynamic block volumes are created by the `foundation-libvirt-resources` layer and attached as raw `/dev/vdb` devices on database and storage nodes. This decouples the OS partition (`/dev/vda`) from persistent application data.

#### 2.2 Host Kernel Tuning

- **Hypervisor Baseline**: Role `hypervisor_baseline` of `platform-foundation` applies loose reverse path filtering, bridge netfilter bypass, connection tracking limits, and TCP MSS clamping on the KVM host. See [Hypervisor Kernel Tuning](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation/-/blob/main/documentation/architecture/hypervisor-kernel-tuning.md).

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

### 4. Identity & OCI Supply

#### 4.1 Identity from Upstream

- **OIDC Authentication**: The Keycloak instance of `platform-foundation` acts as the SSoT Identity Provider and declares the OIDC clients of GitLab and Harbor. GitLab and Harbor read the client secrets from the Downstream Vault.

#### 4.2 Harbor Registry Supply

- **Harbor Origin**: The Harbor Origin of `platform-foundation` provides the proxy cache projects which mirror external registries (Quay, Docker Hub, GHCR), resolving the "chicken-and-egg" issue of pulling control plane images (Calico CNI, Ingress Nginx) during cluster bootstrapping.
- **Production Sync Replication**: The production Harbor cluster deployed inside the Kubernetes environment (`platform-*-frontend` tier) uses Harbor Replication rules to automatically pull images from Harbor Origin, securing a completely air-gapped image distribution pipeline.

### 5. Distributed GitLab HA Architecture

#### 5.1 GitLab Distributed Data Flows

- **Decoupled Workloads**: External client traffic passes through the HAProxy tier to the Kubernetes Ingress Controller. The Ingress forwards traffic to GitLab Rails pods (`webservice`).
- **Service Integration**: Rails pods query Vault via External Secrets (ESO) for runtime credentials, fetch Redis Sentinel for caching paths, connect to Postgres VIPs (routed via HAProxy to the Patroni leader), push persistent artifacts to MinIO, and route Git data via gRPC to Praefect/Gitaly nodes.

#### 5.2 Praefect & Gitaly Cluster

- **Praefect Router**: Praefect sits as a reverse-proxy router in front of Gitaly storage nodes. It records repo metadata (transaction logs, replication generation state) in a dedicated Postgres database.
- **Strong Consistency Voting**: Write operations (like git push) require Praefect to coordinate voting. The write transaction is broadcast to Gitaly nodes, which compute a vote hash over the mutated reference set via the reference-transaction hook. Praefect commits the transaction only if the majority of Gitaly replicas report matching votes, scheduling divergent nodes for asynchronous replication.
- **Gitaly Storage**: Replicas host the raw `.git` directories on dedicated storage devices, validating inbound gRPC traffic using a shared token.

#### 5.3 Kubernetes (Kubeadm) Infrastructure Add-ons

- **Deployment Sequence**: Control plane VMs boot, then Patroni, Sentinel, and MinIO clusters initialize, then `kubeadm init` bootstraps the control plane, then workers join, then Calico CNI configures pod routing, then local-path-provisioner allocates storage, then ESO, Ingress-Nginx, and Reloader deploy, and finally GitLab and Harbor Helm charts are applied.
- **Calico MTU Clamping**: Calico's `veth` interfaces in Pods are aligned with the underlying network, clamping MTU to `1400` (`mtu = local.pod_network_mtu - 50` where `pod_network_mtu` is `1450`). This accommodates the 50-byte VXLAN tunnel header overhead, ensuring that Pod-to-Pod and Pod-to-Service traffic does not exceed the VM NIC MTU threshold of `1450`.
- **Vault Kubernetes Auth Method & cert-manager PKI Provisioning**:
    - **Reviewer Delegation**: A `vault-reviewer` Kubernetes ServiceAccount is granted the ClusterRole `system:auth-delegator`. A long-lived SA token is mapped to a Vault backend configuration (`vault_kubernetes_auth_backend_config`). This allows the Downstream Vault to delegate authentication requests back to the Kubernetes API server via the TokenReview API.
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

### 6. Governance

#### 6.1 GitLab.com Provider Automation

- **State Control**: The `administration-gitlab-project` layer utilizes the provisioner modules of `parent-group-governance` to manage the GitLab.com project, branch protection, code reviewer variables, and workload identity federation bindings.
- **Terraform Import**: The existing project and its branch protection are imported into the state using `terraform import` commands to prevent drift and establish centralized governance.
