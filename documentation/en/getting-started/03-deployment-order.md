# Deployment Order

Each layer reads prior layers' state via `terraform_remote_state`. Layers within the same phase can be applied in parallel unless noted otherwise.

---

## Pre-Flight

Before applying any Terraform layer, complete all steps in [Prerequisites](01-prerequisites.md) and [Initialization](02-initialization.md).

---

## Dependency Diagrams

Three left-to-right diagrams, each building on the previous stage.

---

### Stage 1: Upstream Prerequisites and Foundation

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Bastion as Bastion Vault (parent-group-governance)
    participant Platform as platform-foundation (Downstream Vault, Harbor Origin, Keycloak)
    participant Found as foundation-libvirt-resources

    Note over User, Platform: [Stage 1: Upstream Prerequisites]
    User->>Bastion: 1. Confirm Bastion Vault is unsealed
    User->>Platform: 2. Confirm Downstream Vault, Harbor Origin, and Keycloak are running

    Note over User, Found: [Stage 1 cont.: Foundation]
    User->>Found: 3. Provision Libvirt Networks, Storage Pools, and Data Disks
    Found->>Platform: 4. Read Network Baseline and Domain Suffix
```

---

### Stage 2: Stateful Services

> All `infra-*` VM layers follow the same pattern: authenticate to the Downstream Vault, then receive a TLS leaf certificate (auto-rotated by Vault Agent sidecar).

```mermaid
flowchart LR
    found(["from foundation-libvirt-resources"])

    subgraph P2["Phase 2: infra-* First Wave (parallel)"]
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
    end

    found --> P2
```

---

### Stage 3: Harbor + GitLab Deployment

```mermaid
flowchart LR
    hbs(["From Harbor Origin\n(platform-foundation)"])
    p2(["From Phase 2 DB VMs\ngitlab/harbor postgres, redis, minio"])

    subgraph P4["Phase 4: provision-* Database Provisioning (parallel)"]
        gldb["gitlab-databases\nPatroni + Sentinel + MinIO"]
        hbrdb["harbor-databases\nPatroni + Sentinel + MinIO"]
    end

    subgraph P5["Phase 5: infra-* K8s Clusters (parallel)"]
        glf30["gitlab-frontend\nKubeadm"]
        hbr30["harbor-frontend\nMicroK8s"]
    end

    run30["infra-* gitlab-runner\nMicroK8s"]

    glf40["provision-* gitlab-frontend\nProvision K8s cluster\nCNI / storage class / ingress"]

    subgraph P6["Phase 6: platform-*-frontend Helm Deploy"]
        glf50["gitlab-frontend"]
        hbr50["harbor-frontend"]
        run50["gitlab-runner"]
    end

    manual(["Manual\nBootstrap GitLab Admin PAT"])

    subgraph P7["Phase 7: platform-*-governance Application Provisioning"]
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

1. **governance-gitlab-project: GitLab.com Project (Optional)**

    `governance-gitlab-project` can be applied at any point and depends on no layer of this repository. An existing project requires a first-time `terraform import` of the project and the `main` branch protection before applying. See [Initialization: GitLab.com Project Governance](02-initialization.md#gitlabcom-project-governance).

2. **platform-gitlab-frontend: `OpenSSL::Cipher::CipherError`**

    If this error occurs in the `gitlab-migrations` pod, see the [troubleshooting guide](../operations/troubleshooting.md#gitlab-application). Caused by `rails-secret` regeneration against a preserved database from a prior deployment.
