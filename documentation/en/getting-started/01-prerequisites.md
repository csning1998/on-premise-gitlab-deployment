# Prerequisites

## A. Disclaimer

- This repo currently only supports Linux hosts with CPU virtualization functionality. It has not been tested on other distributions such as Fedora, Arch, CentOS, WSL2, etc. The following command can be used to check whether the development machine supports virtualization:

    ```shell
    lscpu | grep Virtualization
    ```

    Possible outputs include:
    - Virtualization: VT-x (Intel)
    - Virtualization: AMD-V (AMD)
    - If there is no output, virtualization may not be supported.

> [!WARNING]
> **Compatibility Warning**
> This repo currently only supports Linux hosts with CPU virtualization functionality. If the host CPU does not support virtualization (e.g., lacking VT-x/AMD-V), please switch to the `legacy-workstation-on-ubuntu` branch, which supports basic HA Kubeadm cluster setup.
>
> Additionally, this repo is currently an independent personal project and may contain edge cases. Issues will be addressed as they are identified.

## B. System Requirements

Before proceeding, ensure the host system meets the following requirements:

- Linux host (Fedora 43, RHEL 10, or Ubuntu 24 recommended).
- CPU virtualization support (VT-x or AMD-V).
- `sudo` privileges for Libvirt management.
- `podman` and `podman compose` installed for containerized operations.
- `openssl` package (provides the `openssl passwd` command).
- `jq` package (for JSON parsing).

## C. Install IaC Toolkit

### Required. KVM / QEMU

Option `6` in `entry.sh` automates the installation of the QEMU/KVM environment. This process is currently tested only on Ubuntu 24 and RHEL 10. For other platforms, refer to official documentation to manually configure the KVM and QEMU environment.

### Install IaC Tools on Native

1.  **Install IaC Toolkit - OpenTofu / Terraform, HashiCorp Vault, Packer and Ansible**

    Refer to the following resources for toolkit installation:
    - [OpenTofu Installation](https://opentofu.org/docs/intro/install/)
    - [Terraform Installation](https://developer.hashicorp.com/terraform/install)
    - [HashiCorp Vault Installation](https://developer.hashicorp.com/vault/docs/install)
    - [Packer Installation](https://developer.hashicorp.com/packer/install)
    - [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

2.  Ensure Podman / Docker is correctly installed. Select the appropriate installation method from the links below based on your development machine's operating system:
    - [Podman Installation](https://podman.io/getting-started/installation) _Recommended for RHEL / Fedora_
    - [Docker Installation](https://docs.docker.com/get-docker/)

> [!WARNING]
> As of May 1, 2026, this repo requires Terraform 1.14 or higher because it utilizes the `action` block in the Ansible Provider to declare resources. Currently, there is no equivalent implementation in the OpenTofu community. This repo will be migrated back to OpenTofu once such support becomes available. Users are advised to manually substitute `tofu` with `terraform` commands or use an alias for all CLI operations.

## D. Recommended VSCode Plugins

These extensions provide syntax highlighting for the languages used in this project:

1. Ansible language support extension. [Marketplace Link of Ansible](https://marketplace.visualstudio.com/items?itemName=redhat.ansible)

    ```shell
    code --install-extension redhat.ansible
    ```

2. HCL language support extension for Terraform. [Marketplace Link of HashiCorp HCL](https://marketplace.visualstudio.com/items?itemName=HashiCorp.HCL)

    ```shell
    code --install-extension HashiCorp.HCL
    ```

3. Packer tool extension. [Marketplace Link of Packer Powertools](https://marketplace.visualstudio.com/items?itemName=szTheory.vscode-packer-powertools)

    ```shell
    code --install-extension szTheory.vscode-packer-powertools
    ```
