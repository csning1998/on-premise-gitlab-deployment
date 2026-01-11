# PoC: Deploy GitLab Helm on HA Kubeadm Cluster using QEMU + KVM with Packer, Terraform, Vault, and Ansible

## Section 0. Introduction

This repository contains an Infrastructure as Code (IaC) Proof of Concept (PoC) utilizing QEMU-KVM to automate the deployment of a High Availability (HA) Kubernetes Cluster (Kubeadm) in an on-premise environment. This project was developed based on the requirements identified during an internship at Cathay General Hospital to automate the foundation for GitLab on-premise, targeting legacy systems with a repeatable and efficient IaC pipeline.

(The repository is hosted publicly here as a technical portfolio, in agreement with the organization.)

The machine specifications used for development are as follows, for reference:

-   **Chipset:** Intel® HM770
-   **CPU:** Intel® Core™ i7 processor 14700HX
-   **RAM:** Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
-   **SSD:** WD PC SN560 SDDPNQE-1T00-1032

The project can be cloned via the following command:

```shell
git clone https://github.com/csning1998/on-premise-gitlab-deployment.git
```

### A. Disclaimer

-   This project currently only works on Linux devices with CPU virtualization support, and has **not yet** been tested on other distros such as Fedora 41, Arch, CentOS, and WSL2.
-   Currently, these features have only been tested on my personal computer through several system reinstallations, so there may inevitably be some functionality issues. I've tried my best to prevent and address these.

### B. Prerequisites

Before beginning, ensure the following requirements are met:

-   A Linux host (RHEL 10 or Ubuntu 24 recommended).
-   A CPU with virtualization support enabled (VT-x or AMD-V).
-   `sudo` access for Libvirt.
-   `podman` and `podman compose` installed (for containerized mode).
-   `whois` package installed (for the `mkpasswd` command).
-   `jq` package for JSON parsing.

### C. Note

This project requires CPU cwith virtualization support. For users whose CPUs don't support virtualization, refer to the `legacy-workstation-on-ubuntu` branch. This has been tested on Ubuntu 24 to achieve the same basic functionality for establishing `kubeadm` cluster. Use the following in shell to check if developing device supports virtualization:

```shell
lscpu | grep Virtualization
```

The output may show:

-   Virtualization: VT-x (Intel)
-   Virtualization: AMD-V (AMD)
-   If there is no output, virtualization might not be supported.

### D. The Entrypoint: `entry.sh`

The content in Section 1 and Section 2 serves as prerequisite setup before formal execution. Project lifecycle management and configuration are handled through the `entry.sh` script in the root directory. The following content is shown after executing `./entry.sh`:

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

Among options `9`, `10`, and `11`, there are submenus. These menus are dynamically created based on the directories under `packer/output` and `terraform/layers`. In the current complete setup, they are:

1. The submenu of selecting `9) Build Packer Base Image`

    ```text
    [INPUT] Please select an action: 9
    [INFO] Checking status of libvirt service...
    [OK] libvirt service is already running.

    1) 01-base-docker           4) 04-base-postgres         7) 07-base-vault
    2) 02-base-kubeadm          5) 05-base-redis            8) Build ALL Packer Images
    3) 03-base-microk8s         6) 06-base-minio            9) Back to Main Menu

    [INPUT] Select a Packer build to run:
    ```

2. The submenu of selecting `10) Provision Terraform Layer`

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

3. The submenu of selecting `11) Rebuild Layer via Ansible`

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

**A description of how to use this script follows below.**

## Section 1. Environmental Setup

### A. Required. KVM / QEMU

The user's CPU must support virtualization technology to enable QEMU-KVM functionality. Choose whether to install it through option `6` via script (but this has only been tested on Ubuntu 24 and RHEL 10), or refer to relevant resources to set up the KVM and QEMU environment, which depends on the development device's platform.

### B. Option 1. Install IaC tools on Native

1. **Install HashiCorp Toolkit - Terraform and Packer**

    Next, install Terraform, Packer, and Ansible by running `entry.sh` in the project root directory and selecting option `7` for _"Setup Core IaC Tools for Native"_. Or alternatively, follow the official installation guide:

    > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_  
    > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_ > _Reference: [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)_

    Expected output should reflect the latest versions. For instance (in `zsh`):

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

2. Please ensure Podman is installed correctly. Refer to the following URL and choose the installation method corresponding to the development device's platform

