# How to Resolve GitLab `OpenSSL::Cipher::CipherError` Error

## Problem Description

When GitLab internal secrets (especially `rails-secret` / `db_key_base`) are regenerated without wiping the persistent PostgreSQL database, the application fails to decrypt existing data (e.g., user tokens or application settings), resulting in an `OpenSSL::Cipher::CipherError` during migrations or at login.

## Root Cause

- **State Regeneration**: While preserving the `40-provision-gitlab-databases` layer (Postgres persistent data), performing `tofu destroy && tofu apply` on `50-platform-gitlab`, causing `random_password` resources to be destroyed and recreated
- **Encryption Mismatch**: `tofu apply` will recreate the `random_password.gitlab_internal["rails-secret"]` resource, resulting in a new `rails_secret_key` in Vault KV; however, encrypted columns in tables such as `users` and `application_settings` in Postgres are still ciphertext encrypted with the old password, causing Rails to fail during decryption at the application layer. This issue is not related to database connection verification

## Resolution Steps

### Step A. Identify the Mismatch

Check the `gitlab-migrations` pod logs. If the following error occurs, a key mismatch in the current state is confirmed:

```text
OpenSSL::Cipher::CipherError
/srv/gitlab/vendor/bundle/ruby/3.2.0/gems/encryptor-3.0.0/lib/encryptor.rb:98:in `final'
```

### Step B. Wipe Persistent Database Residue

Since the new secrets have been regenerated, any existing data in the database is unrecoverable without the old keys. Therefore, the database must be wiped to allow the migration job to perform a fresh initialization

1. Switch to the root directory of the project.
2. Delete and recreate the Postgres database

    ```bash
    export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt" VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)

    ssh core-gitlab-postgres-node-00 'psql -h 172.16.127.200 -U postgres -d postgres -c "DROP DATABASE gitlabhq_production WITH (FORCE);"'
    ssh core-gitlab-postgres-node-00 'psql -h 172.16.127.200 -U postgres -d postgres -c "CREATE DATABASE gitlabhq_production OWNER gitlab;"'
    ```

3. **Wipe Gitaly Storage Residue (Hashed Storage Conflict Prevention)**

    Because the database was dropped and recreated, new projects will start with initial IDs (e.g. ID `1`) which map to specific hashed storage directories on disk (e.g. `@hashed/6b/86/`). If the physical disk directories from the previous deployment still exist on Gitaly, subsequent `git push` attempts will fail with: `There is already a repository with that name on disk`.

    Log into the Gitaly node and wipe the stale hashed repositories directory:

    ```bash
    ssh core-gitlab-gitaly-node-00 'sudo rm -rf /var/opt/gitlab/git-data/repositories/@hashed'
    ```

4. Re-apply the GitLab platform layer `50-platform-gitlab` to create the data schema and seed initial data using the **new** secrets.

    ```bash
    tofu destroy -auto-approve && tofu apply -auto-approve
    ```

### Step C. Verification

1. Ensure the migration job `kubectl get pods -n gitlab -l app=migrations -w` does not show password errors
2. Log in to the GitLab Web UI using the `root` account and the new password

## Prevention

- **State Persistence**: Unless there is an intention to completely wipe the environment, avoid deleting `terraform.tfstate` for Layer 50
- **Vault Versioning**: If state loss occurs, before re-applying, the old `rails-secret` should be recovered from Vault KV-V2 history; otherwise, the database must be wiped
