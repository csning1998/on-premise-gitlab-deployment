# Layer 25: Security Credentials for All Services

Generates all service passwords via Terraform and writes them to HashiCorp Vault KV v2. Password lifecycle is decoupled from the VM layers (`30-infra-*`), so infrastructure nodes can be destroyed and rebuilt without rotating live secrets.

Paths are written under `secret/<vault_kv_namespace>/`, where `vault_kv_namespace` is derived from L00 metadata.

## Configuration

| Variable                 | Type   | Description                                                                |
| ------------------------ | ------ | -------------------------------------------------------------------------- |
| `minio_root_user`        | string | MinIO root account name (shared by GitLab and Harbor MinIO)                |
| `keycloak_admin_user`    | string | Keycloak administrator account name                                        |
| `keycloak_db_user`       | string | Keycloak database user name                                                |
| `gitlab_enable_praefect` | bool   | Controls whether Praefect-specific secrets are generated (default: `true`) |

Passwords are auto-generated. Only the human-managed usernames above are supplied via `terraform.tfvars`.

## Generated Secrets

### `gitlab/postgres`

Credentials for the GitLab Postgres HA cluster (Patroni + Keepalived).

| Key                       | Description                                                                                                                                        |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pg_superuser_password`   | Password for the `postgres` superuser. Used during `initdb`, Patroni cluster bootstrap, and manual DBA operations.                                 |
| `pg_replication_password` | Password for the streaming replication user. Patroni supplies this when provisioning standby nodes to authenticate WAL streaming from the primary. |
| `pg_vrrp_secret`          | VRRP authentication key for Keepalived. Prevents unauthorized nodes from participating in VIP election and failover within the local network.      |

### `gitlab/redis`

Credentials for the GitLab Redis HA cluster (Sentinel + Keepalived).

| Key                 | Description                                                                                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `redis_requirepass` | Authentication password for all Redis clients (`AUTH` command). GitLab application components use this to connect to Redis.                                                               |
| `redis_masterauth`  | Password used by Redis replicas to authenticate with the master during replication handshake. Set equal to `redis_requirepass` to ensure seamless failover when a new master is promoted. |
| `redis_vrrp_secret` | VRRP authentication key for the Redis load balancing layer (HAProxy + Keepalived). Same operational principle as `pg_vrrp_secret`.                                                        |

### `gitlab/minio`

Credentials for the GitLab MinIO object storage node.

| Key                   | Description                                                                                                                                                            |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `minio_root_user`     | MinIO root administrator account (formerly Access Key). Used for MinIO Console access and bucket or policy management via `mc`. Value sourced from `terraform.tfvars`. |
| `minio_root_password` | MinIO root administrator password (formerly Secret Key). Auto-generated.                                                                                               |
| `minio_vrrp_secret`   | VRRP authentication key for the MinIO load balancing layer. Same operational principle as `pg_vrrp_secret`.                                                            |

### `harbor/postgres`

Credentials for the Harbor Postgres HA cluster. Same key schema as `gitlab/postgres`.

| Key                       | Description                                                             |
| ------------------------- | ----------------------------------------------------------------------- |
| `pg_superuser_password`   | Password for the `postgres` superuser on the Harbor database cluster.   |
| `pg_replication_password` | Password for streaming replication user on the Harbor database cluster. |
| `pg_vrrp_secret`          | VRRP authentication key for the Harbor database Keepalived layer.       |

### `harbor/redis`

Credentials for the Harbor Redis HA cluster. Same key schema as `gitlab/redis`.

| Key                 | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `redis_requirepass` | Authentication password for Harbor Redis clients.                  |
| `redis_masterauth`  | Password for Harbor Redis replica-to-master replication handshake. |
| `redis_vrrp_secret` | VRRP authentication key for the Harbor Redis load balancing layer. |

### `harbor/minio`

Credentials for the Harbor MinIO object storage node. Same key schema as `gitlab/minio`.

| Key                   | Description                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------- |
| `minio_root_user`     | MinIO root administrator account for Harbor storage. Value sourced from `terraform.tfvars`. |
| `minio_root_password` | MinIO root administrator password for Harbor storage. Auto-generated.                       |
| `minio_vrrp_secret`   | VRRP authentication key for the Harbor MinIO load balancing layer.                          |

### `keycloak/frontend`

Credentials for the Keycloak identity provider.

| Key                       | Description                                                                                                                                                  |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `keycloak_admin_user`     | Keycloak administrator account name. Used to access the Keycloak Admin Console and manage realms, clients, and users. Value sourced from `terraform.tfvars`. |
| `keycloak_admin_password` | Keycloak administrator password. Auto-generated.                                                                                                             |
| `keycloak_db_user`        | Database user name for Keycloak's Postgres backend. Value sourced from `terraform.tfvars`.                                                                   |
| `keycloak_db_password`    | Database password for Keycloak's Postgres backend. Auto-generated.                                                                                           |

### `harbor-bootstrapper/frontend`

Credentials for the Harbor Bootstrapper service, which provisions the initial Harbor registry instance before the main Harbor cluster is available.

| Key                                  | Description                                                                                                                        |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| `harbor_bootstrapper_admin_password` | Admin password for the Harbor Bootstrapper Web UI. Used for initial project and robot account setup via the Bootstrapper instance. |
| `harbor_bootstrapper_pg_db_password` | Password for the Harbor Bootstrapper's Postgres database user.                                                                     |

### `gitlab/gitaly`

Tokens for GitLab Gitaly and optionally Praefect. The Praefect keys are only written when `gitlab_enable_praefect = true`.

| Key                       | Condition                       | Description                                                                                                                                   |
| ------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `gitaly_token`            | Always                          | Shared secret between GitLab Rails and Gitaly nodes. All Gitaly RPC calls are authenticated with this token via the `Authorization` header.   |
| `gitlab_shell_secret`     | Always                          | Shared secret between `gitlab-shell` and GitLab Rails for SSH operation callbacks (e.g., authorized key lookup, post-receive hooks).          |
| `praefect_external_token` | `gitlab_enable_praefect = true` | Token used by GitLab Rails to authenticate with the Praefect proxy. Praefect validates this token before forwarding requests to Gitaly nodes. |
| `praefect_db_password`    | `gitlab_enable_praefect = true` | Password for the Praefect tracking database user on the Praefect Patroni cluster.                                                             |

### `gitlab/praefect-patroni`

Credentials for the Praefect Patroni Postgres cluster (separate from the main GitLab Postgres cluster). Only relevant when Praefect is enabled.

| Key                       | Description                                                            |
| ------------------------- | ---------------------------------------------------------------------- |
| `pg_superuser_password`   | Password for the `postgres` superuser on the Praefect Patroni cluster. |
| `pg_replication_password` | Password for streaming replication on the Praefect Patroni cluster.    |
| `pg_vrrp_secret`          | VRRP authentication key for the Praefect Patroni Keepalived layer.     |

### `gitlab/frontend`

Application-level secrets for GitLab Rails.

| Key                | Description                                                                                                                                                                         |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rails_secret_key` | Secret key base for GitLab Rails. Used to sign and encrypt session cookies, CSRF tokens, and other security-sensitive data. Rotating this key invalidates all active user sessions. |
| `root_password`    | Initial password for the GitLab `root` administrator account. Used for first-login access before SSO (Keycloak OIDC) is configured.                                                 |

### `harbor/frontend`

Application-level credentials for the main Harbor registry.

| Key                     | Description                                                                                                                                                                            |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `harbor_admin_password` | Password for the Harbor Web Portal `admin` account. Required for initial project creation, robot account configuration, and registry policy setup before OIDC integration is complete. |
