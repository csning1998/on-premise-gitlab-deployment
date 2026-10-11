# MVP: On-Premise GitLab HA on KVM/QEMU, Provisioned via Multi-Layer Terraform, Packer, and Ansible

> [!CAUTION]
> This repository is currently undergoing major refactoring and the `main` branch is temporarily unusable. It is recommended to refer to the latest stable commit [`676dedc`](https://gitlab.com/csning1998-lab/platform-engineering-lab/on-premise-gitlab-deployment/-/commit/676dedc3b93dc6ac142207c645c792aab728f753).

---

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.
>
> The titles and tables in the Traditional Chinese version of the documentation will remain in English.

## Introduction

A Proof of Concept for Infrastructure as Code which automated deployment of High Availability Kubernetes clusters (Kubeadm / MicroK8s) in a pure on-premise QEMU-KVM environment. Developed during an internship at Cathay General Hospital. The objective is to establish an on-premise GitLab instance with a fully automated IaC pipeline reusable for legacy systems.

1. This repo has been authorized for public release by the relevant company department as part of a technical portfolio.

2. As of May 1, 2026, this repo requires Terraform 1.14 or higher due to use of the `action` block in the Ansible Provider. No equivalent exists in OpenTofu yet. Migration back to OpenTofu is planned once support is available. In the meantime, substitute `tofu` with `terraform` or configure an alias.

3. As of [#128](https://gitlab.com/csning1998/on-premise-gitlab-deployment/-/merge_requests/128), this repository has been migrated to and hosted on GitLab. All subsequent updates will be available at [https://gitlab.com/csning1998/on-premise-gitlab-deployment](https://gitlab.com/csning1998/on-premise-gitlab-deployment). The GitHub repository will now serve as a mirror of the GitLab project.

4. The project can be cloned using the following command with Git 2.47.0+:

    ```shell
    git clone --depth 1 --revision=676dedc3b93dc6ac142207c645c792aab728f753 https://gitlab.com/csning1998-lab/platform-engineering-lab/on-premise-gitlab-deployment.git
    ```

> [!WARNING]
> This repo currently only supports Linux hosts with CPU virtualization (VT-x / AMD-V). For hosts without virtualization support, see the `legacy-workstation-on-ubuntu` branch.

## Upstream Projects

This repository deploys only the GitLab and Harbor services. Shared services and build artifacts come from the following upstream projects.

| Project                                                                                                       | Provides                                                                                                                        |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`parent-group-governance`](https://gitlab.com/csning1998-lab/parent-group-governance)                        | Bastion Vault, GitLab group topology, AI provider federation, and Terraform state backend credentials                           |
| [`platform-foundation`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation)       | Downstream Vault, Harbor Origin, Keycloak, hypervisor baseline, global network baseline, `kvm-provisioning` modules, and images |
| [`platform-observability`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-observability) | LGTM stack (Loki, Grafana, Tempo, and Mimir) which collects the metrics and logs of this repository                             |

## Documentation

Full setup, configuration, and architecture documentation is in [`documentation/`](documentation/README.md). It's still under construction.

| Section                                                                      | Description                                         |
| ---------------------------------------------------------------------------- | --------------------------------------------------- |
| [Prerequisites](documentation/en/getting-started/01-prerequisites.md)        | Hardware, software, and system requirements         |
| [Initialization](documentation/en/getting-started/02-initialization.md)      | SSH keys, GitLab.com project governance credentials |
| [Deployment Order](documentation/en/getting-started/03-deployment-order.md)  | Phase-by-phase Terraform layer apply sequence       |
| [Vault Secrets](documentation/en/configuration/vault-secrets.md)             | Bastion Vault and Downstream Vault secrets          |
| [Terraform Variables](documentation/en/configuration/terraform-variables.md) | `.tfvars` init, HA node count rules, Guest OS       |
| [Trust Store](documentation/en/configuration/trust-store.md)                 | `/etc/hosts`, CA bundle import, verification        |
| [Architecture Overview](documentation/en/architecture/overview.md)           | Toolchain roles, layer map, ADR index               |
| [Troubleshooting](documentation/en/operations/troubleshooting.md)            | Symptom index linking to all layer-specific READMEs |

## Hardware Reference

### Development machine (for reference only)

- **Chipset:** Intel® HM770
- **CPU:** Intel® Core™ i7-14700HX
- **RAM:** Micron Crucial Pro 64 GB (32 GB × 2) DDR5-5600
- **SSD:** WD PC SN560 1 TB

### Network Segment & VIP Allocation

| Usage (Service)    | Component (Role) | Network Segment (CIDR) | Service Tier  | HA-able? | CoW-able? | VIP (HAProxy/Ingress) |
| ------------------ | ---------------- | ---------------------- | ------------- | -------- | --------- | --------------------- |
| Kubeadm Cluster    | Kubeadm Master   | 172.16.126.0/24        | App (GitLab)  | True     | Consider  | 172.16.126.250        |
|                    | Kubeadm Worker   |                        |               |          | Yes       |                       |
| Postgres           | Postgres         | 172.16.127.0/24        | Data (GitLab) | True     | Yes       | 172.16.127.250        |
| Etcd               | Etcd             | 172.16.128.0/24        | Data (GitLab) | True     | No        | 172.16.128.250        |
| Redis              | Redis            | 172.16.129.0/24        | Data (GitLab) | True     | Yes       | 172.16.129.250        |
| MinIO              | MinIO            | 172.16.130.0/24        | Data (GitLab) | True     | Yes       | 172.16.130.250        |
| MicroK8s Cluster   | MicroK8s         | 172.16.131.0/24        | App (Harbor)  | True     | Consider  | 172.16.131.250        |
| Postgres           | Postgres         | 172.16.132.0/24        | Data (Harbor) | True     | Yes       | 172.16.132.250        |
| Etcd               | Etcd             | 172.16.133.0/24        | Data (Harbor) | True     | No        | 172.16.133.250        |
| Redis              | Redis            | 172.16.134.0/24        | Data (Harbor) | True     | Yes       | 172.16.134.250        |
| MinIO              | MinIO            | 172.16.135.0/24        | Data (Harbor) | True     | Yes       | 172.16.135.250        |
| Gitaly             | Gitaly           | 172.16.138.0/24        | Data (GitLab) | True     | Yes       | 172.16.138.250        |
| GitLab Runner      | MicroK8s         | 172.16.139.0/24        | App (GitLab)  | True     | Consider  | 172.16.139.250        |
| Praefect           | Praefect         | 172.16.140.0/24        | Data (GitLab) | True     | Yes       | 172.16.138.250        |
| Patroni (Praefect) | Postgres         | 172.16.141.0/24        | Data (GitLab) | True     | Yes       | 172.16.138.250        |

> [!NOTE]
> CoW-able indicates role compatibility with copy-on-write host filesystems. Raft-family consensus engines (such as etcd and Vault Raft) enforce strict fsync latency and quorum-timeout budgets. Intermittent I/O stalls on copy-on-write filesystems risk consensus failures. Kubeadm Master and MicroK8s embed etcd and dqlite with liveness-probe tolerances sufficient to absorb transient I/O latency without hard failures. Copy-on-write storage for these two roles remains permissible subject to operational discretion.

### Compute Resource & RAM Allocation

| Usage              | Unit RAM | Basic Qty | Subtotal RAM Basic | HA Min Qty | Subtotal RAM HA |
| ------------------ | -------- | --------- | ------------------ | ---------- | --------------- |
| Kubeadm Cluster    | 3.0      | 1         | 3.0                | 3          | 9.0             |
| Kubeadm Cluster    | 6.0      | 2         | 12.0               | 2          | 12.0            |
| Postgres           | 1.0      | 1         | 1.0                | 3          | 3.0             |
| Etcd               | 1.0      | 1         | 1.0                | 3          | 3.0             |
| Redis              | 0.5      | 1         | 0.5                | 3          | 1.5             |
| MinIO              | 1.0      | 1         | 1.0                | 4          | 4.0             |
| MicroK8s Cluster   | 4.0      | 1         | 4.0                | 3          | 12.0            |
| Postgres           | 1.0      | 1         | 1.0                | 3          | 3.0             |
| Etcd               | 1.0      | 1         | 1.0                | 3          | 3.0             |
| Redis              | 0.5      | 1         | 0.5                | 3          | 1.5             |
| MinIO              | 1.0      | 1         | 1.0                | 4          | 4.0             |
| Gitaly             | 2.0      | 1         | 2.0                | 3          | 6.0             |
| GitLab Runner      | 4.0      | 1         | 4.0                | 3          | 12.0            |
| Praefect           | 4.0      | 0         | 0.0                | 3          | 12.0            |
| Patroni (Praefect) | 2.0      | 0         | 0.0                | 3          | 6.0             |
| **Total**          |          | 14        | **32.0**           | 46         | **92.0**        |

> [!NOTE]
> The unit of RAM in the table is GiB.

## Progress

Services currently provisioned:

1. Postgres / Patroni (with etcd)
2. Redis / Sentinel
3. Distributed MinIO for object storage
4. Harbor for Production container registry for GitLab Runner
5. GitLab with full Helm chart deployment on Kubeadm
6. Standalone Gitaly
7. HA Gitaly with (HA) Praefect + subordinated Patroni
8. GitLab Runner on MicroK8s
9. Remote Terraform States
10. Centralized CI/CD Pipeline
11. **[WIP]** Documentation

> [!NOTE]
> **Standalone Gitaly** and **(HA) Praefect with subordinated Patroni** configurations support bidirectional migration. Refer to [README of infra_gitaly_praefect](ansible/roles/infra_gitaly_praefect/README.md) for more detail.

## Terraform Static Analysis Exemptions

The `iac-terraform` component supplies a `checkov_skip` list that exempts `CKV_TF_1`. This check requires the module `source` argument to include a commit hash. The `project-baseline` module is instead consumed from the GitLab Terraform Module Registry, where the revision is pinned by a separate `version` argument. Since a published registry version is immutable, the mutable-reference risk addressed by `CKV_TF_1` does not apply to this source form.
