# Initialization Order

> [!IMPORTANT]
> Initialization must be completed in the following order to ensure proper operation of this repo.

0. **Environment Variables File:** `entry.sh` automatically generates a `.env` file for internal shell script use. This file typically requires no manual intervention.
1. **SSH Key Generation:** SSH keys enable automated configuration by allowing services to authenticate with virtual machines during Terraform and Ansible execution. Use option `5` _"Generate SSH Key"_ in `./entry.sh` to create a key pair. The default name is `id_ed25519_on-premise-gitlab-deployment`, and keys are stored in the `~/.ssh/` directory.
2. **Environment Switching:** Option `9` in `./entry.sh` toggles between "Container" and "Native" environments. See [Environment Setup](02-environment-setup.md) for details.
3. **[Host Kernel Tuning](../configuration/kernel-tuning.md)**: Required before provisioning. Configures asymmetric routing support, bridge netfilter bypass, and MTU/MSS settings.
4. **[Vault Secrets](../configuration/vault-secrets.md)**: Configure Bootstrapper Vault and inject all required secrets.
5. **[Terraform Variables](../configuration/terraform-variables.md)**: Initialize `.tfvars` files for each layer.
6. **Packer Images**: Build base and service images. See [Packer Build](../operations/packer-build.md).
7. **Terraform Layers**: Provision infrastructure layer by layer. See [Deployment Order](04-deployment-order.md).
8. **[Trust Store](../configuration/trust-store.md)**: Export service certificates to the host OS.

## GitHub Credentials for Self-Management

> [!NOTE]
> This repo utilizes [Terraform GitHub Integration](https://registry.terraform.io/providers/integrations/github/latest) by default for repository management. Consequently, a Fine-grained Personal Access Token must be configured. If the cloned repo is not managed via this integration, the `terraform/layers/90-github-meta` layer may be skipped or deleted without affecting subsequent operations.

1. Navigate to [GitHub Developer Settings](https://github.com/settings/personal-access-tokens) to generate a Fine-grained Personal Access Token.
2. Click `Generate new token` and specify the token name, expiration period, and repository access scope.
3. In the Permissions section, configure the following:

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

4. Click `Generate token` and save the value for the following steps.

## GitLab.com Credentials for Mirror Management

> [!NOTE]
> This repo includes a `terraform/layers/90-meta-gitlab` layer that manages the GitLab.com mirror repository configuration (project settings, branch protection) via the `gitlabhq/gitlab` provider. This layer targets the **GitLab.com mirror**, not the on-premise GitLab instance deployed by this project. If the mirror is not managed via this integration, this layer may be skipped or deleted without affecting subsequent operations.

1. Navigate to [GitLab Access Tokens](https://gitlab.com/-/user_settings/personal_access_tokens) to generate a Personal Access Token.
2. Click `Add new token` and specify the token name and expiration date.
3. Configure the following scope:

    | Scope | Description                                                           |
    | ----- | --------------------------------------------------------------------- |
    | `api` | Full API access — required for project settings and branch protection |

4. Click `Create personal access token` and save the value.
5. Store the token in Bootstrapper Vault:

    ```bash
    vault kv put \
        -address="https://127.0.0.1:8200" \
        -ca-cert="${PWD}/vault/tls/ca.pem" \
        secret/on-premise-gitlab-deployment/project_meta \
        gitlab_pat="<your-token>"
    ```