3. After completing the Podman installation, switch to the project root directory:

    1. Default memlock limit (`ulimit -l`) is usually too low for HashiCorp Vault. Rootless Podman inherits this low limit, causing Vault's mlock system call to fail. To address such issue, modify it by running the following command:

        ```shell
        sudo tee -a /etc/security/limits.conf <<EOT
        ${USER}    soft    memlock    unlimited
        ${USER}    hard    memlock    unlimited
        EOT
        ```

        And then reboot the system to take effect. This prevents sensitive data from being swapped to unencrypted swap space.

    2. If using for the first time, execute the following command

        ```shell
        podman compose up --build
        ```

    3. After creating the Container, it only needs to run the container to perform operations:

        ```shell
        podman compose up -d
        ```

    4. Currently, the default setting is `DEBIAN_FRONTEND=noninteractive`. Execute the following command if modification or examination inside the container is necessary:

        ```shell
        podman exec -it iac-controller-base bash
        ```

        Where `iac-controller-base` is the root Container name for the project.

    5. Default Container output after `podman compose up -d` and `podman ps -a` is akin to the following:

        ```text
        CONTAINER ID  IMAGE                                            COMMAND               CREATED         STATUS                   PORTS       NAMES
        61be68ae276e  docker.io/hashicorp/vault:1.20.2                 server -config=/v...  15 minutes ago  Up 15 minutes (healthy)  8200/tcp    iac-vault-server
        79b918f440f1  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-base
        0a4eb3495697  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-packer
        482f58b67295  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-terraform
        aa8d17213095  localhost/on-premise-iac-controller:qemu-latest  /bin/bash             15 minutes ago  Up 15 minutes                        iac-controller-ansible
        ```

    6. **Attention: When switching between the Podman container and the native environment, ALL the Libvirt resources created by Terraform WILL BE DELETED to avoid conflicts.**

### C. Miscellaneous

-   **Suggested Plugins for VSCode:** Enhance productivity with syntax support:

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

To ensure the project runs smoothly, please follow the procedures below to complete the initialization setup.

0. **Environment variable file:** The script `entry.sh` will automatically create a `.env` environment variable that is used by for script files, which can be ignored.

1. **Generate SSH Key:** During the execution of Terraform and Ansible, SSH keys serve as the mechanism for node access authentication and configuration management. These keys are generated by executing `./entry.sh` and selecting option `5` for _"Generate SSH Key"_. A specific key name may be defined, or the default value `id_ed25519_on-premise-gitlab-deployment` may be applied. The resulting public and private key pair is stored in the `~/.ssh` directory.

2. **Switch Environment:** Environment switching between _"Container"_ and _"Native"_ is available via `./entry.sh` by selecting option `13`. This project primarily utilizes Podman. Decoupling Podman and Docker runtime environments is a documented practice to prevent execution conflicts stemming from SELinux-related permissions. For instance, SELinux policies restrict a `container_t` process (standard in Docker) from connecting to a `virt_var_run_t` Socket. Such restrictions can result in "Permission Denied" errors for the Terraform Provider or `virsh` when executed within containers, despite correct filesystem permissions.

### Step B. Set up Variables

#### **Step B.0. Examine the Permissions of Libvirt**

Libvirt's settings directly impact Terraform's execution permissions, thus some permission checks are required.

1. Ensure the user's account is a member of the `libvirt` group.

    ```shell
    sudo usermod -aG libvirt $(whoami)
    ```

    **Note:** Upon completion of this step, a full logout and login or a system restart is required for the new group membership to take effect within the shell session.

2. Modify the `libvirtd` configuration file to explicitly state that the `libvirt` group should manage the socket.

    ```shell
    # If vim is preferred
    sudo vim /etc/libvirt/libvirtd.conf

    # If nano is preferred
    sudo nano /etc/libvirt/libvirtd.conf
    ```

    Locate and uncomment (remove the `#` from the beginning of the line) the following two lines.

    ```toml
    unix_sock_group = "libvirt"
    # ...
    unix_sock_rw_perms = "0770"
    ```

3. Override the `systemd` socket unit settings, as `systemd`'s socket configuration takes precedence over `libvirtd.conf`.

    1. Executing the following command will open a `nano` editor.

        ```shell
        sudo systemctl edit libvirtd.socket
        ```

    2. In the opened editor, paste the following content. Make sure to paste it above the line that says `### Edits below this comment will be discarded` to prevent the configuration file from becoming invalid.

        ```toml
        [Socket]
        SocketGroup=libvirt
        SocketMode=0770
        ```

        Once done, use `Ctrl+O` to save and `Ctrl+X` to exit the editor.

