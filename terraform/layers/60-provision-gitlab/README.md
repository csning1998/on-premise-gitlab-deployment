# Layer 60: GitLab Platform Provisioning

This layer is responsible for provisioning the internal organizational structure (Groups), pre-provisioning of users, and OIDC identity linkage within the GitLab platform.

## GitLab Personal Access Token (PAT)

### Vault Login

The GitLab Terraform Provider requires a PAT with administrator privileges to perform API operations. Since GitLab does not support issuing the first token directly through the API, the following manual bootstrap steps are required.

1. First, obtain Vault login permissions in the current terminal session:

    ```shell
    export VAULT_ADDR="https://172.16.136.250:443"
    export VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt"
    export VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials)
    ```

2. Before logging into the GitLab web interface, retrieve the initial password from Vault:

    ```shell
    vault kv get -mount="secret" "on-premise-gitlab-deployment/gitlab/app/internal"
    ```

### Generating the First PAT

1. Log in to the GitLab web interface using the `root` account.
2. Navigate to **User Settings** → **Personal Access Tokens**.
3. Create a token named `terraform-gitlab-pat`.
4. **Required Scopes**:
    - `api` – Core resource management
    - `admin_mode` – Administrator-level operations
    - `read_user` – Read user information
5. Copy the generated token string.
6. Store the PAT in Vault:

    ```bash
    vault kv put -mount="secret" "on-premise-gitlab-deployment/gitlab/app/pat" token="glpat-..."
    ```

> [!TIP]
> Updating the token in Vault allows the use of ephemeral resources so that the token is not stored in plaintext in the Terraform state file.

### Establishing Users

Refer to `terraform/layers/40-provision-keycloak-oidc/terraform.tfvars.example` to configure and create initial users.
