# Deployment Workflow

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, the pipeline automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

The automated deployment process is divided into the following stages. Deployment sequence and dependencies strictly follow internal system logic:

## Stage 1: Upstream Prerequisites and Foundation

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

## Stage 2+: Application Deployment Dependencies

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Down as Downstream Vault (platform-foundation)
    participant Origin as Harbor Origin (platform-foundation)
    participant SS as StatefulSets (Postgres/Redis/MinIO)
    participant K8sGit as Kubeadm Cluster (Dist GitLab)
    participant K8sHbr as Microk8s Cluster (Dist Harbor)

    Note over User, SS: [Stage 2 / infra-* tier: StatefulSets]
    User->>SS: 1. Provision DB Infrastructure (VMs)
    SS->>Down: Request TLS Certificate (PKI Issue)
    SS->>SS: Start Services with TLS Enabled

    Note over User, K8sHbr: [infra-* tier: K8s Clusters, Depends on Above]
    par Depends on StatefulSets
        User->>K8sGit: 2. Provision Kubeadm Cluster (Dist GitLab)
        K8sGit->>Origin: Pull Bootstrap Images from Harbor Origin
    and
        User->>K8sHbr: 3. Provision Microk8s Cluster (Dist Harbor)
        K8sHbr->>Origin: Pull Bootstrap Images from Harbor Origin
    end

    Note over User, K8sHbr: [provision-* tier: Application-Level Provisioning]
    User->>SS: 4. Provision Database Services (Ansible + Vault Agent TLS)

    Note over User, K8sHbr: [platform-*-frontend tier: Platform Deployment]
    User->>K8sHbr: 5. Deploy Harbor Platform on Microk8s

    Note over User, K8sGit: [platform-*-governance tier: Application Provision]
    User->>K8sGit: 6. Deploy GitLab on Kubeadm
    User->>K8sHbr: 7. Deploy Harbor on Microk8s
```

## Toolchain References

> [!NOTE]
> Procedures derived directly from official documentation are omitted from the list below.
>
> 1. Bibin Wilson, B. (2025). [_How To Setup Kubernetes Cluster Using Kubeadm._](https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests) devopscube.
> 2. Dickson Gathima (2025). [_Building a Highly Available Postgres Cluster with Patroni, etcd, and HAProxy._](https://medium.com/@dickson.gathima/building-a-highly-available-postgresql-cluster-with-patroni-etcd-and-haproxy-1fd465e2c17f) Medium.
> 3. Deniz TÜRKMEN (2025). [_Redis Cluster Provisioning - Fully Automated with Ansible._](https://deniz-turkmen.medium.com/redis-cluster-provisioning-fully-automated-with-ansible-dc719bb48f75) Medium.
