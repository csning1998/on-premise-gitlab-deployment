# Verification of Harbor Functionality with Client Trust

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan)

This document describes the procedure for configuring client-side trust for a self-signed CA and verifying the Harbor Container Registry functionality, including the write status of the MinIO backend.

## Export and Set Root CA Trust on Client Side

Since the Harbor Ingress certificate is a self-signed certificate issued by Layer 20 (Vault PKI), the host executing Podman or Docker (the client) must add the Root CA to its trust list. Failure to do so will result in an `x509: certificate signed by unknown authority` error during login.

1. The Root CA content can be exported as a file using the `vault-pki-setup` module.

    ```bash
    cd path/to/vault-pki-setup
    ```

2. Export the certificate content from the Terraform output.

    ```bash
    terraform output -raw root_ca_certificate > ca.crt
    ```

3. Podman in Rootless mode automatically reads configurations under `~/.config/containers/certs.d/`. It is critical that the directory name matches the Harbor Hostname (`harbor.iac.local`) **exactly**.

    ```bash
    mkdir -p ~/.config/containers/certs.d/harbor.iac.local
    ```

    Subsequently, copy the certificate to this directory and verify the file's existence using `ls -la`.

    ```bash
    cp ca.crt ~/.config/containers/certs.d/harbor.iac.local/ca.crt
    ls -la ~/.config/containers/certs.d/harbor.iac.local
    ```

## Verify Podman Push Image to Harbor

The complete write path to be tested is: `Client -> Ingress (TLS) -> Harbor Core -> Registry -> MinIO (S3)`.

1. Log in to Harbor using the `admin` account and the password defined in Vault (`harbor_admin_password`).

    ```bash
    podman login harbor.iac.local --username admin
    ```

    _(Expected result: Login Succeeded!)_

2. A lightweight image can then be pulled, tagged, and pushed to the `gitlab-registry` project previously declared in the `harbor-system-config` module.

    ```bash
    podman pull docker.io/library/alpine:latest
    ```

3. Apply the tag, ensuring the format follows: `harbor.iac.local/<project_name>/<image_name>:<tag>`.

    ```bash
    podman tag docker.io/library/alpine:latest harbor.iac.local/gitlab-registry/alpine:test-v1
    ```

4. Execute the push command.

    ```bash
    podman push harbor.iac.local/gitlab-registry/alpine:test-v1
    ```

    _Expected result:_

    ```text
    Getting image source signatures
    Copying blob 989e799e6349 done   |
    Copying config a40c03cbb8 done   |
    Writing manifest to image destination
    ```

## Verify MinIO Verification

1. Confirmation is required to ensure Harbor successfully wrote the Image Layers and Manifests to the backend S3 Object Storage. Use the MinIO Client (`mc`) to inspect the bucket contents.

2. Configure the MinIO connection alias. If MinIO uses a self-signed certificate, the `--insecure` flag must be included.
    - Adjust the `Endpoint` according to the actual environment (e.g., `https://172.16.139.200:9000`).
    - Refer to `object_storage_config` in `terraform.tfvars` or the `harbor_minio_admin` password in Vault for `Credentials`.

    ```bash
    mc alias set --insecure myminio https://172.16.139.200:9000 harbor_minio_admin <YOUR_MINIO_PASSWORD>
    ```

3. Verify the connection status.

    ```bash
    mc --insecure admin info myminio
    ```

    The output should appear as follows:

    ```text
    ●  172.16.139.200:9000
        Uptime: 1 hour
        Version: <development>
        Network: 1/1 OK
        Drives: 2/2 OK
        Pool: 1

    ┌──────┬───────────────────────┬─────────────────────┬──────────────┐
    │ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
    │ 1st  │ 0.2% (total: 9.9 GiB) │ 2                   │ 1            │
    └──────┴───────────────────────┴─────────────────────┴──────────────┘

    0.1 MiB Used, 1 Bucket, 0 Objects
    2 drives online, 0 drives offline, EC:1
    ```

4. Inspect the bucket used by Harbor (`harbor-registry`) for the generation of corresponding files.

    ```bash
    mc ls -r myminio/harbor-registry/docker/registry/v2/repositories/gitlab-registry/alpine/
    ```

    The directory structure should be visible, containing `_manifests` and `_layers`:

    ```text
    [2026-02-08 01:37:17 CST]    71B STANDARD _layers/sha256/9da841cba2d188205a2fa437c08e0f3819d6de84dae71e78e70515e282f44e6e/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _layers/sha256/a40c03cbb81c59bfb0e0887ab0b1859727075da7b9cc576a1cec2c771f38c5fb/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/revisions/sha256/b9fb982ba07e72e7f4c261a39ebc9f9e8ab4488d64cda3c52a96fc639fbddc8d/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/tags/test-v1/current/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/tags/test-v1/index/sha256/b9fb982ba07e72e7f4c261a39ebc9f9e8ab4488d64cda3c52a96fc639fbddc8d/link
    ```

5. Re-executing `mc --insecure admin info myminio` at this stage should show an increase in Drives Usage of approximately 3.8 MiB.
6. Finally, the Harbor GUI can be checked for new artifacts within the `gitlab-registry` project; their presence confirms that Harbor is operating correctly.
