# Terraform Pipeline Architecture

## Section 1. Terraform Remote States

All 33 layers store state on GitLab.com via the Terraform HTTP backend (Project ID: `82448331`). `terraform apply` and `terraform destroy` require no extra CLI flags after initialization.

### Step A. Operator Credentials

Every layer reads the GitLab HTTP backend credentials from `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD`. The operator MUST source `scripts/tf_env.sh` before any `terraform` command. The script runs `vault-proxy-env consumer-opgitlab`, which exports the Vault Proxy address, the client certificate, and the state backend token of `opgitlab` from the Bastion Vault. No credential file exists in the working tree. The layer `administration-gitlab-project` loads `credential-distributor-opgitlab` through its own `.envrc` instead.

```bash
source scripts/tf_env.sh
```

### Step B. Initializing a Layer

1. **First-time init (no existing local state)**

    ```bash
    cd terraform/layers/<layer-name>
    terraform init
    ```

2. **Migrating existing local state to remote**

    ```bash
    cd terraform/layers/<layer-name>
    terraform init -migrate-state
    ```

    `-migrate-state` uploads the existing `terraform.tfstate` to GitLab.com and removes the local file reference. A layer which was never applied uses Step B.1 directly.

### Step C. Cross-Layer State Read Mechanism

1. **State base local**: The `locals.tf` of each layer defines `_state_base`, the state address prefix of the project:

    ```hcl
    locals {
      _state_base = "https://gitlab.com/api/v4/projects/82448331/terraform/state"
    }
    ```

2. **Data source pattern**: The `config` of every `data "terraform_remote_state"` block carries the address alone, since the HTTP backend takes the credentials from the environment:

    ```hcl
    data "terraform_remote_state" "metadata" {
      backend = "http"
      config  = { address = "${local._state_base}/foundation-metadata" }
    }
    ```

3. **Initialization**: When migrating all layers, initialize in the deployment order listed below. This is also the `terraform apply` execution order; upstream state must be available before any downstream layer that reads from it is applied. The following table lists all layers in the required deployment sequence:

    | #   | Layer                              |
    | --- | ---------------------------------- |
    | 1   | `foundation-metadata`              |
    | 2   | `foundation-vault-bootstrapper`    |
    | 3   | `foundation-network`               |
    | 4   | `foundation-volume`                |
    | 5   | `shared-load-balancer-frontend`    |
    | 6   | `shared-vault-frontend`            |
    | 7   | `security-vault-approle`           |
    | 8   | `security-credentials`             |
    | 9   | `security-pki`                     |
    | 10  | `platform-keycloak-frontend`       |
    | 11  | `provision-keycloak-oidc`          |
    | 12  | `provision-vault-oidc`             |
    | 13  | `infra-harbor-origin-frontend`     |
    | 14  | `provision-harbor-origin-frontend` |
    | 15  | `infra-harbor-postgres`            |
    | 16  | `infra-harbor-redis`               |
    | 17  | `infra-harbor-minio`               |
    | 18  | `infra-harbor-frontend`            |
    | 19  | `infra-gitlab-postgres`            |
    | 20  | `infra-gitlab-redis`               |
    | 21  | `infra-gitlab-minio`               |
    | 22  | `infra-gitlab-frontend`            |
    | 23  | `infra-gitlab-gitaly-praefect`     |
    | 24  | `infra-gitlab-runner`              |
    | 25  | `provision-gitlab-databases`       |
    | 26  | `provision-gitlab-frontend`        |
    | 27  | `provision-harbor-databases`       |
    | 28  | `platform-harbor-frontend`         |
    | 29  | `platform-gitlab-frontend`         |
    | 30  | `platform-gitlab-governance`       |
    | 31  | `platform-harbor-governance`       |
    | 32  | `platform-gitlab-runner`           |
    | 33  | `meta-github`                      |
    | 34  | `meta-gitlab`                      |

    The following bulk-init script is a convenience shortcut. It iterates in filesystem order, which does not necessarily match the dependency order above. This script assumes all upstream remote states already exist; running it against a clean GitLab project where earlier layers have never been applied will cause remote-state read failures in downstream layers.

    ```bash
    for dir in ./*; do
        if [ -d "$dir" ]; then
            (echo -e "\n\n${dir}" && cd "$dir" && terraform init -upgrade)
        fi
    done
    ```
