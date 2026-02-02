# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

Refer to [README.md](README.md) for English (US) version.

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
git clone -b v1.5.0 --depth 1 https://github.com/csning1998-old/on-premise-gitlab-deployment.git
```

此 repo 具有以下資源分配，基於 RAM 本身限制，僅供參考：

| Network Segment (CIDR) | Service Tier  | Usage (Service)  | Storage Pool Name   | VIP (HAProxy/Ingress) | Node IP Allocation                                 | Component (Role) | Quantity | Unit vCPU | Unit RAM | Subtotal RAM   | Notes                                                     |
| ---------------------- | ------------- | ---------------- | ------------------- | --------------------- | -------------------------------------------------- | ---------------- | -------- | --------- | -------- | -------------- | --------------------------------------------------------- |
| 172.16.134.0/24        | App (GitLab)  | Kubeadm Cluster  | iac-kubeadm         | 172.16.134.250        | `.200` (Master), `.21x` (Worker)                   | Kubeadm Master   | 1        | 2         | 6.0 GiB  | 6,144 MiB      | Used for GitLab Helm Chart deployment                     |
|                        |               |                  |                     |                       |                                                    | Kubeadm Worker   | 2        | 4         | 8.0 GiB  | 16,384 MiB     | For Rails/Sidekiq, GitLab Runner, etc.                    |
| 172.16.135.0/24        | App (Harbor)  | MicroK8s Cluster | iac-harbor          | 172.16.135.250        | `.20x` (Nodes)                                     | MicroK8s Node    | 1        | 4         | 6.0 GiB  | 6,144 MiB      | Full Harbor consumes ~4-5 GB                              |
| 172.16.136.0/24        | Shared        | Vault HA         | iac-vault           | 172.16.136.250        | `.20x` (Vault), `.21x` (HAProxy)                   | Vault (Raft)     | 1        | 2         | 1.0 GiB  | 1,024 MiB      | Raft is lightweight; Shared secrets management center     |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        | TCP forwarding only                                       |
| 172.16.137.0/24        | Data (Harbor) | Postgres HA      | iac-postgres-harbor | 172.16.137.250        | `.20x` (Postgres), `.21x` (Etcd), `.22x` (HAProxy) | Postgres         | 1        | 2         | 2.0 GiB  | 2,048 MiB      | `shared_buffers` set to 512MB; Instantiated via Module 21 |
|                        |               |                  |                     |                       |                                                    | Etcd             | 1        | 1         | 1.0 GiB  | 1,024 MiB      | Patroni low usage                                         |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| 172.16.138.0/24        | Data (Harbor) | Redis HA         | iac-redis-harbor    | 172.16.138.250        | `.20x` (Redis), `.21x` (HAProxy)                   | Redis            | 1        | 1         | 1.0 GiB  | 1,024 MiB      |                                                           |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| 172.16.139.0/24        | Data (Harbor) | MinIO HA         | iac-minio-harbor    | 172.16.139.250        | `.20x` (MinIO), `.21x` (HAProxy)                   | MinIO            | 1        | 2         | 1.5 GiB  | 1,536 MiB      | Go heap not that heavy                                    |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| 172.16.140.0/24        | Data (GitLab) | Postgres HA      | iac-postgres-gitlab | 172.16.140.250        | `.20x` (Postgres), `.21x` (Etcd), `.22x` (HAProxy) | Postgres         | 1        | 2         | 4.0 GiB  | 4,096 MiB      | Replication of Layer 20                                   |
|                        |               |                  |                     |                       |                                                    | Etcd             | 1        | 1         | 1.0 GiB  | 1,024 MiB      | Same as Harbor Postgres                                   |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| 172.16.141.0/24        | Data (GitLab) | Redis HA         | iac-redis-gitlab    | 172.16.141.250        | `.20x` (Redis), `.21x` (HAProxy)                   | Redis            | 1        | 1         | 2.0 GiB  | 2,048 MiB      | Same as Harbor Redis                                      |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| 172.16.142.0/24        | Data (GitLab) | MinIO HA         | iac-minio-gitlab    | 172.16.142.250        | `.20x` (MinIO), `.21x` (HAProxy)                   | MinIO            | 1        | 2         | 3.0 GiB  | 3,072 MiB      | Same as Harbor MinIO                                      |
|                        |               |                  |                     |                       |                                                    | HAProxy          | 1        | 1         | 0.5 GiB  | 512 MiB        |                                                           |
| **Total**              |               |                  |                     |                       |                                                    |                  | **20**   |           |          | **49,152 MiB** | ≈ 48.0 GiB                                                |

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
> 此 repo 目前僅支援具有 CPU virtualization 功能的 Linux 裝置。如果使用的裝置 CPU 不支援 virtualization（例如無 VT-x/AMD-V），請切換至 `legacy-workstation-on-ubuntu` branch，可以支援架設 HA Kubeadm cluster
>
> 此外，目前此 repo 為個人獨立開發，可能存在邊際問題，一經發現將立即修正

### B. Prerequisites

在開始前，要先確認裝置滿足以下條件：

- 一台 Linux Host，建議使用 RHEL 10 或 Ubuntu 24
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
5. Harbor 作為映像檔 Registry
6. **[WIP]** GitLab / Runner / Gitaly 等
7. Private Key Encryption
8. [OpenTofu](https://github.com/opentofu/opentofu.git) Migration 對於 `*.tfstates` 檔案的加密

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
[OK] Development Vault (Local): Running (Unsealed)
[OK] Production Vault (Layer10): Running (Unsealed)
------------------------------------------------------------

1) [DEV] Set up TLS for Dev Vault (Local)          9) Build Packer Base Image
2) [DEV] Initialize Dev Vault (Local)             10) Provision Terraform Layer
3) [DEV] Unseal Dev Vault (Local)                 11) Rebuild Layer via Ansible
4) [PROD] Unseal Production Vault (via Ansible)   12) Verify SSH
5) Generate SSH Key                               13) Switch Environment Strategy
6) Setup KVM / QEMU for Native                    14) Purge All Libvirt Resources
7) Setup Core IaC Tools                           15) Purge All Packer and Terraform Resources
8) Verify IaC Environment                         16) Quit

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

    1) 01-base-docker           4) 04-base-postgres         7) 07-base-vault
    2) 02-base-kubeadm          5) 05-base-redis            8) Build ALL Packer Images
    3) 03-base-microk8s         6) 06-base-minio            9) Back to Main Menu

    [INPUT] Select a Packer build to run:
    ```