4. Now, the services need to be restarted in the correct order for all the settings to take effect.

    1. Reload `systemd` configurations:

        ```shell
        sudo systemctl daemon-reload
        ```

    2. Stop all related services to ensure a clean state:

        ```shell
        sudo systemctl stop libvirtd.service libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket
        ```

    3. Disable `libvirtd.service` to fully hand over management to Socket Activation:

        ```shell
        sudo systemctl disable libvirtd.service
        ```

    4. Restart `libvirtd.socket`

        ```shell
        sudo systemctl restart libvirtd.socket
        ```

5. Verification

    1. Check the socket permissions: The output should show the group as `libvirt` and the permissions as `srwxrwx---`.

        ```shell
        ls -la /var/run/libvirt/libvirt-sock
        ```

    2. Execute `virsh` commands as a **non-root** user.

        ```shell
        virsh list --all
        ```

        Successful execution of the command and the subsequent listing of virtual machines (regardless of whether the list is empty) indicates that all necessary permissions are present.

#### **Step B.1. Prepare GitHub Credentials**

**Note:** This project defaults to using Terraform to manage GitHub's Repository, so a Fine-grained Personal Access Token is required. skip or delete `terraform/layers/90-github-meta` if the user who cloned this project does not use Terraform to manage GitHub's Repository.

