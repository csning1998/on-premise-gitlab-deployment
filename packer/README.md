# Tutorial: Build Packer Images via QEMU with Dual-Stage Pipeline

> **TL;DR**
> 這份文件在 Section 1. 到 Section 5. 主要在講述透握 Packer 建立虛擬機的機制；在 Section 6. 中會提到此 repo 建立 Packer Pipeline 的架構與其背後的原因

## Section 1. Overview

### Step. A. What is Packer?

Packer 是一個可以在多種平台上，做為一個單一事實來源以建立虛擬機的開源工具。Packer 本身支援 Type-I 與 Type-II Hypervisor 的建立，包含 VirtualBox、VMWare、QEMU 或是如 GCP 與 AWS 虛擬機。例如對於 VirtualBox 可以輸出 OVF 檔案、對於 VMWare 可以使用 VMDK 與 VMX 檔案、而對於 AWS EC2 可以使用 AMI 檔案

Packer 可以使用 HCL2 語言進行虛擬機狀態的宣告，一般來說在 Packer Templates 裡面會宣告包括但不限於以下內容：

1. 要使用哪些 Plugin？例如 Builder、Provisioner、與 Post-processor？
2. 如何設定 Plugins？
3. 要使用哪些順序執行這些？

### Step. B. Components

在操作 Packer Templates 時，通常會包含以下流程：

1. 先定義開發者所會使用到的 `plugins` 後進行初始化
2. 以 hard-code 模式撰寫 `source` 區塊，讓一台 VM 可以啟動
3. 在 `source` 區塊定義好之後，就可以在 `build` 區塊中將 `source` 和 `provisioner` 連結起來，執行 VM 開機測試
4. 在確認核心建構流程（VM 啟動、Packer 連線、Provisioner 執行）可以穩定運作後，開發者才會會引入 `variable` 區塊開始進行重構
5. 當映像檔（Artifact）本身已經可以透過 Builder 和 Provisioner 正確產生後，最後才會加入 **Post-processor**。例如加入 `compress` 後處理器將其壓縮，或加入 `artifactory` 後處理器將 VM 上傳

以下會使用開源的 QEMU 虛擬機做為範例說明，其中 Guest 作業系統是 Ubuntu 24.04.03，進行操作的作業系統是 Linux Distro 如 RHEL 10 與 Ubuntu 24。文件撰寫的當下，QEMU 可以在 Ubuntu 24.04.3 與 RHEL 10 進行操作。其餘作業系統仍需要測試

## Section 2. Plugins

### Step. A. Introduction

> [!IMPORTANT]
> **自 2025 年 8 月 1 日起，多數由 HashiCorp 官方維護的 Packer plugins 來源將從 GitHub releases 遷移至 HashiCorp 官方發布站點 releases.hashicorp.com，詳細資訊請參考 Install HashiCorp-maintained plugins**

一個 Packer Template 可以定義一個或多個指定版本的 Plugin(s)，而後針對這些 Plugins 進行初始化。Packer 在執行時，會先下載並安裝 template 中指定的 plugin(s) 以及相關套件；或者使用者可以透過指定 binary 路徑以手動安裝自己開發的 Plugin。而安裝完成的 plugins，原則上會放在 `$HOME/.config/packer/plugins` 裡面

如果要從遠端來源安裝 plugin，那 plugin 就必須要滿足以下需求：

- plugin 專案必須託管在 GitHub 上
- repository 名稱必須為 `packer-plugin-<name>` 格式
- 專案必須使用 semantic version tags，格式為 `v<major>.<minor>.<patch>`
- 與 tag 連結的 release 必須包含 `shasums` 檔案，用以標示該 release 中可用的檔案

原則上 GitHub 的公開 API 會限制單一 IP 的請求數量，一般限制為每小時 60 個 requests；如果操作上會超過這個速率限制，可以提高到每小時 15,000 個 requests。相關的速率限制可以參考 <https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28>

### Step. B. Installation

如果要安裝 QEMU 的 plugin，安裝方式有兩種如下：

1. **透過 CLI 操作**

    Packer 會自動從 HashiCorp 官方的路徑抓取 plugin，CLI 指令如下：

    ```bash
    packer plugins install --path <path-to-downloaded-extracted-binary> <hostname>/<namespace>/<plugin-name>
    ```

    例如要安裝 QEMU 的 Builder，則可以透過以下指令

    ```bash
    packer plugins install github.com/hashicorp/qemu
    ```

2. **透過 Template 操作**

    可以在 Template 中這樣撰寫

    ```hcl
    packer {
        required_plugins {
            qemu = {
                version = "~> 1"
                source  = "github.com/hashicorp/qemu"
            }
        }
    }
    ```

    隨後執行

    ```bash
    packer init .
    ```

## Section 3. Sources I: Minimum Setting

### Step. A. What Settings Are Needed to Build a Virtual Machine?

建立虛擬機的時候，可以從組裝電腦到完整開機的角度開始思考。一台虛擬機的設定會需要考慮到

1. **Virtual Hardware Layer：**CPU / RAM / Harddisk / Network / Screen 等
2. **OS 安裝的 media 與啟動順序**
3. **Hypervisor 與 Packer 之間的通訊**
4. **無人值守（Unattended Installation）安裝設定，這會在 _Section 4._ 中說明**

如果以建立 Ubuntu Server 24.04.3 虛擬機為例，可以另外手動用傳統方式安裝一台虛擬機，以交互驗證 Packer 設定是否正確。在官方文件的 QEMU Plugin 中，對於資源設定上全都包在 `source` 區塊裡面

```hcl
source "qemu" "ubuntu" {
    ...
}
```

而有關 QEMU 的設定項目，可以參考這裡：

QEMU Builder | Integrations | Packer | HashiCorp Developer

一般來說，每一個 Source 定義的設定項目都不盡相同，可以當作 Packer Source 本身就是用類似 API 的架構與底層的服務溝通。使用者接下來會輸入期望狀態到 Packer 的 Source 裡面，而 Source 再透過底層的 Golang 去做到這些期望狀態

### Step. B. Virtual Hardware Layer

1. 首先根據 Canonical 官方網站的內容，有提到一台 Ubuntu Server 虛擬機的最低建議系統要求是 1 GHz CPU、2 GB of RAM、以及 25 GB 的硬碟空間。假定這台虛擬機命名為 `ubuntu-server-24`，則這些在 `source` 區塊中都有對應的設定：

    ```hcl
    source "qemu" "ubuntu" {
        vm_name   = "ubuntu-server-24"
        cpus      = 2     # in vCPU
        memory    = 2048  # in MiB
        disk_size = 25600 # in MiB
    }
    ```

