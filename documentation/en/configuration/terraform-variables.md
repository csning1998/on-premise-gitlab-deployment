# Terraform Variables

> [!NOTE]
> These variable files define configuration for cluster provisioning.

## 1. Initialize `.tfvars` Files

Initialize required `.tfvars` files by copying examples for each layer:

```shell
for f in terraform/layers/*/terraform.tfvars.example; do cp -n "$f" "${f%.example}"; done
```

1. For High Availability (HA) configurations:
    - Services such as Vault (Production mode), Patroni (including etcd), Sentinel, MicroK8s (Harbor), and Kubeadm Master (GitLab) must follow odd-node configuration (`n % 2 != 0`).
    - MinIO Distributed requires node count divisible by four (`n % 4 == 0`).
2. Static IPs assigned during node provisioning must align with designated host-only network subnet.

## 2. Guest OS

This project utilizes Ubuntu Server 24.04.3 LTS (Noble) as default Guest OS.

- Latest release: <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/>
- Specific version tested: <https://old-releases.ubuntu.com/releases/noble/>
- Ensure checksum verification after downloading:
    - Latest Noble: <https://releases.ubuntu.com/noble/SHA256SUMS>
    - Old-release Noble: <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

Support for additional Linux Guest OS such as Fedora 43 or RHEL 10 is planned.

## 3. Independent Testing and Development

- Use menu option `7) Build Packer Base Image` to generate base images. See [Packer Build](../operations/packer-build.md) for details.
- **[Note]**: The `Provision Terraform Layer` interactive menu has been removed. Please manually navigate to the `terraform/layers/` directories and execute `tofu apply` for deployment.

    Occasionally, when rebuilding Harbor in Layer 60, a `module.harbor_system_config.harbor_garbage_collection.gc` "Resource not found" error may occur. Resolved by removing `terraform.tfstate` and `terraform.tfstate*.backup` from `terraform/layers/60-provision-harbor` before re-executing `tofu apply`.

## 4. Resource Cleanup

- **`10) Purge All Packer Artifacts`**: Specifically cleans up all Packer-generated images, resetting the Packer state.
- **`11) Purge All Infrastructure Resources (Libvirt + Terraform)`**: Bundles the destruction of Libvirt virtualization resources with the cleanup of Terraform state files, ensuring the environment is completely reset.

> [!NOTE]
> The following content uses `tofu` as the main command. For users who are using `terraform`, just replace `tofu` with `terraform` accordingly.