2. 選 `10) Provision Terraform Layer` 時

    ```text
    [INPUT] Please select an action: 10
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) 10-vault-core          5) 20-harbor-minio       9) 30-harbor-microk8s    13) 90-github-meta
    2) 20-gitlab-minio        6) 20-harbor-postgres    10) 40-gitlab-platform   14) Back to Main Menu
    3) 20-gitlab-postgres     7) 20-harbor-redis       11) 40-harbor-platform
    4) 20-gitlab-redis        8) 30-gitlab-kubeadm     12) 50-harbor-provision

    [INPUT] Select a Terraform layer to REBUILD:
    ```

3. 選 `11) Rebuild Layer via Ansible` 時

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

1. **安裝 HashiCorp Toolkit - Terraform and Packer**

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
        61be68ae276e  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  15 minutes ago  Up 15 minutes (healthy)  8200/tcp    iac-vault-server
        79b918f440f1  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-base
        0a4eb3495697  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-packer
        482f58b67295  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-terraform
        aa8d17213095  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-ansible
        ```

> [!CAUTION]
> **Data Loss Warning**
>
> 當在 Podman 容器與 Native 環境之間切換時，所有由 Terraform 建立的 Libvirt 資源都會被 **自動刪除**，以避免 Libvirt UNIX socket 的權限與上下文衝突

### C. Miscellaneous

- **建議的 VSCode Plugin：** 主要是相關 syataxes highlighting 的支援而已：
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

0.  **要先建立 Development Vault 後才能建立 Production Vault。其中 Dev Vault 僅用於建立 Prod Vault 與 Packer Images，之後所有專案的敏感資料皆由 Prod Vault 管理**
1.  首先執行 `entry.sh` 選擇選項 `1`，產生 TLS handshake 所需要的檔案。建立 Self-signed CA 時，部分欄位可留空。若需重新產生 TLS 檔案，可再次執行選項 `1`
2.  切換至專案根目錄，執行以下指令啟動 Development mode Vault server。此 repo 預設在 container 走 side-car 模式執行：

    ```shell
    podman compose up -d iac-vault-server
    ```

    啟動 server 後，Dev Vault 就會在 `vault/data/` 路徑中產生 `vault.db` 以及 Raft 相關檔案。如果有需要重新建立 Dev Vault，就必須手動清除 `vault/data/` 內所有檔案。請開新終端機視窗或分頁進行後續操作，以避免 shell session 的環境變數污染

3.  完成前述步驟後，執行 `entry.sh` 選擇選項 2 初始化 Dev Vault。此過程也會自動執行 Unseal
4.  接下來只需手動修改以下專案使用的變數。密碼必須替換為不重複內容，藉以確保安全性
    - **強烈建議執行完任何 `vault kv put` 指令之後，清除 Shell Histroy 的機敏變數，以免洩漏。詳見下方 Note 0 說明**
    - **For Development Vault**
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
            secret/on-premise-gitlab-deployment/variables \
            github_pat="your-github-personal-access-token" \
            ssh_username="some-user-name-for-ssh" \
            ssh_password="$ssh_password" \
            ssh_password_hash="$(printf '%s' "$ssh_password" | openssl passwd -6 -stdin)" \
            vm_username="some-user-name-for-vm" \
            vm_password="$ssh_password" \
            ssh_public_key_path="~/.ssh/some-ssh-key-name.pub" \
            ssh_private_key_path="~/.ssh/some-ssh-key-name"

        vault kv put \
            -address="https://127.0.0.1:8200" \
            -ca-cert="${PWD}/vault/tls/ca.pem" \
            secret/on-premise-gitlab-deployment/infrastructure \
            vault_haproxy_stats_pass="some-password-for-vault-haproxy-stats-pass-for-development-mode" \
            vault_keepalived_auth_pass="some-password-for-vault-keepalived-auth-pass-for-development-mode"
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
        export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
        export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)
        vault secrets enable -path=secret kv-v2
        ```

        ```shell
        vault kv put secret/on-premise-gitlab-deployment/variables \
            ssh_username="some-username-for-ssh-for-production-mode" \
            ssh_password="some-password-for-ssh-for-production-mode" \
            ssh_password_hash='$some-password-for-ssh-for-production-mode' \
            ssh_public_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment.pub" \
            ssh_private_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment" \
            vm_username="some-username-for-vm-for-production-mode" \
            vm_password="some-password-for-vm-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/infrastructure \
            vault_haproxy_stats_pass="some-password-for-vault-haproxy-stats-pass-for-production-mode" \
            vault_keepalived_auth_pass="some-password-for-vault-keepalived-auth-pass-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/gitlab/databases \
            pg_superuser_password="some-password-for-gitlab-pg-superuser-for-production-mode" \
            pg_replication_password="some-password-for-gitlab-pg-replication-for-production-mode" \
            pg_vrrp_secret="some-password-for-gitlab-pg-vrrp-for-production-mode" \
            redis_requirepass="some-password-for-gitlab-redis-requirepass-for-production-mode" \
            redis_masterauth="some-password-for-gitlab-redis-masterauth-for-production-mode" \
            redis_vrrp_secret="some-password-for-gitlab-redis-vrrp-secret-for-production-mode" \
            minio_root_password="some-password-for-gitlab-minio-root-password-for-production-mode" \
            minio_vrrp_secret="some-password-for-gitlab-minio-vrrp-secret-for-production-mode" \
            minio_root_user="some-username-for-gitlab-minio-root-user-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/harbor/databases \
            pg_superuser_password="some-password-for-harbor-pg-superuser-for-production-mode" \
            pg_replication_password="some-password-for-harbor-pg-replication-for-production-mode" \
            pg_vrrp_secret="some-password-for-harbor-pg-vrrp-for-production-mode" \
            redis_requirepass="some-password-for-harbor-redis-requirepass-for-production-mode" \
            redis_masterauth="some-password-for-harbor-redis-masterauth-for-production-mode" \
            redis_vrrp_secret="some-password-for-harbor-redis-vrrp-secret-for-production-mode" \
            minio_root_password="some-password-for-harbor-minio-root-password-for-production-mode" \
            minio_vrrp_secret="some-password-for-harbor-minio-vrrp-secret-for-production-mode" \
            minio_root_user="some-username-for-harbor-minio-root-user-for-production-mode"

        vault kv put secret/on-premise-gitlab-deployment/harbor/app \
            harbor_admin_password="some-password-for-harbor-admin-password-for-production-mode" \
            harbor_pg_db_password="some-password-for-harbor-pg-db-password-for-production-mode"
        ```

    - **Note 0. Security Notice**：在執行完 `vault kv put` 指令之後，強烈建議清除 shell history，以避免敏感資訊外洩
    - **Note 1. How to retrieve secrets**
        1. 使用以下指令從 Vault 取出機密資訊。例如要取出 PostgreSQL superuser 密碼：

            ```shell
            export VAULT_ADDR="https://172.16.136.250:443"
            export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
            export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)
            vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases
            ```

        2. 如果要避免機密外洩，可使用：

            ```shell
            export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        3. 若需保持 shell 環境乾淨，可使用單行指令：

            ```shell
            export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt" VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        在 Development Vault 及其他機密操作方式相同

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
    - `entry.sh` 選項 `3` 做 Unseal Development mode Vault，會使用 Shell Script 的 `vault_dev_unseal_handler()` 執行
    - `entry.sh` 選項 `4` 做 Unseal Production mode Vault，會使用 Ansible Playbook `90-operation-vault-unseal.yaml` 操作

    或者如 B.1-2 所述使用容器，較為簡便

