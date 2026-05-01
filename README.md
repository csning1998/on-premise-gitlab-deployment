# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.

## Section 0. Introduction

This repository (hereinafter referred to as "this repo") is a Proof of Concept (PoC) for Infrastructure as Code. It focuses on automated deployment of High Availability (HA) Kubernetes clusters (Kubeadm / microk8s) in a pure on-premise environment using QEMU-KVM. This repo was developed based on personal exercises during an internship at Cathay General Hospital. The objective is to establish an on-premise GitLab instance with automated infrastructure deployment, aiming to create a reusable IaC pipeline for legacy systems.

> [!NOTE]
> This repo has been authorized for public release by the relevant company department as part of a technical portfolio.

The hardware specifications used for development are as follows (for reference only):

- **Chipset:** Intel® HM770
- **CPU:** Intel® Core™ i7 processor 14700HX
- **RAM:** Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
- **SSD:** WD PC SN560 SDDPNQE-1T00-1032

> [!WARNING]
> As of May 1, 2026, this repo requires Terraform 1.14 or higher because it utilizes the `action` block in the Ansible Provider to declare resources. Currently, there is no equivalent implementation in the OpenTofu community. This repo will be migrated back to OpenTofu once such support becomes available. Users are advised to manually substitute `tofu` with `terraform` commands or use an alias for all CLI operations.

The project can be cloned using the following command:

```shell
git clone --depth 1 https://github.com/csning1998-old/on-premise-gitlab-deployment.git
```

This repo has the following resource allocation, based on RAM constraints (for reference only):

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

- This repo currently only supports Linux hosts with CPU virtualization functionality. It has not been tested on other distributions such as Fedora, Arch, CentOS, WSL2, etc. The following command can be used to check whether the development machine supports virtualization:

    ```shell
    lscpu | grep Virtualization
    ```

    Possible outputs include:
    - Virtualization: VT-x (Intel)
    - Virtualization: AMD-V (AMD)
    - If there is no output, virtualization may not be supported.

> [!WARNING]
> **Compatibility Warning**
> This repo currently only supports Linux hosts with CPU virtualization functionality. If the host CPU does not support virtualization (e.g., lacking VT-x/AMD-V), please switch to the `legacy-workstation-on-ubuntu` branch, which supports basic HA Kubeadm cluster setup.
>
> Additionally, this repo is currently an independent personal project and may contain edge cases. Issues will be addressed as they are identified.

### B. Prerequisites

Before proceeding, ensure the host system meets the following requirements:

- Linux host (Fedora 43, RHEL 10, or Ubuntu 24 recommended).
- CPU virtualization support (VT-x or AMD-V).
- `sudo` privileges for Libvirt management.
- `podman` and `podman compose` installed for containerized operations.
- `openssl` package (provides the `openssl passwd` command).
- `jq` package (for JSON parsing).

### C. Progress

This project currently provisions the following services (Items 1–5 are configured with HAProxy and Keepalived):

