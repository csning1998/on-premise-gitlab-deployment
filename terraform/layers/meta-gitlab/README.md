# GitLab.com Meta Repository Management

This layer manages the GitLab.com mirror repository configuration (project settings, branch protection) via the `gitlabhq/gitlab` provider. It mirrors the structure of `90-meta-github` and authenticates to Bootstrap Vault using the same AppRole pattern established in Layer 15.

> [!NOTE]
> This layer targets the **GitLab.com mirror**, not the on-premise GitLab instance deployed by this project.

## Prerequisites

1. Generate a GitLab Personal Access Token
    1. Navigate to [GitLab Access Tokens](https://gitlab.com/-/user_settings/personal_access_tokens).
    2. Click `Add new token` and specify the token name and expiration date.
    3. Configure the following scope:

        | Scope | Description                                                           |
        | ----- | --------------------------------------------------------------------- |
        | `api` | Full API access — required for project settings and branch protection |

    4. Click `Create personal access token` and save the value.

2. Store the Token in Bootstrap Vault

    ```bash
    vault kv put \
    -address="https://127.0.0.1:8200" \
        -ca-cert="${PWD}/vault/tls/ca.pem" \
        secret/on-premise-gitlab-deployment/project_meta \
        gitlab_pat="<your-token>"
    ```

3. Usage
    1. Import the existing repository (first-time only)

        ```bash
        terraform import gitlab_project.this <ID>/on-premise-gitlab-deployment
        ```

    2. Execute Terraform

        ```bash
        terraform plan
        terraform apply
        ```