#### **Step B.3. Create Variable File for Terraform:**

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

        有時在 Layer 50 的 Service Provision 階段重建 Harbor 會出現 `module.harbor_config.harbor_garbage_collection.gc` Resource not found 錯誤，只需要移除 `terraform/layers/50-harbor-platform` 中的 `terraform.tfstate` 與 `terraform.tfstate.backup` 後重新執行 `terraform apply` 即可

    若在現有機器上反覆測試 Ansible Playbook 而無需重建虛擬機器，可以使用 `11) Rebuild Layer via Ansible`

4. **資源清理**：
    - **`14) Purge All Libvirt Resources`** 主要用在需要清理虛擬化資源，但需要保留專案狀態的情境。這個選項會執行 `libvirt_resource_purger "all"`，**僅刪除** 這個專案建立的所有 guest VM、network 與 storage pool，但會 **保留** Packer 輸出的 image 與 Terraform 的本地 state 檔案
    - **`15) Purge All Packer and Terraform Resources`** 主要用於清空所有 artifacts。這個選項會刪除**所有** Packer 輸出 image 與**所有** Terraform Layer 本地 state，讓 Packer 與 Terraform 狀態幾乎回到全新

#### **Step B.4. Provision the GitHub Repository with Terraform:**

> [!NOTE]
> 若本 repository 是 clone 來個人使用，此步驟（B.4）可透過 `10) Provision Terraform Layer` 選擇 `90-github-meta` 執行。以下內容僅提供 imperative 手動程序參考

