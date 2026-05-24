# Packer Build

## The Entrypoint: `entry.sh`

The `entry.sh` script located in the root directory handles all service initialization and lifecycle management. Executing `./entry.sh` from the repo root displays the following interface:

```text
➜  on-premise-gitlab-deployment git:(main) ✗ ./entry.sh
... (Some preflight check)

======= IaC-Driven Virtualization Management =======

[INFO] Environment: NATIVE
--------------------------------------------------
[OK] Bootstrapper Vault (Local): Running (Unsealed)
[OK] Production Vault (Layer 15): Running (Unsealed)
------------------------------------------------------------

1) [DEV] Set up TLS for Dev Vault (Local)                      7) Build Packer Base Image
2) [DEV] Initialize Dev Vault (Local)                          8) Verify Guest VM Connectivity via SSH
3) [DEV] Unseal Dev Vault (Local)                              9) Switch Environment Strategy
4) [PROD] Unseal Production Vault (via Ansible)               10) Purge All Packer Artifacts
5) Generate SSH Key                                           11) Purge All Infrastructure Resources (Libvirt + Terraform)
6) Verify IaC Environment                                     12) Quit

[INPUT] Please select an action:
```

Where the functions are listed below:

| Option | Description                                              |
| ------ | -------------------------------------------------------- |
| `1`    | Set up TLS for Bootstrapper Vault (Dev/Local)            |
| `2`    | Initialize Bootstrapper Vault                            |
| `3`    | Unseal Bootstrapper Vault                                |
| `4`    | Unseal Production Vault (via Ansible playbook)           |
| `5`    | Generate SSH Key                                         |
| `6`    | Verify IaC Environment (KVM/QEMU installation)           |
| `8`    | Verify Guest VM Connectivity via SSH                     |
| `9`    | Switch Environment Strategy (Container ↔ Native)         |
| `10`   | Purge All Packer Artifacts                               |
| `11`   | Purge All Infrastructure Resources (Libvirt + Terraform) |

## Option 7: Build Packer Base Image

Option `7` dynamically populates submenus by scanning the `packer/output` directory. The submenus for a complete configuration are shown below:

```text
[INPUT] Please select an action: 7
[INFO] Checking status of libvirt service...
[OK] libvirt service is already running.

[INFO] Select Packer category to build:
------------------------------------------------------------
1) Base OS Layers    2) Service Layers    3) Build ALL    4) Back to Main Menu

[INPUT] Select a category:
```

### Base OS Layers (`1`)

Selecting `1` is primarily used to build base OS images, including APT updates, etc.

```text
[INPUT] Select a category: 1
1) ubuntu-24-updated
2) Build ALL in Base OS Images
3) Back
```

### Service Layers (`2`)

Selecting `2` builds service images. It specifies the base image from `1` as a source in Packer HCL and installs the service binaries and related packages.

```text
[INPUT] Select a category: 2
1) base-etcd       3) base-kubeadm        5) base-minio        7) base-redis        9) docker-harbor     11) Back
2) base-haproxy    4) base-microk8s       6) base-postgres     8) base-vault        10) Build ALL in Service Images
```
