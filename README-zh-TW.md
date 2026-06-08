# PoC: Deploy Distributed GitLab Helm Chart on KVM with Packer, Terraform, Vault, and Ansible

> [!NOTE]
> Refer to [README.md](README.md) for English (US) version.
> 繁體中文版本的文件的標題與表格，仍會維持英文內容

## Introduction

這是一個在 QEMU-KVM 的地端環境進行分散式 GitLab Helm Chart 佈署的概念驗證 IaC 個人專案。此 repo 是根據在國泰綜合醫院實習期間的個人練習所開發，目標是透過可重複使用的 IaC pipeline 建立出 on-premise GitLab

1. 此 repository 經公司部門同意公開作為技術作品集
2. 目前因為專案在 Ansible Provider 中使用 `action` Block 宣告資源，在目前 2026 年 5 月 1 日的狀態下，需要用 Terraform 1.14 版本以上的 Binary 執行。OpenTofu 社群目前未見相關實做。如後續有支援，會再修改回 OpenTofu。相關指令請使用者自行使用 `terraform` 取代 `tofu` 或使用 alias 進行 CLI 操作
3. 這個 repository 自 [#128](https://gitlab.com/csning1998/on-premise-gitlab-deployment/-/merge_requests/128) 起，已經遷移到 GitLab 上進行託管，後續更新都會在 [https://gitlab.com/csning1998/on-premise-gitlab-deployment](https://gitlab.com/csning1998/on-premise-gitlab-deployment) 上看到。而 GitHub 這邊則是做為 GitLab 專案的 mirror
4. 可透過以下指令 clone 這個專案：

    ```shell
    git clone --depth 1 https://gitlab.com/csning1998/on-premise-gitlab-deployment.git
    ```

> [!WARNING]
> 此 repo 目前僅支援具有 CPU virtualization 功能的 Linux 裝置。如果使用的裝置 CPU 不支援 virtualization（例如無 VT-x/AMD-V），請切換至 `legacy-workstation-on-ubuntu` branch，可以支援最基本的 HA Kubeadm Cluster 架設

## Documentation

有關完整設定、組態、以及架構文件都存放在 [`documentation/`](documentation/README.md) 中

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

### Single-Host Resource Allocation

| Network Segment (CIDR) | Service Tier  | Usage (Service)     | HA-able? | VIP (HAProxy/Ingress) | Component (Role) | Basic Qty | Unit RAM | Subtotal RAM   |
| ---------------------- | ------------- | ------------------- | -------- | --------------------- | ---------------- | --------- | -------- | -------------- |
| 172.16.125.0/24        | Shared        | Central LB          | True     | 172.16.125.250        | HAProxy          | 2         | 0.5 GiB  | 1,024 MiB      |
| 172.16.126.0/24        | App (GitLab)  | Kubeadm Cluster     | True     | 172.16.126.250        | Kubeadm Master   | 1         | 3.0 GiB  | 3,072 MiB      |
|                        |               |                     |          |                       | Kubeadm Worker   | 2         | 6.0 GiB  | 12,288 MiB     |
| 172.16.127.0/24        | Data (GitLab) | Postgres            | True     | 172.16.127.250        | Postgres         | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.128.0/24        | Data (GitLab) | Etcd                | True     | 172.16.128.250        | Etcd             | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.129.0/24        | Data (GitLab) | Redis               | True     | 172.16.129.250        | Redis            | 1         | 0.5 GiB  | 512 MiB        |
| 172.16.130.0/24        | Data (GitLab) | MinIO               | True     | 172.16.130.250        | MinIO            | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.131.0/24        | App (Harbor)  | MicroK8s Cluster    | True     | 172.16.131.250        | MicroK8s         | 1         | 4.0 GiB  | 4,096 MiB      |
| 172.16.132.0/24        | Data (Harbor) | Postgres            | True     | 172.16.132.250        | Postgres         | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.133.0/24        | Data (Harbor) | Etcd                | True     | 172.16.133.250        | Etcd             | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.134.0/24        | Data (Harbor) | Redis               | True     | 172.16.134.250        | Redis            | 1         | 0.5 GiB  | 512 MiB        |
| 172.16.135.0/24        | Data (Harbor) | MinIO               | True     | 172.16.135.250        | MinIO            | 1         | 1.0 GiB  | 1,024 MiB      |
| 172.16.136.0/24        | Shared        | Vault               | True     | 172.16.136.250        | Vault (Raft)     | 1         | 0.5 GiB  | 512 MiB        |
| 172.16.137.0/24        | App (Harbor)  | Harbor Bootstrapper | False    | 172.16.137.250        | Docker Engine    | 1         | 1.5 GiB  | 1,536 MiB      |
| 172.16.138.0/24        | Data (GitLab) | Gitaly              | True     | 172.16.138.250        | Gitaly           | 1         | 2.0 GiB  | 2,048 MiB      |
| 172.16.139.0/24        | App (GitLab)  | GitLab Runner       | True     | 172.16.139.250        | MicroK8s         | 1         | 4.0 GiB  | 4,096 MiB      |
| 172.16.142.0/24        | Shared        | Keycloak SSO        | False    | 172.16.142.250        | Docker Engine    | 1         | 1.5 GiB  | 1,536 MiB      |
| **Total**              |               |                     |          |                       |                  | 18        |          | **37,376 MiB** |

### Quorum-Minimum HA Resource Allocation

| Network Segment (CIDR) | Service Tier  | Usage (Service)     | HA-able? | VIP (HAProxy/Ingress) | Component (Role) | HA Min Qty | Unit RAM | Subtotal RAM   |
| ---------------------- | ------------- | ------------------- | -------- | --------------------- | ---------------- | ---------- | -------- | -------------- |
| 172.16.125.0/24        | Shared        | Central LB          | True     | 172.16.125.250        | HAProxy          | 2          | 0.5 GiB  | 1,024 MiB      |
| 172.16.126.0/24        | App (GitLab)  | Kubeadm Cluster     | True     | 172.16.126.250        | Kubeadm Master   | 3          | 3.0 GiB  | 9,216 MiB      |
|                        |               |                     |          |                       | Kubeadm Worker   | 2          | 6.0 GiB  | 12,288 MiB     |
| 172.16.127.0/24        | Data (GitLab) | Postgres            | True     | 172.16.127.250        | Postgres         | 3          | 1.0 GiB  | 3,072 MiB      |
| 172.16.128.0/24        | Data (GitLab) | Etcd                | True     | 172.16.128.250        | Etcd             | 3          | 1.0 GiB  | 3,072 MiB      |
| 172.16.129.0/24        | Data (GitLab) | Redis               | True     | 172.16.129.250        | Redis            | 3          | 0.5 GiB  | 1,536 MiB      |
| 172.16.130.0/24        | Data (GitLab) | MinIO               | True     | 172.16.130.250        | MinIO            | 4          | 1.0 GiB  | 4,096 MiB      |
| 172.16.131.0/24        | App (Harbor)  | MicroK8s Cluster    | True     | 172.16.131.250        | MicroK8s         | 3          | 4.0 GiB  | 12,288 MiB     |
| 172.16.132.0/24        | Data (Harbor) | Postgres            | True     | 172.16.132.250        | Postgres         | 3          | 1.0 GiB  | 3,072 MiB      |
| 172.16.133.0/24        | Data (Harbor) | Etcd                | True     | 172.16.133.250        | Etcd             | 3          | 1.0 GiB  | 3,072 MiB      |
| 172.16.134.0/24        | Data (Harbor) | Redis               | True     | 172.16.134.250        | Redis            | 3          | 0.5 GiB  | 1,536 MiB      |
| 172.16.135.0/24        | Data (Harbor) | MinIO               | True     | 172.16.135.250        | MinIO            | 4          | 1.0 GiB  | 4,096 MiB      |
| 172.16.136.0/24        | Shared        | Vault               | True     | 172.16.136.250        | Vault (Raft)     | 3          | 0.5 GiB  | 1,536 MiB      |
| 172.16.137.0/24        | App (Harbor)  | Harbor Bootstrapper | False    | 172.16.137.250        | Docker Engine    | 1          | 1.5 GiB  | 1,536 MiB      |
| 172.16.138.0/24        | Data (GitLab) | Gitaly              | True     | 172.16.138.250        | Gitaly           | 3          | 2.0 GiB  | 6,144 MiB      |
| 172.16.139.0/24        | App (GitLab)  | GitLab Runner       | True     | 172.16.139.250        | MicroK8s         | 3          | 4.0 GiB  | 12,288 MiB     |
| 172.16.140.0/24        | Data (GitLab) | Praefect            | True     | 172.16.138.250        | Praefect         | 3          | 4.0 GiB  | 12,288 MiB     |
| 172.16.141.0/24        | Data (GitLab) | Patroni (Praefect)  | True     | 172.16.138.250        | Postgres         | 3          | 2.0 GiB  | 6,144 MiB      |
| 172.16.142.0/24        | Shared        | Keycloak SSO        | False    | 172.16.142.250        | Docker Engine    | 1          | 1.5 GiB  | 1,536 MiB      |
| **Total**              |               |                     |          |                       |                  | 53         |          | **99,840 MiB** |

## Progress

目前有處理的服務包含：

1. HashiCorp Vault HA Raft cluster for PKI with Sidecar, ACL, AppRole, RBAC
2. Postgres / Patroni (with etcd)
3. Redis / 哨兵模式
4. Distributed MinIO 針對物件儲存
5. Harbor for Production container registry for GitLab Runner
6. GitLab with full Helm chart deployment on Kubeadm
7. Harbor Bootstrapper as OCI seed registry for Helm charts and images
8. Keycloak OIDC for SSO integration for GitLab, Harbor (both), and Vault
9. Standalone Gitaly
10. HA Gitaly with Praefect
11. GitLab Runner on MicroK8s
12. **[WIP]** Remote Terraform States
13. **[Pending]** Prometheus / Grafana / Loki Integration
