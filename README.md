# MVP: On-Premise GitLab HA on KVM/QEMU, Provisioned via Multi-Layer Terraform, Packer, and Ansible

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.
>
> The titles and tables in the Traditional Chinese version of the documentation will remain in English.

## Introduction

A Proof of Concept for Infrastructure as Code which automated deployment of High Availability Kubernetes clusters (Kubeadm / MicroK8s) in a pure on-premise QEMU-KVM environment. Developed during an internship at Cathay General Hospital. Objective: establish an on-premise GitLab instance with a fully automated IaC pipeline reusable for legacy systems.

1. This repo has been authorized for public release by the relevant company department as part of a technical portfolio.

2. As of May 1, 2026, this repo requires Terraform 1.14 or higher due to use of the `action` block in the Ansible Provider. No equivalent exists in OpenTofu yet. Migration back to OpenTofu is planned once support is available. In the meantime, substitute `tofu` with `terraform` or configure an alias.

3. As of [#128](https://gitlab.com/csning1998/on-premise-gitlab-deployment/-/merge_requests/128), this repository has been migrated to and hosted on GitLab. All subsequent updates will be available at [https://gitlab.com/csning1998/on-premise-gitlab-deployment](https://gitlab.com/csning1998/on-premise-gitlab-deployment). The GitHub repository will now serve as a mirror of the GitLab project.

4. The project can be cloned using the following command:

    ```shell
    git clone --depth 1 https://gitlab.com/csning1998/on-premise-gitlab-deployment.git
    ```

> [!WARNING]
> This repo currently only supports Linux hosts with CPU virtualization (VT-x / AMD-V). For hosts without virtualization support, see the `legacy-workstation-on-ubuntu` branch.

## Documentation

Full setup, configuration, and architecture documentation is in [`documentation/`](documentation/README.md). It's still under construction.

| Section                                                                       | Description                                              |
| ----------------------------------------------------------------------------- | -------------------------------------------------------- |
| [Prerequisites](documentation/en/getting-started/01-prerequisites.md)         | Hardware, software, and system requirements              |
| [Environment Setup](documentation/en/getting-started/02-environment-setup.md) | Podman, Libvirt permissions, container vs. native        |
| [Initialization](documentation/en/getting-started/03-initialization.md)       | SSH keys, GitHub / GitLab PAT, Vault bootstrap           |
| [Deployment Order](documentation/en/getting-started/04-deployment-order.md)   | Phase-by-phase Terraform layer apply sequence            |
| [Vault Secrets](documentation/en/configuration/vault-secrets.md)              | Bootstrapper Vault and Production Vault secret injection |
| [Terraform Variables](documentation/en/configuration/terraform-variables.md)  | `.tfvars` init, HA node count rules, Guest OS            |
| [Kernel Tuning](documentation/en/configuration/kernel-tuning.md)              | `rp_filter`, `ip_forward`, bridge netfilter, MSS         |
| [Trust Store](documentation/en/configuration/trust-store.md)                  | `/etc/hosts`, CA bundle import, verification             |
| [Architecture Overview](documentation/en/architecture/overview.md)            | Toolchain roles, layer map, ADR index                    |
| [Troubleshooting](documentation/en/operations/troubleshooting.md)             | Symptom index linking to all layer-specific READMEs      |

## Hardware Reference

### Development machine (for reference only)

- **Chipset:** Intel® HM770
- **CPU:** Intel® Core™ i7-14700HX
- **RAM:** Micron Crucial Pro 64 GB (32 GB × 2) DDR5-5600
- **SSD:** WD PC SN560 1 TB

### Network Segment & VIP Allocation

| Usage (Service)     | Component (Role) | Network Segment (CIDR) | Service Tier  | HA-able? | VIP (HAProxy/Ingress) |
| ------------------- | ---------------- | ---------------------- | ------------- | -------- | --------------------- |
| Central LB          | HAProxy          | 172.16.125.0/24        | Shared        | True     | 172.16.125.250        |
| Kubeadm Cluster     | Kubeadm Master   | 172.16.126.0/24        | App (GitLab)  | True     | 172.16.126.250        |
|                     | Kubeadm Worker   |                        |               |          |                       |
| Postgres            | Postgres         | 172.16.127.0/24        | Data (GitLab) | True     | 172.16.127.250        |
| Etcd                | Etcd             | 172.16.128.0/24        | Data (GitLab) | True     | 172.16.128.250        |
| Redis               | Redis            | 172.16.129.0/24        | Data (GitLab) | True     | 172.16.129.250        |
| MinIO               | MinIO            | 172.16.130.0/24        | Data (GitLab) | True     | 172.16.130.250        |
| MicroK8s Cluster    | MicroK8s         | 172.16.131.0/24        | App (Harbor)  | True     | 172.16.131.250        |
| Postgres            | Postgres         | 172.16.132.0/24        | Data (Harbor) | True     | 172.16.132.250        |
| Etcd                | Etcd             | 172.16.133.0/24        | Data (Harbor) | True     | 172.16.133.250        |
| Redis               | Redis            | 172.16.134.0/24        | Data (Harbor) | True     | 172.16.134.250        |
| MinIO               | MinIO            | 172.16.135.0/24        | Data (Harbor) | True     | 172.16.135.250        |
| Vault               | Vault (Raft)     | 172.16.136.0/24        | Shared        | True     | 172.16.136.250        |
| Harbor Bootstrapper | Docker Engine    | 172.16.137.0/24        | App (Harbor)  | False    | 172.16.137.250        |
| Gitaly              | Gitaly           | 172.16.138.0/24        | Data (GitLab) | True     | 172.16.138.250        |
| GitLab Runner       | MicroK8s         | 172.16.139.0/24        | App (GitLab)  | True     | 172.16.139.250        |
| Praefect            | Praefect         | 172.16.140.0/24        | Data (GitLab) | True     | 172.16.138.250        |
| Patroni (Praefect)  | Postgres         | 172.16.141.0/24        | Data (GitLab) | True     | 172.16.138.250        |
| Keycloak SSO        | Docker Engine    | 172.16.142.0/24        | Shared        | False    | 172.16.142.250        |
| Observability Stack | MicroK8s         | 172.16.143.0/24        | Shared        | True     | 172.16.143.250        |
| MinIO               | MinIO            | 172.16.144.0/24        | Shared        | True     | 172.16.144.250        |

### Compute Resource & RAM Allocation

| Usage               | Unit RAM | Basic Qty | Subtotal RAM Basic | HA Min Qty | Subtotal RAM HA |
| ------------------- | -------- | --------- | ------------------ | ---------- | --------------- |
| Central LB          | 0.5 GiB  | 2         | 1,024 MiB          | 2          | 1,024 MiB       |
| Kubeadm Cluster     | 3.0 GiB  | 1         | 3,072 MiB          | 3          | 9,216 MiB       |
| Kubeadm Cluster     | 6.0 GiB  | 2         | 12,288 MiB         | 2          | 12,288 MiB      |
| Postgres            | 1.0 GiB  | 1         | 1,024 MiB          | 3          | 3,072 MiB       |
| Etcd                | 1.0 GiB  | 1         | 1,024 MiB          | 3          | 3,072 MiB       |
| Redis               | 0.5 GiB  | 1         | 512 MiB            | 3          | 1,536 MiB       |
| MinIO               | 1.0 GiB  | 1         | 1,024 MiB          | 4          | 4,096 MiB       |
| MicroK8s Cluster    | 4.0 GiB  | 1         | 4,096 MiB          | 3          | 12,288 MiB      |
| Postgres            | 1.0 GiB  | 1         | 1,024 MiB          | 3          | 3,072 MiB       |
| Etcd                | 1.0 GiB  | 1         | 1,024 MiB          | 3          | 3,072 MiB       |
| Redis               | 0.5 GiB  | 1         | 512 MiB            | 3          | 1,536 MiB       |
| MinIO               | 1.0 GiB  | 1         | 1,024 MiB          | 4          | 4,096 MiB       |
| Vault               | 0.5 GiB  | 1         | 512 MiB            | 3          | 1,536 MiB       |
| Harbor Bootstrapper | 1.5 GiB  | 1         | 1,536 MiB          | 1          | 1,536 MiB       |
| Gitaly              | 2.0 GiB  | 1         | 2,048 MiB          | 3          | 6,144 MiB       |
| GitLab Runner       | 4.0 GiB  | 1         | 4,096 MiB          | 3          | 12,288 MiB      |
| Praefect            | 4.0 GiB  | 0         | 0 MiB              | 3          | 12,288 MiB      |
| Patroni (Praefect)  | 2.0 GiB  | 0         | 0 MiB              | 3          | 6,144 MiB       |
| Keycloak SSO        | 1.5 GiB  | 1         | 1,536 MiB          | 1          | 1,536 MiB       |
| Observability Stack | 4.0 GiB  | 1         | 4,096 MiB          | 3          | 12,288 MiB      |
| MinIO               | 1.0 GiB  | 1         | 1,024 MiB          | 4          | 4,096 MiB       |
| **Total**           |          | 21        | **42,496 MiB**     | 60         | **116,224 MiB** |

## Progress

Services currently provisioned:

1. HashiCorp Vault HA Raft cluster for PKI with Sidecar, ACL, AppRole, RBAC
2. Postgres / Patroni (with etcd)
3. Redis / Sentinel
4. Distributed MinIO for object storage
5. Harbor for Production container registry for GitLab Runner
6. GitLab with full Helm chart deployment on Kubeadm
7. Harbor Bootstrapper as OCI seed registry for Helm charts and images
8. Keycloak OIDC for SSO integration for GitLab, Harbor (both), and Vault
9. Standalone Gitaly
10. HA Gitaly with (HA) Praefect + subordinated Patroni
11. GitLab Runner on MicroK8s
12. Remote Terraform States
13. Centralized CI/CD Pipeline
14. **[WIP]** Documentation
15. **[Waiting]** Prometheus / Grafana / Loki Integration

> [!NOTE]
> **Standalone Gitaly** and **(HA) Praefect with subordinated Patroni** configurations support bidirectional migration. Refer to [README of 30-infra-gitaly-praefect](ansible/roles/30-infra-gitaly-praefect/README.md) for more detail.