1. Visit [GitHub Developer Settings](https://github.com/settings/personal-access-tokens) to apply for a Fine-grained Personal Access Token.

2. Select the `Generate new token` button on the upper-right corner of the page, then set the Token name, Expiration, and Repository access.

3. For the Permissions section, select the following permissions:

    - **Metadata:** `Read-only` (Mandatory)
    - **Administration:** `Read and Write` (for modifying Repo settings and Ruleset)
    - **Contents:** `Read and Write` (for reading Ref and Git information)
    - **Repository security advisories:** `Read and Write` (for managing security advisories)
    - **Dependabot alerts:** `Read and Write` (for managing dependency alerts)
    - **Secrets:** `Read and Write` (optional for managing Actions Secrets)
    - **Variables:** `Read and Write` (optional for managing Actions Variables)
    - **Webhooks:** `Read and Write` (optional for managing Webhooks)

4. Click `Generate token` and copy the generated token. Preserve this for the next step.

#### **Step B.2. Create Confidential Variable File for HashiCorp Vault**

> _**All secrets will be integrated into HashiCorp Vault with Development mode and Production mode. This project defaults to using Vault with HTTPS configuration, and the certificate is self-signed. Please follow the steps below to ensure correct setup.**_

0. **Development mode is the previous stage of Production Vault, only used to set up Production Vault. Subsequently, the Production Vault is used for managing all sensitive data for the entire project.**

1. First, run the `entry.sh` script and select option `1` to generate the files required for the TLS handshake. During the creation of the self-signed CA certificate, fields may be left blank. If regeneration of TLS files is necessary, option `1` may be executed again.

2. Switch to the project's root directory and run the following command to start the Development mode Vault server.

    - If running it on the host is preferred:

        ```shell
        vault server -config=vault/vault.hcl
        ```

    - **(Recommended)** If running it in a container (side-car mode) is preferred:

        ```shell
        podman compose up -d iac-vault-server
        ```

    After starting the server, Vault will create `vault.db` and Raft-related files in the `vault/data/` directory. If reinitialization of Vault is necessary, all files within the `vault/data/` directory must be manually cleared.

    **Note:** Please open a new terminal window or tab for subsequent operations.

3. Once the previous steps are complete, run `entry.sh` and select option `2` to initialize Vault. This process will also automatically perform the required unseal action for Vault.

4. Next, only the following variables used in the project require manual modification. Passwords must be replaced with unique values to ensure security.

    - **For Development Vault**

        - The following variables are used for packer and bootstrapping production HashiCorp Vault in Terraform Layer `10`.

            - `github_pat`: GitHub Personal Access Token obtained from the previous step.
            - `ssh_username`, `ssh_password`: SSH Username and Password
            - `vm_username`, `vm_password`: VM Username and Password
            - `ssh_public_key_path`, `ssh_private_key_path`: SSH Public and Private Key Path located in the host.

        ```shell
        export VAULT_ADDR="https://127.0.0.1:8200"
        export VAULT_CACERT="${PWD}/vault/tls/ca.pem"
        export VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt)
        vault secrets enable -path=secret kv-v2
        ```

        ```shell
        vault kv put \
            secret/on-premise-gitlab-deployment/variables \
            github_pat="your-github-personal-access-token" \
            ssh_username="some-user-name-for-ssh" \
            ssh_password="some-user-password-for-ssh" \
            ssh_password_hash=$(echo -n "$ssh_password" | mkpasswd -m sha-512 -P 0) \
            vm_username="some-user-name-for-vm" \
            vm_password="some-user-password-for-vm" \
            ssh_public_key_path="~/.ssh/some-ssh-key-name.pub" \
            ssh_private_key_path="~/.ssh/some-ssh-key-name"
        ```

    - **For Production Vault**

        - The following variables are used for bootstrapping Terraform Layer of Patroni / Sentinel / MinIO (S3) / Harbor / GitLab Clusters.

            - `ssh_username`, `ssh_password`: SSH login credentials.
            - `vm_username`, `vm_password`: Virtual Machine login credentials.
            - `ssh_public_key_path`, `ssh_private_key_path`: Local paths on the host machine for the SSH public and private keys.
            - `pg_superuser_password`: Password for the PostgreSQL superuser (`postgres`). Used for initial database creation (`initdb`), Patroni management operations, and manual database maintenance.
            - `pg_replication_password`: Password for the Streaming Replication User. When Patroni establishes a standby node, the standby node uses this password to connect to the primary node for Write-Ahead Log (WAL) synchronization.
            - `pg_vrrp_secret`: VRRP (Virtual Router Redundancy Protocol) authentication key for Keepalived nodes. Ensures only authorized nodes participate in Virtual IP (VIP) election and failover, preventing malicious interference within the local network.
            - `redis_requirepass`: Redis client authentication password. Required by any client (e.g., GitLab, Harbor) connecting to Redis to access data via the `AUTH` command.
            - `redis_masterauth`: Authentication password used by Redis replicas to connect to the master node for synchronization. During failover, the new replica uses this password for the handshake with the promoted master. This is typically identical to `redis_requirepass` for simplified management.
            - `redis_vrrp_secret`: VRRP authentication key for the Redis load balancing layer (HAProxy/Keepalived). Operates on the same principle as `pg_vrrp_secret`.
            - `minio_root_user`: MinIO root administrator account (formerly Access Key). Used for logging into the MinIO Console or managing buckets and policies via the MinIO Client (`mc`).
            - `minio_root_password`: MinIO root administrator password (formerly Secret Key).
            - `minio_vrrp_secret`: VRRP authentication key for the MinIO load balancing layer (HAProxy/Keepalived). Operates on the same principle as `pg_vrrp_secret`.
            - `vault_haproxy_stats_pass`: Login password for the HAProxy Stats Dashboard. Protects the Web UI (typically on port 8404) that displays backend server health status and traffic statistics.
            - `vault_keepalived_auth_pass`: VRRP authentication key for the Vault cluster load balancers, used to secure the Vault service VIP.
            - `harbor_admin_password`: Default password for the Harbor Web Portal `admin` account. Used for the initial login to Harbor to create projects and set up robot accounts after deployment.
            - `harbor_pg_db_password`: Dedicated password for Harbor services (Core, Notary, Clair) to connect to the PostgreSQL database. This is an application-level password (typically for DB user `harbor`) with lower privileges than `pg_superuser_password`.

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

    - **Note 0:**

        Use the following command to fetch the confidential information from the vault. For instance, to fetch the superuser password of PostgreSQL, use the following command with the environment variables for production vault and the following command:

        ```shell
        export VAULT_ADDR="https://172.16.136.250:443"
        export VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt"
        export VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json)

        vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases
        ```

        To prevent the secret from being exposed, the following command can be used:

        ```shell
        export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
        ```

        Single line command is used if keeping the shell environment clean is required:

        ```shell
        export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/10-vault-core/tls/vault-ca.crt" VAULT_TOKEN=$(jq -r .root_token ansible/fetched/vault/vault_init_output.json) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/databases)
        ```

        Similar logic applies to other secrets or Development Vault.

    - **Note 1:**

        In which `ssh_username` and `ssh_password` are the account and password used to log into the virtual machine; while `ssh_password_hash` is the hashed password required for virtual machine automatic installation (Cloud-init). This password needs to be generated using the password string from `ssh_password`. For instance, if the password is `HelloWorld@k8s`, then the corresponding password hash should be generated using the following command:

        ```shell
        mkpasswd -m sha-512 HelloWorld@k8s
        ```

        If it shows `mkpasswd` command not found, possibly due to lack of `whois` package.

        In which `ssh_public_key_path` needs to be changed to the **public key** name generated earlier, the public key will be in `*.pub` format.

    - **Note 2:**

        The current SSH identity variables are primarily used for Packer in a single-use scenario, while the VM identity variables are used by Terraform when cloning VMs. In principle, these can be set to the same value. However, if different names are required for different VMs, the objects and relevant code in HCL can be modified directly. Typically, the `ansible_runner.vm_credentials` variable and related variable passing would be modified, followed by the use of a `for_each` loop for iteration. This increases complexity; therefore, if no other requirements exist, maintaining identical SSH and VM identity variables is recommended.

5. When starting the project, the Vault server is launched in a single terminal window (e.g., within an IDE) using `vault server -config=vault/vault.hcl`. The following options are available for use:

    - option `3` in `entry.sh` to unseal the Development mode Vault database
    - option `4` to unseal the Production mode Vault database

    Alternatively, use the container as described in B.1-2, which is suggested due to simplicity.

#### **Step B.3. Create Variable File for Terraform:**

1. Rename the `terraform/layers/*/terraform.tfvars.example` file to `terraform/layers/*/terraform.tfvars` file using the following command:

    ```shell
    for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
    ```

    Then modify the `terraform.tfvars` file based on the requirements of each cluster. HA and non-HA are both supported.

2. For users setting up an HA Cluster (GitLab as example), the number of elements in `gitlab_kubeadm_compute.masters` and `gitlab_kubeadm_compute.workers` determines the number of nodes generated. Ensure the quantity of nodes in `gitlab_kubeadm_compute.masters` is an odd number to prevent the etcd Split-Brain risk in Kubernetes. Meanwhile, `gitlab_kubeadm_compute.workers` can be configured based on the number of IPs. The IPs provided by the user must correspond to the host-only network segment.

    - The latest version is available at <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/> .
    - The test version of this project is also available at <https://old-releases.ubuntu.com/releases/noble/> .
    - After selecting the version, please verify the checksum.
        - For latest Noble version: <https://releases.ubuntu.com/noble/SHA256SUMS>
        - For "Noble-old-release" version: <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

    Deploying other Linux distro would be supported if I have time. I'm still a full-time university student.

3. **[Example] To deploy a complete GitLab HA Cluster from scratch**:

    - **First Step**: Enter the main menu `9) Build Packer Base Image`, then select `02-base-kubeadm` to build the base image required by Kubeadm.

    - **Second Step**: After the previous step is complete, return to the main menu and enter `10) Provision Terraform Layer`, then select `30-gitlab-kubeadm` to deploy the entire GitLab cluster (Now only kubeadm is implemented).

        Based on testing, this complete process (from building the Packer image to completing the Terraform deployment) takes approximately 7 minutes.

4. **Isolated Testing and Development**:

    The `9`, `10`, and `11` menus can be used for separate testing

    - To test Packer image building independently, use `9) Build Packer Base Image`.

    - To test or rebuild a specific Terraform module layer independently (such as Harbor or Postgres), use `10) Provision Terraform Layer`.

        - Rebuilding Harbor in Layer 50's Service Provision stage sometimes shows `module.harbor_config.harbor_garbage_collection.gc` Resource not found error occurred, just remove `terraform.tfstate` and `terraform.tfstate.backup` in `terraform/layers/50-harbor-platform` and reexecute `terraform apply`.

    - To repeatedly test Ansible Playbooks on existing machines without recreating virtual machines, use `11) Rebuild Layer via Ansible`.

5. **Resource Cleanup**:

    - **`14) Purge All Libvirt Resources`**:

        This option executes `libvirt_resource_purger "all"`, which **only deletes** all virtual machines, virtual networks, and storage pools created by this project, but **will preserve** Packer's output images and Terraform's local state files. This is suitable for scenarios where cleaning up virtualization resources is required without clearing the project state.

    - **`15) Purge All Packer and Terraform Resources`**:

        This option deletes **all** Packer output images and **all** Terraform Layer local states, causing Packer and Terraform states in this project to be restored to an almost brand new state.

#### **Step B.4. Provision the GitHub Repository with Terraform:**

**Note:** This step (B.4) can be performed by `10) Provision Terraform Layer` with `90-github-meta` as the target layer if this repository is cloned for _personal_ use. The following content is provided for imperative manual procedures only.

1. Inject Token from Vault with Shell Bridge Pattern. Execute this at the project root to ensure `${PWD}` points to the correct Vault certificate path.

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat ${PWD}/vault/keys/root-token.txt) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/variables)
    ```

2. Execute the governance layer. Since the repository already exists, an import is required for the first run.

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. Initialize and Import.

    - **Scenario A (Repo exists):** For managing an existing repository (e.g., this project), it **MUST** be imported first.
    - **Scenario B (New Repo):** For creating a brand new repository from scratch, skip the import step.

    ```shell
    terraform init
    terraform import github_repository.this on-premise-gitlab-deployment
    ```

4. Apply Rulesets. Using `terraform plan` is a good practice to preview the changes before applying.

    ```shell
    terraform apply -auto-approve
    ```

    The output would be akin to the following:

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

#### **Step B.5. Export Certs of Services:**

1. To configure Terraform Runner for MinIO (Layer 20):

    1. The deployment of Layer 10 Vault should be completed first to generate `vault-root-ca.crt`, located at `terraform/layers/10-vault-core/tls/`

    2. Ensure Terraform Runner has Vault CA

        - For RHEL / CentOS, perform the following steps

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /etc/pki/ca-trust/source/anchors/
            sudo update-ca-trust
            ```

        - For Ubuntu / Debian, perform the following steps

            ```shell
            sudo cp terraform/layers/10-vault-core/tls/vault-ca.crt /usr/local/share/ca-certificates/
            sudo update-ca-certificates
            ```

    3. Verify Trust Store

        ```shell
        curl -I https://minio.iac.local:9000/minio/health/live
        ```

        If the output is `HTTP/1.1 200 OK`, then the Trust Store is configured correctly.

