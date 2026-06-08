# Terraform Remote State — GitLab.com HTTP Backend

All 33 layers store state on GitLab.com via the Terraform HTTP backend (Project ID: `82448331`). `terraform apply` and `terraform destroy` require no extra CLI flags after initialization.

## Section 1. Local Credential Files

Two gitignored files must be created once by the operator. Neither enters version control.

### Step A. `terraform/backend-auth.hcl`

Used only by `terraform init -backend-config`. Contains the GitLab PAT with `api` scope.

```hcl
username = "oauth2"
password = "glpat-xxxxxxxxxxxxxxxxxxxx"
```

### Step B. `terraform/backend-state.json`

Read at plan/apply time by each layer's `locals.tf` via `jsondecode(file(...))`. Supplies credentials for cross-layer `data "terraform_remote_state"` reads without CLI injection.

```json
{ "username": "oauth2", "token": "glpat-xxxxxxxxxxxxxxxxxxxx" }
```

## Section 2. Initializing a Layer

### Step A. First-time init (no existing local state)

```bash
cd terraform/layers/<layer-name>
terraform init \
  -backend-config=../../backend-auth.hcl \
  -backend-config=backend.hcl
```

### Step B. Migrating existing local state to remote

```bash
cd terraform/layers/<layer-name>
terraform init -migrate-state \
  -backend-config=../../backend-auth.hcl \
  -backend-config=backend.hcl
```

`-migrate-state` uploads the existing `terraform.tfstate` to GitLab.com and removes the local file reference. Layers that were never applied can use Step A directly.

## Section 3. Cross-Layer State Read Mechanism

### Step A. Authentication locals

Each layer's `locals.tf` defines three locals consumed by all `data "terraform_remote_state"` blocks in that layer:

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

### Step B. Data source pattern

`data.tf` in every layer uses `merge()` to inject `_state_auth` alongside the layer-specific address:

```hcl
data "terraform_remote_state" "metadata" {
  backend = "http"
  config  = merge(local._state_auth, { address = "${local._state_base}/00-foundation-metadata" })
}
```

## Section 4. Layer Initialization Order

When migrating all layers, initialize in dependency order so that upstream state is available before downstream layers are read:

```text
00-foundation-metadata
00-foundation-vault-bootstrapper
05-foundation-network
05-foundation-volume
10-shared-load-balancer-frontend
15-shared-vault-frontend
20-security-vault-approle
25-security-credentials
25-security-pki
30-infra-gitlab-frontend
30-infra-gitlab-gitaly-praefect
30-infra-gitlab-minio
30-infra-gitlab-postgres
30-infra-gitlab-redis
30-infra-gitlab-runner
30-infra-harbor-bootstrapper-frontend
30-infra-harbor-frontend
30-infra-harbor-minio
30-infra-harbor-postgres
30-infra-harbor-redis
30-infra-keycloak-frontend
40-provision-gitlab-databases
40-provision-gitlab-frontend
40-provision-harbor-bootstrapper-frontend
40-provision-harbor-databases
40-provision-keycloak-oidc
45-security-vault-oidc
50-platform-gitlab-frontend
50-platform-gitlab-runner
50-platform-harbor-frontend
60-provision-gitlab
60-provision-harbor
90-meta-gitlab
```
