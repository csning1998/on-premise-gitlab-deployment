# Deployment Workflow

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, it automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

The automated deployment process is divided into the following stages. Deployment sequence and dependencies strictly follow internal system logic:

## Stage 1: Foundation — Libvirt, Networking, and Secret Management

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

## Stage 3+: Application Deployment Dependencies

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Prod as Production Vault (L15-25)
    participant SS as StatefulSets (Postgres/Redis/MinIO)
    participant Harbor as Bootstrapper Harbor
    participant K8sGit as Kubeadm Cluster (Dist GitLab)
    participant K8sHbr as Microk8s Cluster (Dist Harbor)

    Note over User, Harbor: [Stage 3 / L30 Infra: StatefulSets & Bootstrapper Harbor]
    par
        User->>SS: 1. Provision DB Infrastructure (VMs & LBs)
        SS->>Prod: Request TLS Certificate (PKI Issue)
        SS->>SS: Start Services with TLS Enabled
    and
        User->>Harbor: 2. Provision Bootstrapper Harbor Infrastructure
        Harbor->>Prod: Request TLS Certificate (PKI Issue)
        Harbor->>Harbor: Initialize Seed Container Registry
    end

    Note over User, K8sHbr: [L30 Infra: K8s Clusters - Depends on Above]
    par Depends on StatefulSets + Bootstrapper Harbor
        User->>K8sGit: 3. Provision Kubeadm Cluster (Dist GitLab)
        K8sGit->>Harbor: Pull Bootstrap Images from Seed Registry
    and
        User->>K8sHbr: 4. Provision Microk8s Cluster (Dist Harbor)
        K8sHbr->>Harbor: Pull Bootstrap Images from Seed Registry
    end

    Note over User, K8sHbr: [L40: Application-Level Provisioning]
    User->>SS: 5. Provision Database Services (Ansible + Vault Agent TLS)
    User->>Harbor: 6. Provision Bootstrapper Harbor (Ansible)

    Note over User, K8sHbr: [L50: Platform Deployment]
    User->>K8sHbr: 7. Deploy Harbor Platform on Microk8s

    Note over User, K8sGit: [L60: Application Provision]
    User->>K8sGit: 8. Deploy GitLab on Kubeadm
    User->>K8sHbr: 9. Deploy Harbor on Microk8s
```

## Toolchain References

> [!NOTE]
> Procedures derived directly from official documentation are omitted from the list below.
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Aditi Sangave (2025). [_How to Setup HashiCorp Vault HA Cluster with Integrated Storage (Raft)._](https://www.velotio.com/engineering-blog/how-to-setup-hashicorp-vault-ha-cluster-with-integrated-storage-raft) Velotio Tech Blog.
> 3. Dickson Gathima (2025). [_Building a Highly Available PostgreSQL Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 4. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning — Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.
