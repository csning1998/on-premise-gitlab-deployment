# Trust Store and Certificate Export

Exporting service certificates allows users to browse the following services directly from the Host side without certificate errors:

- Prod Vault: `https://vault.production.iac.internal`
- Harbor: `https://harbor.production.iac.internal`
- Harbor MinIO Console: `https://minio.harbor.production.iac.internal`
- GitLab: `https://gitlab.production.iac.internal`
- GitLab MinIO Console: `https://minio.gitlab.production.iac.internal`

This requires two steps in sequence:

## 1. DNS Resolution (`/etc/hosts`)

Handle DNS resolution in `/etc/hosts` by adding the following content (default for this repo) to the host's `/etc/hosts`. Note that this should be adjusted according to the actual IPs output by Terraform.

```text
172.16.126.250  gitlab.production.iac.internal
172.16.131.250  harbor.production.iac.internal notary.harbor.production.iac.internal
172.16.136.250  vault.production.iac.internal
172.16.135.250  minio.harbor.production.iac.internal core-harbor-minio.production.iac.internal
172.16.130.250  minio.gitlab.production.iac.internal core-gitlab-minio.production.iac.internal
```

## 2. Import Trust Bundle

Since this repo has already aggregated the Infrastructure CA and Service CA into a single `trust-bundle.crt` in L25, the Host can trust these two independent certificate roots simultaneously. Refer to the content of _Step B.5_. The aggregated certificate file can now be confirmed in the `terraform/layers/25-security-pki/tls/` path.

Execute the following command to import both CAs into the operating system:

- **RHEL / CentOS / Fedora:**

    ```bash
    sudo cp terraform/layers/25-security-pki/tls/trust-bundle.crt /etc/pki/ca-trust/source/anchors/on-premise-gitlab-pki-bundle.crt
    sudo update-ca-trust
    ```

- **Ubuntu / Debian:**

    ```shell
    sudo cp terraform/layers/25-security-pki/tls/trust-bundle.crt /usr/local/share/ca-certificates/on-premise-gitlab-pki-bundle.crt
    sudo update-ca-certificates
    ```

## 3. Verification

Verify the Trust Store configuration by testing connectivity to MinIO from the host. This mainly verifies that the host trusts the Service CA. For example:

```shell
curl -I https://minio.harbor.production.iac.internal:9000/minio/health/live
```

If it outputs `HTTP/1.1 200 OK`, it means the Trust Store is correctly configured.

Access Harbor from the host to verify the Trust Store:

```shell
curl -vI https://harbor.production.iac.internal
```

If it displays `SSL certificate verify ok` and `HTTP/2 200`, it means the full PKI Chain—spanning Vault certificate issuance, cert-manager signing, Ingress deployment, and host-level trust—is successfully established.

Another verification method is directly through the GUI to access the corresponding locations.
