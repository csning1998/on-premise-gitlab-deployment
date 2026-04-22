# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

> [!NOTE]
> Refer to [README.md](README.md) for English (US) version.

## Section 0. Introduction

這個 repository （以下簡稱「此 repo」）是一套 Infrastructure as Code 的 PoC（概念驗證），主要是透過 QEMU-KVM 在純地端環境中進行 HA 的 Kubernetes Cluster (Kubeadm / microk8s) 的自動佈署。此 repo 是根據在國泰綜合醫院實習期間的個人練習所開發，目標是建立出 on-premise GitLab 建立自動佈署基礎設施，目標是針對 legacy 系統做出可以重複利用的 IaC pipeline

> [!NOTE]
> 本 repository 經公司部門同意公開作為技術作品集

開發使用的機器規格如下，僅供參考：

- **Chipset：** Intel® HM770
- **CPU：** Intel® Core™ i7 processor 14700HX
- **RAM：** Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
- **SSD：** WD PC SN560 SDDPNQE-1T00-1032

可透過以下指令 clone 這個專案：

```shell
git clone --depth 1 https://github.com/csning1998-old/on-premise-gitlab-deployment.git
```

此 repo 具有以下資源分配，基於 RAM 本身限制，僅供參考：

| Network Segment (CIDR) | Service Tier  | Usage (Service)  | Storage Pool Name   | VIP (HAProxy/Ingress) | Node IP Allocation               | Component (Role) | Quantity | Unit vCPU | Unit RAM | Subtotal RAM   | Notes                                      |
| ---------------------- | ------------- | ---------------- | ------------------- | --------------------- | -------------------------------- | ---------------- | -------- | --------- | -------- | -------------- | ------------------------------------------ |
| 172.16.125.0/24        | Shared        | Central LB       | core-central-lb     | 172.16.125.250        | `.20x` (Frontend)                | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        | TCP forwarding only                        |
| 172.16.126.0/24        | App (GitLab)  | Kubeadm Cluster  | core-gitlab-kubeadm | 172.16.126.250        | `.200` (Master), `.21x` (Worker) | Kubeadm Master   | 1        | 4         | 4.0 GiB  | 4,096 MiB      | Used for GitLab Helm Chart deployment      |
|                        |               |                  |                     |                       |                                  | Kubeadm Worker   | 2        | 4         | 6.0 GiB  | 12,288 MiB     | For Rails/Sidekiq, GitLab Runner, etc.     |
| 172.16.127.0/24        | Data (GitLab) | Postgres HA      | core-gitlab-pg      | 172.16.127.250        | `.20x` (Postgres)                | Postgres         | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Instantiated via Module 30                 |
| 172.16.128.0/24        | Data (GitLab) | Etcd HA          | core-gitlab-etcd    | 172.16.128.250        | `.20x` (Etcd)                    | Etcd             | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Patroni backend                            |
| 172.16.129.0/24        | Data (GitLab) | Redis HA         | core-gitlab-redis   | 172.16.129.250        | `.20x` (Redis)                   | Redis            | 1        | 2         | 2.0 GiB  | 2,048 MiB      |                                            |
| 172.16.130.0/24        | Data (GitLab) | MinIO HA         | core-gitlab-minio   | 172.16.130.250        | `.20x` (MinIO)                   | MinIO            | 1        | 2         | 3.0 GiB  | 3,072 MiB      | Distributed MinIO ready                    |
| 172.16.131.0/24        | App (Harbor)  | MicroK8s Cluster | core-harbor         | 172.16.131.250        | `.20x` (Nodes)                   | MicroK8s Node    | 1        | 4         | 4.0 GiB  | 4,096 MiB      | Full Harbor consumes ~4-5 GB               |
| 172.16.132.0/24        | Data (Harbor) | Postgres HA      | core-harbor-pg      | 172.16.132.250        | `.20x` (Postgres)                | Postgres         | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Same as GitLab Postgres                    |
| 172.16.133.0/24        | Data (Harbor) | Etcd HA          | core-harbor-etcd    | 172.16.133.250        | `.20x` (Etcd)                    | Etcd             | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Patroni backend                            |
| 172.16.134.0/24        | Data (Harbor) | Redis HA         | core-harbor-redis   | 172.16.134.250        | `.20x` (Redis)                   | Redis            | 1        | 2         | 2.0 GiB  | 2,048 MiB      |                                            |
| 172.16.135.0/24        | Data (Harbor) | MinIO HA         | core-harbor-minio   | 172.16.135.250        | `.20x` (MinIO)                   | MinIO            | 1        | 2         | 3.0 GiB  | 3,072 MiB      | Same as GitLab MinIO                       |
| 172.16.136.0/24        | Shared        | Vault HA         | core-vault          | 172.16.136.250        | `.20x` (Vault)                   | Vault (Raft)     | 1        | 2         | 1.0 GiB  | 1,024 MiB      | Raft is lightweight; Shared secrets center |
| 172.16.137.0/24        | App (Harbor)  | Bootstrapper     | core-bootstrapper   | 172.16.137.250        | `.200` (Docker)                  | Docker Engine    | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Ephemeral deployment controller            |
| 172.16.138.0/24        | Data (GitLab) | Gitaly node      | core-gitaly         | 172.16.138.250        | `.20x`                           | Gitaly           | 1        | 2         | 2.0 GiB  | 2,048 MiB      | [Pending] Not deployed                     |
| **Total**              |               |                  |                     |                       |                                  |                  | **19**   |           |          | **55,296 MiB** | ≈ 54.0 GiB                                 |

### A. Disclaimer

- 此 repo 目前僅支援具有 CPU virtualization 功能的 Linux 裝置，還沒有在 Fedora、Arch、CentOS、WSL2 等其他 distro 上測試。可使用以下指令檢查開發裝置是否支援 virtualization：

    ```shell
    lscpu | grep Virtualization
    ```

    輸出可能為：
    - Virtualization: VT-x (Intel)
    - Virtualization: AMD-V (AMD)
    - 若無輸出，則可能不支援 virtualization

> [!WARNING]
> **Compatibility Warning**
> 此 repo 目前僅支援具有 CPU virtualization 功能的 Linux 裝置。如果使用的裝置 CPU 不支援 virtualization（例如無 VT-x/AMD-V），請切換至 `legacy-workstation-on-ubuntu` branch，可以支援最基本的 HA Kubeadm Cluster 架設
>
> 此外，目前此 repo 為個人獨立開發，可能存在邊際問題，一經發現將立即修正

### B. Prerequisites

在開始前，要先確認裝置滿足以下條件：

- 一台 Linux Host，建議使用 Fedora 43、RHEL 10 或 Ubuntu 24
- CPU 必須有支援 virtualization，即具有 VT-x 或 AMD-V
- 具備 `sudo` 權限以操作 Libvirt
- 已安裝 `podman` 與 `podman compose`，用於 containerized 模式
- 已安裝 `openssl` 套件，主要需要 `openssl passwd` 指令
- 已安裝 `jq` 套件，用於解析 JSON

