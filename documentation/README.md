# Documentation

> English documentation is in [en/](en/). Traditional Chinese (zh-TW) is planned.

## Getting Started

| Document                                                        | Description                                       |
| --------------------------------------------------------------- | ------------------------------------------------- |
| [Prerequisites](en/getting-started/01-prerequisites.md)         | Hardware, software, and system requirements       |
| [Environment Setup](en/getting-started/02-environment-setup.md) | Podman, Libvirt permissions, container vs. native |
| [Initialization](en/getting-started/03-initialization.md)       | First-run order, GitHub PAT setup                 |
| [Deployment Order](en/getting-started/04-deployment-order.md)   | Phase-by-phase Terraform layer apply sequence     |

## Configuration

| Document                                                       | Description                                                 |
| -------------------------------------------------------------- | ----------------------------------------------------------- |
| [Vault Secrets](en/configuration/vault-secrets.md)             | Bootstrapper Vault and Production Vault secret injection    |
| [Terraform Variables](en/configuration/terraform-variables.md) | `.tfvars` init, HA node count rules, Guest OS, cleanup      |
| [Kernel Tuning](en/configuration/kernel-tuning.md)             | `rp_filter`, `ip_forward`, `bridge-nf-call`, conntrack, MSS |
| [Trust Store](en/configuration/trust-store.md)                 | `/etc/hosts` entries, CA bundle import, verification        |

## Architecture

| Document                                                      | Description                                        |
| ------------------------------------------------------------- | -------------------------------------------------- |
| [Overview](en/architecture/overview.md)                       | Toolchain roles, layer map, ADR index              |
| [Deployment Workflow](en/architecture/deployment-workflow.md) | Stage-by-stage Mermaid diagrams                    |
| [Network Topology](en/architecture/network-topology.md)       | Asymmetric routing, PBR, bridge isolation, MTU/MSS |
| [Terraform Layers](en/architecture/terraform-layers.md)       | Layer 00 SSoT deep dive                            |
| [PKI and Vault](en/architecture/pki-and-vault.md)             | Certificate rotation rules, Vault Agent sidecar    |

## Operations

| Document                                                                         | Description                                                   |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [Packer Build](en/operations/packer-build.md)                                    | `entry.sh` menu, two-stage image build                        |
| [GitHub Meta](en/operations/github-meta.md)                                      | Terraform GitHub provider, Shell Bridge Pattern               |
| [Harbor Bootstrapper: Helm Sync](en/operations/harbor-bootstrapper-helm-sync.md) | `helm pull` + `helm push` to Bootstrapper Harbor OCI registry |
| [Troubleshooting](en/operations/troubleshooting.md)                              | Symptom index linking to all layer-specific READMEs           |

## Architecture Decision Records (ADRs)

| ADR                                                        | Title                                |
| ---------------------------------------------------------- | ------------------------------------ |
| [ADR 001](en/adr/001-two-stage-vault.md)                   | Two-Stage Vault Architecture         |
| [ADR 002](en/adr/002-centralized-load-balancer.md)         | Centralized Load Balancer with PBR   |
| [ADR 003](en/adr/003-layer-00-ssot.md)                     | Layer 00 as Single Source of Truth   |
| [ADR 004](en/adr/004-podman-over-docker.md)                | Podman Over Docker                   |
| [ADR 005](en/adr/005-harbor-bootstrapper-seed-registry.md) | Harbor Bootstrapper as Seed Registry |
| [ADR 006](en/adr/006-packer-two-stage-image.md)            | Two-Stage Packer Image Build         |