1. 使用 Shell Bridge Pattern 從 Vault 注入 Token。在專案根目錄執行以確保 `${PWD}` 指向正確的 Vault 憑證路徑

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/variables)
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

- Prod Vault：`https://vault.iac.local`
- Harbor：`https://harbor.iac.local`
- Harhor MinIO Console：`https://s3.harbor.iac.local`
- GitLab：`https://gitlab.iac.local` （**WIP**）
- GitLab MinIO Console：`https://s3.gitlab.iac.local` （**WIP**）

這樣需要做兩件事情，依序如下：

1.  在 `/etc/hosts` 處理 DNS 解析，將以下內容（此 repo 預設）加入 host 端的 `/etc/hosts`。注意這要依照實際 Terraform 輸出的 IP 進行調整

    ```text
    172.16.134.250  gitlab.iac.local
    172.16.135.250  harbor.iac.local notary.harbor.iac.local
    172.16.136.250  vault.iac.local
    172.16.139.250  s3.harbor.iac.local
    172.16.142.250  s3.gitlab.iac.local
    ```

2.  要建立 Host-level Trust (Infrastructure & Service CAs). 由於 `tls/` 路徑並沒有做 git 版控, 因此在做憑證匯入之前，需要從 live Vault server 取得 Root CA
    1. **準備環境變數與下載 CA**： 使用 `curl` 從 Vault PKI 引擎中取得 Service CA 的公鑰。這裡需要加上 `-k` 參數，因為這時候 trust chain 還沒有被建立起來。這裡先設定 Vault Address 後，就下載到 `terraform/layers/10-vault-core/tls` 路徑內

        ```bash
        export VAULT_ADDR="https://172.16.136.250:443"
        curl -k $VAULT_ADDR/v1/pki/prod/ca/pem -o terraform/layers/10-vault-core/tls/vault-pki-ca.crt
        ```

    2. 匯入 CA 到系統 trust chain
        - RHEL / CentOS：

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /etc/pki/ca-trust/source/anchors/
            sudo update-ca-trust
            ```

        - Ubuntu / Debian：

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /usr/local/share/ca-certificates/
            sudo update-ca-certificates
            ```

