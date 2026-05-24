# Harbor Bootstrapper: Helm Chart OCI Sync

> [!NOTE]
> The following has been integrated into `40-provision-harbor-bootstrapper-frontend` via the Ansible Provider. Executing `terraform apply` automates the requirements described below.

Since Helm Charts related to Layer 50 consistently utilize OCI to connect with Bootstrapper Harbor, it is necessary to first `helm pull` the relevant artifacts from remote repositories and push them to Bootstrapper Harbor. Ensure that `30-infra-harbor-bootstrapper-frontend` and `40-provision-harbor-bootstrapper-frontend` have been executed successfully.

## Steps

1. **Environment Variables and Login**

    ```bash
    export VAULT_ADDR="https://172.16.136.250:443"
    export VAULT_SKIP_VERIFY=true

    ROLE_ID=$(sudo cat /etc/vault.d/approle/role_id)
    SECRET_ID=$(sudo cat /etc/vault.d/approle/secret_id)

    export HARBOR_REGISTRY="harbor-bootstrapper.production.iac.internal"
    export VAULT_TOKEN=$(vault write -field=token auth/workload-approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
    vault kv get -field=password_pusher secret/on-premise-gitlab-deployment/harbor-bootstrapper/robot | \
    helm registry login "$HARBOR_REGISTRY" -u 'robot$helm-charts+helm-pusher' --password-stdin
    ```

2. Pull relevant Helm Charts for this project; these are the versions currently in use:

    ```bash
    helm pull ingress-nginx --version 4.10.0 --repo https://kubernetes.github.io/ingress-nginx
    helm pull ingress-nginx --version 4.13.1 --repo https://kubernetes.github.io/ingress-nginx
    helm pull metrics-server --version 3.13.0 --repo https://kubernetes-sigs.github.io/metrics-server/
    helm pull oci://quay.io/jetstack/charts/cert-manager --version v1.14.0
    helm pull oci://ghcr.io/rancher/local-path-provisioner/charts/local-path-provisioner --version 0.0.35
    helm pull gitlab --version 9.8.2 --repo https://charts.gitlab.io/
    helm pull tigera-operator --version v3.28.0 --repo https://docs.tigera.io/calico/charts
    helm pull harbor --version 1.18.0 --repo https://helm.goharbor.io
    ```

3. Push the retrieved artifacts to the `helm-charts` (default) Proxy Project:

    ```bash
    helm push ingress-nginx-4.10.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push ingress-nginx-4.13.1.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push metrics-server-3.13.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push cert-manager-v1.14.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push local-path-provisioner-0.0.35.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push gitlab-9.8.2.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push tigera-operator-v3.28.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    helm push harbor-1.18.0.tgz oci://"$HARBOR_REGISTRY"/helm-charts
    ```

4. Subsequently, Layer 50 Helm Charts can be executed.

> [!NOTE]
> To use remote sources, typically the `repository` and `chart` information for each Helm Chart Module in the `terraform/modules/kubernetes-addons` path must be configured. Refer to the [code record](https://github.com/csning1998/on-premise-gitlab-deployment/tree/018233b3032e517b43e52fc4e17bcd3dde7cf52f/terraform/modules/kubernetes-addons) from #96.
