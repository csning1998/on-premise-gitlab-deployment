# How to Resolve GitLab `OpenSSL::Cipher::CipherError` Error

## Problem Description

When GitLab internal secrets (especially `rails-secret` / `db_key_base`) are regenerated without wiping the persistent PostgreSQL database, the application fails to decrypt existing data (e.g., user tokens or application settings), resulting in an `OpenSSL::Cipher::CipherError` during migrations or at login.

## Root Cause

- **State Regeneration**: While preserving the `40-provision-gitlab-databases` layer (Postgres persistent data), performing `terraform destroy && terraform apply` on `50-platform-gitlab`, causing `random_password` resources to be destroyed and recreated
- **Encryption Mismatch**: `terraform apply` will recreate the `random_password.gitlab_internal["rails-secret"]` resource, resulting in a new `rails_secret_key` in Vault KV; however, encrypted columns in tables such as `users` and `application_settings` in Postgres are still ciphertext encrypted with the old password, causing Rails to fail during decryption at the application layer. This issue is not related to database connection verification

## Resolution Steps

### Step A. Identify the Mismatch

Check the `gitlab-migrations` pod logs. If the following error occurs, a key mismatch in the current state is confirmed:

```text
OpenSSL::Cipher::CipherError
/srv/gitlab/vendor/bundle/ruby/3.2.0/gems/encryptor-3.0.0/lib/encryptor.rb:98:in `final'
```

### Step B. Execute HCL-Native Database Reset

To resolve the `CipherError` with minimal intervention—without dropping the database or destroying Gitaly repository directories on disk—deploy the pre-configured Kubernetes Job to clear the encryption-drift residues:

1. **Delete Any Stale Reset Job (If Exists)**

    ```bash
    ssh core-gitlab-frontend-master-00 "kubectl delete job -n gitlab gitlab-db-token-reset"
    ```

2. **Deploy the Reset Job Natively via Terraform**: Execute `terraform apply` with the reset variable enabled. This mounts the necessary database client certificates (mTLS) and executes `TRUNCATE TABLE application_settings CASCADE;` safely:

    ```bash
    terraform apply -auto-approve -var="enable_db_token_reset=true"
    ```

3. **Verify the Reset Execution**: Check the logs of the deployed reset container. It should show a successful `TRUNCATE TABLE` output:

    ```bash
    ssh core-gitlab-frontend-master-00 "kubectl logs -f -n gitlab -l app=gitlab-db-token-reset"
    ```

4. **Restart the Crashing Migrations Pod**: Force recreate the migrations pod. The setup script will automatically initialize the application settings dynamically with the correct Vault-backed encryption keys:

    ```bash
    ssh core-gitlab-frontend-master-00 "kubectl delete pod -n gitlab -l app=migrations"
    ```

5. **Clean Up Reset Resources**: Once migrations have successfully completed, run standard apply to automatically reclaim the Job resource:

    ```bash
    terraform apply -auto-approve
    ```

### Step C. Verification

1. Ensure the migration job `kubectl get pods -n gitlab -l app=migrations -w` does not show password errors
2. Log in to the GitLab Web UI using the `root` account and the new password

## Prevention

- **State Persistence**: Unless there is an intention to completely wipe the environment, avoid deleting `terraform.tfstate` for Layer 50
- **Vault Versioning**: If state loss occurs, before re-applying, the old `rails-secret` should be recovered from Vault KV-V2 history; otherwise, the database must be wiped