2. 接下來要開啟虛擬機，會需要映像檔來源以及 checksum 256 來驗證映像檔來源正確。對於映像檔資訊可以參考
    - 舊版 Ubuntu 24 LTS（Noble）的資訊：
        - ISO Download Page：<https://old-releases.ubuntu.com/releases/noble/>
        - Checksum：<https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>
    - 最新 Ubuntu 24 LTS（Noble）的資訊：
        - ISO Download Page：<https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/>
        - Checksum：<https://releases.ubuntu.com/noble/SHA256SUMS>

    根據以上網址，經確認後 Ubuntu Server 24.03 的 ISO 路徑與 `sha256`，可以分別對應到 `source` 的以下內容

    ```hcl
    source "qemu" "ubuntu" {
        ...
        iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
        iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
    }
    ```

    這邊就處理完最基本的硬體設定了

3. 接下來包含以下要開始處理 QEMU 真正重點的設定了。那 QEMU 本身就是一個模擬器，原則上會希望能執行包含 Windows 3.1 這類古老系統，因此可想而知在設定選項涵蓋很多「歷史包袱」的需求而設定。但對於如 Packer 安裝 Ubuntu 24 等現代技術操作上，原則上可以用到最佳選項。舉例來說，開發者操作 QEMU 時，可以選擇
    1. **Type-I Hypervisor ：**直接利用作業系統 kernel 層級的 KVM 模組
    2. **Type-II Hypervisor：**用純軟體（TCG）去 模擬 一個 CPU

    但使用 TCG 模擬 CPU 本身就會多一個「模擬」的算力資源開銷，這是 CPU 不支援虛擬化技術時才會使用的方法；針對支援虛擬化技術的 CPU，可以直接利用 KVM 的方式以執行 Guest OS。而使用 KVM 時，可以設定將 host CPU 的所有特性跟指令集直接 pass-through 給 VM。這樣做得好處在於，可以避免 KVM 模擬一個通用的 `qemu64` CPU，讓執行效率提升

    要確認電腦內有無 QEMU 套件，可以執行 `ls -la /usr/bin/qemu-system-x86_64` 檢驗，如果出現以下輸出，代表已經安裝好套件

    ```text
    lrwxrwxrwx. 1 root root 21 Oct 16 03:14 /usr/bin/qemu-system-x86_64 -> /usr/libexec/qemu-kvm
    ```

    確認完成後，這階段的 HCL 可以這樣設定

    ```hcl
    source "qemu" "ubuntu" {
        ...
        accelerator = "kvm"  # Run Guest OS via VT-x / AMD-V
        qemu_binary = "/usr/bin/qemu-system-x86_64"  # QEMU Binary
        qemuargs    = [["-cpu", "host"]]  # pass-through
    }
    ```

    這樣設定就可以讓 Packer 知道要如何操作 QEMU/KVM 之間的 CPU 資源

4. 完成 CPU 設定後，接下來處理 Disk 與 Network I/O。在 KVM 環境下，最有效率的方式是使用 `VirtIO` 這種 Paravirtualized 驅動程式。當 Guest OS 安裝 `virtio` 驅動程式後，Guest OS 與 Host KVM 雙方都會知道彼此處於虛擬化環境，就能直接透過 `virtio` 進行 I/O 操作，繞過模擬硬體造成的性能瓶頸

    那前述的的網路與硬碟資源畢竟是 Paravirtualized，所以需要把網路連到 Host 端才能建立網路通訊。因此需要另外設定 `bridge`：

    ```hcl
    source "qemu" "ubuntu" {
        ...
        disk_interface = "virtio"  # Paravirtualized Harddisk
        net_device     = "virtio-net"  # Paravirtualized Network
        net_bridge     = "virbr0"  # Bridge network
    }
    ```

    有關 bridge network，可以用 `ip a show virbr0` 或 `ip route | grep virbr0` 等方式檢查
    - `ip a show virbr0`

        ```text
        5: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc htb state DOWN group default qlen 1000
            link/ether 52:54:00:0b:41:d2 brd ff:ff:ff:ff:ff:ff
            inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
               valid_lft forever preferred_lft forever
        ```

    - `ip route | grep virbr0`

        ```text
        192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown
        ```

    如果網路沒有開啟，可以透過以下指令檢查服務

    ```bash
    sudo systemctl is-active libvirtd  # Check status
    sudo systemctl start libvirtd  # Start Libvirt Service
    ```

5. 上面完成後，接下來就試開機會需要使用到的「螢幕」。原則上對於類 Type-I Hypervisor 的架構之下，不會直接看到虛擬機的 GUI 視窗的 VM 畫面，這情況下可以使用 VNC Viewer。由於 QEMU 解析 VNC display address 的方式，port 最小值無法設定低於 `5900`，而最大值不能超過 `6000`。Packer 會隨機指定一個 port 給 VNC 使用：

    ```hcl
    source "qemu" "ubuntu" {
        ...
        headless     = true
        vnc_port_min = 5900
        vnc_port_max = 6000
    }
    ```

    如果要設定 port 數值固定，可以將 `vnc_port_min` 的值設定與 `vnc_port_max` 相同。這裡設定 `headless = true` 的原因是，在下階段的 Ubuntu 虛擬機開機時，為了做到無人值守安裝，所以在操作上會透過序列埠或模擬鍵盤注入指令。這在 VNC 介入的情況下，會因為 QEMU VNC 伺服器內部的單一連線配額限制被使用者佔用，導致 Packer 無法在注入指令時建立連線而出錯

### Step. C. Boot

完成以上，就可以做最基本的開機測試了，可以在 shell 中使用以下指令

```bash
packer init . && packer build .
```

如果可以完成開機，接下來就要讓後續安裝步驟 **完全自動化**

### Step. D. Complete Minimum Source Block

以下內容是完整的 Minimum `source` 區塊：

```hcl
source "qemu" "ubuntu" {
    # Section 3.B.1: Virtual Hardware Layer - Basic Resources
    vm_name   = "ubuntu-server-24"
    cpus      = 2     # in vCPU
    memory    = 2048  # in MiB
    disk_size = 25600 # in MiB

    # Section 3.B.2: ISO Source and Checksum
    iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"

    # Section 3.B.3: CPU and Hypervisor (KVM) Optimization
    accelerator = "kvm"  # Run Guest OS via VT-x / AMD-V
    qemu_binary = "/usr/bin/qemu-system-x86_64"  # QEMU Binary
    qemuargs    = [["-cpu", "host"]]  # pass-through host CPU features

    # Section 3.B.4: Disk and Network I/O with VirtIO
    disk_interface = "virtio"     # Paravirtualized Harddisk
    net_device     = "virtio-net" # Paravirtualized Network
    net_bridge     = "virbr0"     # Bridge network

    # Section 3.B.5: VNC for Headless Operation
    headless     = true
    vnc_port_min = 5900
    vnc_port_max = 6000
}
```

## Section 4. Sources II: Unattended Installation

### Step. A. Brief Historical Review of Unattended Install

