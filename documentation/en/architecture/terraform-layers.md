# Terraform Layer Model

## foundation-libvirt-resources: Foundation Resources (SSoT)

> [!TIP]
> **`foundation-libvirt-resources`** is the "Infrastructure Metadata Repository" and Single Source of Truth (SSoT) for the entire project.

Every provisioning step depends on the primary functions of `foundation-libvirt-resources`. The layer calls the `foundation-resources` module of `platform-foundation`, reads the network baseline and the domain suffix from the `foundation-libvirt-resources` state of `platform-foundation`, and is responsible for:

1. **Global Naming Definitions**: Translates abstract `service_catalog` into specific component identifiers such as `cluster_name`, `storage_pool_name`, ensuring naming consistency.
2. **Automated Network Allocation**: Automatically calculates subnets, VIPs (`.250`), gateways, and host IP ranges for each service based on `cidr_index`. A `validation` mechanism is included to prevent IP conflicts from manual allocation.
3. **Deterministic Connection Attributes**: Generates fixed MAC addresses and DNS SANs for each VM. This ensures that physical characteristics and TLS certificate identification remain persistent even if resources are rebuilt.
4. **Libvirt Realization**: Creates the NAT and HostOnly networks, the storage pools, and the data disks of every component, and writes the SSH client configuration of every cluster.
5. **Cross-Layer Reference Standard**: Enables data-driven deployment via `terraform_remote_state` for all subsequent layers (e.g., the `infra-*` layers).
