# Service Catalog Definition

> [!NOTE]
> Refer to [README-zh-TW.md](README-zh-TW.md) for Traditional Chinese (Taiwan) version.

## Overview

The **Service Catalog** serves as the **Single Source of Truth (SSoT)** for the entire infrastructure's security and identity architecture. It primarily defines the **identity**, **runtime environment**, **lifecycle stage**, and **dependency chain** for every service within the ecosystem.

The catalog automates the provisioning of the following resources:

1. **Vault PKI Roles**: Tailored for both internal components and external backing services.
2. **Certificate TTL Policies**: Time-To-Live strategies enforced based on the service's lifecycle stage.
3. **Metadata Injection**: Automated injection of **Organizational Unit (OU)** data into certificates for future auditing purposes.

## Schema Reference

The catalog is structured as a map of service objects. The following fields define the **Core Attributes** of each service:

| Field              | Description                                                                                             | Purpose (Architectural Dimension)                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **`runtime`**      | The technology infrastructure hosting the service (e.g., `kubeadm`, `microk8s`, `docker`, `baremetal`). | **Service Polymorphism**: Enables the same service identity to remain consistent across different infrastructure types. |
| **`stage`**        | The lifecycle environment (e.g., `production`, `development`, `staging`).                               | **Policy-as-Code**: Governs certificate TTL (e.g., `production` = 1 Year, `development` = 1 Day).                       |
| **`components`**   | Internal service parts requiring frontend or Ingress certificates.                                      | **Ingress/Access Control**: Facilitates the generation of specific roles, such as `gitlab-frontend-role`.               |
| **`dependencies`** | External backing services required for operation (e.g., Postgres, Redis).                               | **Dependency Composition**: Defines the vertical technology stack and generates roles like `gitlab-postgres-role`.      |

---

## Registered Services

The following services are currently defined in the catalog:

### 1. GitLab Helm Chart

- **Identity**: `gitlab`
- **Context**: Production workload running on a **Kubeadm** cluster.
- **Access Points**:
    - Subdomains: `gitlab`, `kas`, `minio`

- **Dependencies**:
    - Utilizes **Baremetal** infrastructure for persistent storage.
    - **Postgres** (Runtime: `baremetal`)
    - **Redis** (Runtime: `baremetal`)
    - **MinIO** (Runtime: `baremetal`)

### 2. Harbor (Production)

- **Identity**: `harbor`
- **Context**: Production workload running on a **MicroK8s** cluster.
- **Access Points**:
    - Subdomains: `harbor`, `notary.harbor`

- **Dependencies**:
    - Utilizes **Baremetal** infrastructure for persistent storage.
    - **Postgres** (Runtime: `baremetal`)
    - **Redis** (Runtime: `baremetal`)
    - **MinIO** (Runtime: `baremetal`)

### 3. Harbor (Development)

- **Identity**: `dev-harbor`
- **Context**: Development workload running on a **Docker** host.
- **Access Points**:
    - Subdomains: `dev-harbor`, `notary.dev-harbor`

- **Dependencies**:
    - **None** (Standalone). This service uses internal/embedded databases. No external Vault roles are generated for backing services.

## Automated Vault Behavior

Based on the configurations defined above, Layer 10 automatically provisions the following resources:

### Role Naming Convention

Vault Roles are generated using a strict naming pattern to ensure identity persistence during infrastructure migrations:

- **Naming Format**: `${service}-${component}-role`
- **Example**: `gitlab-postgres-role` (Note: Infrastructure-specific identifiers like `kubeadm` or `baremetal` are excluded from the role name).

### Certificate Metadata (OU Injection)

All certificates issued via these roles will include specific metadata in the **Organizational Unit (OU)** field to meet auditing requirements:

- **GitLab Certs**: `OU=production`, `OU=kubeadm`
- **Dev-Harbor Certs**: `OU=development`, `OU=docker`

### TTL Policy Assignment

| Service Environment      | Max TTL | Default TTL |
| ------------------------ | ------- | ----------- |
| **Production Services**  | 1 Year  | 30 Days     |
| **Staging Services**     | 30 Days | 7 Days      |
| **Development Services** | 7 Days  | 1 Day       |
| **Default**              | 1 Day   | 1 Hour      |