1. **Early Era: Pressed and kickstart**

    接下來就可以看到 Packer 把虛擬機映像檔載入並開啟了，那照一般安裝虛擬機的作業系統時，會需要人為介入進行手動設定才可以完成開機，可以想像 Windows 作業系統的安裝過程。早期在 1990 年代的系統管理員，會透過手動安裝、或是 `dd`、`Ghost` 、或一些自定義腳本進行大規模部屬。但在 Linux 作業系統的應用逐漸成熟之後，兩個 Linux 陣營 Debian 與 Fedora 分別推出 Pressed 與 Kickstart 進行標準安裝框架。其中
    - **Preseed** 是一種基於 `debconf` 設定資料庫的宣告式模式的安裝方法，理論上較為嚴謹
    - **Kickstart** 是一種以「錄製與重播」為核心的程序化方法 ，操作上較為務實

    這些工具在 **作業系統安裝期間** 運作，其輸入是安裝媒介（ISO、PXE ），輸出是一個安裝好的作業系統的裸機或 VM

2. **Cloud Computing and `cloud-init`**

    一直到雲端運算興起的 2007 年左右，自動化安裝的焦點從「安裝」轉入「初始化」。雲端平台如 AWS EC2 、OpenStack 在當時引入了 **映像檔（Images）** 和 **實例（Instances）** 的概念，也就是說作業系統 _永遠不會_ 從 ISO 檔案「安裝」到 VM 上，而是預先安裝好的 **標準映像檔** 被複製出來後，在幾秒鐘內啟動成為一個新的 VM 實例。但問題在於，每個從同一個映像檔啟動的實例都是 _完全相同_ 的，但虛擬機之間有會需要有一些個別設定，例如唯一主機名稱（例如在 Kubernetes 中的 hostname 相同會出現衝突）、網路設定、SSH 公鑰（用於登入）和使用者帳戶

    在這情況下，相較於 Kickstart 和 Preseed 只在「安裝時」運作，所以在雲端環境中已經不太需要了。而在 2007 年左右，當時 Canonical 在 AWS EC2 上的 Ubuntu 映像檔提供了一個稱為「user-data」的機制。就是在使用者啟動實例時，可以先傳遞一小塊自訂資料。而 `cloud-init` 的前身 `ec2-init` 是一個會在系統首次開機時啟動小程式，而這程式會透過一特別的本地 IP 位址（`169.254.169.254`）從 EC2 metadata service 中取得 `user-data` 和 SSH 金鑰，然後對系統進行組態設定。那 `cloud-init` 的核心機制與 Kickstart/Preseed 完全不同，本身是透過標準的 YAML 格式進行宣告的，使用者就可以在檔案內定義這些首次開機的任務
    1. **執行階段**：`cloud-init` 在作業系統安裝 _完成後_、每次系統開機時執行
    2. **首次開機偵測**：檢查本地快取，判斷這是否是該實例的「首次開機」
    3. **資料獲取**：如果是首次開機，會偵測所在的雲端環境（AWS、Azure、OpenStack 等），並從 metadata service 中取得組態資料
    4. **組態執行**：根據 `user-data` 執行一系列初始化任務，包括但不限於：
        - 設定主機名稱
        - 將使用者的 SSH 公鑰添加到帳戶中
        - 安裝額外套件
        - 建立使用者帳戶
        - 執行任意 shell 腳本

    因為這個機制直接解決所有雲端平台和所有包括 RHEL 、Debian 、Fedora 、Arch Linux 等 Linux Distro、以及 FreeBSD  等其他作業系統共同面臨的問題，所以很快就成為事實上的業界標準

### Step. B. SSH Username and Password

在 Packer 階段的 SSH 會分為兩個階段，分別為 **Guest OS 安裝** 與 **Packer Communicator** 兩個階段，其帳號密碼設定 **必須一致**

- **Guest OS 安裝**

    SSH 連線在 `packer build` 流程中，與 `cloud-init` 的設定需要一致。在 `autoinstall` 階段中，`subiquity` 會讀取 `user-data` 中定義的使用者帳號與密碼，直接寫入 VM 的磁碟上（新系統的 `/etc/passwd` 和 `/etc/shadow`）以建立使用者帳戶。其中 Linux 系統不會以明文儲存密碼，而是會執行一個單向的密碼編譯函式（Cryptographic Hash Function 如 SHA-512 crypt），並將產生的雜湊值儲存在 `/etc/shadow` 檔案中，所以在 `cloud-init` 中的密碼就必須要是雜湊值

    > [!NOTE]
    > 假定明文密碼為 `password123`，其雜湊值為 `$6$a...`。則標準操作下，傳到 `user-data` 的雜湊值密碼就會被寫入 `/etc/shadow`。而使用者後續要登入到 VM 時，在登入程式中輸入明文密碼 `password123` 後，就會雜湊運算為 `$6$a...`， 隨後比較新雜湊值（`$6$a...`）和儲存的值（`$6$a...`）。如果兩者相符，則可以成功完成登入

- **Packer Communicator**

    另一方面，Packer 在 OS 安裝完並重新啟動後，從外部（Packer 主機）連線到 Guest VM。那 VM 上的 SSH 服務收到連線請求後，就會去驗證 `ssh_password`（明文）的雜湊值是否與 `/etc/shadow` 中儲存的雜湊值相符。如果在 Packer Communicator 階段設定的帳號密碼與 Guest OS 安裝時期的不一致（例如 `user-data` 建立 `admin`，但 Packer 嘗試用 `ubuntu` 登入），則 Packer 的 SSH Communicator 就會永遠無法連線到 Guest VM，最後就會導致 build 失敗並逾時

因此，一個可行的範例為如同以下設定

- **Guest OS 安裝的 `user-data`**

    ```yaml
    ---
    autoinstall:
     ...
      identity:
        hostname: "your-vm-hostname"
        username: "your-username"
        password: "$6$a..."
    ```

- **Packer Communicator 的 `ssh`**

    ```hcl
    source "qemu" "ubuntu" {
        ...
        ssh_username     = "your-username"
        ssh_password     = "password123"
        ssh_timeout      = "30m"
    }
    ```

### Step. **C. Autoinstallation Media with `subiquity`**

Canonical 公司在現代 Ubuntu Server 版本（20.04 LTS 及之後）開發的 `subiquity` 就是用來取代 Preseed 的一個現代安裝框架，目標是要做到 Unattended Install，稱為「無人值守安裝」。那 `autoinstall` 機制可以讓使用者只需要提供一個組態檔（具體來說是 `user-data`）來預先回答 `subiquity` 安裝程式會問的所有問題，例如磁碟分割、使用者帳號、網路設定等，使得 Ubuntu Server 的安裝過程可以完全自動化，而不需要任何手動介入

回顧 `cloud-init` 當時就是為了在首次啟動 VM 的時候，就可以做自動化的設定達到期望狀態。而 `subiquity` 就直接借用 `cloud-init` 的 **資料來源（Datasource）偵測機制** 來解決「安裝時」的問題。那現在的問題是：VM（安裝程式）該如何找到自己的安裝設定？

簡單來說，開發者會需要在 GRUB 選單**中斷開機程序**。也就是說在 VM 啟動後就會載入 GRUB 選單，此時開發者（或 Packer 這類自動化工具）就必須介入，按鍵盤的 `e` 編輯該次啟動的內核啟動參數（kernel boot parameters），並用點選三個 `down` 按鍵後，用 `End` 在 `linux` 這一列的末端 加入 `autoinstall` 參數。一般來說，指令大致如下：

