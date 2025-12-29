# On-Premise GitLab Deployment on HA Kubeadm Cluster

This documentation details the **On-Premise GitLab Deployment** project. The repository implements an Infrastructure as Code Proof of Concept utilizing QEMU-KVM. The primary objective is the automated deployment of a High Availability Kubernetes Cluster in an on-premise environment.

This project targets legacy systems to provide a repeatable and efficient IaC pipeline for deploying GitLab and Harbor.

## Documentation Contents

### [Concepts](concepts/architecture.md)

This section details the underlying design, architecture, and security models.

-   **[System Architecture](concepts/architecture.md)**: High-level design and toolchain descriptions (Packer, Terraform, Ansible).
-   **[Security Model](concepts/security-model.md)**: Vault integration, PKI trust chain, and secret management mechanisms.

### [Guides](guides/get-started.md)

This section provides procedural instructions for infrastructure setup and deployment.

-   **[Get Started](guides/get-started.md)**: Prerequisites and hardware specifications.
-   **[Configuration](guides/configuration.md)**: Setup procedures for SSH keys, Vault secrets, and GitHub tokens.
-   **[Provisioning](guides/provisioning.md)**: Instructions for image building and Terraform layer deployment.
-   **[Operations](guides/operations.md)**: Procedures for environment switching and resource cleanup.

### [Reference](reference/variables.md)

This section lists technical specifications for lookup purposes.

-   **[Variables & Secrets](reference/variables.md)**: Comprehensive list of Vault secrets and Terraform variables.
-   **[Troubleshooting](reference/troubleshooting.md)**: Documentation of common issues and workarounds.

## Disclaimer

-   **Linux Compatibility**: This project functions exclusively on Linux devices with CPU virtualization support (tested on RHEL 10 and Ubuntu 24). Compatibility with Fedora 41, Arch, CentOS, or WSL2 is not verified.
-   **Experimental Status**: Features underwent testing in a personal development environment. Functionality variances may exist across different hardware configurations.

---

[Return to Repository Root](../README.md)