2. To access `harbor.iac.local` from the host, perform the following steps

    1. Get the IP address of the Harbor node

        ```shell
        kubectl get svc -n ingress-system -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
        ```

        Add the stdout as `<harbor-node-ip> harbor.iac.local` to `etc/hosts`

    2. Export the Ingress TLS certificate from Kubernetes. Since the CA Chain is configured in the Vault, meaning that it can be directly fetched from the Kubernetes Secret.

        ```shell
        ssh harbor-microk8s-node-00 "kubectl get secret -n harbor harbor-ingress-tls -o jsonpath='{.data.ca\.crt}' | base64 -d" > vault-root-ca.crt
        ```

        This is the same as the Layer 10 certificate.

    3. Import the Trust Store. For example, on RHEL, use the following command

        ```shell
        sudo cp vault-root-ca.crt /etc/pki/ca-trust/source/anchors/
        sudo update-ca-trust extract
        ```

        and then verify by `curl -vI` as follow

        ```shell
        curl -vI https://harbor.iac.local
        ```

        If it shows `SSL certificate verify ok` and `HTTP/2 200`, meaning that the entire PKI Chain has been successfully established from the Vault certificate issuance, through Cert-Manager signing, to Ingress deployment, and finally to host trust.

## Section 3. System Architecture

This project employs three tools - Packer, Terraform, and Ansible - using an Infrastructure as Code (IaC) approach to achieve a fully automated workflow from virtual machine image creation to Kubernetes cluster deployment. The overall architecture follows the principle of Immutable Infrastructure, ensuring that each deployment environment is consistent and predictable.

### A. Deployment Workflow

1. **The Core Bootstrap Process**: The Development Vault is used to store initial secrets, then the Production Vault is built.

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

2. **Data Services & PKI**: Automate the deployment of a secure data service. MinIO as an example, similar for other data services.

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

> The clusters are built by referencing the following articles. Work Cited:
>
> 1. Bibin Wilson, B. (2025). _How To Setup Kubernetes Cluster Using Kubeadm._ devopscube. <https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests>
> 2. Aditi Sangave (2025). _How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._ Velotio Tech Blog. <https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft>
> 3. Dickson Gathima (2025). _Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._ Medium. <https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f>
> 4. Deniz TÜRKMEN (2025). _Redis Cluster Provisioning — Fully Automated with Ansible._ Medium. <https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75>
>
> **Note:** The operations of the Cluster that completely refer to the official documentation are not included in the above list.

_**(To be continued...)**_