### C. Progress

目前此專案可以建立以下 1 到 5 的 Services，其中單獨 Service 接配有 HAProxy 搭配 Keepalived

1. HA HashiCorp Vault with Raft Storage
2. Postgres / Patroni 包含 etcd
3. Redis / Sentinel
4. MinIO (S3) / Distributed MinIO
5. Harbor 作為映像檔 GitLab 的 Registry
6. GitLab Webapp 本體
7. **[ONGOING]** 修正 Harbor 與 GitLab 的 Rediss 問題
8. **[WIP]** GitLab Runner (on Microk8s) / Gitaly (Praefact) 等
9. Private Key Encryption
10. [OpenTofu](https://github.com/opentofu/opentofu.git) Migration 對於 `*.tfstates` 檔案的加密

### D. The Entrypoint: `entry.sh`

> [!NOTE]
> Section 1 與 Section 2 的內容為正式執行前的前置作業。詳見以下說明：

此 Repo 的服務前置作業、與生命週期管理等，都會透過根目錄下的 `entry.sh` 腳本處理。在終端機切換到此 repo 的根目錄後，執行 `./entry.sh` 會顯示以下內容：

```text
➜  on-premise-gitlab-deployment git:(main) ✗ ./entry.sh
... (Some preflight check)

======= IaC-Driven Virtualization Management =======

[INFO] Environment: NATIVE
--------------------------------------------------
[OK] Bootstrapper Vault (Local): Running (Unsealed)
[OK] Production Vault (Layer 15): Running (Unsealed)
------------------------------------------------------------

1) [DEV] Set up TLS for Bootstrapper Vault (Local)          7) Setup Core IaC Tools                          13) Switch Environment Strategy
2) [DEV] Initialize Bootstrapper Vault (Local)              8) Verify IaC Environment                        14) Purge Specific Terraform Layer
3) [DEV] Unseal Bootstrapper Vault (Local)                  9) Build Packer Base Image                       15) Purge All Libvirt Resources
4) [PROD] Unseal Production Vault (via Ansible)            10) Provision Terraform Layer                     16) Purge All Packer and Terraform Resources
5) Generate SSH Key                                        11) Rebuild Terraform Layer via Ansible           17) Quit
6) Setup KVM / QEMU for Native                             12) Verify SSH

[INPUT] Please select an action:
```

選擇選項 `9`、`10`、`11` 後會根據 `packer/output` 與 `terraform/layers` 目錄動態產生 submenu。目前完整設定下的 submenu 如下：

> [!NOTE]
> 目前選項 `11` 的功能故障

1. 選 `9) Build Packer Base Image` 時

    ```text
    [INPUT] Please select an action: 9
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.

    [INFO] Select Packer category to build:
    ------------------------------------------------------------
    1) Base OS Layers    2) Service Layers    3) Build ALL    4) Back to Main Menu

    [INPUT] Select a category:
    ```

    選擇 `1` 主要是用來建立基礎映像檔案，會包含 APT 更新等

    ```text
    [INPUT] Select a category: 1
    1) ubuntu-24-updated
    2) Build ALL in Base OS Images
    3) Back
    ```

    選擇 `2` 會建立服務映像檔案。這會在 Packer HCL 內指定 `1` 所建立好的映像檔案來源，並在映像檔案內安裝該服務的執行檔與相關套件

    ```text
    [INPUT] Select a category: 2
    1) base-etcd       3) base-kubeadm        5) base-minio        7) base-redis        9) docker-harbor     11) Back
    2) base-haproxy    4) base-microk8s       6) base-postgres     8) base-vault        10) Build ALL in Service Images
    ```

2. 選 `10) Provision Terraform Layer` 時

    ```text
    [INPUT] Please select an action: 10
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) 00-foundation-metadata                       8) 25-security-pki                            15) 30-infra-harbor-minio                      22) 50-platform-harbor
    2) 00-foundation-vault-bootstrapper             9) 30-infra-gitlab-frontend                   16) 30-infra-harbor-postgres                   23) 60-provision-gitlab
    3) 05-foundation-network                       10) 30-infra-gitlab-minio                      17) 30-infra-harbor-redis                      24) 60-provision-harbor
    4) 05-foundation-volume                        11) 30-infra-gitlab-postgres                   18) 40-provision-gitlab-databases              25) 90-meta-github
    5) 10-shared-load-balancer-frontend            12) 30-infra-gitlab-redis                      19) 40-provision-harbor-bootstrapper-frontend  26) Back to Main Menu
    6) 15-shared-vault-frontend                    13) 30-infra-harbor-bootstrapper-frontend      20) 40-provision-harbor-databases
    7) 20-security-vault-approle                   14) 30-infra-harbor-frontend                   21) 50-platform-gitlab

    [INPUT] Select a Terraform layer to UPDATE / PROVISION:
    ```

3. _**（即將棄用）**_ 選 `11) Rebuild Layer via Ansible` 時

    ```text
    [INPUT] Please select an action: 11
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) inventory-10-vault-core.yaml         6) inventory-20-harbor-postgres.yaml
    2) inventory-20-gitlab-minio.yaml       7) inventory-20-harbor-redis.yaml
    3) inventory-20-gitlab-postgres.yaml    8) inventory-30-gitlab-kubeadm.yaml
    4) inventory-20-gitlab-redis.yaml       9) inventory-30-harbor-microk8s.yaml
    5) inventory-20-harbor-minio.yaml      10) Back to Main Menu

    [INPUT] Select a Cluster Inventory to run its Playbook:
    ```

**以下為 `entry.sh` 的使用說明**

## Section 1. Environmental Setup

### A. Required. KVM / QEMU

可以透過 `entry.sh` 選項 `6` 自動安裝 QEMU/KVM 環境，注意目前僅在 Ubuntu 24 與 RHEL 10 上測試過。亦可自行參考相關資源後，根據該開發裝置的平台設定 KVM 與 QEMU 環境

### B. Option 1. Install IaC tools on Native

1. **_（即將棄用）_ 安裝 HashiCorp Toolkit - Terraform and Packer**

    接著在專案根目錄執行 `entry.sh`，選擇選項 `7` _"Setup Core IaC Tools for Native"_ 來安裝 Terraform、Packer 與 Ansible。可以參考官方安裝說明：

    > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_
    > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_
    > _Reference: [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)_

    預期輸出應顯示最新版本，例如（在 zsh 下）：

    ```text
    ...
    [INPUT] Please select an action: 7
    [STEP] Verifying Core IaC Tools (HashiCorp/Ansible)...
    [STEP] Setting up core IaC tools...
    [TASK] Installing OS-specific base packages for RHEL...
    ...
    [TASK] Installing Ansible Core using pip...
    ...
    [INFO] Installing HashiCorp Toolkits (Terraform, Packer, Vault)...
    [TASK] Installing terraform...
    ...
    [TASK] Installing packer...
    ...
    [TASK] Installing vault...
    ...
    [TASK] Installing to /usr/local/bin/vault
    [INFO] Verifying installed tools...
    [STEP] Verifying Core IaC Tools (HashiCorp/Ansible)...
    [INFO] HashiCorp Packer: Installed
    [INFO] HashiCorp Terraform: Installed
    [INFO] HashiCorp Vault: Installed
    [INFO] Red Hat Ansible: Installed
    [OK] Core IaC tools setup and verification completed.
    ```

2. 要確認 Podman / Docker 已經正確安裝，需根據開發裝置的作業系統，參考以下網址選擇對應安裝方式

    > _Reference: [Podman Installation](https://podman.io/getting-started/installation)_
    > _Reference: [Docker Installation](https://docs.docker.com/get-docker/)_

3. 以 Podman 為例，在 Podman 安裝完成後，切換至專案根目錄：
    1. 通常預設的 memlock limit (`ulimit -l`) 較低，會導致 HashiCorp Vault 的 mlock system call 失敗，且一般情況下的 Rootless Podman 只是經過 `uid` mapping 到 Host 上的普通使用者，會直接繼承權限限制。為解決此問題，請執行以下指令修改：

        ```shell
        sudo tee -a /etc/security/limits.conf <<EOT
        ${USER}    soft    memlock    unlimited
        ${USER}    hard    memlock    unlimited
        EOT
        ```

        這樣才能讓 user namespace 內的 Vault 進程真正鎖定記憶體。修改後需要重新開機才能生效，以避免敏感資料被換出到未加密的 swap 空間

    2. 若為第一次使用，請執行：

        ```shell
        podman compose up --build
        ```

    3. 在容器建立後，之後只需執行以下指令即可啟動：

        ```shell
        podman compose up -d
        ```

    4. 目前預設設定為 `DEBIAN_FRONTEND=noninteractive`。若需進入容器修改或檢查，可執行：

        ```shell
        podman exec -it iac-controller-base bash
        ```

        其中 `iac-controller-base` 為這個專案的 root Container 名稱

    5. 執行 `podman compose --profile all up -d` 與 `podman ps -a` 後的預設容器輸出類似以下：

        ```text
        CONTAINER ID  IMAGE                                            COMMAND               CREATED         STATUS                   PORTS       NAMES
        974baf0177f6  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  24 seconds ago  Up 14 seconds (healthy)  8200/tcp    iac-vault-server
        ea3b31db9a5c  localhost/on-premise-iac-controller:qemu-latest  /bin/bash -c whil...  24 seconds ago  Up 14 seconds                        iac-runner
        ```

> [!NOTE]
> **Resolved: Data Loss Warning**
> ~~當在 Podman 容器與 Native 環境之間切換時，所有由 Terraform 建立的 Libvirt 資源都會被 **自動刪除**，以避免 Libvirt UNIX socket 的權限與上下文衝突~~

### C. Miscellaneous

**建議的 VSCode Plugin：** 主要是相關 syataxes highlighting 的支援而已：

1. Ansible language support extension. [Marketplace Link of Ansible](https://marketplace.visualstudio.com/items?itemName=redhat.ansible)

    ```shell
    code --install-extension redhat.ansible
    ```

2. HCL language support extension for Terraform. [Marketplace Link of HashiCorp HCL](https://marketplace.visualstudio.com/items?itemName=HashiCorp.HCL)

    ```shell
    code --install-extension HashiCorp.HCL
    ```

3. Packer tool extension. [Marketplace Link of Packer Powertools](https://marketplace.visualstudio.com/items?itemName=szTheory.vscode-packer-powertools)

    ```shell
    code --install-extension szTheory.vscode-packer-powertools
    ```

## Section 2. Configuration

### Step A. Project Overview

> [!IMPORTANT]
> 為確保此 repo 可以順利執行，請務必依以下順序完成初始化設定

0. **環境變數檔案：** `entry.sh` 會自動產生 `.env` 環境變數檔案，主要是給其他 shell script 使用，可以忽略不管
1. **產生 SSH Key：** 在 Terraform 與 Ansible 執行過程中，SSH key 主要是讓服務可以登入虛擬機進行自動化設定。在執行 `./entry.sh` 的選項 `5` _"Generate SSH Key"_ 就可以產生 SSH Key，預設名稱為 `id_ed25519_on-premise-gitlab-deployment`。這步驟產生的公鑰與私鑰會儲存於 `~/.ssh/` 目錄下
2. **切換環境：** 可透過 `./entry.sh` 的選項 `13` 在 _"Container"_ 與 _"Native"_ 環境之間切換

    其中此 repo 以 Podman 作為 container runtime。之所以避開使用 Docker，主要就是避免 SELinux 權限衝突問題。在啟用 SELinux 的系統（例如 Fedora、RHEL、CentOS Stream 等）上，Docker 容器預設執行在 `container_t` 的 SELinux domain。這樣即使正確 mount `/var/run/libvirt/libvirt-sock` 後，SELinux policy 仍會禁止 `container_t` 連線到 `virt_var_run_t` 的 UNIX socket，從而導致 Terraform libvirt provider 或 `virsh` 出現 **Permission denied** 錯誤，即便檔案權限含 `0770` 與 `libvirt` 群組已經正確設定亦同

    相對來說 **rootless Podman** 的 process 上下文（即 `task_struct`）通常為使用者的 `unconfined_t` 或類似的 SELinux type，而不會強制套用 `container_t`。因此在使用者已加入 `libvirt` 群組的前提下，能夠順利連線到 `libvirt` socket，無需額外調整 SELinux policy。若使用者環境強制使用 Docker，可考慮關閉 SELinux（但不推薦）、或自訂 SELinux module，或改用 TCP 連線 `libvirtd` 但安全性較低

### Step B. Set up Variables

#### **Step B.0. Examine the Permissions of Libvirt**

> [!NOTE]
> Libvirt 的檔案權限設定問題，這也會直接影響 [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest) 的執行權限，因此需要先進行一些權限檢查

1. 確保使用者帳號已加入 `libvirt` 群組

    ```shell
    sudo usermod -aG libvirt $(whoami)
    ```

    完成後需完整登出再登入，或重新開機。這樣 group 變更才會在 shell session 中生效

2. 修改 `libvirtd` 設定檔，要明確指定 `libvirt` 群組管理 socket

    ```shell
    # If vim is preferred
    sudo vim /etc/libvirt/libvirtd.conf

    # If nano is preferred
    sudo nano /etc/libvirt/libvirtd.conf
    ```

    找到以下兩行，移除開頭的 `#` 來取消註解

    ```toml
    unix_sock_group = "libvirt"
    # ...
    unix_sock_rw_perms = "0770"
    ```

3. 現在要覆蓋 systemd socket unit 設定，因為 systemd socket 設定會比 `libvirtd.conf` 優先
    1. 執行以下指令開啟 nano 編輯器

        ```shell
        sudo systemctl edit libvirtd.socket
        ```

    2. 要在編輯器中貼上以下內容，且確保是貼在 `### Edits below this comment will be discarded` 這一列的上方，才不會讓設定檔失效

        ```toml
        [Socket]
        SocketGroup=libvirt
        SocketMode=0770
        ```

        完成後按 `Ctrl+O` 儲存、`Ctrl+X` 離開

4. 請依照正確順序重新啟動服務讓所有設定生效
    1. 重新載入 `systemd` 設定：

        ```shell
        sudo systemctl daemon-reload
        ```

    2. 停止所有 `libvirtd` 相關的服務確保乾淨狀態：

        ```shell
        sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
        ```

    3. 停用 `libvirtd.service`，完全交由 Socket Activation 管理：

        ```shell
        sudo systemctl disable libvirtd.service
        ```

    4. 重新啟動 `libvirtd.socket`

        ```shell
        sudo systemctl restart libvirtd.socket
        ```

5. 驗證
    1. 檢查 socket 權限：輸出應顯示群組為 `libvirt`，權限為 `srwxrwx---`

        ```shell
        ls -la /var/run/libvirt/libvirt-sock
        ```

    2. 以 **非 root** 使用者執行 `virsh` 指令

        ```shell
        virsh list --all
        ```

        若指令成功執行並列出虛擬機器（即使清單為空），代表所有必要權限已正確設定

#### **Step B.1. Prepare GitHub Credentials for Self-Management**

> [!NOTE]
> 這個專案預設使用 [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) 管理 Repository，因此需要 Fine-grained Personal Access Token 的設定。如果 clone 此 repo 的使用者不使用 Terraform GitHub Integration 管理 repo，可以跳過或刪除 `terraform/layers/90-github-meta`，且後續執行不會受影響

1. 前往 [GitHub Developer Settings](https://github.com/settings/personal-access-tokens) 申請 Fine-grained Personal Access Token
2. 點擊頁面上方右側的 `Generate new token` 按鈕，設定 Token 名稱、有效期限與 Repository 存取範圍
3. 在 Permissions 部分，選擇以下權限：

    | Permission                     | Access Level   | Description                               |
    | ------------------------------ | -------------- | ----------------------------------------- |
    | Metadata                       | Read-only      | Mandatory                                 |
    | Administration                 | Read and Write | For modifying Repo settings and Ruleset   |
    | Contents                       | Read and Write | For reading Ref and Git information       |
    | Repository security advisories | Read and Write | For managing security advisories          |
    | Dependabot alerts              | Read and Write | For managing dependency alert             |
    | Secrets                        | Read and Write | (Optional) for managing Actions Secrets   |
    | Variables                      | Read and Write | (Optional) for managing Actions Variables |
    | Webhooks                       | Read and Write | (Optional) for managing Webhooks          |

4. 點擊 `Generate token` 並複製產生的 token 供下一步使用

#### **Step B.2. Create Confidential Variable File for HashiCorp Vault**

> [!IMPORTANT]
> **所有機密資料均整合到 HashiCorp Vault 內，且分為 Development mode 與 Production mode。此 repo 預設使用的 Vault 是走 HTTPS 傳輸、且憑證為 Self-signed CA。請依以下步驟正確設定**

0.  **要先建立 Bootstrapper Vault 後才能建立 Production Vault。其中 Bootstrapper Vault 僅用於建立 Production Vault 與 Packer Images，之後所有專案的敏感資料皆由 Production Vault 管理**
1.  首先執行 `entry.sh` 選擇選項 `1`，產生 TLS handshake 所需要的檔案。建立 Self-signed CA 時，部分欄位可留空。若需重新產生 TLS 檔案，可再次執行選項 `1`
2.  切換至專案根目錄，執行以下指令啟動引導用 Bootstrapper Vault server。此 repo 預設在 container 走 side-car 模式執行：

    ```shell
    podman compose up -d iac-vault-server
    ```

    啟動 server 後，Bootstrapper Vault 就會在 `vault/data/` 路徑中產生 `vault.db` 以及 Raft 相關檔案。如果有需要重新建立 Bootstrapper Vault，就必須手動清除 `vault/data/` 與 `vault/keys/` 內所有檔案。請開新終端機視窗或分頁進行後續操作，以避免 shell session 的環境變數污染

3.  完成前述步驟後，執行 `entry.sh` 選擇選項 2 初始化 Bootstrapper Vault。此過程也會自動執行 Unseal
4.  接下來只需手動修改以下專案使用的變數。密碼必須替換為不重複內容，藉以確保安全性
    - **強烈建議執行完任何 `vault kv put` 指令之後，清除 Shell Histroy 的機敏變數，以免洩漏。詳見下方 Note 0 說明**
    - **針對 Bootstrapper Vault**
        - 以下變數用來建立 packer 與 Terraform Layer `10` 中的 production HashiCorp Vault
            - `github_pat`: 前一步取得的 GitHub Personal Access Token
            - `ssh_username`, `ssh_password`: SSH 使用者名稱與密碼
            - `vm_username`, `vm_password`: VM 使用者名稱與密碼
            - `ssh_public_key_path`, `ssh_private_key_path`: 位於 host 的 SSH 公私鑰路徑

        ```shell
        printf "Enter ssh Password: "
        read -s ssh_password
        vault kv put \
            -address="https://127.0.0.1:8200" \
            -ca-cert="${PWD}/vault/tls/ca.pem" \
            secret/on-premise-gitlab-deployment/guest_vm \
            ssh_username="<YOUR_PRODUCTION_SSH_USERNAME>" \
            ssh_password="$ssh_password" \
            ssh_password_hash="$(printf '%s' "$ssh_password" | openssl passwd -6 -stdin)" \
            vm_username="<YOUR_PRODUCTION_VM_USERNAME_OR_SAME_AS_ssh_username>" \
            vm_password="<YOUR_PRODUCTION_VM_PASSWORD_OR_SAME_AS_ssh_password>" \
            ssh_public_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment.pub" \
            ssh_private_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment"

        vault kv put \
            -address="https://127.0.0.1:8200" \
            -ca-cert="${PWD}/vault/tls/ca.pem" \
            secret/on-premise-gitlab-deployment/project_meta \
            github_pat="<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>"

        vault kv put \
            -address="https://127.0.0.1:8200" \
            -ca-cert="${PWD}/vault/tls/ca.pem" \
            secret/on-premise-gitlab-deployment/infrastructure \
            haproxy_stats_pass="haproxy_stats_pass_dev_password" \
            keepalived_auth_pass="keepalived_auth_pass_dev_password"
        ```

        如果沒有使用 `90-github-meta` 管理 GitHub Repo 的設定，可以刪除 `github_pat` 這個 secret

    - **For Production Vault**
        - 以下變數用來建立 Patroni / Sentinel / MinIO (S3) / Harbor / GitLab 叢集的 Terraform Layer
            - `ssh_username`, `ssh_password`: SSH 登入憑證
            - `vm_username`, `vm_password`: 虛擬機器登入憑證
            - `ssh_public_key_path`, `ssh_private_key_path`: host 機器上的 SSH 公私鑰路徑
            - `pg_superuser_password`: PostgreSQL superuser (`postgres`) 密碼。用來初始化資料庫 (`initdb`)、Patroni 管理操作、以及手動進行資料庫維護
            - `pg_replication_password`: Streaming Replication 使用者密碼。這是 Patroni 在建立 standby 節點時，standby 會使用這密碼連接到 primary 進行 WAL 同步
            - `pg_vrrp_secret`: Keepalived 節點的 VRRP 認證金鑰。主要是確保只有授權節點參與 Virtual IP (VIP) 選舉與 failover，避免本地網路中出現惡意干擾
            - `redis_requirepass`: Redis client 端認證密碼。GitLab、Harbor 等任何連接到 Redis 的 client 端都需要透過 `AUTH` 指令使用此密碼存取資料
            - `redis_masterauth`: Redis replica 連接到 master 進行同步時的認證密碼。這是在 failover 時，新的 replica 會使用此密碼對升級為 master 的節點做交握。雖然 Redis 允許不同密碼，但通常會設定與 `redis_requirepass` 相同以避免在 Sentinel + HA 情境下不同會導致 failover 後 replication 失敗
            - `redis_vrrp_secret`: Redis 負載平衡層 (HAProxy/Keepalived) 的 VRRP 認證金鑰，原理與 `pg_vrrp_secret` 相同
            - `minio_root_user`: MinIO root 管理員帳號（舊稱 Access Key），主要用於登入 MinIO Console 或透過 MinIO Client (`mc`) 管理 bucket 與 policy
            - `minio_root_password`: MinIO root 管理員密碼（舊稱 Secret Key）
            - `minio_vrrp_secret`: MinIO 負載平衡層 (HAProxy/Keepalived) 的 VRRP 認證金鑰，原理與 `pg_vrrp_secret` 相同
            - `vault_haproxy_stats_pass`: HAProxy Stats Dashboard 的登入密碼，主要用來保護 Web UI（通常在 port `8404`），呈現後端伺服器健康狀態、以及流量統計
            - `vault_keepalived_auth_pass`: Vault cluster 負載平衡器的 VRRP 認證金鑰，用來保護 Vault 服務 VIP
            - `harbor_admin_password`: Harbor Web Portal `admin` 帳號的預設密碼，用來初次登入 Harbor 建立 project 與設定 robot account
            - `harbor_pg_db_password`: Harbor 服務 (Core、Notary、Clair) 連接到 PostgreSQL 的專用密碼，這是應用層級密碼（通常對應 DB user `harbor`），權限低於 `pg_superuser_password`

        ```shell
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt"
        export VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials)
        vault secrets enable -path=secret kv-v2

        printf "Enter ssh Password: "
        read -s ssh_password
        vault kv put secret/on-premise-gitlab-deployment/guest_vm \
            ssh_username="<YOUR_PRODUCTION_SSH_USERNAME>" \
            ssh_password="$ssh_password" \
            ssh_password_hash="$(printf '%s' "$ssh_password" | openssl passwd -6 -stdin)" \
            vm_username="<YOUR_PRODUCTION_VM_USERNAME_OR_SAME_AS_ssh_username>" \
            vm_password="<YOUR_PRODUCTION_VM_PASSWORD_OR_SAME_AS_ssh_password>" \
            ssh_public_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment.pub" \
            ssh_private_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment"

        vault kv put secret/on-premise-gitlab-deployment/infrastructure \
            haproxy_stats_pass="<YOUR_HAPROXY_STATS_PASSWORD>" \
            keepalived_auth_pass="<YOUR_KEEPALIVED_AUTH_PASSWORD>"

        vault kv put secret/on-premise-gitlab-deployment/gitlab/databases \
            pg_superuser_password="<YOUR_GITLAB_PG_SUPERUSER_PASSWORD>" \
            pg_replication_password="<YOUR_GITLAB_PG_REPLICATION_PASSWORD>" \
            pg_vrrp_secret="<YOUR_GITLAB_PG_VRRP_SECRET>" \
            redis_requirepass="<YOUR_GITLAB_REDIS_REQUIREPASS>" \
            redis_masterauth="<YOUR_GITLAB_REDIS_MASTERAUTH>" \
            redis_vrrp_secret="<YOUR_GITLAB_REDIS_VRRP_SECRET>" \
            minio_root_password="<YOUR_GITLAB_MINIO_ROOT_PASSWORD>" \
            minio_vrrp_secret="<YOUR_GITLAB_MINIO_VRRP_SECRET>" \
            minio_root_user="<YOUR_GITLAB_MINIO_ROOT_USER>"

        vault kv put secret/on-premise-gitlab-deployment/harbor/databases \
            pg_superuser_password="<YOUR_HARBOR_PG_SUPERUSER_PASSWORD>" \
            pg_replication_password="<YOUR_HARBOR_PG_REPLICATION_PASSWORD>" \
            pg_vrrp_secret="<YOUR_HARBOR_PG_VRRP_SECRET>" \
            redis_requirepass="<YOUR_HARBOR_REDIS_REQUIREPASS>" \
            redis_masterauth="<YOUR_HARBOR_REDIS_MASTERAUTH>" \
            redis_vrrp_secret="<YOUR_HARBOR_REDIS_VRRP_SECRET>" \
            minio_root_password="<YOUR_HARBOR_MINIO_ROOT_PASSWORD>" \
            minio_vrrp_secret="<YOUR_HARBOR_MINIO_VRRP_SECRET>" \
            minio_root_user="<YOUR_HARBOR_MINIO_ROOT_USER>"

        vault kv put secret/on-premise-gitlab-deployment/harbor/app \
            harbor_admin_password="<YOUR_HARBOR_ADMIN_PASSWORD>" \
            harbor_pg_db_password="<YOUR_HARBOR_PG_DB_PASSWORD>"

        vault kv put secret/on-premise-gitlab-deployment/harbor-bootstrapper/app \
            harbor_bootstrapper_admin_password="<YOUR_BOOTSTRAPPER_ADMIN_PASSWORD>" \
            harbor_bootstrapper_pg_db_password="<YOUR_BOOTSTRAPPER_PG_DB_PASSWORD>"
        ```

    - **Note 0. Security Notice**：在執行完 `vault kv put` 指令之後，強烈建議清除 shell history，以避免敏感資訊外洩
    - **Note 1. How to retrieve secrets**
        1. 使用以下指令從 Vault 取出機密資訊。例如要取出 PostgreSQL superuser 密碼：

            ```shell
            export VAULT_ADDR="https://172.16.136.250:443"
            export VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt"
            export VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) \
                vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials)
            vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases
            ```

        2. 如果要避免機密外洩，可使用：

            ```shell
            export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)
            ```

        3. 若需保持 shell 環境乾淨，可使用單行指令：

            ```shell
            export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt" VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)
            ```

            可以操作 `echo` 指令進行驗證。在 Bootstrapper Vault 及其他機密操作方式相同

            這指令在佈署 GitLab 出現 `OpenSSL::Cipher::CipherError` 時會使用到。可以參考 [這裡](terraform/layers/50-platform-gitlab/README-zh-TW.md) 說明

    - **Note 2:**

        _這裡僅做參考，密碼變數已經整合成單列指令，可以依照需求調整_

        `ssh_username` 與 `ssh_password` 是用來登入虛擬機器的帳號與密碼；`ssh_password_hash` 是 cloud-init 自動安裝所需的 hashed 密碼，需使用 `ssh_password` 的原始字串產生。例如密碼為 `HelloWorld@k8s`，則使用以下指令產生對應 hash：

        ```shell
        printf '%s' "HelloWorld@k8s" | openssl passwd -6 -stdin
        ```

        - 若出現 `openssl` command not found，可能是缺少 `openssl` 套件
        - `ssh_public_key_path` 需改為先前產生的 **公鑰** 名稱，公鑰檔名為 `*.pub` 格式

    - **Note 3:**

        目前的 SSH identity 變數（`ssh_`）主要會用在 Packer 的單次使用情境；而 VM identity 變數（`vm_`）則由 Terraform 在 clone VM 時使用。原則上兩者可設為相同值。若因不同 VM 需要不同名稱，可直接修改 HCL 中的物件與相關程式碼。通常會修改 `ansible_runner.vm_credentials` 變數及相關傳遞方式，然後使用 `for_each` 迴圈迭代。但這此方式會增加複雜度，因此如果沒有其他需求，建議可以維持 SSH 與 VM identity 變數相同

5.  在此 repo 中，Vault 在每一次啟動之後，都會需要進行 unseal 操作。可以使用以下方式：
    - `entry.sh` 選項 `3` 做 Unseal Bootstrapper Vault，會使用 Shell Script 的 `vault_dev_unseal_handler()` 執行
    - `entry.sh` 選項 `4` 做 Unseal Production mode Vault，會使用 Ansible Playbook `90-operation-vault-unseal.yaml` 操作

    或者如 B.1-2 所述使用容器，較為簡便

6.  由於 Layer 50 相關的 Helm Chart 一律都採用 OCI 與 Bootstrapper Harbor 進行連線，因此需要先從遠端 `helm pull` 相關 Artifacts 並且推送到 Bootstrapper Harbor 中。要先確保 `30-infra-harbor-bootstrapper-frontend` 與 `40-provision-harbor-bootstrapper-frontend` 都有成功執行

    在確定 L30 與 L40 有關 Bootstrapper Harbor 已執行之後，可以直接執行以下指令：
    1. **環境變數相關以及登入**

        ```bash
        # 1. Environments
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_SKIP_VERIFY=true

        ROLE_ID=$(sudo cat /etc/vault.d/approle/role_id)
        SECRET_ID=$(sudo cat /etc/vault.d/approle/secret_id)

        export HARBOR_REGISTRY="harbor-bootstrapper.production.iac.local"
        export VAULT_TOKEN=$(vault write -field=token auth/workload-approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
        vault kv get -field=password_pusher secret/on-premise-gitlab-deployment/harbor-bootstrapper/robot | \
        helm registry login "$HARBOR_REGISTRY" -u 'robot$helm-charts+helm-pusher' --password-stdin
        ```

    2. Pull 本次專案中相關的 Helm Chart，這是目前採用的版本

        ```bash
        helm pull ingress-nginx --version 4.10.0 --repo https://kubernetes.github.io/ingress-nginx
        helm pull ingress-nginx --version 4.13.1 --repo https://kubernetes.github.io/ingress-nginx
        helm pull metrics-server --version 3.13.0 --repo https://kubernetes-sigs.github.io/metrics-server/
        helm pull oci://quay.io/jetstack/charts/cert-manager --version v1.14.0
        helm pull oci://ghcr.io/rancher/local-path-provisioner/charts/local-path-provisioner --version 0.0.35
        helm pull gitlab --version 9.8.2 --repo https://charts.gitlab.io/
        helm pull tigera-operator --version v3.28.0 --repo https://docs.tigera.io/calico/charts
        helm pull harbor --version 1.18.0 --repo https://helm.goharbor.io
        ```

    3. Push 剛剛取得的 Artifacts 到 `helm-charts`（預設）的 Porxy Project 內

        ```bash
        helm push ingress-nginx-4.10.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push ingress-nginx-4.13.1.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push metrics-server-3.13.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push cert-manager-v1.14.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push local-path-provisioner-0.0.35.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push gitlab-9.8.2.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push tigera-operator-v3.28.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        helm push harbor-1.18.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
        ```

    4. 後續才能執行 L50 的 Helm Chart

> [!NOTE]
> 如果要使用遠端來源，通常要設定 `terraform/modules/kubernetes-addons` 路徑中每一個 Helm Chart Module 的`repository` 與 `chart` 資訊。可以參考 #96 當時的 [程式碼紀錄](https://github.com/csning1998-old/on-premise-gitlab-deployment/tree/018233b3032e517b43e52fc4e17bcd3dde7cf52f/terraform/modules/kubernetes-addons)

#### **Step B.3. Understand the Metadata:**

> [!TIP]
> **Layer 00 (Foundation Metadata)** 是整個專案的「基礎設施元資料庫」與單一真理來源 (SSoT)。

在執行任何 Provision 之前，必須理解 `00` 層級的主要工作，這 Layer 不會建立任何虛擬化資源，而是負責計算：

1. **全域名稱定義**：將抽象的 `service_catalog` 轉換為具體的元件標識，如 `cluster_name`, `storage_pool_name`，確保命名一致性。
2. **自動化網路分配**：基於 `cidr_index` 自動計算每個服務的子網段、VIP (`.250`)、Gateway 以及主機 IP 範圍。其中設有 `validation` 機制以避免人為手動分配導致的 IP 衝突
3. **決定論式連線屬性**：為每台 VM 生成固定的 MAC 地址與 DNS SANs。這樣即便資源重建，其物理特徵與 TLS 憑證辨識等依然維持不變
4. **跨層級引用標準**：透過 `terraform_remote_state` 進行資料驅動佈署，提供給後續所有層級（如 `30-infra-xxx`）使用

#### **Step B.4. Create Variable File for Terraform:**

> [!NOTE]
> 這些是建立 Clusters 的變數檔案

1. 將 `terraform/layers/*/terraform.tfvars.example` 重新命名為 `terraform/layers/*/terraform.tfvars`，使用以下指令：

    ```shell
    for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
    ```

    1. 在 HA 模式下，
        - Vault（Production mode）、 Patroni 含 etcd、Sentinel、Microk8s（Harbor）、Kubeadm Master（GitLab） 服務需要符合 `n%2 != 0` 的設定
        - MinIO Distributed 需要符合 `n%4 == 0` 的設定
    2. 節點建立的 IP 必須對應到 host-only 網路區段

2. 目前專案預設使用 Ubuntu Server 24.04.3 LTS (Noble) 做為 Guest OS
    - 最新版本可於 <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/> 取得
    - 這個專案測試版本可於 <https://old-releases.ubuntu.com/releases/noble/> 取得
    - 選定版本後，請驗證 checksum
        - 最新 Noble 版本： <https://releases.ubuntu.com/noble/SHA256SUMS>
        - "Noble-old-release" 版本： <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

    若有時間，未來會支援其他 Linux Guest OS 如 Fedora 43 或 RHEL 10

3. **獨立測試與開發**：可以使用
    - 選單 `9) Build Packer Base Image` 建立 Packer image
    - 選單 `10) Provision Terraform Layer` 獨立測試或重建特定 Terraform module layer（如 Harbor 或 Postgres 等）

        有時在 Layer 60 的 Service Provision 階段重建 Harbor 會出現 `module.harbor_system_config.harbor_garbage_collection.gc` Resource not found 錯誤，只需要移除 `terraform/layers/60-provision-harbor` 中的 `terraform.tfstate` 與 `terraform.tfstate.backup` 後重新執行 `terraform apply` 即可

    若在現有機器上反覆測試 Ansible Playbook 而無需重建虛擬機器，可以使用 `11) Rebuild Layer via Ansible`

4. **資源清理**：
    - **`14) Purge Specific Terraform Layer`** 主要用於清空特定 Terraform Layer 的虛擬機、儲存空間、網卡、以及 Terraform 的 state 檔案
    - **`15) Purge All Libvirt Resources`** 主要用在需要清理虛擬化資源，但需要保留專案狀態的情境。這個選項會執行 `libvirt_resource_purger "all"`，**僅刪除** 這個專案建立的所有 guest VM、network 與 storage pool，但會 **保留** Packer 輸出的 image 與 Terraform 的本地 state 檔案
    - **`16) Purge All Packer and Terraform Resources`** 主要用於清空所有 artifacts。這個選項會刪除**所有** Packer 輸出 image 與**所有** Terraform Layer 本地 state，讓 Packer 與 Terraform 狀態幾乎回到全新

#### **Step B.4. Provision the GitHub Repository with Terraform:**

> [!NOTE]
> 若本 repository 是 clone 來個人使用，此步驟（B.4）可透過 `10) Provision Terraform Layer` 選擇 `90-github-meta` 執行。以下內容僅提供 imperative 手動程序參考

1. 使用 Shell Bridge Pattern 從 Vault 注入 Token。在專案根目錄執行以確保 `${PWD}` 指向正確的 Vault 憑證路徑

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/project_meta)
    ```

2. 由於 repository 已存在，首次執行 governance layer 前需 import

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. 初始化與 Import
    - **情境 A（Repo 已存在）：** 若管理現有 repository（例如此專案），**必須** 先 import
    - **情境 B（全新 Repo）：** 若從頭建立全新 repository，可跳過 import 步驟

    ```shell
    terraform init
    terraform import github_repository.this on-premise-gitlab-deployment
    ```

4. 套用 Ruleset：建議先執行 `terraform plan` 預覽變更再 apply

    ```shell
    terraform apply -auto-approve
    ```

    輸出類似以下：

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

#### **Step B.5. Export Certs of Services:**

匯出服務憑證可以讓使用者在 Host 端直接瀏覽以下服務，且不會出現憑證錯誤

- Prod Vault：`https://vault.production.iac.local`
- Harbor：`https://harbor.production.iac.local`
- Harhor MinIO Console：`https://minio.harbor.production.iac.local`
- GitLab：`https://gitlab.production.iac.local`
- GitLab MinIO Console：`https://minio.gitlab.production.iac.local`

這樣需要做兩件事情，依序如下：

1.  在 `/etc/hosts` 處理 DNS 解析，將以下內容（此 repo 預設）加入 host 端的 `/etc/hosts`。注意這要依照實際 Terraform 輸出的 IP 進行調整

    ```text
    172.16.126.250  gitlab.production.iac.local
    172.16.131.250  harbor.production.iac.local notary.harbor.production.iac.local
    172.16.136.250  vault.production.iac.local
    172.16.135.250  minio.harbor.production.iac.local core-harbor-minio.production.iac.local
    172.16.130.250  minio.gitlab.production.iac.local core-gitlab-minio.production.iac.local
    ```

2.  要建立 Host-level Trust (Infrastructure & Service CAs). 由於 `tls/` 路徑並沒有做 git 版控, 因此在做憑證匯入之前，需要從 live Vault server 取得 Root CA。這裡可以使用 `curl` 從 Vault PKI 引擎中取得 Service CA 的公鑰。這裡需要加上 `-k` 參數，因為這時候 trust chain 還沒有被建立起來。這裡先設定 Vault Address 後，就下載到 `terraform/layers/15-shared-vault-frontend/tls` 路徑內

    ```bash
    export VAULT_ADDR="https://172.16.136.250:443"
    curl -k $VAULT_ADDR/v1/pki/prod/ca/pem -o terraform/layers/15-shared-vault-frontend/tls/vault-pki-ca.crt
    ```

3.  **將兩個 Certificates 都匯入 System Trust Store:**

    現在在 `terraform/layers/15-shared-vault-frontend/tls/` 路徑內存在兩個 CA 檔案：
    - `bootstrap-ca.crt`：**Infrastructure CA** （由 Terraform 當場產生）
    - `vault-pki-ca.crt`：**Service CA** （透過 Vault API 下載）

    執行以下指令將兩份 CA 匯入作業系統：
    - **RHEL / CentOS / Fedora:**

        ```shell
        # 1. Copy both CAs to the anchors directory
        sudo cp terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt /etc/pki/ca-trust/source/anchors/
        sudo cp terraform/layers/15-shared-vault-frontend/tls/vault-pki-ca.crt /etc/pki/ca-trust/source/anchors/

        # 2. Update the trust store
        sudo update-ca-trust
        ```

    - **Ubuntu / Debian:**

        ```shell
        # 1. Copy both CAs to the shared certificates directory
        sudo cp terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt /usr/local/share/ca-certificates/bootstrap-ca.crt
        sudo cp terraform/layers/15-shared-vault-frontend/tls/vault-pki-ca.crt /usr/local/share/ca-certificates/vault-pki-ca.crt

        # 2. Update the certificates
        sudo update-ca-certificates
        ```

4.  從 host 存取 MinIO 做簡單測試驗證 Trust Store，這主要是驗證 host 端信任 Service CA

    ```shell
    curl -I https://minio.harbor.production.iac.local:9000/minio/health/live
    ```

    若輸出 `HTTP/1.1 200 OK`，代表 Trust Store 已正確設定

5.  從 host 存取 Harbor 驗證 Trust Store

    ```shell
    curl -vI https://harbor.production.iac.local
    ```

    若顯示 `SSL certificate verify ok` 與 `HTTP/2 200`，代表從 Vault 憑證發行、經 cert-manager 簽署、Ingress 部署到 host 信任的完整 PKI Chain 已成功建立

## Section 3. System Architecture

此 Repo 是採用 Packer、Terraform、Ansible 三個工具，基於 immutable infrastructure 的模式，實作出從建立虛擬機器 image 到完整 Kubernetes cluster 的自動化流程

### A. Deployment Workflow

自動化部署流程分為以下數個階段，整體佈署時序與相依關係嚴格遵循系統內部運作邏輯：

1. 基礎 Libvirt 資源、網路、以及密碼管理

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant Boot as Bootstrapper Vault (L00)
        participant Meta as Resource Metadata (L00)
        participant LV as Libvirt Volume & Network (L05)
        participant LB as Centralized Load Balancer (L10)
        participant Prod as Production Vault (L15-25)

        Note over User, Meta: [Stage 1: Foundation Bootstrapping]
        User->>Boot: 1. Init & Unseal Bootstrapper Vault (AppRole)
        Boot->>Boot: 2. Enable KV Engine & Write Static Secrets
        User->>Meta: 3. Provision Resource Metadata
        Meta->>Boot: 4. Auth via AppRole & Read Creds

        Note over User, LB: [Stage 1 cont.: Network & Load Balancer]
        User->>LV: 5. Provision Libvirt Volume & Network (L05)
        LV->>Boot: 6. Auth via AppRole & Read Metadata
        User->>LB: 7. Provision Centralized Load Balancer (L10)
        LB->>Boot: 8. Auth via AppRole & Read Network Config

        Note over User, Prod: [Stage 2: Production Vault Setup]
        User->>Prod: 9. Provision Vault Nodes (L15)
        Prod->>Prod: 10. Configure HA Raft Backend & Enable Engines
        User->>Prod: 11. Init & Unseal Production Vault Cluster
        User->>Prod: 12. Configure AppRole Auth & PKI Root CA (L20/25)
        User->>Prod: 13. Manually Inject Application Secrets
    ```

2. PBR 策略大致如下

    ```mermaid
    graph LR
    subgraph Central_LB["Central LB"]
        direction TB
        RULE["ip rule: from &lt;VIP&gt; lookup rt_&lt;name&gt;"]

        subgraph PBR_Standard["Standard Segments<br>(L3 Symmetric)"]
            direction LR
            RT_GE["rt_gitlab_etcd<br>128.0/24 → gw .128.1"]
            RT_GM["rt_gitlab_minio<br>130.0/24 → gw .130.1"]
            RT_GP["rt_gitlab_postgres<br>127.0/24 → gw .127.1"]
            RT_GR["rt_gitlab_redis<br>129.0/24 → gw .129.1"]
            RT_HB["rt_harbor_bootstrapper<br>137.0/24 → gw .137.1"]
            RT_HE["rt_harbor_etcd<br>133.0/24 → gw .133.1"]
            RT_HF["rt_harbor_frontend<br>131.0/24 → gw .131.1"]
            RT_HM["rt_harbor_minio<br>135.0/24 → gw .135.1"]
            RT_HP["rt_harbor_postgres<br>132.0/24 → gw .132.1"]
            RT_HR["rt_harbor_redis<br>134.0/24 → gw .134.1"]
        end

        subgraph PBR_Vault["Vault Segment<br>(L2 Exception)"]
            RT_VF["rt_vault_frontend\n136.0/24\nscope link: ALL subnets"]
        end
    end

    subgraph Libvirt_Router["Libvirt Host Router"]
        GW_STD["172.16.xxx.1"]
    end

    subgraph Segments["Service Segments"]
        SEG_HF["Harbor Frontend<br>172.16.131.0/24"]
        SEG_HR["Harbor Redis<br>172.16.134.0/24"]
        SEG_HP["Harbor Postgres<br>172.16.132.0/24"]
        SEG_VF["Vault Frontend<br>172.16.136.0/24"]
    end

    RULE --> PBR_Standard
    RULE --> PBR_Vault

    RT_HR & RT_HP & RT_HF -->|"cross-subnet reply"| GW_STD
    GW_STD --> SEG_HF & SEG_HR & SEG_HP

    RT_VF -->|"L2 direct (bypass router)"| SEG_VF
    RT_VF -->|"scope link all → L2 return"| SEG_HF

    SEG_HF -->|"SYN → 172.16.134.250"| RT_HR
    SEG_VF -->|"SYN → 172.16.136.250"| RT_VF
    ```

3. 有關應用程式佈署關係如下：

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant Prod as Production Vault (L15-25)
        participant SS as StatefulSets (Postgres/Redis/MinIO)
        participant Harbor as Bootstrapper Harbor
        participant K8sGit as Kubeadm Cluster (Dist GitLab)
        participant K8sHbr as Microk8s Cluster (Dist Harbor)

        Note over User, Harbor: [Stage 3 / L30 Infra: StatefulSets & Bootstrapper Harbor]
        par
            User->>SS: 1. Provision DB Infrastructure (VMs & LBs)
            SS->>Prod: Request TLS Certificate (PKI Issue)
            SS->>SS: Start Services with TLS Enabled
        and
            User->>Harbor: 2. Provision Bootstrapper Harbor Infrastructure
            Harbor->>Prod: Request TLS Certificate (PKI Issue)
            Harbor->>Harbor: Initialize Seed Container Registry
        end

        Note over User, K8sHbr: [L30 Infra: K8s Clusters - Depends on Above]
        par Depends on StatefulSets + Bootstrapper Harbor
            User->>K8sGit: 3. Provision Kubeadm Cluster (Dist GitLab)
            K8sGit->>Harbor: Pull Bootstrap Images from Seed Registry
        and
            User->>K8sHbr: 4. Provision Microk8s Cluster (Dist Harbor)
            K8sHbr->>Harbor: Pull Bootstrap Images from Seed Registry
        end

        Note over User, K8sHbr: [L40: Application-Level Provisioning]
        User->>SS: 5. Provision Database Services (Ansible + Vault Agent TLS)
        User->>Harbor: 6. Provision Bootstrapper Harbor (Ansible)

        Note over User, K8sHbr: [L50: Platform Deployment]
        User->>K8sHbr: 7. Deploy Harbor Platform on Microk8s

        Note over User, K8sGit: [L60: Application Provision]
        User->>K8sGit: 8. Deploy GitLab on Kubeadm
        User->>K8sHbr: 9. Deploy Harbor on Microk8s
    ```

### B. Toolchain Roles and Responsibilities

本專案的 Clusters 建立有參考下文章：

> [!NOTE]
> 完全參考官方文件操作的叢集步驟未列入下列清單
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Aditi Sangave (2025). [_How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._](https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft) Velotio Tech Blog.
> 3. Dickson Gathima (2025). [_Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 4. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning — Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.

_**(待續...)**_
