# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.

## Section 0. Introduction

This repository (hereinafter referred to as "this repo") is a Proof of Concept (PoC) for Infrastructure as Code. It primarily achieves automated deployment of a High Availability (HA) Kubernetes cluster (Kubeadm / microk8s) in a purely on-premise environment using QEMU-KVM. This repo was developed based on personal exercises conducted during an internship at Cathay General Hospital. The objective is to establish an on-premise GitLab instance capable of automated infrastructure deployment, with the aim of creating a reusable IaC pipeline for legacy systems.

> [!NOTE]
> This repo has been approved for public release by the relevant company department as part of a technical portfolio.

The machine specifications used for development are listed below for reference only:

- **Chipset:** Intel® HM770
- **CPU:** Intel® Core™ i7 processor 14700HX
- **RAM:** Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
- **SSD:** WD PC SN560 SDDPNQE-1T00-1032

The project can be cloned using the following command:

```shell
git clone -b v1.6.0 --depth 1 https://github.com/csning1998-old/on-premise-gitlab-deployment.git
```

The following resource allocation is configured based on RAM constraints:

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

- Linux host (RHEL 10 or Ubuntu 24 recommended).
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
5. Harbor Container Registry.
6. **[WIP]** GitLab / Runner / Gitaly etc.
7. Private Key Encryption.
8. [OpenTofu](https://github.com/opentofu/opentofu.git) Migration for the feature of `*.tfstate` files encryption.

### D. The Entrypoint: `entry.sh`

> [!NOTE]
> Section 1 and Section 2 cover the pre-execution setup tasks. See below for details.

The `entry.sh` script located in the root directory handles all service initialization and lifecycle management. Executing `./entry.sh` from the repo root displays the following interface:

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

Options `9`, `10`, and `11` dynamically populate submenus by scanning the `packer/output` and `terraform/layers` directories. The submenus for a complete configuration are shown below:

> [!NOTE]
> Option `11` is currently mulfunctioning.

1. When selecting `9) Build Packer Base Image`.

    ```text
    [INPUT] Please select an action: 9
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.

    1) 01A-docker-harbor          4) 04-base-postgres          7) 07-base-vault            10) Build ALL Packer Images
    2) 02-base-kubeadm            5) 05-base-redis             8) 08-base-haproxy          11) Back to Main Menu
    3) 03-base-microk8s           6) 06-base-minio             9) 09-base-etcd

    [INPUT] Select a Packer build to run:
    ```

2. When selecting `10) Provision Terraform Layer`.

    ```text
    [INPUT] Please select an action: 10
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.
    1) 10-vault-raft         4) 30-gitlab-minio      7) 30-harbor-minio     10) 40-gitlab-kubeadm   13) 50-harbor-platform  16) 90-github-meta
    2) 20-vault-pki          5) 30-gitlab-postgres   8) 30-harbor-postgres  11) 40-harbor-microk8s  14) 60-gitlab-service   17) Back to Main Menu
    3) 30-dev-harbor-core    6) 30-gitlab-redis      9) 30-harbor-redis     12) 50-gitlab-platform  15) 60-harbor-service

    [INPUT] Select a Terraform layer to REBUILD:
    ```

3. When selecting `11) Rebuild Layer via Ansible`.

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

The following sections detail the usage instructions for `entry.sh`.

## Section 1. Environmental Setup

### A. Required. KVM / QEMU

Option `6` in `entry.sh` automates the installation of the QEMU/KVM environment. This process is currently tested only on Ubuntu 24 and RHEL 10. For other platforms, refer to official documentation to manually configure the KVM and QEMU environment.

### B. Option 1. Install IaC tools on Native

1. **Install HashiCorp Toolkit - Terraform and Packer**

    Execute `entry.sh` in the project root directory and select option `7` "Setup Core IaC Tools for Native" to install Terraform, Packer, and Ansible. Refer to the official installation guides for more details:

    > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_
    > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_
    > _Reference: [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)_

    The expected output should be the latest version. For instance (in zsh):

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

2. Verify that Podman or Docker is correctly installed. The appropriate installation method should be selected based on the host operating system by following the official documentation linked below:

    > _Reference: [Podman Installation](https://podman.io/getting-started/installation)_
    > _Reference: [Docker Installation](https://docs.docker.com/get-docker/)_

3. For Podman-based setups, navigate to the project root directory after the installation:
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
        61be68ae276e  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  15 minutes ago  Up 15 minutes (healthy)  8200/tcp    iac-vault-server
        79b918f440f1  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-base
        0a4eb3495697  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-packer
        482f58b67295  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-terraform
        aa8d17213095  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-ansible
        ```

> [!CAUTION]
> **Data Loss Warning**
> When switching between Podman container and Native environments, all Libvirt resources provisioned by Terraform will be automatically deleted. This measure prevents permission and context conflicts associated with the Libvirt UNIX socket.

### C. Miscellaneous

- **Recommended VSCode Plugins:** These extensions provide syntax highlighting for the languages used in this project:

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
> Initialization must be completed in the following order to ensure proper operation of this repo.

0. **Environment Variables File:** `entry.sh` automatically generates a `.env` file for internal shell script use. This file typically requires no manual intervention.
1. **SSH Key Generation:** SSH keys enable automated configuration by allowing services to authenticate with virtual machines during Terraform and Ansible execution. Use option `5` _"Generate SSH Key"_ in `./entry.sh` to create a key pair. The default name is `id_ed25519_on-premise-gitlab-deployment`, and keys are stored in the `~/.ssh/` directory.
2. **Environment Switching:** Option `13` in `./entry.sh` toggles between "Container" and "Native" environments.

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
> This project utilizes [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) by default for repository management. Consequently, a Fine-grained Personal Access Token must be configured. If the cloned repo is not managed via this integration, the `terraform/layers/90-github-meta` layer may be skipped or deleted without affecting subsequent operations.

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
> Confidential data is centralized within HashiCorp Vault and categorized into Development and Production modes. By default, the Vault instances in this repo utilize HTTPS secured by a self-signed CA. Follow these steps for correct configuration.

0. **The Development Vault is a prerequisite for establishing the Production Vault. The Dev Vault serves exclusively to provision the Prod Vault and Packer images; thereafter, all sensitive project data is managed by the Prod Vault.**
1. Execute `entry.sh` and select option `1` to generate the required TLS handshake files. Fields may be left blank when creating the self-signed CA. If TLS file regeneration is required, execute option `1` again.
2. Navigate to the project root and execute the following command to start the Development Vault server. This repo defaults to running Vault in sidecar mode within the container:

    ```shell
    podman compose up -d iac-vault-server
    ```

    Upon initialization, the Dev Vault generates `vault.db` and Raft-related files in `vault/data/`. To recreate the Dev Vault, all files within `vault/data/` must be manually deleted. Open a new terminal window or tab for subsequent operations to prevent environment variable conflicts in the current shell session.

3. After completing the previous steps, execute `entry.sh` and select option `2` to initialize the Dev Vault. This process also automatically performs the unseal operation.
4. Manually update the following variables. All default passwords must be replaced with unique values to ensure security.
    - Purging sensitive variables from shell history after executing `vault kv put` commands is strongly recommended to mitigate data exposure. Refer to Note 0 for details.
    - For Development Vault
        - The following variables are required for provisioning the production HashiCorp Vault across Packer and Terraform Layer 10:
        - `github_pat`: The GitHub Personal Access Token obtained in the previous step.
        - `ssh_username`, `ssh_password`: Credentials for SSH access.
        - `vm_username`, `vm_password`: Credentials for the virtual machine.
        - `ssh_public_key_path`, `ssh_private_key_path`: Paths to the SSH public and private keys on the host.

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

        If `90-github-meta` is not used to manage GitHub repository settings, the `github_pat` secret can be deleted.

    - **For Production Vault**
        - The following variables are required for provisioning the Terraform layers for Patroni, Sentinel, MinIO (S3), Harbor, and GitLab clusters:
            - `ssh_username`, `ssh_password`: SSH login credentials.
            - `vm_username`, `vm_password`: Virtual machine login credentials.
            - `ssh_public_key_path`, `ssh_private_key_path`: Paths to the SSH public and private keys on the host machine.
            - `pg_superuser_password`: Password for the PostgreSQL superuser (`postgres`). Required for database initialization (`initdb`), Patroni management operations, and manual maintenance tasks.
            - `pg_replication_password`: Credentials for the streaming replication user. Patroni utilizes this password when provisioning standby nodes to enable WAL synchronization with the primary.
            - `pg_vrrp_secret`: VRRP authentication key for Keepalived nodes. Ensures that only authorized nodes participate in Virtual IP (VIP) election and failover, mitigating malicious interference within the local network.
            - `redis_requirepass`: Authentication password for Redis clients. All clients connecting to Redis, such as GitLab or Harbor, must authenticate via the `AUTH` command using this password.
            - `redis_masterauth`: Authentication password used by Redis replicas to synchronize with the master. During failover, new replicas utilize this password for handshakes with the newly promoted master. This is typically set identical to `redis_requirepass` to ensure seamless replication in Sentinel + HA configurations.
            - `redis_vrrp_secret`: VRRP authentication key for the Redis load balancing layer (HAProxy/Keepalived). Follows the same operational principle as `pg_vrrp_secret`.
            - `minio_root_user`: MinIO root administrator account (formerly Access Key), used for MinIO Console access and managing buckets or policies via the MinIO Client (`mc`).
            - `minio_root_password`: MinIO root administrator password (formerly Secret Key).
            - `minio_vrrp_secret`: VRRP authentication key for the MinIO load balancing layer (HAProxy/Keepalived). Follows the same operational principle as `pg_vrrp_secret`.
            - `vault_haproxy_stats_pass`: Password for the HAProxy Stats Dashboard (typically on port `8404`), used for monitoring backend server health and traffic statistics via the Web UI.
            - `vault_keepalived_auth_pass`: VRRP authentication key for the Vault cluster load balancer to secure the Vault service VIP.
            - `harbor_admin_password`: Default password for the Harbor Web Portal `admin` account, required for initial project creation and robot account configuration.
            - `harbor_pg_db_password`: Dedicated password for Harbor services (Core, Notary, Clair) to connect to PostgreSQL. This application-level credential (assigned to the `harbor` DB user) is restricted with fewer privileges than `pg_superuser_password`.

        ```shell
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_CACERT="${PWD}/terraform/layers/10-vault-raft/tls/vault-ca.crt"
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

    - **Note 0. Security Notice**: Clearing the shell history after executing `vault kv put` commands is strongly recommended to mitigate sensitive data exposure.
    - **Note 1. Secret Retrieval**
        1. Use the following command to retrieve credentials from Vault. For example, to fetch the PostgreSQL superuser password:

            ```shell
            export VAULT_ADDR="https://172.16.136.250:443"
            export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
            export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)
            vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases
            ```

        2. To prevent exposing secrets in the shell output, subshells can be utilized:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        3. For a more streamlined execution, use a single-line command:

            ```shell
            export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt" VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
            ```

        The same procedure applies to the Development Vault and other secrets.

    - **Note 2**:

        _For reference only since the passwords are already combined into a single-line command_

        `ssh_username` and `ssh_password` refer to the credentials used for virtual machine access. `ssh_password_hash` is the hashed value required by cloud-init for automated installation, which must be derived from the `ssh_password` string. For instance, if the password is `HelloWorld@k8s`, generate the hash using the following command:

        ```shell
        printf '%s' "HelloWorld@k8s" | openssl passwd -6 -stdin
        ```

        - If a "command not found" error occurs for `openssl`, ensure the `openssl` package is installed.
        - `ssh_public_key_path` should point to the filename of the previously generated public key (typically in `*.pub` format).

    - **Note 3**:

        SSH identity variables (`ssh_`) are primarily utilized in Packer for one-time provisioning, whereas VM identity variables (`vm_`) are used by Terraform during VM cloning. Both may be set to identical values. While it is possible to configure unique credentials for different VMs by modifying the `ansible_runner.vm_credentials` variable and implementing `for_each` loops in the HCL code, this approach introduces unnecessary complexity. Unless specific requirements dictate otherwise, maintaining identical values for SSH and VM identity variables is recommended.

5. In this repo, Vault must be unsealed after every startup. The following options are available:
    - Option `3` in `entry.sh` unseals the Development Vault. This operation is performed by the `vault_dev_unseal_handler()` shell function.
    - Option `4` in `entry.sh` unseals the Production Vault. This is managed via the `90-operation-vault-unseal.yaml` Ansible playbook.

    Alternatively, the containerized approach described in sections B.1 and B.2 provides a more streamlined workflow.

#### **Step B.3. Create Variable File for Terraform:**

> [!NOTE]
> These variable files define the configuration for cluster provisioning.

1. Initialize the required `.tfvars` files by copying the examples for each layer:

    ```shell
    for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
    ```

    1. For High Availability (HA) configurations:
        - Services such as Vault (Production mode), Patroni (including etcd), Sentinel, MicroK8s (Harbor), and Kubeadm Master (GitLab) must follow an odd-node configuration (`n % 2 != 0`).
        - MinIO Distributed requires a node count divisible by four (`n % 4 == 0`).
    2. Static IPs assigned during node provisioning must align with the designated host-only network subnet.

2. This project utilizes Ubuntu Server 24.04.3 LTS (Noble) as the default Guest OS.
    - The latest release is available at: [https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/](https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/).
    - The specific version tested for this project is available at: [https://old-releases.ubuntu.com/releases/noble/](https://old-releases.ubuntu.com/releases/noble/).
    - Ensure checksum verification after downloading:
        - Latest Noble: [https://releases.ubuntu.com/noble/SHA256SUMS](https://releases.ubuntu.com/noble/SHA256SUMS)
        - Old-release Noble: [https://old-releases.ubuntu.com/releases/noble/SHA256SUMS](https://old-releases.ubuntu.com/releases/noble/SHA256SUMS)

    Support for additional Linux distributions, such as Fedora 43 or RHEL 10, is planned for future updates.

3. **Independent Testing and Development**:
    - Use menu option `9) Build Packer Base Image` to generate a base image.
    - Use menu option `10) Provision Terraform Layer` to test or redeploy specific layers (e.g., Harbor, Postgres).

        Note: When rebuilding Harbor in Layer 50, a `module.harbor_system_config.harbor_garbage_collection.gc` "Resource not found" error may occur. This is resolved by removing `terraform.tfstate` and `terraform.tfstate.backup` from `terraform/layers/50-harbor-platform` before re-executing `terraform apply`.

    To test Ansible playbooks on existing hosts without reprovisioning virtual machines, use option `11) Rebuild Layer via Ansible`.

4. **Resource Cleanup**:
    - **`14) Purge All Libvirt Resources`**: Used to clear virtualization resources while maintaining the project state. This executes `libvirt_resource_purger "all"`, which deletes all guest VMs, networks, and storage pools created by this project, while preserving Packer images and Terraform local state files.
    - **`15) Purge All Packer and Terraform Resources`**: Used for a complete cleanup of all artifacts. This deletes all Packer output images and all Terraform local state files, resetting the project environment to a pristine state.

#### **Step B.4. Provision the GitHub Repository with Terraform:**

> [!NOTE]
> For local management of a cloned repository, this step can be automated by selecting `90-github-meta` via option `10) Provision Terraform Layer`. The following instructions detail the imperative manual procedure for reference:

1. Inject the GitHub token from Vault using a shell subquery. Execute this from the project root to verify that `${PWD}` aligns with the Vault credential directory:

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/variables)
    ```

2. Existing repositories must be imported into the Terraform state before the initial execution of the governance layer.

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. Initialization and Import
    - **Scenario A (Existing Repository):** When managing an existing repository (such as this project), the import operation is **mandatory**.
    - **Scenario B (New Repository):** When creating a new repository from scratch, the import step can be bypassed.

    ```shell
    terraform init
    terraform import github_repository.this on-premise-gitlab-deployment
    ```

4. Apply Ruleset: Executing `terraform plan` to preview changes before applying is recommended.

    ```shell
    terraform apply -auto-approve
    ```

    The output should look similar to the following:

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

#### **Step B.5. Export Certs of Services:**

Importing service certificates into the host trust store enables secure access to the following services without triggering browser security warnings:

- Prod Vault: `https://vault.iac.local`
- Harbor: `https://harbor.iac.local`
- Harbor MinIO Console: `https://s3.harbor.iac.local`
- GitLab: `https://gitlab.iac.local` (**WIP**)
- GitLab MinIO Console: `https://s3.gitlab.iac.local` (**WIP**)

Complete the following configuration steps in sequence:

1. Configure DNS resolution by appending the following entries to the host's `/etc/hosts` file. These values must be aligned with the actual static IPs provisioned by Terraform:

    ```text
    172.16.134.250  gitlab.iac.local
    172.16.135.250  harbor.iac.local notary.harbor.iac.local
    172.16.136.250  vault.iac.local
    172.16.139.250  s3.harbor.iac.local
    172.16.142.250  s3.gitlab.iac.local
    ```

2. Establish Host-level Trust (Infrastructure & Service CAs). Since the `tls/` directory is not tracked by git, the Service Root CA should be retrieve from the live Vault server before importing them. Use `curl` to fetch the public key of the Service CA directly from the Vault PKI engine. Using `-k` is required here as the trust chain is not yet established. Set the Vault Address (VIP) and download the Service CA to the local tls directory.

    ```bash
    export VAULT_ADDR="https://172.16.136.250:443"
    curl -k $VAULT_ADDR/v1/pki/prod/ca/pem -o terraform/layers/10-vault-core/tls/vault-pki-ca.crt
    ```

3. **Import BOTH Certificates into System Trust Store:**

    Now there exists two CA files in `terraform/layers/10-vault-core/tls/`:
    - `vault-ca.crt`: The **Infrastructure CA** (generated by Terraform locally).
    - `vault-pki-ca.crt`: The **Service CA** (downloaded from Vault API).

    Execute the import commands based on your OS:
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

4. Verify the trust store configuration by testing connectivity to MinIO. This verifies that the host trusts the "Service CA":

    ```shell
    curl -I https://s3.harbor.iac.local:9000/minio/health/live
    ```

    An `HTTP/1.1 200 OK` response confirms that the trust store is correctly configured.

5. Verify the complete certificate chain by accessing the Harbor interface:

    ```shell
    curl -vI https://harbor.iac.local
    ```

    If the output displays `SSL certificate verify ok` and `HTTP/2 200`, the full PKI chain—spanning Vault issuance, cert-manager signing, Ingress deployment, and host-level trust—is successfully established.

## Section 3. System Architecture

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, it automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

### A. Deployment Workflow

1. **Core Bootstrap Workflow**: The Development Vault centralizes initial secrets management, followed by the provisioning of the Production Vault.

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

2. **Data Services and PKI**: Provisions data services through automated pipelines. MinIO serves as the representative model for these workflows, which follow the same architectural patterns applied to PostgreSQL and Redis.

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

The cluster configurations in this project draw upon the following resources:

> [!NOTE]
> Procedures derived directly from official documentation are omitted from the list below.
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Aditi Sangave (2025). [_How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._](https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft) Velotio Tech Blog.
> 3. Dickson Gathima (2025). [_Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 4. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning — Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.

**_(To be continued...)_**
