# Initialization Order

> [!IMPORTANT]
> Initialization must be completed in the following order to ensure proper operation of this repo.

0. **Environment Variables File:** `entry.sh` automatically generates a `.env` file for internal shell script use. This file typically requires no manual intervention.
1. **SSH Key Generation:** SSH keys enable automated configuration by allowing services to authenticate with virtual machines during Terraform and Ansible execution. Use the _"Generate SSH Key"_ option in `./entry.sh` to create a key pair. The default name is `id_ed25519_on-premise-gitlab-deployment`, and keys are stored in the `~/.ssh/` directory.
2. **Hypervisor Baseline:** Required before provisioning. Role `hypervisor_baseline` of `platform-foundation` configures the libvirt socket permissions and the host kernel tuning. See [Hypervisor Kernel Tuning](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation/-/blob/main/documentation/architecture/hypervisor-kernel-tuning.md).
3. **[Vault Secrets](../configuration/vault-secrets.md)**: Inject the secrets which this repository reads from the Bastion Vault and the Downstream Vault.
4. **[Terraform Variables](../configuration/terraform-variables.md)**: Initialize `.tfvars` files for each layer.
5. **Packer Images**: Build the Gitaly and Praefect image on top of the distro image of `platform-foundation`. See [Packer Build](../operations/packer-build.md).
6. **Terraform Layers**: Provision infrastructure layer by layer. See [Deployment Order](03-deployment-order.md).
7. **[Trust Store](../configuration/trust-store.md)**: Export service certificates to the host OS.

## GitLab.com Project Governance

> [!NOTE]
> The `terraform/layers/administration-gitlab-project` layer manages the GitLab.com project of this repository (project settings, branch protection, code reviewer variables, and workload identity federation bindings). This layer targets the **GitLab.com project**, not the on-premise GitLab instance deployed by this project.

The layer requires no personal access token of its own:

1. The GitLab provider token is read from `secret/parent-group-governance/terraform/state-backend` in the Bastion Vault.
2. The Bastion Vault login runs through the governance Vault Proxy of `parent-group-governance`, which the `.envrc` of the layer loads with `eval "$(vault-proxy-env governance)"` after one `direnv allow`.
3. The HTTP backend credentials come from `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD`, which the same `.envrc` exports.
4. The workload identity federation bindings require an Anthropic `org:admin` OAuth token in `ANTHROPIC_AUTH_TOKEN`, which is not stored in Vault.
