# GitHub Repository Meta Management

> [!NOTE]
> If this repository is cloned for personal use, this step can be manually performed by navigating to the `terraform/layers/90-github-meta` directory and executing `tofu apply`. Following instructions detail the manual procedure for reference:

This repo utilizes [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) by default for repository management. Consequently, a Fine-grained Personal Access Token must be configured. If the cloned repo is not managed via this integration, the `terraform/layers/90-github-meta` layer may be skipped or deleted without affecting subsequent operations.

## Setup Steps

1. Use the Shell Bridge Pattern to inject the Token from Vault. Execute this in the project root to ensure `${PWD}` points to the correct Vault certificate path.

    ```shell
    export GITHUB_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=github_pat secret/on-premise-gitlab-deployment/project_meta)
    ```

2. Since the repository already exists, it must be imported before the first execution of the governance layer:

    ```shell
    cd terraform/layers/90-github-meta
    ```

3. Initialization and Import
    - **Scenario A (Repository already exists):** When managing an existing repository (such as This repo), the import operation is **mandatory**.
    - **Scenario B (New Repository):** When creating a new repository from scratch, the import step can be bypassed.

    ```shell
    tofu init
    tofu import github_repository.this on-premise-gitlab-deployment
    ```

4. Apply Ruleset: It is recommended to execute `tofu plan` to preview changes before applying:

    ```shell
    tofu apply -auto-approve
    ```

    The output should look similar to:

    ```shell
    Apply complete! Resources: x added, y changed, z destroyed.
    Outputs:

    repository_ssh_url = "git@github.com:username/on-premise-gitlab-deployment.git"
    ruleset_id = <a-numeric-id>
    ```

## GitHub PAT Permissions

When generating the Fine-grained Personal Access Token at [GitHub Developer Settings](https://github.com/settings/personal-access-tokens), configure the following permissions:

| Permission                     | Access Level   | Description                               |
| ------------------------------ | -------------- | ----------------------------------------- |
| Metadata                       | Read-only      | Mandatory                                 |
| Administration                 | Read and Write | For modifying Repo settings and Rulesets  |
| Contents                       | Read and Write | For reading Ref and Git information       |
| Repository security advisories | Read and Write | For managing security advisories          |
| Dependabot alerts              | Read and Write | For managing dependency alerts            |
| Secrets                        | Read and Write | (Optional) for managing Actions Secrets   |
| Variables                      | Read and Write | (Optional) for managing Actions Variables |
| Webhooks                       | Read and Write | (Optional) for managing Webhooks          |
