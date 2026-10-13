# MVP: On-Premise GitLab HA on KVM/QEMU, Provisioned via Multi-Layer Terraform, Packer, and Ansible

> [!CAUTION]
> This repository is currently undergoing major refactoring and the `main` branch is temporarily unusable. It is recommended to refer to the latest stable commit [`676dedc`](https://gitlab.com/csning1998-lab/platform-engineering-lab/on-premise-gitlab-deployment/-/commit/676dedc3b93dc6ac142207c645c792aab728f753).

---

> [!NOTE]
> Refer to [README.md](README.md) for English (US) version.
>
> 繁體中文版本的文件的標題與表格，仍會維持英文內容

## Introduction

這是一個在 QEMU-KVM 的地端環境進行分散式 GitLab Helm Chart 佈署的概念驗證 IaC 個人專案。此 repo 是根據在國泰綜合醫院實習期間的個人練習所開發，目標是透過可重複使用的 IaC pipeline 建立出 on-premise GitLab

1. 此 repository 經公司部門同意公開作為技術作品集

2. 目前因為專案在 Ansible Provider 中使用 `action` Block 宣告資源，在目前 2026 年 5 月 1 日的狀態下，需要用 Terraform 1.14 版本以上的 Binary 執行。OpenTofu 社群目前未見相關實做。如後續有支援，會再修改回 OpenTofu。相關指令請使用者自行使用 `terraform` 取代 `tofu` 或使用 alias 進行 CLI 操作

3. 這個 repository 自 [#128](https://gitlab.com/csning1998/on-premise-gitlab-deployment/-/merge_requests/128) 起，已經遷移到 GitLab 上進行託管，後續更新都會在 [https://gitlab.com/csning1998/on-premise-gitlab-deployment](https://gitlab.com/csning1998/on-premise-gitlab-deployment) 上看到。而 GitHub 則是做為 GitLab 專案的 mirror

4. 可透過以下指令 clone 這個專案，在 Git 2.47.0 以上版本可用：

    ```shell
    git clone --depth 1 --revision=676dedc3b93dc6ac142207c645c792aab728f753 https://gitlab.com/csning1998-lab/platform-engineering-lab/on-premise-gitlab-deployment.git
    ```

> [!WARNING]
> 此 repo 目前僅支援具有 CPU virtualization 功能的 Linux 裝置。如果使用的裝置 CPU 不支援 virtualization（例如無 VT-x/AMD-V），請切換至 `legacy-workstation-on-ubuntu` branch，可以支援最基本的 HA Kubeadm Cluster 架設

## Upstream Projects

此 repository 只佈署 GitLab 與 Harbor 服務。共用服務與建置產物由以下上游專案提供

| Project                                                                                                       | Provides                                                                                                                        |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [`parent-group-governance`](https://gitlab.com/csning1998-lab/parent-group-governance)                        | Bastion Vault, GitLab group topology, AI provider federation, and Terraform state backend credentials                           |
| [`platform-foundation`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation)       | Downstream Vault, Harbor Origin, Keycloak, hypervisor baseline, global network baseline, `kvm-provisioning` modules, and images |
| [`platform-observability`](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-observability) | LGTM stack (Loki, Grafana, Tempo, and Mimir) which collects the metrics and logs of this repository                             |

## Documentation

有關完整設定、組態、以及架構文件都存放在 [`documentation/`](documentation/README.md) 中。目前持續更新中

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
> CoW-able 欄位指的是該角色的儲存引擎是否跑 Raft 家族的共識程序（etcd、Vault Raft），且對 fsync 與 quorum timeout 有嚴格預算，CoW 主機檔案系統的間歇性 I/O 停頓會直接變成共識失敗。雖然 Kubeadm Master 跟 MicroK8s 分別內嵌 etcd 跟 dqlite，但周邊的 liveness probe 容忍度足夠寬鬆，同樣的 host 抖動很少會浮現成硬錯誤，所以這兩個角色的 CoW 就不設定為強制禁用

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
> 表格中 RAM 的單位是 GiB

## Progress

目前有處理的服務包含：

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
> **Standalone Gitaly** 與 **(HA) Praefect 即從屬 Patroni** 組態可以雙向同步。可參考 [platform_gitaly_praefect 的 README](ansible/roles/platform_gitaly_praefect/README.md)
