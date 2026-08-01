# Architecture Overview

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, it automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

## Toolchain Roles

| Tool                     | Role                                                                                                                    |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| **Packer**               | Builds immutable VM images (two-stage: base OS to service binaries)                                                     |
| **Terraform / OpenTofu** | Provisions all infrastructure resources (VMs, networks, Vault config, K8s addons) in 33 sequenced layers                |
| **Ansible**              | Configures services inside VMs after provisioning (Patroni, Redis Sentinel, MinIO cluster, Harbor, GitLab)              |
| **HashiCorp Vault**      | Central secret management: KV secrets, PKI engine (Root CA + Service CA), AppRole auth, Vault Agent sidecar rotation    |
| **HAProxy + Keepalived** | Layer-4 load balancing with VRRP-based VIP failover for every service cluster                                           |
| **Podman**               | Hosts the IaC controller container (`iac-runner`) and Bootstrapper Vault, avoiding SELinux socket conflicts with Docker |

## Infrastructure Layers

The table below is ordered by provisioning sequence and dependency; layer names carry no numeric prefix, and `terraform_remote_state` is the authoritative dependency declaration:

| Layer(s)                                                     | Category       | Description                                        |
| -------------------------------------------------------------- | -------------- | -------------------------------------------------- |
| `foundation-metadata`, `foundation-vault-bootstrapper`          | Foundation     | Resource metadata (SSoT) + Bootstrapper Vault      |
| `foundation-network`, `foundation-volume`                       | Foundation     | Libvirt networks and storage volumes               |
| `shared-load-balancer-frontend`                                 | Shared         | Centralized Load Balancer (HAProxy + Keepalived)   |
| `shared-vault-frontend`                                         | Shared         | Production Vault cluster (HA Raft)                 |
| `security-vault-approle`                                        | Security       | Vault AppRole authentication                       |
| `security-pki`                                                  | Security       | Vault PKI Engine (Root CA + Service CA)            |
| `infra-*`                                                       | Infrastructure | VM provisioning for all service clusters           |
| `provision-*`                                                   | Provisioning   | Ansible-based service configuration                |
| `provision-vault-oidc`                                          | Security       | Vault OIDC (Keycloak integration)                  |
| `platform-*-frontend`                                           | Platform       | Kubernetes add-ons (Ingress, cert-manager, Calico) |
| `platform-*-governance`                                         | Application    | GitLab and Harbor Helm chart deployment            |
| `meta-*`                                                        | Meta           | GitHub repository governance                       |

## Key Architectural Decisions

- **[ADR 001](../adr/001-two-stage-vault.md)**: Two-stage Vault (Bootstrapper to Production)
- **[ADR 002](../adr/002-centralized-load-balancer.md)**: Centralized Load Balancer with Policy-Based Routing
- **[ADR 003](../adr/003-metadata.md)**: `foundation-metadata` as Single Source of Truth
- **[ADR 004](../adr/004-podman-over-docker.md)**: Podman over Docker (SELinux compatibility)
- **[ADR 005](../adr/005-harbor-bootstrapper-seed-registry.md)**: Harbor Bootstrapper as Seed Registry
- **[ADR 006](../adr/006-packer-two-stage-image.md)**: Two-stage Packer image build

## Further Reading

- [Deployment Workflow](deployment-workflow.md): stage-by-stage provisioning sequence with Mermaid diagrams
- [Network Topology](network-topology.md): asymmetric routing, PBR, bridge-nf-call, MTU/MSS
- [Terraform Layers](terraform-layers.md): `foundation-metadata` SSoT deep dive
- [PKI and Vault](pki-and-vault.md): certificate rotation rules
