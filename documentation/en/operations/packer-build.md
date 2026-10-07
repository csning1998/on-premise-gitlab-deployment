# Packer Build

## The Entrypoint: `entry.sh`

The `entry.sh` script located in the root directory handles all service initialization and lifecycle management. Executing `./entry.sh` from the repo root displays the following interface:

```text
➜  on-premise-gitlab-deployment git:(main) ✗ ./entry.sh
... (Some preflight check)

======= IaC-Driven Virtualization Management =======

1) Generate SSH Key                                            5) [PROD] Revert Gitaly to Standalone for Safety Pre-check
2) Verify IaC Environment                                      6) Purge All Packer Artifacts
3) Build Packer Base Image                                     7) Purge All Infrastructure Resources (Libvirt + Terraform)
4) Verify Guest VM Connectivity via SSH                        8) Quit

[INPUT] Please select an action:
```

Where the functions are listed below:

| Option | Description                                              |
| ------ | -------------------------------------------------------- |
| `1`    | Generate SSH Key                                         |
| `2`    | Verify IaC Environment (KVM/QEMU installation)           |
| `3`    | Build Packer Base Image                                  |
| `4`    | Verify Guest VM Connectivity via SSH                     |
| `5`    | Revert Gitaly to Standalone before a Praefect migration  |
| `6`    | Purge All Packer Artifacts                               |
| `7`    | Purge All Infrastructure Resources (Libvirt + Terraform) |

## Option 3: Build Packer Base Image

Option `3` dynamically populates submenus by scanning the `*.pkrvars.hcl` files under `packer/services`. The submenus are shown below:

```text
[INPUT] Please select an action: 3
[INFO] Checking status of libvirt service...
[OK] libvirt service is already running.

[INFO] Select Packer category to build:
------------------------------------------------------------
1) Service Layers    2) Build ALL    3) Back to Main Menu

[INPUT] Select a category:
```

### Service Layers (`1`)

Selecting `1` builds service images. Each service image uses the `ubuntu-24-updated` distro image in the `packer/output` directory of `platform-foundation` as the source in Packer HCL and installs the service binaries and related packages.

```text
[INPUT] Select a category: 1
1) base-baremetal-gitaly-praefect
2) Build ALL in Service Images
3) Back
```

The distro image and the shared service images for Postgres, Redis, etcd, MinIO, Kubeadm, and MicroK8s are built in `platform-foundation`.