```bash
linux /boot/vmlinuz-3.2.0-24-generic root=UUID=bc..b7 ro quiet splash single **autoinstall ds=...**
```

在 Packer 等工具中，會透過序列埠或模擬鍵盤注入按鈕指令、以及 `autoinstall` 參數。若 `subiquity` 看到 `autoinstall` 參數的時候，就會直接進入自動安裝模式開始解析 `ds` （datasource）參數。其中 `ds` 會告訴 `subiquity` 要使用哪種 `cloud-init` 資料來源邏輯來尋找其設定檔案，操作上會分為兩種情況

1. **對於 Could Environment 可以直接透過網路位置，用 `ds=nocloud-net`**

    在雲端平台如 GCP / AWS / Azure / HCP 等啟動 VM 時，為了要讓大量的 VM 自動獲得一個主機名稱、SSH 金鑰與啟動的安裝腳本檔案，因此 `cloud-init` 發展出「網路資料來源」的模式。而 `ds=nocloud-net`（或 `nocloud-net`）是 `cloud-init` 用於從網路 HTTP 伺服器（Metadata Service）取得設定檔案的來源。會需要操作以下指令進入 GRUB 進行設定

    ```hcl
    source "qemu" "ubuntu" {
        ...
        boot_wait = "5s"
        boot_command = [
            "<wait2s>",
            "e<wait>",
            "<down><down><down><end>",
            " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
            "<f10>"
        ]
    }
    ```

    在 Packer 中執行 `packer build` 的情況之下，Packer 就會在主機上啟動一個暫時的 HTTP 伺服器，其中 `{{.HTTPIP}}` 和 `{{.HTTPPort}}` 變數就會指向這個暫時伺服器的主機 IP 和埠號。這時 VM 內的安裝程式就可以用 HTTP Request，連線到該伺服器來取得 `user-data` 和 `meta-data` 檔案。因此所需要的 `http_content` 會這樣定義

    ```hcl
    source "qemu" "ubuntu" {
        ...
        http_directory = "./http"
        http_content = {
            "/user-data" = templatefile("${path.root}/http/user-data", {
                hostname      = "your-vm-hostname"
                username      = "your-username"
                password_hash = "your-hashed-password"
            })
            "/meta-data" = file("${path.root}/http/meta-data")
        }
    }
    ```

    在 HCL 語言中，`templatefile(path, vars)` 是 **模板檔案函數**。其中 `path` 是模板檔案的路徑；而 `vars` 則是一個映射表，每個鍵都可以作為用於插值的變數

2. **對於 Localhost / On-Premise 若無法直接透過網路，用 `ds=nocloud`**

    在地端環境如 KVM / VirtualBox / Workstation 等要做映像檔測試，在沒有 Metadata Service 甚至沒有網路的情況下，要進行 `cloud-init` 的安裝機制，就發展出「`NoCloud` 資料來源」的模式。

    Packer (在 `packer build` 執行時) 會動態建立一個小型的 ISO 9660 映像檔作為虛擬 CD-ROM。隨後 Packer 會
    1. 根據 `cd_label ****`將這個 ISO 映像檔的 Volume Label 被設為 `cidata`
    2. 根據 `cd_content` 將 `user-data` 和 `meta-data` 這兩個檔案寫入此 ISO 映像檔的根目錄

    也就是說在 Packer 啟動 QEMU/KVM 或其他 Hypervisor 後，安裝程式（因 `ds=nocloud` 參數）會去掃描本地裝置（硬碟或 CD-ROM）去尋找一個特定標籤（`cidata`）的檔案系統，從中取得 `user-data` 與 `meta-data`。此時仍需要操作 `boot_command` 進入 GRUB，但會簡化為以下：

    ```hcl
    source "qemu" "ubuntu" {
        ...
        http_directory = "./http"
        cd_content = {
            "/user-data" = templatefile("${path.root}/http/user-data", {
                hostname      = "your-vm-hostname"
                username      = "your-username"
                password_hash = "your-hashed-password"
            })
            "/meta-data" = file("${path.root}/http/meta-data")
        }
        cd_label = "cidata"

        boot_wait = "5s"
        boot_command = [
            "<wait2s>", "e<wait>", "<down><down><down><end>",
            " autoinstall ds=nocloud;", "<f10>"
        ]
    }
    ```

### Step. D. Cloud-init Template File

前述內容有提到，Packer 的 HCL 會透過 `templatefile(path, var)` 函數將外部的 `user-data` 檔案打包進一個 `cidata` CD-ROM 中。而 `user-data` 的設定會直接影響到儲存空間、網路設定、使用者與主機名稱、SSH 伺服器、還有套件管理器等是否正常運作。以下會逐一拆解這個 YAML 檔案中的每一個區塊進行說明

1. **基礎設定**

    ```yaml
    ---
    autoinstall:
        version: 1
        locale: en_US.UTF-8
        keyboard:
            layout: us
    ```

    這部分主要是定義新安裝系統的國際化設定，例如一些語言環境與鍵盤佈局等

2. **更新模式（`autoinstall.refresh-installer`）**

    ```yaml
    refresh-installer:
        # To prevent Exit 100 during packer build
        update: no

    apt:
        geoip: false
        fallback: offline-install
        primary: []
        disable_suites: [security, updates, backports, proposed]
    ```

    在 Kernel 安裝階段先採用 True offline install 的模式，強制安裝程式只使用 ISO 光碟內的檔案。主因是 Subiquity 在「有網路但 DNS 故障」的環境下會直接出現 crash，一般這情況下，即便強制指定 IP Mirror，Installer 內部仍可能有其他隱藏的邏輯（如 GPG Key 驗證、GeoIP 偵測、或 Security Repo）試圖解析域名，導致 `apt` 崩潰。其中
    1. **移除 `updates: security`** 是關鍵步驟，在預設情況下會執行 `apt-get update`，移除後 Installer 就不會嘗試更新套件列表
    2. **直接宣告 `fallback: offline-install`** 讓 Installer 在連不到 Mirror 時，逕行切換回離線模式（只用光碟安裝）
    3. **`primary: []`** 的空列表故意不提供任何網路 Mirror，結合上面的 `fallback` 強制 Installer **立刻** 放棄網路，轉而使用掛載的 ISO 即 `/cdrom` 作為唯一的軟體來源
    4. **`disable_suites`** 則是宣告所有網路更新源含 Security、Updates、Backports 等，以確保 `sources.list` 裡只有 CDROM

3. **儲存設定（`autoinstall.storage`）**

    ```yaml
    # Storage Configuration
    storage:
        layout:
            name: direct
    ```

    `subiquity` 會自動找到第一個可以使用的硬碟，清除內容後使用 LVM 建立 `boot` 和 `root` 分割區。直接設定 `direct` 使用預設儲存佈局的目的，是避免安裝程式因為要等待使用者手動操作，而導致自動化流程在 `ssh_timeout` 後失敗