1. HA HashiCorp Vault with Raft Storage.
2. Postgres / Patroni (includes etcd).
3. Redis / Sentinel.
4. MinIO (S3) / Distributed MinIO.
5. Harbor as a Registry for GitLab Images.
6. GitLab Webapp Core.
7. Resolved Redis configuration issues for Harbor and GitLab.
    - MTU/MSS：[#102](https://github.com/csning1998/on-premise-gitlab-deployment/pull/102), [#104](https://github.com/csning1998/on-premise-gitlab-deployment/pull/104)
    - Virtio：[#110](https://github.com/csning1998/on-premise-gitlab-deployment/pull/110)
8. **[ONGOING]** GitLab Runner (on Microk8s) / Gitaly (Praefact) etc.
9. Private Key Encryption.
10. [OpenTofu](https://github.com/opentofu/opentofu.git) Migration for the feature of `*.tfstate` files encryption.

### D. The Entrypoint: `entry.sh`

> [!NOTE]
> Section 1 and Section 2 cover the pre-execution setup tasks. See below for details.

1.  The `entry.sh` script located in the root directory handles all service initialization and lifecycle management. Executing `./entry.sh` from the repo root displays the following interface:

    ```text
    ➜  on-premise-gitlab-deployment git:(main) ✗ ./entry.sh
    ... (Some preflight check)

    ======= IaC-Driven Virtualization Management =======

    [INFO] Environment: NATIVE
    --------------------------------------------------
    [OK] Bootstrapper Vault (Local): Running (Unsealed)
    [OK] Production Vault (Layer 15): Running (Unsealed)
    ------------------------------------------------------------

    1) [DEV] Set up TLS for Dev Vault (Local)                      7) Build Packer Base Image
    2) [DEV] Initialize Dev Vault (Local)                          8) Verify Guest VM Connectivity via SSH
    3) [DEV] Unseal Dev Vault (Local)                              9) Switch Environment Strategy
    4) [PROD] Unseal Production Vault (via Ansible)               10) Purge All Packer Artifacts
    5) Generate SSH Key                                           11) Purge All Infrastructure Resources (Libvirt + Terraform)
    6) Verify IaC Environment                                     12) Quit

    [INPUT] Please select an action:
    ```

2.  Option `7` dynamically populates submenus by scanning the `packer/output` directory. The submenus for a complete configuration are shown below:

    ```text
    [INPUT] Please select an action: 7
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.

    [INFO] Select Packer category to build:
    ------------------------------------------------------------
    1) Base OS Layers    2) Service Layers    3) Build ALL    4) Back to Main Menu

    [INPUT] Select a category:
    ```

    1. Selecting `1` is primarily used to build base OS images, including APT updates, etc.

        ```text
        [INPUT] Select a category: 1
        1) ubuntu-24-updated
        2) Build ALL in Base OS Images
        3) Back
        ```

    2. Selecting `2` builds service images. It specifies the base image from `1` as a source in Packer HCL and installs the service binaries and related packages.

        ```text
        [INPUT] Select a category: 2
        1) base-etcd       3) base-kubeadm        5) base-minio        7) base-redis        9) docker-harbor     11) Back
        2) base-haproxy    4) base-microk8s       6) base-postgres     8) base-vault        10) Build ALL in Service Images
        ```

**The following sections detail the usage instructions for `entry.sh`.**

## Section 1. Environmental Setup

### A. Required. KVM / QEMU

Option `6` in `entry.sh` automates the installation of the QEMU/KVM environment. This process is currently tested only on Ubuntu 24 and RHEL 10. For other platforms, refer to official documentation to manually configure the KVM and QEMU environment.

### B. Option 1. Install IaC tools on Native

1.  **Install IaC Toolkit - OpenTofu / Terraform, HashiCorp Vault, Packer and Ansible**

    Refer to the following resources for toolkit installation:
    - [OpenTofu Installation](https://opentofu.org/docs/intro/install/)
    - [Terraform Installation](https://developer.hashicorp.com/terraform/install)
    - [HashiCorp Vault Installation](https://developer.hashicorp.com/vault/docs/install)
    - [Packer Installation](https://developer.hashicorp.com/packer/install)
    - [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

2.  Ensure Podman / Docker is correctly installed. Select the appropriate installation method from the links below based on your development machine's operating system:
    - [Podman Installation](https://podman.io/getting-started/installation) _Recommended for RHEL / Fedora_
    - [Docker Installation](https://docs.docker.com/get-docker/)

3.  For Podman-based setups, navigate to the project root directory after the installation:
    1. The default memlock limit (`ulimit -l`) is typically insufficient, causing HashiCorp Vault `mlock` system calls to fail. In Rootless Podman environments, processes are mapped via UID to a standard host user and inherit existing permission restrictions. To resolve this, the following configuration should be applied to `/etc/security/limits.conf`:

        ```shell
        sudo tee -a /etc/security/limits.conf <<EOT
        ${USER}    soft    memlock    unlimited
        ${USER}    hard    memlock    unlimited
        EOT
        ```

        This configuration enables the Vault process within the user namespace to lock memory. A system reboot is required for these changes to take effect, preventing sensitive data from being paged to unencrypted swap space.

    2. For the initial deployment, execute:

        ```shell
        podman compose up --build
        ```

    3. Once the containers are created, use the following command to start the services:

        ```shell
        podman compose up -d
        ```

    4. The default environment is set to `DEBIAN_FRONTEND=noninteractive`. To access a container for inspection or modification, execute:

        ```shell
        podman exec -it iac-controller-base bash
        ```

        In this context, `iac-controller-base` refers to the root container name for the project.

    5. The default container status after running `podman compose --profile all up -d` and `podman ps -a` should resemble the following:

        ```text
        CONTAINER ID  IMAGE                                            COMMAND               CREATED         STATUS                   PORTS       NAMES
        974baf0177f6  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  24 seconds ago  Up 14 seconds (healthy)  8200/tcp    iac-vault-server
        ea3b31db9a5c  localhost/on-premise-iac-controller:qemu-latest  /bin/bash -c whil...  24 seconds ago  Up 14 seconds                        iac-runner
        ```

> [!NOTE]
> **Resolved: Data Loss Warning**
> ~~When switching between Podman container and Native environments, all Libvirt resources provisioned by Terraform will be automatically deleted. This measure prevents permission and context conflicts associated with the Libvirt UNIX socket.~~

### C. Miscellaneous

**Recommended VSCode Plugins:** These extensions provide syntax highlighting for the languages used in this project:

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
> Initialization must be completed in the following order to ensure proper operation of This repo.

0. **Environment Variables File:** `entry.sh` automatically generates a `.env` file for internal shell script use. This file typically requires no manual intervention.
1. **SSH Key Generation:** SSH keys enable automated configuration by allowing services to authenticate with virtual machines during Terraform and Ansible execution. Use option `5` _"Generate SSH Key"_ in `./entry.sh` to create a key pair. The default name is `id_ed25519_on-premise-gitlab-deployment`, and keys are stored in the `~/.ssh/` directory.
2. **Environment Switching:** Option `9` in `./entry.sh` toggles between "Container" and "Native" environments.

    This repo utilizes Podman as the container runtime to prevent SELinux permission conflicts. On systems with SELinux enabled (e.g., Fedora, RHEL, CentOS Stream), Docker containers run within the `container_t` domain by default. In such environments, the SELinux policy prohibits `container_t` from connecting to the `virt_var_run_t` UNIX socket, even if `/var/run/libvirt/libvirt-sock` is correctly mounted with `0770` permissions and proper group ownership. This results in **Permission denied** errors for `virsh` or the Terraform libvirt provider.

    Conversely, the process context (`task_struct`) of rootless Podman is typically the user's `unconfined_t` or a similar SELinux type, rather than being restricted to `container_t`. Therefore, assuming the user is a member of the `libvirt` group, connection to the `libvirt` socket proceeds successfully without additional SELinux policy adjustments. If Docker must be used, alternative workarounds include disabling SELinux (not recommended), implementing custom SELinux modules, or enabling TCP connections for `libvirtd` at the cost of reduced security.

### Step B. Set up Variables

#### **Step B.0. Examine the Permissions of Libvirt**

> [!NOTE]
> Incorrect Libvirt file permissions will directly obstruct the [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest). The following permission checks should be performed before proceeding.

1. Ensure the user account is a member of the `libvirt` group.

    ```shell
    sudo usermod -aG libvirt $(whoami)
    ```

    A full logout and login, or a system reboot, is required for the group membership changes to take effect in the current shell session.

2. Modify the `libvirtd` configuration to delegate socket management to the `libvirt` group.

    ```shell
    # Using Vim
    sudo vim /etc/libvirt/libvirtd.conf

    # Using Nano
    sudo nano /etc/libvirt/libvirtd.conf
    ```

    Uncomment the following lines within the file:

    ```toml
    unix_sock_group = "libvirt"
    # ...
    unix_sock_rw_perms = "0770"
    ```

3. Override the systemd socket unit settings, as systemd configurations take precedence over `libvirtd.conf`.
    1. Open the systemd editor for the socket unit:

        ```shell
        sudo systemctl edit libvirtd.socket
        ```

    2. Insert the following configuration above the `### Edits below this comment will be discarded` line to ensure the settings are applied:

        ```toml
        [Socket]
        SocketGroup=libvirt
        SocketMode=0770
        ```

    Save and exit the editor (Press `Ctrl+O`, `Enter`, then `Ctrl+X` in Nano).

4. Restart the services in the following order to apply the changes.
    1. Reload the `systemd` manager configuration:

        ```shell
        sudo systemctl daemon-reload
        ```

    2. Stop all `libvirtd` related services to ensure a clean transition:

        ```shell
        sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
        ```

    3. Disable `libvirtd.service` to delegate service management to systemd socket activation:

        ```shell
        sudo systemctl disable libvirtd.service
        ```

    4. Restart the `libvirtd.socket`:

        ```shell
        sudo systemctl restart libvirtd.socket
        ```

5. Verification.
    1. Inspect the socket permissions; the output should indicate the `libvirt` group and `srwxrwx---` permissions.

        ```shell
        ls -la /var/run/libvirt/libvirt-sock
        ```

    2. Execute the `virsh` command as a non-root user:

        ```shell
        virsh list --all
        ```

Successful execution and the display of virtual machines—regardless of whether the list is empty—confirms that permissions are correctly configured.

#### **Step B.1. Prepare GitHub Credentials for Self-Management**

> [!NOTE]
> This repo utilizes [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) by default for repository management. Consequently, a Fine-grained Personal Access Token must be configured. If the cloned repo is not managed via this integration, the `terraform/layers/90-github-meta` layer may be skipped or deleted without affecting subsequent operations.

1. Navigate to [GitHub Developer Settings](https://github.com/settings/personal-access-tokens) to generate a Fine-grained Personal Access Token.
2. Click `Generate new token` and specify the token name, expiration period, and repository access scope.
3. In the Permissions section, configure the following:

    | Permission                     | Access Level   | Description                               |
    | ------------------------------ | -------------- | ----------------------------------------- |
    | Metadata                       | Read-only      | Mandatory                                 |
    | Administration                 | Read and Write | For modifying Repo settings and Rulesets  |
    | Contents                       | Read and Write | For reading Ref and Git information       |
    | Repository security advisories | Read and Write | For managing security advisories          |
    | Dependabot alerts              | Read and Write | For managing dependency alerts            |
    | Secrets                        | Read and Write | (Optional) for managing Actions Secrets   |
    | Variables                      | Read and Write | (Optional) for managing Actions Variables |
    | Webhooks                       | Read and Write | (Optional) for managing Webhooks          |

4. Click `Generate token` and save the value for the following steps.

#### **Step B.2. Create Confidential Variable File for HashiCorp Vault**

> [!IMPORTANT]
> **Confidential data is centralized within HashiCorp Vault and categorized into Development and Production modes. This repo default setup uses HTTPS secured by a self-signed CA. Follow these steps for correct configuration.**

0. **Bootstrapper Vault is a prerequisite for establishing Production Vault. Bootstrapper Vault serves exclusively to provision Prod Vault and Packer Images; thereafter, all sensitive project data is managed by Prod Vault.**
1. Execute `entry.sh` and select option `1` to generate the required TLS handshake files. Fields may be left blank when creating the self-signed CA. If TLS file regeneration is required, execute option `1` again.
2. Navigate to the project root and execute the following command to start Bootstrapper Vault server. This repo defaults to running Vault in sidecar mode within the container:

    ```shell
    podman compose up -d iac-vault-server
    ```

    Upon initialization, Bootstrapper Vault generates `vault.db` and Raft-related files in `vault/data/`. To recreate Bootstrapper Vault, all files within `vault/data/` and `vault/keys/` must be manually deleted. Open a new terminal window or tab for subsequent operations to prevent environment variable conflicts in the current shell session.

3. After completing previous steps, execute `entry.sh` and select option `2` to initialize Bootstrapper Vault. This process also automatically performs unseal operation.
4. Manually update the following variables. All default passwords must be replaced with unique values to ensure security.
    - **Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate data exposure. Refer to Note 0 for details.**
    - **For Bootstrapper Vault**
        - The following variables are required for provisioning production HashiCorp Vault across Packer and Terraform Layer `10`:
            - `github_pat`: The GitHub Personal Access Token obtained in previous step.
            - `ssh_username`, `ssh_password`: Credentials for SSH access.
            - `vm_username`, `vm_password`: Credentials for virtual machine.
            - `ssh_public_key_path`, `ssh_private_key_path`: Paths to SSH public and private keys on host.

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

        If `90-github-meta` is not used to manage GitHub repo settings, `github_pat` secret can be deleted.

    - **For Production Vault**
        - Following variables are required for provisioning Terraform layers for Patroni, Sentinel, MinIO (S3), Harbor, and GitLab clusters:
            - `ssh_username`, `ssh_password`: SSH login credentials.
            - `vm_username`, `vm_password`: Virtual machine login credentials.
            - `ssh_public_key_path`, `ssh_private_key_path`: Paths to SSH public and private keys on host machine.
            - `pg_superuser_password`: Password for PostgreSQL superuser (`postgres`). Required for database initialization (`initdb`), Patroni management operations, and manual maintenance tasks.
            - `pg_replication_password`: Credentials for streaming replication user. Patroni utilizes this password when provisioning standby nodes to enable WAL synchronization with primary.
            - `pg_vrrp_secret`: VRRP authentication key for Keepalived nodes. Ensures that only authorized nodes participate in Virtual IP (VIP) election and failover, mitigating malicious interference within local network.
            - `redis_requirepass`: Authentication password for Redis clients. All clients connecting to Redis, such as GitLab or Harbor, must authenticate via `AUTH` command using this password.
            - `redis_masterauth`: Authentication password used by Redis replicas to synchronize with master. During failover, new replicas utilize this password for handshakes with newly promoted master. This is typically set identical to `redis_requirepass` to ensure seamless replication in Sentinel + HA configurations.
            - `redis_vrrp_secret`: VRRP authentication key for Redis load balancing layer (HAProxy/Keepalived). Follows same operational principle as `pg_vrrp_secret`.
            - `minio_root_user`: MinIO root administrator account (formerly Access Key), used for MinIO Console access and managing buckets or policies via MinIO Client (`mc`).
            - `minio_root_password`: MinIO root administrator password (formerly Secret Key).
            - `minio_vrrp_secret`: VRRP authentication key for MinIO load balancing layer (HAProxy/Keepalived). Follows same operational principle as `pg_vrrp_secret`.
            - `vault_haproxy_stats_pass`: Password for HAProxy Stats Dashboard (typically on port `8404`), used for monitoring backend server health and traffic statistics via Web UI.
            - `vault_keepalived_auth_pass`: VRRP authentication key for Vault cluster load balancer to secure Vault service VIP.
            - `harbor_admin_password`: Default password for Harbor Web Portal `admin` account, required for initial project creation and robot account configuration.
            - `harbor_pg_db_password`: Dedicated password for Harbor services (Core, Notary, Clair) to connect to PostgreSQL. This application-level credential (assigned to `harbor` DB user) is restricted with fewer privileges than `pg_superuser_password`.

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

    - **Note 0. Security Notice**: Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate sensitive data exposure.
    - **Note 1. How to retrieve secrets**
        1. Use following command to retrieve credentials from Vault. For example, to fetch PostgreSQL superuser password:

            ```shell
            export VAULT_ADDR="https://172.16.136.250:443"
            export VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt"
            export VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) \
                vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials)
            vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases
            ```

        2. To prevent exposing secrets in shell output:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)
            ```

        3. For a more streamlined execution using a single-line command:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt" VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)
            ```

            `echo` command can be used for verification. Same procedure applies to Bootstrapper Vault and other secrets.

            This command is used when `OpenSSL::Cipher::CipherError` occurs during GitLab deployment. Please refer to [L50 README](terraform/layers/50-platform-gitlab/README.md) for detailed explanation.

    - **Note 2**:

        _For reference only as passwords are already combined into a single-line command_

        `ssh_username` and `ssh_password` refer to credentials for virtual machine access. `ssh_password_hash` is hashed value required by cloud-init for automated installation, derived from `ssh_password` string. For instance, if password is `HelloWorld@k8s`, generate hash using:

        ```shell
        printf '%s' "HelloWorld@k8s" | openssl passwd -6 -stdin
        ```

        - If "command not found" error occurs for `openssl`, ensure `openssl` package is installed.
        - `ssh_public_key_path` should point to filename of previously generated **public key** (typically in `*.pub` format).

    - **Note 3**:

        SSH identity variables (`ssh_`) are primarily utilized in Packer for one-time provisioning, whereas VM identity variables (`vm_`) are used by Terraform during VM cloning. Both may be set to identical values. While it is possible to configure unique credentials for different VMs by modifying `ansible_runner.vm_credentials` variable and implementing `for_each` loops in HCL, this approach introduces unnecessary complexity. Unless specific requirements dictate otherwise, maintaining identical values for SSH and VM identity variables is recommended.

5. Vault must be unsealed after every startup in This repo. Following options are available:
    - Option `3` in `entry.sh` unseals Bootstrapper Vault, using `vault_dev_unseal_handler()` shell function.
    - Option `4` in `entry.sh` unseals Production Vault via `90-operation-vault-unseal.yaml` Ansible playbook.

    Alternatively, containerized approach described in B.1-2 is more streamlined.

6. **UPDATE**: The following has been integrated into `40-provision-harbor-bootstrapper-frontend` via the Ansible Provider. Executing `terraform apply` automates the requirements described below.

    Since Helm Charts related to Layer 50 consistently utilize OCI to connect with Bootstrapper Harbor, it is necessary to first `helm pull` the relevant artifacts from remote repositories and push them to Bootstrapper Harbor. Ensure that `30-infra-harbor-bootstrapper-frontend` and `40-provision-harbor-bootstrapper-frontend` have been executed successfully.

    Once it is confirmed that the Bootstrapper Harbor related L30 and L40 have been executed, you can directly run the following commands (This will be integrated into L40 triggered by Ansible Provider):
    1. **Environment Variables and Login**

        ```bash
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_SKIP_VERIFY=true

        ROLE_ID=$(sudo cat /etc/vault.d/approle/role_id)
        SECRET_ID=$(sudo cat /etc/vault.d/approle/secret_id)

        export HARBOR_REGISTRY="harbor-bootstrapper.production.iac.local"
        export VAULT_TOKEN=$(vault write -field=token auth/workload-approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
        vault kv get -field=password_pusher secret/on-premise-gitlab-deployment/harbor-bootstrapper/robot | \
        helm registry login "$HARBOR_REGISTRY" -u 'robot$helm-charts+helm-pusher' --password-stdin
        ```

    2. Pull relevant Helm Charts for this project; these are the versions currently in use:

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

    3. Push the retrieved artifacts to the `helm-charts` (default) Proxy Project:

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

    4. Subsequently, Layer 50 Helm Charts can be executed.

> [!NOTE]
> To use remote sources, typically the `repository` and `chart` information for each Helm Chart Module in the `terraform/modules/kubernetes-addons` path must be configured. Refer to the [code record](https://github.com/csning1998-old/on-premise-gitlab-deployment/tree/018233b3032e517b43e52fc4e17bcd3dde7cf52f/terraform/modules/kubernetes-addons) from #96.

#### **Step B.3. Understand the Metadata:**

> [!TIP]
> **Layer 00 (Foundation Metadata)** is the "Infrastructure Metadata Repository" and Single Source of Truth (SSoT) for the entire project.

Before proceeding with any provisioning, it is essential to understand the primary functions of Layer `00`. This layer does not create any virtualization resources but is responsible for calculating:

1. **Global Naming Definitions**: Translates abstract `service_catalog` into specific component identifiers such as `cluster_name`, `storage_pool_name`, ensuring naming consistency.
2. **Automated Network Allocation**: Automatically calculates subnets, VIPs (`.250`), gateways, and host IP ranges for each service based on `cidr_index`. A `validation` mechanism is included to prevent IP conflicts from manual allocation.
3. **Deterministic Connection Attributes**: Generates fixed MAC addresses and DNS SANs for each VM. This ensures that physical characteristics and TLS certificate identification remain persistent even if resources are rebuilt.
4. **Cross-Layer Reference Standard**: Enables data-driven deployment via `terraform_remote_state` for all subsequent layers (e.g., `30-infra-xxx`).

#### **Step B.4. Create Variable File for Terraform:**

> [!NOTE]
> These variable files define configuration for cluster provisioning.

1. Initialize required `.tfvars` files by copying examples for each layer:

    ```shell
    for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
    ```

    1. For High Availability (HA) configurations:
        - Services such as Vault (Production mode), Patroni (including etcd), Sentinel, MicroK8s (Harbor), and Kubeadm Master (GitLab) must follow odd-node configuration (`n % 2 != 0`).
        - MinIO Distributed requires node count divisible by four (`n % 4 == 0`).
    2. Static IPs assigned during node provisioning must align with designated host-only network subnet.

2. This project utilizes Ubuntu Server 24.04.3 LTS (Noble) as default Guest OS.
    - Latest release: <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/>
    - Specific version tested: <https://old-releases.ubuntu.com/releases/noble/>
    - Ensure checksum verification after downloading:
        - Latest Noble: <https://releases.ubuntu.com/noble/SHA256SUMS>
        - Old-release Noble: <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

    Support for additional Linux Guest OS such as Fedora 43 or RHEL 10 is planned.

3. **Independent Testing and Development**:
    - Use menu option `7) Build Packer Base Image` to generate base images.
    - **[Note]**: The `Provision Terraform Layer` interactive menu has been removed. Please manually navigate to the `terraform/layers/` directories and execute `tofu apply` for deployment.

        Occasionally, when rebuilding Harbor in Layer 60, a `module.harbor_system_config.harbor_garbage_collection.gc` "Resource not found" error may occur. Resolved by removing `terraform.tfstate` and `terraform.tfstate*.backup` from `terraform/layers/60-provision-harbor` before re-executing `tofu apply`.

4. **Resource Cleanup**:
    - **`10) Purge All Packer Artifacts`**: Specifically cleans up all Packer-generated images, resetting the Packer state.
    - **`11) Purge All Infrastructure Resources (Libvirt + Terraform)`**: Bundles the destruction of Libvirt virtualization resources with the cleanup of Terraform state files, ensuring the environment is completely reset.

> [!NOTE]
> The following content uses `tofu` as the main command. For users who are using `terraform`, just replace `tofu` with `terraform` accordingly.

#### **Step B.5. Vault PKI Certificate Rotation Rules:**

Configuration related to Vault PKI Rotation:

1.  **Infrastructure Root CA**: Defined in L00 and generated by `tls_self_signed_cert`. The default expiration is 1 year. It is specifically used for the HTTPS interfaces of the Central Load Balancer and the Vault server itself. In principle, the Root CA **does not perform automatic rotation**, as it would create an idempotent invalid loop.

2.  **Service Root CA**: Defined in L25 via the Vault PKI Engine (`pki/prod`) with `type = "internal"`. It is used for TLS / mTLS communication between all internal services, including Postgres, Redis, MinIO, Harbor, and GitLab. If the Root CA needs to be replaced, execute the following command in the `terraform/layers/25-security-pki` directory:

    ```shell
    tofu apply -replace="module.vault_pki_setup.vault_pki_secret_backend_root_cert.prod_root_ca" -auto-approve
    ```

3.  **Leaf Certificate Rotation**: Leaf certificates are determined by `max_lease_ttl_seconds` in L25 `terraform.tfvars`. Among these, Postgres, Redis, MinIO, and Bootstrapper Harbor are deployed with **Vault Agent** for sidecar rotation. The Vault Agent automatically requests a new certificate from Vault before the existing one expires and writes it to the internal `/etc/vault.d/` path.

#### **Step B.6. Provision the GitHub Repository with Terraform:**

> [!NOTE]
> If this repository is cloned for personal use, this step can be manually performed by navigating to the `terraform/layers/90-github-meta` directory and executing `tofu apply`. Following instructions detail the manual procedure for reference:

1. Use the Shell Bridge Pattern to inject the Token from Vault. Execute this in the project root to ensure `${PWD}` points to the correct Vault certificate path.

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/project_meta)
    ```

2. Since the repository already exists, it must be imported before the first execution of the governance layer:

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. Initialization and Import
    - **Scenario A (Repository already exists):** When managing an existing repository (such as This repo), the import operation is **mandatory**.
    - **Scenario B (New Repository):** When creating a new repository from scratch, the import step can be bypassed.

    ```shell
    tofu init
    tofu import github_repository.this on-premise-gitlab-deployment
    ```

4. Apply Ruleset: It is recommended to execute `tofu plan` to preview changes before applying:

    ```shell
    tofu apply -auto-approve
    ```

    The output should look similar to:

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

#### **Step B.7. Export Certs of Services:**

Exporting service certificates allows users to browse the following services directly from the Host side without certificate errors:

- Prod Vault: `https://vault.production.iac.local`
- Harbor: `https://harbor.production.iac.local`
- Harbor MinIO Console: `https://minio.harbor.production.iac.local`
- GitLab: `https://gitlab.production.iac.local`
- GitLab MinIO Console: `https://minio.gitlab.production.iac.local`

This requires two steps in sequence:

1.  Handle DNS resolution in `/etc/hosts` by adding the following content (default for this repo) to the host's `/etc/hosts`. Note that this should be adjusted according to the actual IPs output by Terraform.

    ```text
    172.16.126.250  gitlab.production.iac.local
    172.16.131.250  harbor.production.iac.local notary.harbor.production.iac.local
    172.16.136.250  vault.production.iac.local
    172.16.135.250  minio.harbor.production.iac.local core-harbor-minio.production.iac.local
    172.16.130.250  minio.gitlab.production.iac.local core-gitlab-minio.production.iac.local
    ```

2.  Since this repo has already aggregated the Infrastructure CA and Service CA into a single `trust-bundle.crt` in L25, the Host can trust these two independent certificate roots simultaneously. Refer to the content of _Step B.5_. The aggregated certificate file can now be confirmed in the `terraform/layers/25-security-pki/tls/` path.

    Execute the following command to import both CAs into the operating system:
    - **RHEL / CentOS / Fedora:**

        ```bash
        sudo cp terraform/layers/25-security-pki/tls/trust-bundle.crt /etc/pki/ca-trust/source/anchors/on-premise-gitlab-pki-bundle.crt
        sudo update-ca-trust
        ```

    - **Ubuntu / Debian:**

        ```shell
        sudo cp terraform/layers/25-security-pki/tls/trust-bundle.crt /usr/local/share/ca-certificates/on-premise-gitlab-pki-bundle.crt
        sudo update-ca-certificates
        ```

3.  Verify the Trust Store configuration by testing connectivity to MinIO from the host. This mainly verifies that the host trusts the Service CA. For example:

    ```shell
    curl -I https://minio.harbor.production.iac.local:9000/minio/health/live
    ```

    If it outputs `HTTP/1.1 200 OK`, it means the Trust Store is correctly configured.

4.  Access Harbor from the host to verify the Trust Store:

    ```shell
    curl -vI https://harbor.production.iac.local
    ```

    If it displays `SSL certificate verify ok` and `HTTP/2 200`, it means the full PKI Chain—spanning Vault certificate issuance, cert-manager signing, Ingress deployment, and host-level trust—is successfully established.

5.  Another verification method is directly through the GUI to access the corresponding locations.

## Section 3. System Architecture

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, it automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

### A. Deployment Workflow

The automated deployment process is divided into the following stages. Deployment sequence and dependencies strictly follow internal system logic:

1. Foundation Libvirt resources, networking, and secret management:

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

2. Policy-Based Routing (PBR) overview on the Central LB:

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

3. Application deployment dependencies:

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

The cluster establishing in This repo refers to following articles:

> [!NOTE]
> Procedures derived directly from official documentation are omitted from the list below.
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Aditi Sangave (2025). [_How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._](https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft) Velotio Tech Blog.
> 3. Dickson Gathima (2025). [_Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 4. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning — Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.

_**(To be continued...)**_
