# Architecture Overview

This repo leverages Packer, Terraform, and Ansible to implement an automated pipeline. Adhering to immutable infrastructure principles, the pipeline automates the entire lifecycle, from VM image creation to the provisioning of a complete Kubernetes cluster.

## Toolchain Roles

| Tool                     | Role                                                                                                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Packer**               | Builds the Gitaly and Praefect image on top of the distro image of `platform-foundation`                                                                    |
| **Terraform / OpenTofu** | Provisions all infrastructure resources (VMs, networks, K8s addons) in sequenced layers                                                                     |
| **Ansible**              | Configures services inside VMs after provisioning (Patroni, Redis Sentinel, MinIO cluster, Gitaly, Praefect)                                                |
| **HashiCorp Vault**      | Secrets and PKI come from the Downstream Vault of `platform-foundation`, and bootstrap credentials come from the Bastion Vault of `parent-group-governance` |
| **HAProxy + Keepalived** | Layer-4 load balancing with VRRP-based VIP failover for the non-Kubernetes services                                                                         |

## Infrastructure Layers

The table below is ordered by provisioning sequence and dependency. Layer names carry no numeric prefix, and `terraform_remote_state` is the authoritative dependency declaration:

| Layer(s)                        | Category       | Description                                                     |
| ------------------------------- | -------------- | --------------------------------------------------------------- |
| `foundation-libvirt-resources`  | Foundation     | Resource metadata (SSoT), Libvirt networks, and storage volumes |
| `infra-*`                       | Infrastructure | VM provisioning for all service clusters                        |
| `provision-*`                   | Provisioning   | Ansible-based service configuration                             |
| `platform-*-frontend`           | Platform       | Kubernetes add-ons (Ingress, cert-manager, Calico)              |
| `platform-*-governance`         | Application    | GitLab and Harbor Helm chart deployment                         |
| `administration-gitlab-project` | Governance     | GitLab.com project settings, code review, and WIF bindings      |

## Key Architectural Decisions

- **[ADR 003](../adr/003-foundation-libvirt-resources.md)**: `foundation-libvirt-resources` as Single Source of Truth
- **[ADR 006](../adr/006-packer-two-stage-image.md)**: Two-stage Packer image build

## Further Reading

- [Deployment Workflow](deployment-workflow.md): stage-by-stage provisioning sequence with Mermaid diagrams
- [Hypervisor Kernel Tuning](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation/-/blob/main/documentation/architecture/hypervisor-kernel-tuning.md): asymmetric routing, bridge-nf-call, MTU/MSS, owned by `platform-foundation`
- [Terraform Layers](terraform-layers.md): `foundation-libvirt-resources` SSoT deep dive
