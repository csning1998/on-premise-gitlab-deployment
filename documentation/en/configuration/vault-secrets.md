# Vault Secrets Configuration

> [!IMPORTANT]
> **This repository runs no Vault instance. Bootstrap credentials reside in the Bastion Vault of `parent-group-governance`, and application secrets reside in the Downstream Vault of `platform-foundation`. Both instances use HTTPS secured by their own CA.**

The setup, initialization, and unseal procedures of both instances are documented in the upstream projects. This document lists only the secrets which this repository reads.

---

## Bastion Vault Secrets

**Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate data exposure. Refer to Note 0 for details.**

Packer reads the following variables from `secret/on-premise-gitlab-deployment/guest_vm` while building the Gitaly and Praefect image:

- `ssh_username`, `ssh_password`: Credentials for SSH access.
- `guest_username`, `guest_password`: Credentials for virtual machine.
- `ssh_public_key_path`, `ssh_private_key_path`: Paths to SSH public and private keys on host.

```shell
printf "Enter ssh Password: "
read -s ssh_password
vault kv put \
    -address="https://172.16.0.1:8200" \
    -ca-cert="<PARENT_GROUP_GOVERNANCE_ROOT>/vault/tls/ca.pem" \
    secret/on-premise-gitlab-deployment/guest_vm \
    ssh_username="<YOUR_PRODUCTION_SSH_USERNAME>" \
    ssh_password="$ssh_password" \
    ssh_password_hash="$(printf '%s' "$ssh_password" | openssl passwd -6 -stdin)" \
    guest_username="<YOUR_PRODUCTION_VM_USERNAME_OR_SAME_AS_ssh_username>" \
    guest_password="<YOUR_PRODUCTION_VM_PASSWORD_OR_SAME_AS_ssh_password>" \
    ssh_public_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment.pub" \
    ssh_private_key_path="~/.ssh/id_ed25519_on-premise-gitlab-deployment"
```

---

## Downstream Vault Secrets

The Terraform layers for the Patroni, Sentinel, MinIO (S3), Harbor, and GitLab clusters read the following variables under the tenant prefix `on-premise-gitlab-deployment` of the Downstream Vault:

- `pg_superuser_password`: Password for Postgres superuser (`postgres`). Required for database initialization (`initdb`), Patroni management operations, and manual maintenance tasks.
- `pg_replication_password`: Credentials for streaming replication user. Patroni utilizes this password when provisioning standby nodes to enable WAL synchronization with primary.
- `pg_vrrp_secret`: VRRP authentication key for Keepalived nodes. Ensures that only authorized nodes participate in Virtual IP (VIP) election and failover, mitigating malicious interference within local network.
- `redis_requirepass`: Authentication password for Redis clients. All clients connecting to Redis, such as GitLab or Harbor, must authenticate via `AUTH` command using this password.
- `redis_masterauth`: Authentication password used by Redis replicas to synchronize with master. During failover, new replicas utilize this password for handshakes with newly promoted master. This is typically set identical to `redis_requirepass` to ensure seamless replication in Sentinel + HA configurations.
- `redis_vrrp_secret`: VRRP authentication key for Redis load balancing layer (HAProxy/Keepalived). Follows same operational principle as `pg_vrrp_secret`.
- `minio_root_user`: MinIO root administrator account (formerly Access Key), used for MinIO Console access and managing buckets or policies via MinIO Client (`mc`).
- `minio_root_password`: MinIO root administrator password (formerly Secret Key).
- `minio_vrrp_secret`: VRRP authentication key for MinIO load balancing layer (HAProxy/Keepalived). Follows same operational principle as `pg_vrrp_secret`.
- `harbor_admin_password`: Default password for Harbor Web Portal `admin` account, required for initial project creation and robot account configuration.
- `harbor_pg_db_password`: Dedicated password for Harbor services (Core, Notary, Clair) to connect to Postgres. This application-level credential (assigned to `harbor` DB user) is restricted with fewer privileges than `pg_superuser_password`.

The tenant registration and the operator login of the Downstream Vault follow `platform-foundation`.

---

## Notes

### Note 0. Security Notice

Clearing shell history after executing `vault kv put` commands is strongly recommended to mitigate sensitive data exposure.

### Note 1. How to Retrieve Secrets

1. After logging in to the Downstream Vault as the operator of this repository, retrieve a credential such as the Postgres superuser password with the following command:

    ```shell
    vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases
    ```

2. To prevent exposing secrets in shell output:

    ```shell
    export PG_SUPERUSER_PASSWORD=$(vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)
    ```

    This command is used when `OpenSSL::Cipher::CipherError` occurs during GitLab deployment. Please refer to [platform-gitlab-frontend README](../../../terraform/layers/platform-gitlab-frontend/README.md) for detailed explanation.

### Note 2. SSH vs VM Identity Variables

`ssh_username` and `ssh_password` refer to credentials for virtual machine access. `ssh_password_hash` is hashed value required by cloud-init for automated installation, derived from `ssh_password` string. For instance, if password is `HelloWorld@k8s`, generate hash using:

```shell
printf '%s' "HelloWorld@k8s" | openssl passwd -6 -stdin
```

- If "command not found" error occurs for `openssl`, ensure `openssl` package is installed.
- `ssh_public_key_path` should point to filename of previously generated **public key** (typically in `*.pub` format).

### Note 3. SSH vs VM Credential Separation

SSH identity variables (`ssh_`) are primarily utilized in Packer for one-time provisioning, whereas VM identity variables (`vm_`) are used by Terraform during VM cloning. Both may be set to identical values. Unique credentials for different VMs are possible by modifying `ansible_runner.vm_credentials` variable and implementing `for_each` loops in HCL, but this approach introduces unnecessary complexity. Identical values for SSH and VM identity variables are recommended unless specific requirements call for separation.
