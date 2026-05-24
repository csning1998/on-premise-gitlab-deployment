# Vault Secrets Configuration

> [!IMPORTANT]
> **Confidential data is centralized within HashiCorp Vault and categorized into Development and Production modes. This repo default setup uses HTTPS secured by a self-signed CA. Follow these steps for correct configuration.**

**Bootstrapper Vault is a prerequisite for establishing Production Vault. Bootstrapper Vault serves exclusively to provision Prod Vault and Packer Images; thereafter, all sensitive project data is managed by Prod Vault.**

## Setup Steps

1. Execute `entry.sh` and select option `1` to generate the required TLS handshake files. Fields may be left blank when creating the self-signed CA. If TLS file regeneration is required, execute option `1` again.
2. Navigate to the project root and execute the following command to start Bootstrapper Vault server. This repo defaults to running Vault in sidecar mode within the container:

    ```shell
    podman compose up -d iac-vault-server
    ```

    Upon initialization, Bootstrapper Vault generates `vault.db` and Raft-related files in `vault/data/`. To recreate Bootstrapper Vault, all files within `vault/data/` and `vault/keys/` must be manually deleted. Open a new terminal window or tab for subsequent operations to prevent environment variable conflicts in the current shell session.

3. After completing previous steps, execute `entry.sh` and select option `2` to initialize Bootstrapper Vault. This process also automatically performs unseal operation.
4. Manually update the following variables. All default passwords must be replaced with unique values to ensure security.

---

## Bootstrapper Vault Secrets

**Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate data exposure. Refer to Note 0 for details.**

The following variables are required for provisioning production HashiCorp Vault across Packer and Terraform Layer `10`:

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

---

## Production Vault Secrets

Following variables are required for provisioning Terraform layers for Patroni, Sentinel, MinIO (S3), Harbor, and GitLab clusters:

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

---

## Notes

### Note 0. Security Notice

Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate sensitive data exposure.

### Note 1. How to Retrieve Secrets

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

    This command is used when `OpenSSL::Cipher::CipherError` occurs during GitLab deployment. Please refer to [L50 README](../../layers/50-platform-gitlab/README.md) for detailed explanation.

### Note 2. SSH vs VM Identity Variables

`ssh_username` and `ssh_password` refer to credentials for virtual machine access. `ssh_password_hash` is hashed value required by cloud-init for automated installation, derived from `ssh_password` string. For instance, if password is `HelloWorld@k8s`, generate hash using:

```shell
printf '%s' "HelloWorld@k8s" | openssl passwd -6 -stdin
```

- If "command not found" error occurs for `openssl`, ensure `openssl` package is installed.
- `ssh_public_key_path` should point to filename of previously generated **public key** (typically in `*.pub` format).

### Note 3. SSH vs VM Credential Separation

SSH identity variables (`ssh_`) are primarily utilized in Packer for one-time provisioning, whereas VM identity variables (`vm_`) are used by Terraform during VM cloning. Both may be set to identical values. While it is possible to configure unique credentials for different VMs by modifying `ansible_runner.vm_credentials` variable and implementing `for_each` loops in HCL, this approach introduces unnecessary complexity. Unless specific requirements dictate otherwise, maintaining identical values for SSH and VM identity variables is recommended.

---

## Vault Unseal

Vault must be unsealed after every startup in this repo. Following options are available:

- Option `3` in `entry.sh` unseals Bootstrapper Vault, using `vault_dev_unseal_handler()` shell function.
- Option `4` in `entry.sh` unseals Production Vault via `90-operation-vault-unseal.yaml` Ansible playbook.
