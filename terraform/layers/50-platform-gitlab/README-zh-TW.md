# How to Resolve GitLab `OpenSSL::Cipher::CipherError` Error

## Problem Description

當 GitLab 內部的一些機敏資訊，特別是 `rails-secret` / `db_key_base` 等，在還沒有清除持久性 PostgreSQL 資料庫的狀況下進行重新產生時，應用程式會出現無法解密現有資料（例如：使用者權杖或應用程式設定）的情境，從而導致在執行資料遷移或登入時發生 `OpenSSL::Cipher::CipherError` 錯誤

## Root Cause

- **狀態重新產生**：在保留 `40-provision-gitlab-databases` 層（Postgres 持久性資料）的同時，對 `50-platform-gitlab` 執行 `tofu destroy && tofu apply`，導致 `random_password` 資源被銷毀並重新建立
- **加密密鑰不匹配**：`tofu apply` 會重建 `random_password.gitlab_internal["rails-secret"]` 資源，使得 Vault KV 中的 `rails_secret_key` 產生全新的值；但 Postgres 裡面的 `users`、`application_settings` 等資料表的加密欄位還是用舊的密碼加密的密文，導致 Rails 在應用層解密時失敗。這問題不在資料庫連線驗證

## Resolution Steps

### Step A. Identify the Mismatch

檢查 `gitlab-migrations` pod 的紀錄，如果出現以下錯誤，就代表目前狀態下的密碼錯誤：

```text
OpenSSL::Cipher::CipherError
/srv/gitlab/vendor/bundle/ruby/3.2.0/gems/encryptor-3.0.0/lib/encryptor.rb:98:in `final'
```

### Step B. Wipe Persistent Database Residue

由於新的密碼已重新產生，如果在沒有舊密鑰的情況下，資料庫中的任何現有資料都無法復原。因此這時候就必須要清除資料庫，才能讓 Migration 重新執行初始化

1. 先切換到專案根目錄
2. 刪除並重新建立 Postgres 資料庫

    ```bash
    export PG_SUPERUSER_PASSWORD=$(VAULT_ADDR="https://172.16.136.250:443" VAULT_CACERT="${PWD}/terraform/layers/15-shared-vault-frontend/tls/bootstrap-ca.crt" VAULT_TOKEN=$(VAULT_ADDR="https://127.0.0.1:8200" VAULT_CACERT="${PWD}/vault/tls/ca.pem" VAULT_TOKEN=$(cat $HOME/.vault-token) vault kv get -field=prod_vault_root_token secret/on-premise-gitlab-deployment/credentials) vault kv get -field=pg_superuser_password secret/on-premise-gitlab-deployment/gitlab/databases)

    ssh core-gitlab-postgres-node-00 'psql -h 172.16.127.200 -U postgres -d postgres -c "DROP DATABASE gitlabhq_production WITH (FORCE);"'
    ssh core-gitlab-postgres-node-00 'psql -h 172.16.127.200 -U postgres -d postgres -c "CREATE DATABASE gitlabhq_production OWNER gitlab;"'
    ```

3. 重新套用 GitLab 平台層 `50-platform-gitlab`，以使用**新**的機密資訊來建立資料結構描述並植入初始資料。

    ```bash
    tofu destroy -auto-approve && tofu apply -auto-approve
    ```

### Step C. Verification

1. 先確定 `kubectl get pods -n gitlab -l app=migrations -w` 沒有出現密碼錯誤
2. 使用 `root` 帳號以及新密碼登入 GitLab Web UI

## Prevention

- **狀態持久性**：除非有打算完全清除環境，否則應避免刪除 Layer 50 的 `terraform.tfstate`
- **Vault 版本控制**：如果發生狀態遺失，那在重新套用之前，建議先嘗試從 Vault KV-V2 歷史紀錄中復原舊的 `rails-secret`；否則請準備清除資料庫
