# Deployment Order

Each layer reads prior layers' state via `terraform_remote_state`. Layers within the same phase can be applied in parallel unless noted otherwise.

---

## Pre-Flight

Before applying any Terraform layer, complete all steps in [Prerequisites](01-prerequisites.md), [Environment Setup](02-environment-setup.md), and [Initialization](03-initialization.md).

---

## Dependency Diagrams

Three left-to-right diagrams, each building on the previous stage.

---

### Stage 1 — Foundation

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Boot as Bootstrapper Vault (L00)
    participant Meta as Resource Metadata (L00)
    participant LV as Libvirt Volume & Network (L05)
    participant LB as Centralized Load Balancer (L10)
    participant Prod as Production Vault (L15-25)

    Note over User, Meta: [Stage 1: Foundation Bootstrapping]
    User->>Boot: 1. Init & Unseal Bootstrapper Vault (AppRole)
    Boot->>Boot: 2. Enable KV Engine & Write Static Secrets
    User->>Meta: 3. Provision Resource Metadata
    Meta->>Boot: 4. Auth via AppRole & Read Creds

    Note over User, LB: [Stage 1 cont.: Network & Load Balancer]
    User->>LV: 5. Provision Libvirt Volume & Network (L05)
    LV->>Boot: 6. Auth via AppRole & Read Metadata
    User->>LB: 7. Provision Centralized Load Balancer (L10)
    LB->>Boot: 8. Auth via AppRole & Read Network Config

    Note over User, Prod: [Stage 2: Production Vault Setup]
    User->>Prod: 9. Provision Vault Nodes (L15)
    Prod->>Prod: 10. Configure HA Raft Backend & Enable Engines
    User->>Prod: 11. Init & Unseal Production Vault Cluster
    User->>Prod: 12. Configure AppRole Auth & PKI Root CA (L20/25)
    User->>Prod: 13. Manually Inject Application Secrets
```

---

### Stage 2 — Harbor Bootstrapper Assembly

> All L30 VM layers follow the same pattern: authenticate to Production Vault via AppRole, then receive a TLS leaf certificate (auto-rotated by Vault Agent sidecar).

```mermaid
flowchart LR
    L25(["← L25 pki"])

    subgraph P2["Phase 2 — L30 First Wave (parallel)"]
        direction TB
        subgraph gl_db["GitLab Stateful Services"]
            gp["gitlab-postgres"]
            gr["gitlab-redis"]
            gm["gitlab-minio"]
            git["gitaly-praefect"]
        end
        subgraph hbr_db["Harbor Stateful Services"]
            hp["harbor-postgres"]
            hr["harbor-redis"]
            hm["harbor-minio"]
        end
        kc30["keycloak-frontend"]
        hbs30["harbor-bootstrapper-frontend"]
    end

    subgraph P3["Phase 3 — L40 First Wave"]
        kc40["keycloak-oidc<br/>Configure Realm + RBAC<br/>Register OIDC clients<br/>Write client secrets to Vault"]
        hbs40["harbor-bootstrapper-frontend<br/>Configure Harbor<br/>helm pull → helm push to OCI"]
        voidc["vault-oidc (L45)<br/>Bind Vault OIDC → Keycloak"]
    end

    seed(["Seed Registry ready →<br/>All Helm Charts available via OCI"])

    L25 --> P2
    kc30 --> kc40
    kc40 --> hbs40 & voidc
    hbs40 --> seed
```

---

### Stage 3 — Harbor + GitLab Deployment

```mermaid
flowchart LR
    hbs(["← L40 harbor-bootstrapper\nseed registry"])
    p2(["← Phase 2 DB VMs\ngitlab/harbor postgres, redis, minio"])

    subgraph P4["Phase 4 — L40 Database Provisioning (parallel)"]
        gldb["gitlab-databases\nPatroni + Sentinel + MinIO"]
        hbrdb["harbor-databases\nPatroni + Sentinel + MinIO"]
    end

    subgraph P5["Phase 5 — L30 K8s Clusters (parallel)"]
        glf30["gitlab-frontend\nKubeadm"]
        hbr30["harbor-frontend\nMicroK8s"]
    end

    run30["L30 gitlab-runner\nMicroK8s"]

    glf40["L40 gitlab-frontend\nProvision K8s cluster\nCNI / storage class / ingress"]

    subgraph P6["Phase 6 — L50 Platform Helm Deploy"]
        glf50["gitlab-frontend"]
        hbr50["harbor-frontend"]
        run50["gitlab-runner"]
    end

    manual(["Manual\nBootstrap GitLab Admin PAT"])

    subgraph P7["Phase 7 — L60 Application Provisioning"]
        gl60["provision-gitlab\nGroups / Users / OIDC\nKeycloak UUID anchors"]
        hbr60["provision-harbor\nProjects / Robot accounts\nOIDC linkage"]
    end

    p2 --> gldb & hbrdb
    hbs --> run30 & glf30 & hbr30
    gldb --> glf30 & glf40
    hbrdb --> hbr30 & hbr50
    glf30 --> glf40
    hbr30 --> hbr50
    glf40 --> glf50
    glf50 --> run50 & manual
    manual --> gl60
    hbr50 --> hbr60
```

---

## Notes

1. **Phase 8 — L90: Repository Meta (Optional)**

    `90-meta-github` and `90-meta-gitlab` can be applied at any point after Bootstrapper Vault is initialized. Both require a first-time `terraform import` before applying. See [GitHub Meta](../operations/github-meta.md) and [Initialization → GitLab.com Credentials](03-initialization.md#gitlabcom-credentials-for-mirror-management).

2. **L50 GitLab: `OpenSSL::Cipher::CipherError`**

    If this error occurs in the `gitlab-migrations` pod, see the [troubleshooting guide](../operations/troubleshooting.md#gitlab-application). Caused by `rails-secret` regeneration against a preserved database from a prior deployment.