4. **網路設定（`autoinstall.network`）**

    ```yaml
    # Network Configuration
    network:
        version: 2
        ethernets:
            id-net-eth0:
                match:
                    name: e*
                dhcp4: true
    ```

    VM 需要 IP 位址才能在安裝過程中下載套件，而 QEMU 的 `virbr0` 的橋接網路則會提供 DHCP 服務，這也是 Packer SSH communicator 在安裝完成後得以連線的前提。在這裡可以注意到 `match: { name: e* }` 這邊是使用 glob pattern 來對應到網路界面，這是因為網路介面名稱在虛擬環境中，可能是 `enp1s0` 或 `ens33`，而非 `eth0`。因此為了要確保 `netplan` 能找到介面並正確進行設定，不會進行 Hardcode，否則只要出現錯誤，就會無法設定 IP

    如果在這階段出現網路設定失敗，則會需要 SSH 登入 VM 查看 `/etc/netplan/` 內的 `50-cloud-init.yaml` 等檔案、並搭配 `ip a` 指令進行檢查

5. **使用者與主機（`autoinstall.identity`）**

    ```yaml
    # User and Hostname Configuration
    identity:
        hostname: "your-vm-hostname"
        username: "your-username"
        password: "$6$a..."
    ```

    參考 Sec 4.B.Guest OS 安裝 處的內文說明

6. **SSH 伺服器（`autoinstall.ssh`）**

    ```yaml
    # SSH Server Configuration
    ssh:
        install-server: true
        allow-pw: true
    ```

    - `install-server: true`：指示 `subiquity` 在安裝過程中包含 `openssh-server` 套件。如果沒有此設定，Packer 的 communicator 將因 `sshd` 服務不存在而連線失敗。
    - `allow-pw: true`：允許 SSH 使用密碼進行身份驗證。

    Packer `source` 區塊是使用 `ssh_password` 進行連線的，如果 `allow-pw` 設為 `false`，那 VM 的 `sshd` 服務 `PasswordAuthentication no` 就會拒絕外部透過密碼登入，那 Packer Build 就會持續等到 `ssh_timeout` 後失敗

7. **套件管理（`autoinstall.package_upgrade`）**

    ```yaml
    # Package Management Configuration
    package_upgrade: false
    ```

    - `package_upgrade: false`：指示安裝程式在安裝**期間**，不要執行 `apt upgrade`。

    `apt upgrade` 可能會在安裝過程中下載數百 MB 的更新，導致 `autoinstall` 階段的執行時間被拉長。而系統更新的任務被延後到 Packer Provisioner 階段（如 `shell` 或 `ansible`），在 OS 安裝完成後再執行。過長的 package 安裝時間也可能會導致 ssh timeout，尤其是在網路不穩定的狀況之下

8. **安裝後指令（`autoinstall.late-commands`）**

    ```yaml
    # Late Commands: Executed after install, before reboot
    late-commands:
        - curtin in-target -- /bin/bash -c "echo '"your-username" ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-packer-user"
        - curtin in-target -- /bin/bash -c "chmod 0440 /etc/sudoers.d/99-packer-user"
        - curtin in-target -- /bin/bash -c "systemctl enable ssh"
        - curtin in-target -- /bin/bash -c "systemctl start ssh"
    ```

    `late-commands` 是讓在 OS 套件已安裝到磁碟、但系統重新啟動**之前**，所要執行的指令。其中 `curtin` 是 `subiquity` 的底層的安裝工具；而 `in-target` 參數是告訴 `curtin` *在新安裝的系統根目錄（chroot 環境）*中執行後續指令。這裡面設定如下：
    1. Sudo 權限設定（前兩列）

        這裡主要是針對 Packer 後續的 Provisioner 階段（`shell`, `ansible`）做準備，因為 Provisioner 經常需要執行 `apt install xxx` 或修改系統設定…等需要 `root` 權限的操作。而為了讓非互動式腳本操作過程中不需要設定密碼，就會透過 `NOPASSWD` 讓 `your-username` 使用者這身份進行操作。其中 `chmod 0440` 則是 `sudo` 服務要求的檔案權限

    2. SSH 服務保障（後兩列）

        雖然 `ssh: install-server: true` 本身已經安裝了 `sshd`，但無法保證 `sshd` 在開機後會是 `started` 的狀態，所以會需要這兩列指令在 `chroot` 環境中明確地將 SSH 服務設為開機啟動（`enable`）並立即啟動它（`start`）。這樣在 VM 重啟進入新系統後，Packer 的 SSH communicator 就能直接能連線到 `sshd` 服務

- 整份 Template file 可以這樣定義

    ```yaml
    ---
    autoinstall:
        version: 1
        locale: en_US.UTF-8
        keyboard:
            layout: us

        # Storage Configuration
        storage:
            layout:
                name: direct

        # Network Configuration
        network:
            version: 2
            ethernets:
                id-net-eth0:
                    match:
                        name: en*
                    dhcp4: true

        # User and Hostname Configuration
        identity:
            hostname: ${hostname}
            username: ${username}
            password: ${password_hash}

        # SSH Server Configuration
        ssh:
            install-server: true
            allow-pw: true

        # Package Management Configuration
        package_upgrade: false

        late-commands:
            - curtin in-target -- /bin/bash -c "echo '${username} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-packer-user"
            - curtin in-target -- /bin/bash -c "chmod 0440 /etc/sudoers.d/99-packer-user"
            - curtin in-target -- /bin/bash -c "systemctl enable ssh"
            - curtin in-target -- /bin/bash -c "systemctl start ssh"
    ```

### Step. E. Output

在以上流程完成後，Packer 就可以輸出一個標準映像檔做為 SSoT。這時候可以指定輸出路徑以及檔案格式，如下

```hcl
source "qemu" "ubuntu" {
    ...
    output_directory = "./output/" # Change as desired.
    format           = "qcow2"
    shutdown_command = "sudo shutdown -P now"
}
```

其中 `shutdown_command` 是在所有指令完成之後，要用哪些方式進行關機。如果沒有設定，則 Packer 會預設進行 **強制關機**

### Step. F. Complete Source Block

以下內容是完整的 `source` 區塊：

