# Terraform Pipeline Architecture

## Section 1. Terraform Remote States

All 33 layers store state on GitLab.com via the Terraform HTTP backend (Project ID: `82448331`). `terraform apply` and `terraform destroy` require no extra CLI flags after initialization.

### Step A. Local Credential Files

Two gitignored files must be created once by the operator. Neither enters version control.

1. **`terraform/backend-auth.hcl`**

    Used only by `terraform init -backend-config`. Contains the GitLab PAT with `api` scope.

    ```hcl
    username = "oauth2"
    password = "glpat-xxxxxxxxxxxxxxxxxxxx"
    ```

2. **`terraform/backend-state.json`**

    Read at plan/apply time by each layer's `locals.tf` via `jsondecode(file(...))`. Supplies credentials for cross-layer `data "terraform_remote_state"` reads without CLI injection.

    ```json
    { "username": "oauth2", "token": "glpat-xxxxxxxxxxxxxxxxxxxx" }
    ```

    The JSON file is usually required when working with multiple layers. However, it is not needed when working with a single layer.

### Step B. Initializing a Layer

1. **First-time init (no existing local state)**

    ```bash
    cd terraform/layers/<layer-name>
    terraform init -backend-config=../../backend-auth.hcl
    ```

2. **Migrating existing local state to remote**

    ```bash
    cd terraform/layers/<layer-name>
    terraform init -migrate-state -backend-config=../../backend-auth.hcl
    ```

    `-migrate-state` uploads the existing `terraform.tfstate` to GitLab.com and removes the local file reference. Layers that were never applied can use Step A directly.

### Step C. Cross-Layer State Read Mechanism

1. **Authentication locals**: Each layer's `locals.tf` defines three locals consumed by all `data "terraform_remote_state"` blocks in that layer:

    ```hcl
    locals {
        _gl_creds   = jsondecode(file("${path.root}/../../backend-state.json"))
        _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
        _state_auth = {
            username = local._gl_creds.username
            password = local._gl_creds.token
        }
    }
    ```

2. **Data source pattern**: `data.tf` in every layer uses `merge()` to inject `_state_auth` alongside the layer-specific address:

    ```hcl
    data "terraform_remote_state" "metadata" {
      backend = "http"
      config  = merge(local._state_auth, { address = "${local._state_base}/foundation-metadata" })
    }
    ```

3. **Initialization**: When migrating all layers, initialize in the deployment order listed below. This is also the `terraform apply` execution order; upstream state must be available before any downstream layer that reads from it is applied. The following table lists all layers in the required deployment sequence:

    | #   | Layer                                    |
    | --- | ----------------------------------------- |
    | 1   | `foundation-metadata`                    |
    | 2   | `foundation-vault-bootstrapper`          |
    | 3   | `foundation-network`                     |
    | 4   | `foundation-volume`                      |
    | 5   | `shared-load-balancer-frontend`          |
    | 6   | `shared-vault-frontend`                  |
    | 7   | `security-vault-approle`                 |
    | 8   | `security-credentials`                   |
    | 9   | `security-pki`                           |
    | 10  | `infra-keycloak-frontend`                |
    | 11  | `provision-keycloak-oidc`                |
    | 12  | `provision-vault-oidc`                   |
    | 13  | `infra-harbor-bootstrapper-frontend`     |
    | 14  | `provision-harbor-bootstrapper-frontend` |
    | 15  | `infra-harbor-postgres`                  |
    | 16  | `infra-harbor-redis`                     |
    | 17  | `infra-harbor-minio`                     |
    | 18  | `infra-harbor-frontend`                  |
    | 19  | `infra-gitlab-postgres`                  |
    | 20  | `infra-gitlab-redis`                     |
    | 21  | `infra-gitlab-minio`                     |
    | 22  | `infra-gitlab-frontend`                  |
    | 23  | `infra-gitlab-gitaly-praefect`           |
    | 24  | `infra-gitlab-runner`                    |
    | 25  | `provision-gitlab-databases`             |
    | 26  | `provision-gitlab-frontend`              |
    | 27  | `provision-harbor-databases`             |
    | 28  | `platform-harbor-frontend`               |
    | 29  | `platform-gitlab-frontend`               |
    | 30  | `platform-gitlab-governance`             |
    | 31  | `platform-harbor-governance`             |
    | 32  | `platform-gitlab-runner`                 |
    | 33  | `meta-github`                            |
    | 34  | `meta-gitlab`                            |

    The following bulk-init script is a convenience shortcut. It iterates in filesystem order, which does not necessarily match the dependency order above. This script assumes all upstream remote states already exist; running it against a clean GitLab project where earlier layers have never been applied will cause remote-state read failures in downstream layers.

    ```bash
    for dir in ./*; do
        if [ -d "$dir" ]; then
            (echo -e "\n\n${dir}" && cd "$dir" && terraform init -upgrade -backend-config=../../backend-auth.hcl)
        fi
    done
    ```
