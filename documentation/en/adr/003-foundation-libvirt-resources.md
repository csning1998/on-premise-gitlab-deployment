# ADR 003: foundation-libvirt-resources as Single Source of Truth (SSoT)

**Status:** Accepted

**Context:**

With many Terraform layers spanning multiple service clusters, maintaining consistency across IP addresses, MAC addresses, storage pool names, DNS SANs, and cluster names manually would be error-prone and brittle. Copy-pasting values between layer `terraform.tfvars` files creates subtle drift and makes refactoring painful.

**Decision:**

Designate `foundation-libvirt-resources` as the Single Source of Truth (SSoT) for all infrastructure metadata of this repository. The layer calls the `foundation-resources` module of `platform-foundation` with the `service_catalog` of this repository, and reads the network baseline and the domain suffix from the `foundation-libvirt-resources` state of `platform-foundation`. The layer:

1. **Global Naming Definitions**: Translates abstract `service_catalog` into specific component identifiers such as `cluster_name`, `storage_pool_name`, ensuring naming consistency.
2. **Automated Network Allocation**: Automatically calculates subnets, VIPs (`.250`), gateways, and host IP ranges for each service based on `cidr_index`. A `validation` mechanism is included to prevent IP conflicts from manual allocation.
3. **Deterministic Connection Attributes**: Generates fixed MAC addresses and DNS SANs for each VM. This ensures that physical characteristics and TLS certificate identification remain persistent even if resources are rebuilt.
4. **Libvirt Realization**: Creates the NAT and HostOnly networks, the storage pools, and the data disks of every component, and writes the SSH client configuration of every cluster.
5. **Cross-Layer Reference Standard**: Enables data-driven deployment via `terraform_remote_state` for all subsequent layers (e.g., the `infra-*` layers).

All subsequent layers consume the `foundation_*` class outputs of `foundation-libvirt-resources` via `terraform_remote_state`. No layer hardcodes an IP, MAC, or cluster name directly.

**Consequences:**

- `foundation-libvirt-resources` must be applied after the `foundation-libvirt-resources` layer of `platform-foundation` and before any other layer of this repository.
- Changes to `foundation-libvirt-resources` (e.g., adding a new service segment) cascade to all dependent layers, which is the intended behavior.
- `terraform_remote_state` creates a hard dependency graph, and layers cannot be applied out of order.
- Debugging requires tracing values back through `foundation-libvirt-resources` outputs, adding one indirection step.

**Related layers:** `foundation-libvirt-resources`, all downstream layers via `terraform_remote_state`