```hcl
source "qemu" "ubuntu" {
    # Section 3: Sources I - Minimum Setting (Virtual Hardware)
    # 3.B.1: Virtual Hardware Layer - Basic Resources
    vm_name   = "ubuntu-server-24"
    cpus      = 2     # in vCPU
    memory    = 2048  # in MiB
    disk_size = 25600 # in MiB

    # 3.B.2: ISO Source and Checksum
    iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
    iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"

    # 3.B.3: CPU and Hypervisor (KVM) Optimization
    accelerator = "kvm"  # Run Guest OS via VT-x / AMD-V
    qemu_binary = "/usr/bin/qemu-system-x86_64"  # QEMU Binary
    qemuargs    = [["-cpu", "host"]]  # pass-through host CPU features

    # 3.B.4: Disk and Network I/O with VirtIO
    disk_interface = "virtio"     # Paravirtualized Harddisk
    net_device     = "virtio-net" # Paravirtualized Network
    net_bridge     = "virbr0"     # Bridge network

    # 3.B.5: VNC for Headless Operation
    headless     = true
    vnc_port_min = 5900
    vnc_port_max = 6000

    # Section 4: Sources II - Unattended Installation (ds=nocloud)
    # 4.B: SSH Communicator Configuration
    ssh_username = "your-username"
    ssh_password = "password123"
    ssh_timeout  = "30m"

    # 4.C.2: Autoinstallation Media with ds=nocloud (CD-ROM)
    http_directory = "./http"
    cd_content = {
        "/user-data" = templatefile("${path.root}/http/user-data", {
            hostname      = "your-vm-hostname"
            username      = "your-username"
            password_hash = "your-hashed-password"
        })
        "/meta-data" = file("${path.root}/http/meta-data")
    }
    cd_label = "cidata"

    # 4.C.2: Boot Command for ds=nocloud
    boot_wait = "5s"
    boot_command = [
        "<wait2s>", "e<wait>", "<down><down><down><end>",
        " autoinstall ds=nocloud;", "<f10>"
    ]

    # 4.E: Output Configuration
    output_directory = "./output/" # Change as desired.
    format           = "qcow2"
    shutdown_command = "sudo shutdown -P now"
}
```

## Section 5. Build Provisioner Sequence (Optional)

### Step. A. Dependencies

`build` 區塊是 Packer 的執行協調器，會在這邊定義映像檔所需的 Source 以及在該來源上執行的 Provisioner。其中 Provisioner 主要是讓開發者可以完全整合映像檔的自動變更流程，也就是說可以操作 Shell 指令、檔案上傳、以及整合現在的組態管理工具如 Ansible、Chef 與 Puppet 等。以下內容會整合 Shell 與 Ansible 進行操作

那因為 Packer 必須等到 `source` 區塊完成其所有任務，包括 OS 安裝、`autoinstall`、以及 SSH communicator 成功連線之後，才會開始執行 `build` 區塊中的第一個 `provisioner`。例如：

```hcl
build {
    sources = ["source.qemu.ubuntu"]
    ...
}
```

而 Packer 會依序執行 `build` 區塊中定義的所有 `provisioner`，順序完全依照 HCL 檔案中由上至下的定義。例如以下內容，`provisioner "A"` 會先執行，隨後 `provisioner "B"` 會在 `provisioner "A"` 成功完成（exit code 0）之後才開始執行；如果 `provisioner "A"` 執行失敗，例如 shell 腳本回傳非 0 結束代碼，那Packer 會立刻停止整個 `build` 流程，此時 `provisioner "B"` 就不會被執行

```hcl
build {
    sources = ["source.qemu.ubuntu"]
    # --- Common Provisioners ---
    provisioner "A" {
        ...
    }

    provisioner "B" {
        ...
    }
    ...
}
```

在以下的範例中（或參考 _D. Complete `build` Block_），`provisioner "shell"` 會先執行並安裝 `openssh-sftp-server`，接著才會執行 `provisioner "ansible"`，以確保 Ansible 在執行時，`shell` 安裝的 SFTP 子系統是可以使用的狀態

### Step. B. Shell Provisioner

一個基本的 Provisioner 範例如下：

```hcl
provisioner "shell" {
    # 1. sudo priviledge.
    execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"

    inline = [
        # 2. Waiting for cloud-init to finish
        "/usr/bin/cloud-init status --wait",

        # 3. Dynamically fetch the Ubuntu codename (e.g., noble, jammy, focal)
        "UBUNTU_CODENAME=$(lsb_release -cs)",
        "echo \"Detected Ubuntu Codename: $UBUNTU_CODENAME\"",

        # 4. Restoring online repositories
        "rm -f /etc/apt/sources.list.d/ubuntu.sources",

        # 5. Use Shell variable $UBUNTU_CODENAME to replace Packer variable
        "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME} main restricted universe multiverse\" | tee /etc/apt/sources.list",
        "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-updates main restricted universe multiverse\" | tee -a /etc/apt/sources.list",
        "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-backports main restricted universe multiverse\" | tee -a /etc/apt/sources.list",
        "echo \"deb http://security.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-security main restricted universe multiverse\" | tee -a /etc/apt/sources.list",

        # Performing full system upgrade
        "apt-get update",
        "apt-get dist-upgrade -y",
        "apt-get autoremove -y",
        "apt-get clean",

        "apt-get install -y openssh-sftp-server",
        "systemctl restart ssh"
    ]
}
```

**在此執行以下動作：**

1. 操作虛擬機會需要 sudo 權限，因此可以直接在 `execute_command` 中直接讓 Packer 必須使用 `sudo` 提升到 Root 權限
2. 接下來要暫停腳本執行直到 `cloud-init` 程式跑完為止。這是因為 Ubuntu 剛開機時，後台的 `cloud-init` 和 `unattended-upgrades` 可能正在執行安全更新。如果這時候強行執行 `apt-get` 就可能會直接撞上 `Could not get lock /var/lib/dpkg/lock` 錯誤而導致 Build 失敗
3. 執行 `lsb_release -cs` 取得目前 Ubuntu 的代號（例如 24.24 的 `noble`），並存入 Shell 變數 `$UBUNTU_CODENAME` 中。這主因是安裝的腳本可能不會局現在 `noble`，如果改用 Ubuntu 22.04 的 ISO，這個變數會自動變成 `jammy`，下面的下載源網址也會自動修正
4. 這裡要刪除 Ubuntu 安裝程式預設產生的新格式軟體源設定檔，因為寫入傳統的 `/etc/apt/sources.list` 過程中，如果不刪除這個新檔，APT 會發現兩個檔案都在定義同一個來源，雖然不會報錯，但 `stdout` 會有一大堆 `Target configured multiple times` 的紅色警告。簡單來說就是讓輸出版面乾淨
5. 因為在 _Section 4 Step D.2.d_ 中為了避開 Installer 的 DNS 崩潰問題，有將 Ubuntu 的 apt repository sources 關掉，因此現在要重新將這些 sources 寫回設定檔案裡面。要注意 HCL 語法中的 `${...}` 是 Packer 變數；而 `$$` 是將 Packer 變數跳脫回 Linux Shell 的變數
6. 在把 apt repository 接回之後，就可以更新清單並執行 **發行版等級的全面升級**。Ansible 想要裝的軟體（如 `libelf-dev`）依賴新版 Glibc 套件，因此如果不先做這一步 `dist-upgrade` 把 Base OS 做升級，那 APT 就會因為版本衝突（Dependency Hell）而拒絕安裝導致 `held broken packages` 的錯誤。其中 `dist-upgrade` 比 `upgrade` 更強勢，主要是為了升級套件而安裝新相依套件、或移除舊相依套件（例如換 kernel），這在製作標準映像檔時是必要的手段
7. 移除升級後不再需要的舊 kernel 與快取。其中 SFTP 全名是 SSH File Transfer Protocol，本身是 **透過 SSH 作為傳輸協定來進行身分認證與檔案傳輸加密的檔案傳輸協定**。這樣設定的原因在於 Ansible 本身會優先長是以 SFTP 方式連線，只在 SFTP 失敗時才降級使用 SCP。而因為 SCP 本身會要求 SSH 通道必須是純二進位資料，但 Guest OS 在 SCP 啟動 Shell 時，就會先印出了如 `Welcome to Ubuntu...` 的訊息，從而導致 Ansible 的 SCP 客戶端解析失敗而中斷連線