3.  **將兩個 Certificates 都匯入 System Trust Store:**

    現在在 `terraform/layers/10-vault-core/tls/` 路徑內存在兩個 CA 檔案：
    - `vault-ca.crt`：**Infrastructure CA** （由 Terraform 當場產生）
    - `vault-pki-ca.crt`：**Service CA** （透過 Vault API 下載）

    執行以下指令將兩份 CA 匯入作業系統：
    - **RHEL / CentOS / Fedora:**

        ```shell
        # 1. Copy both CAs to the anchors directory
        sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /etc/pki/ca-trust/source/anchors/
        sudo cp terraform/layers/10-vault-core/tls/vault-pki-ca.crt /etc/pki/ca-trust/source/anchors/

        # 2. Update the trust store
        sudo update-ca-trust
        ```

    - **Ubuntu / Debian:**

        ```shell
        # 1. Copy both CAs to the shared certificates directory
        sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /usr/local/share/ca-certificates/vault-ca.crt
        sudo cp terraform/layers/10-vault-core/tls/vault-pki-ca.crt /usr/local/share/ca-certificates/vault-pki-ca.crt

        # 2. Update the certificates
        sudo update-ca-certificates
        ```

4.  從 host 存取 MinIO 做簡單測試驗證 Trust Store，這主要是驗證 host 端信任 Service CA

    ```shell
    curl -I https://s3.harbor.iac.local:9000/minio/health/live
    ```

    若輸出 `HTTP/1.1 200 OK`，代表 Trust Store 已正確設定

5.  從 host 存取 Harbor 驗證 Trust Store

    ```shell
    curl -vI https://harbor.iac.local
    ```

    若顯示 `SSL certificate verify ok` 與 `HTTP/2 200`，代表從 Vault 憑證發行、經 cert-manager 簽署、Ingress 部署到 host 信任的完整 PKI Chain 已成功建立

## Section 3. System Architecture

此 Repo 是採用 Packer、Terraform、Ansible 三個工具，基於 immutable infrastructure 的模式，實作出從建立虛擬機器 image 到完整 Kubernetes cluster 的自動化流程

### A. Deployment Workflow

