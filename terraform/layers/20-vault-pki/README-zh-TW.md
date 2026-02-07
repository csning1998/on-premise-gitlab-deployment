# Service Catalog Definition

Refer to [README.md](README.md) for English (US) version.

## Overview

**Service Catalog** 是整個基礎設施安全與身分架構的**單一事實來源（Single Source of Truth, SSoT）**，主要是定義在整個基礎設施中的每個服務的**身分（Identity）**、**執行環境（Runtime Environment）**、**生命週期階段（Lifecycle Stage）** 以及**相依鏈（Dependency Chain）**。

這個目錄會自動產生以下資源：

1. **Vault PKI 角色**：針對內部組件與外部相依服務
2. **憑證存活時間（TTL） 策略**：基於生命週期階段的 TTL 設定
3. **憑證中注入原始資料**：在憑證中注入組織單位（OU）以供日後稽核

## Schema Reference

這個目錄結構是服務物件的映射（Map），有以下欄位定義每個服務的核心屬性：

| 欄位               | 說明                                                                     | 目的（架構維度）                                                                      |
| ------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| **`runtime`**      | 託管服務的基礎設施（例如：`kubeadm`, `microk8s`, `docker`, `baremetal`） | **服務多態性**：相同的服務身分在不同的基礎設施上執行                                  |
| **`stage`**        | 服務的生命週期環境（例如：`production`, `development`, `staging`）       | **Policy-as-Code**：決定憑證的 TTL（例如：`production` = 1 年，`development` = 1 天） |
| **`components`**   | 需要前端/入口（Ingress） 憑證的服務內部組件                              | **入口/存取控制**：生成如 `gitlab-frontend-role` 等角色                               |
| **`dependencies`** | 運行所需外部後端服務（例如：Postgres, Redis）                            | **相依組合**：定義垂直技術堆疊並生成如 `gitlab-postgres-role` 等角色                  |

---

## Registered Services

目前目錄內已定義以下服務：

### 1. GitLab Helm Chart

- **Identity**：`gitlab`
- **Context**：執行在 **Kubeadm** 上的生產環境工作負載
- **Access Points**：
    - 子網域：`gitlab`, `kas`, `minio`

- **Dependencies**：
    - 使用裸機（Baremetal）做為永久基礎設施
    - **Postgres**（執行環境：`baremetal`）
    - **Redis**（執行環境：`baremetal`）
    - **MinIO**（執行環境：`baremetal`）

### 2. Harbor (Production)

- **Identity**：`harbor`
- **Context**：執行在 **MicroK8s** 上的生產環境工作負載
- **Access Points**：
    - 子網域：`harbor`, `notary.harbor`

- **Dependencies**：
    - 使用裸機（Baremetal）做為永久基礎設施
    - **Postgres**（執行環境：`baremetal`）
    - **Redis**（執行環境：`baremetal`）
    - **MinIO**（執行環境：`baremetal`）

### 3. Harbor (Development)

- **Identity**：`dev-harbor`
- **Context**：執行在 **Docker** 主機上的開發環境工作負載
- **Access Points**：
    - 子網域：`dev-harbor`, `notary.dev-harbor`

- **Dependencies**：
    - **無**（獨立運行），使用內置/嵌入式資料庫，不會為後端服務生成外部 Vault 角色

## Automated Vault Behavior

基於上述組態，Layer 10 會自動設定以下資源：

### Role Naming Convention

Vault 角色的命名會遵循嚴格的命名模式，以確保基礎設施做遷移時，服務的身分保持一致：

- **命名格式**：`${service}-${component}-role`
- **範例**：`gitlab-postgres-role`（注意：`kubeadm` 或 `baremetal` 等環境名稱會被排除在命名之外）

### Certificate Metadata (OU Injection)

透過這些角色所核發的所有憑證，都會在 **組織單位（OU）** 欄位中包含特定原始資料，以供日後稽核需求使用：

- **GitLab 憑證**：`OU=production`, `OU=kubeadm`
- **Dev-Harbor 憑證**：`OU=development`, `OU=docker`

### TTL Policy Assignment

| Service Environment      | Max TTL | Default TTL |
| ------------------------ | ------- | ----------- |
| **Production Services**  | 1 Year  | 30 Days     |
| **Staging Services**     | 30 Days | 7 Days      |
| **Development Services** | 7 Days  | 1 Day       |
| **Default**              | 1 Day   | 1 Hour      |