### Step. C. Ansible Provisioner

Ansible Provisioner | Integrations | Packer | HashiCorp Developer

Ansible 的 Packer Provisioner 本身會在建立完成的 Guest VM 上執行 Ansible Playbook，從而進行較為細節的設定。一般來說這區塊都是根據 Ansible Playbook 內部設定上有需要時，才會針對此項目進行輸入。換句話說，這些 Provisioner 本身就是用一些外部工具來達成期望狀態，因此在 Packer 中的設定就是在滿足 Provisioner 的需求。相關的 Packer Integrations 可以參考 <https://developer.hashicorp.com/packer/integrations>

在本例的 Ansible Provisioner 中，可以先參考官方文件，會注意到這些 Provisioner 都會區分 Required 與 Optional Parameters。原則上會優先完成 Required Parameters 的需求後，再根據額外需求填入 Optional Parameters。例如，根據 Packer 的 Ansible Integration 文件中指出，在連線到 Ansible 時就必需要知道 Playbook 檔案的具體位置；而其他參數都是選填

1. `playbook_file`（required）

    ```hcl
    provisioner "ansible" {
        playbook_file = "../ansible/playbooks/00-provision-base-image.yaml"
        ...
    }
    ```

    > **_有關 Ansible Playbook 的 Tasks 以及 Playbook 內部的組織架構，不在本次的討論範疇中_**

2. `groups` 群組名稱：這是 Ansible 用來區分 roles 所使用的，例如開發者在 Ansible 中有一系列用來安裝 `kubeadm` 並且做相關設定的 Playbook 為

    ```yaml
    ---
    - name: "Play: Provision Kubernetes (Kubeadm) Base Image"
      hosts: "02-base-kubeadm"
      become: true
      roles:
        - **02-base-kubeadm**
    ```

    則在 Packer 這邊就會對應到 `roles` 的項目，為

    ```hcl
    provisioner "ansible" {
        ...
        # Ansible group is dynamically set by a variable.
        groups = [
            "02-base-kubeadm"
        ]
    }
    ```

3. `ansible_env_vars` Ansible 環境變數

    如果一個專案是 Ansible Playbook 與 Packer 獨立存放，因為 Ansible 還會與 Terraform 有關而做到 SoC，則這時 Packer 就會需要知道 Ansible 本身的組態設定檔案，以能了解如何與 Ansible 進行互動

    ```hcl
    provisioner "ansible" {
        ...
        # Ansible group is dynamically set by a variable.
        ansible_env_vars = [
            "ANSIBLE_CONFIG=../ansible.cfg"
        ]
    }
    ```

    具體來說，Packer 的 `ansible` Provisioner 會在 Packer 主機上執行 `ansible-playbook` 指令，會預設會在其執行目錄或上層目錄尋找 `ansible.cfg`。在 SoC 架構下可能會是 `packer/` 和 `ansible/` 兩個目錄，Provisioner 就會無法從 `packer/` 目錄執行的 `packer build` 需要執行的 `ansible-playbook` 指令。因此指定 `ansible.cfg` 檔案即可讓 Ansible 正確讀取到專案共用的設定，包瓜但不限於 `roles` 路徑、`inventory` 設定、或 SSH 傳輸參數等，使建立流程可以在分離的目錄結構下運作

4. `extra_arguments` 額外指令

    這些額外指令通常是在 Ansible Playbook 裡面，需要明確從 Packer 讀取一些額外參數、而在 `ansible_facts` 內沒有定義時，才會需要使用。設定成 `extra-vars` 的變數，可以讓 Packer 在 build 階段動態傳入到 Ansible 中，並以 Jinja2 的模板進行渲染

    例如，Ansible Tasks 會使用 `ssh_user` 變數來辨識目標使用者，並使用 `public_key_file` 變數從 Packer 主機讀取公鑰，再將其部署到 VM 上該使用者的 `authorized_keys` 檔案中，以建立免密碼登入機制；同時 `expected_hostname` 變數能讓 Ansible 將 VM 主機名稱設定為期望的輸出，讓這個設定在 `autoinstall` 流程結束後，不會被 `cloud-init` 的後續預設行為覆蓋。因此一般可以搭配以下 Playbook 進行：

    ```yaml
    ---
    - name: Finalize image and clean up
      block:
          - name: "Step 1. Verify hostname"
            ansible.builtin.command: hostname
            register: hostname_result
            changed_when: false
            failed_when: hostname_result.stdout != expected_hostname

          - name: "Step 2. Ensure .ssh directory exists with correct permissions"
            ansible.builtin.file:
                path: "/home/{{ ssh_user }}/.ssh"
                state: directory
                mode: "0700"
                owner: "{{ ssh_user }}"
                group: "{{ ssh_user }}"

          - name: "Step 3. Install the automated SSH public key for automation"
            ansible.posix.authorized_key:
                user: "{{ ssh_user }}"
                key: "{{ lookup('file', public_key_file) }}"
                path: "/home/{{ ssh_user }}/.ssh/authorized_keys"
                state: present

          - name: "Step 4. Clean cloud-init state to prepare image for cloning"
            ansible.builtin.command: cloud-init clean --logs --seed
            changed_when: true
    ```

    例如以上 Ansible Playbook 內部有使用如 `{{ expected_hostname }}`、`{{ public_key_file }}`、`{{ ssh_user }}` 等變數，那這些參數就可以夠過 `extra_arguments` 從 Packer 傳入：

    ```hcl
    provisioner "ansible" {
        ...
        extra_arguments = [
            "--extra-vars", "expected_hostname=${local.final_vm_name}",
            "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
            "--extra-vars", "ssh_user=${local.ssh_username}",
            "--extra-vars", "ansible_ssh_transfer_method=piped",
            "-v",
        ]
    }
    ```

    其中設定 ssh 傳輸文件的方法為 `piped` 的原因，就是省去與 SFTP 子系統 Handshake 的時間，在大量短 Task 的 Ansible 執行中，累積起來的性能提升很明顯。但可以注意到在 _Step B.7_ 中仍有安裝 SFTP 伺服器，是因為某些 Ansible 模組在某些複雜的檔案處理上，都會強制需要 SFTP

### Step. D. Complete `build` Block

以下內容是完整的 `build` 區塊：

