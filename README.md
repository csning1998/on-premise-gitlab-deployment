# PoC: Deploy Distributed GitLab Helm Chart on KVM with Packer, Terraform, Vault, and Ansible

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.

## Introduction

A Proof of Concept for Infrastructure as Code — automated deployment of High Availability Kubernetes clusters (Kubeadm / MicroK8s) in a pure on-premise QEMU-KVM environment. Developed during an internship at Cathay General Hospital. Objective: establish an on-premise GitLab instance with a fully automated IaC pipeline reusable for legacy systems.

1. This repo has been authorized for public release by the relevant company department as part of a technical portfolio.

2. As of May 1, 2026, this repo requires Terraform 1.14 or higher due to use of the `action` block in the Ansible Provider. No equivalent exists in OpenTofu yet. Migration back to OpenTofu is planned once support is available. In the meantime, substitute `tofu` with `terraform` or configure an alias.

3. As of #128, this repository has been migrated to and hosted on GitLab. All subsequent updates will be available at [https://gitlab.com/csning1998/on-premise-gitlab-deployment](https://gitlab.com/csning1998/on-premise-gitlab-deployment). The GitHub repository will now serve as a mirror of the GitLab project.

4. The project can be cloned using the following command:

    ```shell
    git clone --depth 1 https://gitlab.com/csning1998/on-premise-gitlab-deployment.git
    ```

## Documentation

Full setup, configuration, and architecture documentation is in [`documentation/`](documentation/README.md).

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

Development machine (for reference only):

- **Chipset:** Intel® HM770
- **CPU:** Intel® Core™ i7-14700HX
- **RAM:** Micron Crucial Pro 64 GB (32 GB × 2) DDR5-5600
- **SSD:** WD PC SN560 1 TB

Resource allocation for single-host deployment:

| Network Segment (CIDR) | Service Tier  | Usage (Service)     | VIP (HAProxy/Ingress) | Component (Role) | Qty | Unit RAM | Subtotal RAM   |
| ---------------------- | ------------- | ------------------- | --------------------- | ---------------- | --- | -------- | -------------- |
| 172.16.125.0/24        | Shared        | Central LB          | 172.16.125.250        | HAProxy          | 2   | 0.5 GiB  | 1,024 MiB      |
| 172.16.126.0/24        | App (GitLab)  | Kubeadm Cluster     | 172.16.126.250        | Kubeadm Master   | 1   | 3.0 GiB  | 3,072 MiB      |
|                        |               |                     |                       | Kubeadm Worker   | 2   | 6.0 GiB  | 12,288 MiB     |
| 172.16.127.0/24        | Data (GitLab) | Postgres HA         | 172.16.127.250        | Postgres         | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.128.0/24        | Data (GitLab) | Etcd HA             | 172.16.128.250        | Etcd             | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.129.0/24        | Data (GitLab) | Redis HA            | 172.16.129.250        | Redis            | 1   | 0.5 GiB  | 512 MiB        |
| 172.16.130.0/24        | Data (GitLab) | MinIO HA            | 172.16.130.250        | MinIO            | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.131.0/24        | App (Harbor)  | MicroK8s Cluster    | 172.16.131.250        | MicroK8s Node    | 1   | 4.0 GiB  | 4,096 MiB      |
| 172.16.132.0/24        | Data (Harbor) | Postgres HA         | 172.16.132.250        | Postgres         | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.133.0/24        | Data (Harbor) | Etcd HA             | 172.16.133.250        | Etcd             | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.134.0/24        | Data (Harbor) | Redis HA            | 172.16.134.250        | Redis            | 1   | 0.5 GiB  | 512 MiB        |
| 172.16.135.0/24        | Data (Harbor) | MinIO HA            | 172.16.135.250        | MinIO            | 1   | 1.0 GiB  | 1,024 MiB      |
| 172.16.136.0/24        | Shared        | Vault HA            | 172.16.136.250        | Vault (Raft)     | 1   | 0.5 GiB  | 512 MiB        |
| 172.16.137.0/24        | App (Harbor)  | Harbor Bootstrapper | 172.16.137.250        | Docker Engine    | 1   | 1.5 GiB  | 1,536 MiB      |
| 172.16.138.0/24        | Data (GitLab) | Gitaly              | 172.16.138.250        | Gitaly           | 1   | 2.0 GiB  | 2,048 MiB      |
| 172.16.139.0/24        | App (GitLab)  | GitLab Runner       | 172.16.139.250        | MicroK8s Node    | 1   | 4.0 GiB  | 4,096 MiB      |
| 172.16.142.0/24        | Shared        | Keycloak SSO        | 172.16.142.250        | Docker Engine    | 1   | 1.5 GiB  | 1,536 MiB      |
| **Total**              |               |                     |                       |                  | 19  |          | **40,448 MiB** |

## Progress

Services currently provisioned (items 1–5 include HAProxy + Keepalived HA):

1. HashiCorp Vault — HA Raft cluster
2. PostgreSQL / Patroni (with etcd)
3. Redis / Sentinel
4. MinIO — distributed object storage
5. Harbor — production container registry
6. GitLab — full Helm chart deployment on Kubeadm
7. Harbor Bootstrapper — OCI seed registry for Helm charts and images
8. Keycloak OIDC — SSO integration for GitLab, Harbor, and Vault
9. Standalone Gitaly
10. **[Ongoing]** HA Gitaly with Praefect
11. **[Ongoing]** GitLab Runner on MicroK8s
12. Private key encryption

> [!WARNING]
> This repo currently only supports Linux hosts with CPU virtualization (VT-x / AMD-V). For hosts without virtualization support, see the `legacy-workstation-on-ubuntu` branch.
