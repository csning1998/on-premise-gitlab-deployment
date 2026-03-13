# Verification of Harbor Functionality with Client Trust

> [!NOTE]
> Refer to [README.md](README.md) for English (US) version.

這份文件在說明要如何在客戶端機器（Client）設定對自簽 CA 的信任，並驗證 Harbor 的 Container Registry 功能以及後端 MinIO 的寫入狀態

## Export and Set Root CA Trust on Client Side

因為 Harbor 的 Ingress 憑證是由 Layer 20（Vault PKI）簽發的自簽憑證，因此執行 Podman 或 Docker 的主機即 client 必須將該 Root CA 加入信任清單，否則在執行登入時會出現 `x509: certificate signed by unknown authority` 錯誤

1.  可以讓 CA Cert 輸出在 `vault-pki-setup` 模組中，將 Root CA 的內容匯出為檔案

    ```bash
    cd path/to/vault-pki-setup
    ```

2.  從 Terraform 輸出中匯出憑證內容

    ```bash
    terraform output -raw root_ca_certificate > ca.crt
    ```

3.  在 Rootless 下的 Podman 會自動讀取 `~/.config/containers/certs.d/` 下的設定，而必須注意目錄名稱必須與 Harbor 的 Hostname（`harbor.iac.local`）**完全一致**

    ```bash
    mkdir -p ~/.config/containers/certs.d/harbor.iac.local
    ```

    隨後複製憑正到該目錄，並透過 `ls -la` 確認檔案是否存在

    ```bash
    cp ca.crt ~/.config/containers/certs.d/harbor.iac.local/ca.crt
    ls -la ~/.config/containers/certs.d/harbor.iac.local
    ```

## Verify Podman Push Image to Harbor

測試完整的寫入路徑為 `Client -> Ingress (TLS) -> Harbor Core -> Registry -> MinIO (S3)`。

1.  使用 `admin` 帳號與 Vault 中設定的密碼（`harbor_admin_password`）登入 Harbor

    ```bash
    podman login harbor.iac.local --username admin
    ```

    _（預期結果為 Login Succeeded!）_

2.  接下來可以 pull 一個輕量級 Image，標記後推送到已經在 `harbor-system-config` 模組中宣告的 `gitlab-registry` 專案內

    ```bash
    podman pull docker.io/library/alpine:latest
    ```

3.  隨後做 Tag，注意格式為 `harbor.iac.local/<project_name>/<image_name>:<tag>`

    ```bash
    podman tag docker.io/library/alpine:latest harbor.iac.local/gitlab-registry/alpine:test-v1
    ```

4.  隨後即可做 Push

    ```bash
    podman push harbor.iac.local/gitlab-registry/alpine:test-v1
    ```

    _預期結果為：_

    ```text
    Getting image source signatures
    Copying blob 989e799e6349 done   |
    Copying config a40c03cbb8 done   |
    Writing manifest to image destination
    ```

## Verify MinIO Verification

1. 接下來要確認 Harbor 是否確實將 Image Layer 與 Manifest 寫入後端的 S3 Object Storage 中。使用 MinIO Client（`mc`）檢查 Bucket 內容

2. 隨後設定 MinIO 連線別名 `alias`。若 MinIO 使用自簽憑證需加 `--insecure`
    - `Endpoint` 請依實際環境調整（如 `https://172.16.139.200:9000`）
    - `Credentials` 參考 `terraform.tfvars` 中的 `object_storage_config` 或 Vault 內的 `harbor_minio_admin` 密碼

    ```bash
    mc alias set --insecure myminio https://172.16.139.200:9000 harbor_minio_admin <YOUR_MINIO_PASSWORD>
    ```

3. 驗證連線狀態

    ```bash
    mc --insecure admin info myminio
    ```

    輸出應如下

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

4. 檢查 Harbor 使用的 Bucket（`harbor-registry`）是否有對應的檔案產生

    ```bash
    mc ls -r myminio/harbor-registry/docker/registry/v2/repositories/gitlab-registry/alpine/
    ```

    應看到類似以下的目錄結構，包含 `_manifests` 與 `_layers`：

    ```text
    [2026-02-08 01:37:17 CST]    71B STANDARD _layers/sha256/9da841cba2d188205a2fa437c08e0f3819d6de84dae71e78e70515e282f44e6e/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _layers/sha256/a40c03cbb81c59bfb0e0887ab0b1859727075da7b9cc576a1cec2c771f38c5fb/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/revisions/sha256/b9fb982ba07e72e7f4c261a39ebc9f9e8ab4488d64cda3c52a96fc639fbddc8d/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/tags/test-v1/current/link
    [2026-02-08 01:37:17 CST]    71B STANDARD _manifests/tags/test-v1/index/sha256/b9fb982ba07e72e7f4c261a39ebc9f9e8ab4488d64cda3c52a96fc639fbddc8d/link
    ```

5. 這時候重新執行 `mc --insecure admin info myminio` 後，即可看到 Drives Usage 增加 3.8 MiB 左右
6. 接下來可以回到 Harbor GUI 查看 `gitlab-registry` 專案中是否有新的 Artifact，若有即代表 Harbor 運作正常