1. **核心 Bootstrap 流程**：使用 Development Vault 儲存初始機密，接著建立 Production Vault

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant Entry as entry.sh
        participant DevVault as Dev Vault<br>(Local)
        participant TF as Terraform<br>(Layer 10)
        participant Libvirt
        participant Ansible
        participant ProdVault as Prod Vault<br>(Layer 10)

        %% Step 1: Bootstrap
        Note over User, DevVault: [Bootstrap Phase]
        User->>Entry: [DEV] Initialize Dev Vault
        Entry->>DevVault: Init & Unseal
        Entry->>DevVault: Enable KV Engine (secret/)
        User->>DevVault: Write Initial Secrets (SSH Keys, Root Pass)

        %% Step 2: Infrastructure
        Note over User, ProdVault: [Layer 10: Infrastructure]
        User->>Entry: Provision Layer 10
        Entry->>TF: Apply (Stage 1)
        TF->>DevVault: Read SSH Keys/Creds
        TF->>Libvirt: Create Vault VMs (Active/Standby)
        TF->>Ansible: Trigger Provisioning
        Ansible->>ProdVault: Install Vault Binary & Config

        %% Step 3: Operation
        Note over User, ProdVault: [Layer 10: Operation]
        User->>Entry: [PROD] Unseal Production Vault
        Entry->>Ansible: Run Playbook (90-operation-unseal)
        Ansible->>ProdVault: Init (if new) & Unseal
        Ansible-->>Entry: Return Root Token (Saved to Artifacts)

        %% Step 4: Configuration
        Note over User, ProdVault: [Layer 10: Configuration]
        Entry->>TF: Apply (Stage 2 - Vault Provider)
        TF->>ProdVault: Enable PKI Engine (Root CA)
        TF->>ProdVault: Configure Roles (postgres, redis, minio)
        TF->>ProdVault: Enable AppRole Auth
    ```

2. **資料服務與 PKI**：自動佈署資料庫服務。以 MinIO 為例，而 Postgres 與 Redis 類似

    ```mermaid
    sequenceDiagram
        autonumber
        actor User
        participant TF as Terraform<br>(Layer 20)
        participant ProdVault as Prod Vault<br>(Layer 10)
        participant Libvirt
        participant Ansible
        participant Agent as Vault Agent<br>(On Guest)
        participant Service as MinIO Service

        Note over User, Service: [Layer 20: Provisioning MinIO]

        %% Terraform Phase
        User->>TF: Apply Layer 20 (MinIO)
        TF->>ProdVault: 1. Create AppRole 'harbor-minio'
        ProdVault-->>TF: Return RoleID & SecretID
        TF->>Libvirt: 2. Create MinIO VMs & LBs

        %% Ansible Phase
        TF->>Ansible: 3. Trigger Playbook (Pass AppRole Creds)

        Ansible->>Agent: 3a. Install Vault Agent
        Ansible->>Agent: 3b. Write RoleID/SecretID to /etc/vault.d/approle/
        Ansible->>Agent: 3c. Configure Agent Templates (public.crt, private.key)
        Ansible->>Agent: 3d. Start Vault Agent Service

        %% Runtime Phase
        Agent->>ProdVault: 4. Auth (AppRole Login)
        ProdVault-->>Agent: Return Client Token
        Agent->>ProdVault: 5. Request Cert (pki/prod/issue/minio-role)
        ProdVault-->>Agent: Return Signed Cert & Key

        Agent->>Service: 6. Render Certs to /etc/minio/certs/
        Agent->>Service: 7. Restart/Reload MinIO Service

        Service->>Service: 8. Start with TLS (HTTPS)

        %% Client Config
        Ansible->>Service: 9. Trust CA & Configure 'mc' Client
    ```

### B. Toolchain Roles and Responsibilities

本專案的 Clusters 建立有參考下文章：

> [!TIP]
> 完全參考官方文件操作的叢集步驟未列入下列清單
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Aditi Sangave (2025). [_How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._](https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft) Velotio Tech Blog.
> 3. Dickson Gathima (2025). [_Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 4. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning — Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.

_**(待續...)**_
