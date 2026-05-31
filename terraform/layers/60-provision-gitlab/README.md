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
    vault kv get -mount="secret" "on-premise-gitlab-deployment/gitlab/app/pat"
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
    vault kv patch -mount="secret" "on-premise-gitlab-deployment/gitlab/app/pat" token="glpat-..."
    ```

> [!TIP]
> Updating the token in Vault allows the use of ephemeral resources so that the token is not stored in plaintext in the Terraform state file.

### Establishing Users

Refer to `terraform/layers/40-provision-keycloak-oidc/terraform.tfvars.example` to configure and create initial users.

## Harbor CI Registry Credentials

Each team subgroup receives the credentials of its dedicated Harbor `ci-{team}` robot as group level CI/CD variables. A pipeline running under a team subgroup authenticates to Production Harbor as that robot and pushes images into the matching `team-{name}` project. The robot accounts and their Vault entries are created by `60-provision-harbor`, so that layer must be applied before this one.

Teams are the subgroups under the target org whose Keycloak `type` attribute is `team`. Role groups such as `dev-leads` have no Harbor robot and are excluded. The variables are provisioned by `resources-harbor-ci-vars.tf`, which reads each robot from Vault and sets two group variables.

- `CI_REGISTRY_USER` holds the robot name such as `robot$ci-infra`. It is created with `raw = true` so GitLab does not treat the dollar sign as a variable reference and corrupt the value at job runtime. The robot name is not secret so it is left unmasked.
- `CI_REGISTRY_PASSWORD` holds the robot secret. It is masked and also uses `raw = true`.

Both variables are left unprotected so that merge request and feature branch pipelines can authenticate, not only pipelines that run on protected branches.

## Push Repository to GitLab

To import an existing project (e.g., `test-repo`) to the on-premise GitLab instance, configure the local environment for DNS resolution, trust the self-signed PKI certificate chain, and push using OIDC credentials.

1.  **DNS Resolution**

    Add a static mapping in your local `/etc/hosts` file to resolve the GitLab domain to the load balancer VIP:

    ```text
    <GITLAB_VIP> gitlab.production.iac.internal
    ```

    Default VIP of GitLab is `172.16.126.250`

2.  **TLS Certificate Trust**

    Since the GitLab instance uses a private certificate chain signed by the Vault PKI, the PKI trust-bundle must be trusted locally:

    ```bash
    sudo cp /path-to-repo/terraform/layers/25-security-pki/tls/trust-bundle.crt /etc/pki/ca-trust/source/anchors/on-premise-gitlab-pki-bundle.crt
    sudo update-ca-trust
    ```

    Under typical Linux/Unix environments, `update-ca-trust` automatically imports the certificate chain into the system-wide certificate store. Most standard command-line tools (such as `curl` and `git`) automatically trust the GitLab domain.

    If the Git client still reports self-signed certificate errors, Git can be configured to explicitly trust the bundle for the GitLab domain:

    ```bash
    git config --global http.https://gitlab.production.iac.internal/.sslCAInfo "/etc/pki/ca-trust/source/anchors/on-premise-gitlab-pki-bundle.crt"
    ```

3.  **Local Repository Setup & Push**

    Within the local repository directory, the remote URL is configured and pushed:
    1. A blank project with the same name must first be created in the GitLab Web UI.
    2. The local repository is initialized and pushed:

        ```bash
        git init --initial-branch=main
        git add .
        git commit -m "initial commit"
        git remote add origin https://gitlab.production.iac.internal/group/team/test-repo.git
        git push -u origin main
        ```

    The structure of Groups and Teams can be configured by referring to the RBAC guidelines documented in [`OIDC README.md`](../40-provision-keycloak-oidc/README.md). If following the configurations in [`OIDC terraform.tfvars.example`](../40-provision-keycloak-oidc/terraform.tfvars.example), when an account belongs to the `infra` group under the `engineering` team, the corresponding repository path is: `https://gitlab.production.iac.internal/engineering/infra/test-repo.git`

### [Recommand] SSH Key Authentication Setup

Since the public Keepalived VIP (`172.16.126.250`) on port 22 is occupied by the host's standard SSH daemon, the GitLab SSH Shell is exposed via K8s NodePort **`32022`** on the physical node IPs (e.g. Master `172.16.126.200`).

To bypass connection issues and achieve seamless, password-free Git operations via SSH:

1. **Generate SSH Key for GitLab**: Generate an SSH keypair for the repository similar to the approach used for GitHub. It is assumed that the public key is named `id_ed25519_test_on_prem_gitlab_repo.pub` and has already been added under the _User Settings > SSH Keys_ path in the GitLab Frontend GUI.

2. **Configure Local SSH Clients**: Add the following snippet to your local `~/.ssh/config` to redirect traffic automatically:

    ```text
    Host gitlab.production.iac.internal
        HostName 172.16.126.200
        Port 32022
        User git
        IdentityFile ~/.ssh/id_ed25519_test_on_prem_gitlab_repo
        IdentitiesOnly yes
    ```

3. **Add SSH Key to GitLab**: Copy the content of your public key (`~/.ssh/id_ed25519_test_on_prem_gitlab_repo.pub`) and paste it into **User Settings -> SSH Keys** in the GitLab Web UI.

4. **Configure Git Remote URL**: Set or switch the local Git remote to use SSH format (thanks to the SSH config, you don't need to specify the port in the git URL):

    ```bash
    git remote add origin git@gitlab.production.iac.internal:engineering/infra/test-repo.git
    git remote set-url origin git@gitlab.production.iac.internal:engineering/infra/test-repo.git
    ```

5. **Verify Connection**
   Test the handshake connection via:

    ```bash
    ssh -T git@gitlab.production.iac.internal
    ```

    Expected output: `Welcome to GitLab, @username!`

> [!TIP]
> When prompted for credentials during HTTPS push, authentication is supported directly using the Keycloak OIDC username and password, or a Personal Access Token (PAT) generated via the GitLab UI.

### If GitLab is Redeployed

If the `gitlab-shell` service within Kubernetes is redeployed, it will naturally generate a brand-new SSH host key. Consequently, if the cache on your development host contains the SSH fingerprint of the old container, SSH will reject the handshake out of security precautions. You can clear the stale key cache by running the following command:

```bash
ssh-keygen -f "/path/to/.ssh/known_hosts" -R "[<gitlab-vip>]:<gitlab-shell-NodePort>"
```

Where:

- `gitlab-vip` defaults to `172.16.126.250`
- `gitlab-shell-NodePort` defaults to `32022`
