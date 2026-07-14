# How to Resolve GitLab `OpenSSL::Cipher::CipherError` Error

## Problem Description

When GitLab internal secrets (especially `rails-secret` / `db_key_base`) are regenerated without wiping the persistent Postgres database, the application fails to decrypt existing data (e.g., user tokens or application settings), resulting in an `OpenSSL::Cipher::CipherError` during migrations or at login.

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

To resolve the `CipherError` with minimal intervention without dropping the database or destroying Gitaly repository directories on disk, deploy the pre-configured Kubernetes Job to clear the encryption-drift residues:

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

---

## GitLab Rails Secrets Delivery

GitLab requires a stable set of Rails secrets: `secret_key_base`, `otp_key_base`, `db_key_base`, `encrypted_settings_key_base`, the `active_record_encryption` keys, and `openid_connect_signing_key`. `db_key_base` in particular **must never change** once data exists. Regenerating it corrupts every encrypted column in Postgres and produces the `CipherError` documented above.

### Architecture: Vault-Native, Zero tfstate Exposure

Terraform never reads or stores any secret value; it only declares **how** secrets reach the cluster. All key material is generated in process memory and written directly to Vault KV.

```text
terraform_data.seed_rails_secrets   runs templates/seed-rails-secrets.sh.tftpl via local-exec
    └─ Vault KV secret/on-premise-gitlab-deployment/gitlab/app/rails-secrets, field secrets_yml
        └─ SecretStore "gitlab-vault-store" via Vault K8s auth, mount kubernetes/gitlab/frontend, role core-gitlab-frontend-role
            └─ ExternalSecret "gitlab-rails-secret" → K8s Secret
                └─ Helm chart global.railsSecrets.secret = "gitlab-rails-secret"
```

### Seeding

`terraform_data.seed_rails_secrets` replaces the former manual `init-secrets.sh` pre-flight step. During `terraform apply` it:

1. Authenticates to Vault via AppRole. The `role_id` and `secret_id` come from the same remote state the Vault provider already uses, namely `20-security-vault-approle`.
2. Generates all key material with `openssl` in process memory.
3. Writes the assembled `secrets.yml` to Vault KV as the `secrets_yml` field.

It is **idempotent**: if the KV path already exists the script skips generation and exits, so repeated applies are no-ops. The PEM payload is built with `jq` so newlines and special characters are safely JSON-escaped.

### Re-seeding / Rotation

Tainting the resource alone will not regenerate the keys, because the script is idempotent against the existing KV entry. To rotate, delete or overwrite the Vault KV entry first, then `terraform apply`.

> [!WARNING]
> Rotating `db_key_base` invalidates all existing encrypted data. Only do this on a greenfield database, or follow the `CipherError` reset procedure above.

---

## CI Job Token Signing Key

GitLab 17+ requires an RSA private key in `ApplicationSetting.ci_job_token_signing_key` to sign CI job token JWTs. Without it every job fails at the _prepare environment_ phase with `RuntimeError: "CI job token signing key is not set"`.

### Greenfield: Normal Path, No Action Required

On a clean first deploy, the Helm chart migration job auto-generates `ci_job_token_signing_key` and encrypts it with `db_key_base` from `gitlab-rails-secret`. `var.enable_ci_signing_key_rotation` defaults to `false`, so none of the rotation resources below are created.

### Rotation: Only When a Key Replacement Is Needed

The rotation path is gated by `var.enable_ci_signing_key_rotation` and `var.ci_signing_key_rotation_version`. The RSA key never passes through Terraform state.

1. **Place the new key in Vault.** `init-secrets.sh` no longer manages this key, so generate it manually:

    ```bash
    openssl genrsa 4096 \
        | vault kv put secret/on-premise-gitlab-deployment/gitlab/app/ci-job-token-signing-key private_key_pem=-
    ```

2. **Enable rotation.** Increment `var.ci_signing_key_rotation_version` so a fresh Job resource is created rather than re-running the old one, set `var.enable_ci_signing_key_rotation = true`, then `terraform apply`.
3. **Job applies the key.** An `ExternalSecret` pulls the Vault key into a K8s Secret; the `kubernetes_job` runs `gitlab-rails` to overwrite `ApplicationSetting.ci_job_token_signing_key`.
4. **Disable rotation.** Reset `var.enable_ci_signing_key_rotation = false`.