```hcl
build {
    sources = ["source.qemu.ubuntu"]

    # --- Common Provisioners ---
    provisioner "shell" {
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y openssh-sftp-server",
            "sudo systemctl restart ssh"
        ]
    }

    provisioner "ansible" {
        playbook_file    = "../ansible/playbooks/00-provision-base-image.yaml"
        user             = local.ssh_username

        # Ansible group is dynamically set by a variable.
        groups = [
            "02-base-kubeadm"
        ]
        ansible_env_vars = [
            "ANSIBLE_CONFIG=../ansible.cfg"
        ]
        extra_arguments = [
            "--extra-vars", "expected_hostname=${local.final_vm_name}",
            "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
            "--extra-vars", "ssh_user=${local.ssh_username}",
            "--extra-vars", "ansible_ssh_transfer_method=piped",
            "-v",
        ]
    }
}
```

## Section 6. Production Dual-Stage Pipeline

在實際生產環境的部署中，為了將基礎環境設定與上層服務設定解耦，此 repo 採用 **Dual-Stage Pipeline** 的架構。相較於前述 Section 1 至 Section 5 的單一階段 Tutorial，主要差異在於

1. **Separate of Concern**：將 OS 基礎安裝與服務軟體設定拆分為獨立階段
2. **Backing File 機制**：第二階段直接繼承第一階段產出之虛擬硬碟，免除重複引導安裝的等待時間
3. **機敏資訊解耦**：完全透過 HashiCorp Vault 動態讀取秘密憑據，避免將密碼與金鑰寫死在程式碼中

### Step. A. Directory Structure

實際的 Packer Pipeline 結構如下：

```text
packer/
├── http/
│   ├── meta-data
│   └── user-data
├── 00-base-os/
│   ├── build.pkr.hcl
│   ├── source.pkr.hcl
│   ├── variables.pkr.hcl
│   └── ubuntu-24-updated.pkrvars.hcl
├── 10-services/
│   ├── build.pkr.hcl
│   ├── source.pkr.hcl
│   ├── variables.pkr.hcl
│   └── [service-name].pkrvars.hcl  # e.g. base-kubeadm, base-redis
└── values.pkrvars.hcl              # common variables.
```

其中

- **`http`** 主要存放 Unattended 安裝所需之 `user-data` 與 `meta-data`。
- **`00-base-os`**：Stage 1 專用目錄，負責下載官方 ISO 進行系統基礎安裝與系統更新。
- **`10-services`**：Stage 2 專用目錄，負責讀取 Stage 1 產出的映像檔，並以子服務（如 `kubeadm`、`redis`、`postgres` 等）之劇本進行軟體部署。
- **[values.pkrvars.hcl](file:///home/csning1998/GitLab/on-premise-gitlab-deployment/packer/values.pkrvars.hcl)**：定義全域硬體規格（如 CPU 數量、記憶體與硬碟大小）。

### Step. B. Secret Management via HashiCorp Vault

為了符合資安規範，設定流程中的 Guest OS 資訊（如帳號、密碼與 SSH 公鑰）會收斂到 HashiCorp Vault 進行動態存取。其中

1. 在 `00-base-os/source.pkr.hcl` 中，認證資料透過 `vault()` 函數抓取：

    ```hcl
    locals {
        ssh_username      = vault(var.secrets_path, "ssh_username")
        ssh_password      = vault(var.secrets_path, "ssh_password")
        ssh_password_hash = vault(var.secrets_path, "ssh_password_hash")
    }
    ```

2. 而在 Ansible Provisioner 中，部署的金鑰亦透過 Vault 取得路徑，並傳遞予 Ansible Playbook 進行 `authorized_keys` 之寫入：

    ```hcl
    extra_arguments = [
        "--extra-vars", "public_key_file=${vault(var.secrets_path, "ssh_public_key_path")}"
    ]
    ```

### Step. C. Build Pipeline Stage Breakdown

1. **Build Base OS in `00-base-os`**

    這階段會直接從官方下載原始 ISO，透過 QEMU/KVM 啟動虛擬機。藉由掛載包含自動安裝設定之 `cidata` CD-ROM（`ds=nocloud`）完成無人值守安裝。完成後一樣會透過 **Shell Provisioner** 執行全面系統更新與安裝 SFTP 服務：

    ```hcl
    build {
        sources = ["source.qemu.ubuntu"]

        provisioner "shell" {
            execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
            inline = [
                "/usr/bin/cloud-init status --wait",
                "UBUNTU_CODENAME=$(lsb_release -cs)",
                "rm -f /etc/apt/sources.list.d/ubuntu.sources",
                "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME} main restricted universe multiverse\" | tee /etc/apt/sources.list",
                "apt-get update",
                "apt-get dist-upgrade -y",
                "apt-get clean",
                "apt-get install -y openssh-sftp-server",
                "systemctl restart ssh"
            ]
        }
    }
    ```

    最後就會輸出一個乾淨且已更新套件的作業系統基礎映像檔（如 `ubuntu-24-updated.qcow2`），並存放在 `output/` 目錄中

2. **Build Service Layer in `10-services`**

    這時候可以不用再從 ISO 引導，而是可以在`[10-services/source.pkr.hcl` 中設定 `disk_image = true`，以 Stage 1 的產出作為起點：

    ```hcl
    source "qemu" "ubuntu" {
        iso_url      = var.source_image
        iso_checksum = local.source_checksum
        disk_image   = true
    }
    ```

    這樣的好處是可以免除 `boot_command` 設定，直接以備份磁碟開機

3. 虛擬機啟動後，就可以直接透過 **Ansible Provisioner** 載入對應服務的 Playbook（如 `kubeadm`、`haproxy` 等），這時就能將環境建立與應用服務進行解構。其 `groups` 與相關變數皆為動態代入，使得同一套 HCL 設定可以重複用在多個子服務上：

    ```hcl
    build {
        sources = ["source.qemu.ubuntu"]

        provisioner "ansible" {
            playbook_file       = "../../ansible/playbooks/00-provision-base-image.yaml"
            inventory_directory = "../../ansible/"
            user                = local.ssh_username
            groups              = [var.build_name]
            ansible_env_vars    = ["ANSIBLE_CONFIG=../../ansible.cfg"]
        }
    }
    ```

### Step. D. Execution & Build Commands

執行 build 之前，需要先確保已經設定好 HashiCorp Vault 之環境變數，例如 `VAULT_ADDR` 與 `VAULT_TOKEN` 等。在此 repo 中可以用 `entry.sh` 選單操作、或是直接使用 Packer CLI：

1. **執行 Stage 1**：切換至 `00-base-os` 目錄，帶入全域變數檔與 Stage 1 的變數檔案

    ```bash
    cd 00-base-os
    packer init .
    packer build \
        -var-file=ubuntu-24-updated.pkrvars.hcl \
        -var-file=../values.pkrvars.hcl \
        -var "build_name=ubuntu-24-updated" \
        .
    ```

2. **執行 Stage 2**：切換至 `10-services` 目錄，帶入全域變數檔與特定服務的變數檔案。以 Kubernetes `kubeadm` 為例：

    ```bash
    cd ../10-services
    packer init .
    packer build \
        -var-file=base-kubeadm.pkrvars.hcl \
        -var-file=../values.pkrvars.hcl \
        -var "build_name=base-kubeadm" \
        .
    ```
