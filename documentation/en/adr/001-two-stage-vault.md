# ADR 001: Two-Stage Vault Architecture (Bootstrapper + Production)

**Status:** Accepted

**Context:**

Production Vault requires PKI infrastructure and TLS certificates to operate securely. However, the certificates themselves need to be issued by a trusted CA, creating a chicken-and-egg problem. Additionally, Packer image builds and early Terraform layers need access to secrets (SSH credentials, VM passwords) before Production Vault exists.

**Decision:**

Implement a two-stage Vault architecture:

1. **Bootstrapper Vault** (`foundation-vault-bootstrapper`): A locally-running, self-signed-CA Vault instance that starts via `podman compose`. Serves exclusively for:
    - Provisioning Packer images (SSH credentials, VM passwords)
    - Bootstrapping Production Vault nodes (`shared-vault-frontend`)
    - Storing the `prod_vault_root_token` for initial Production Vault access

2. **Production Vault** (spanning `shared-vault-frontend` through `security-pki`): A HA Vault cluster with Raft backend, PKI Engine, AppRole auth, and OIDC. After `security-pki` is applied, all application secrets migrate here. Bootstrapper Vault is no longer used for application secrets.

**Consequences:**

- Bootstrapper Vault must be initialized and unsealed before any other layer can proceed.
- The `prod_vault_root_token` stored in Bootstrapper Vault is the recovery path if Production Vault root token is lost.
- Adding a second Vault increases operational overhead (two unseal procedures), mitigated by `entry.sh` options 3 and 4.
- Provides clean separation of concerns: bootstrapping infrastructure vs. running infrastructure.

**Related layers:** `foundation-vault-bootstrapper`, `shared-vault-frontend`, `security-vault-approle`, `security-pki`
