# Terraform Layer Model

## foundation-metadata: Foundation Metadata (SSoT)

> [!TIP]
> **`foundation-metadata`** is the "Infrastructure Metadata Repository" and Single Source of Truth (SSoT) for the entire project.

Before proceeding with any provisioning, it is essential to understand the primary functions of `foundation-metadata`. This layer does not create any virtualization resources but is responsible for calculating:

1. **Global Naming Definitions**: Translates abstract `service_catalog` into specific component identifiers such as `cluster_name`, `storage_pool_name`, ensuring naming consistency.
2. **Automated Network Allocation**: Automatically calculates subnets, VIPs (`.250`), gateways, and host IP ranges for each service based on `cidr_index`. A `validation` mechanism is included to prevent IP conflicts from manual allocation.
3. **Deterministic Connection Attributes**: Generates fixed MAC addresses and DNS SANs for each VM. This ensures that physical characteristics and TLS certificate identification remain persistent even if resources are rebuilt.
4. **Cross-Layer Reference Standard**: Enables data-driven deployment via `terraform_remote_state` for all subsequent layers (e.g., the `infra-*` layers).
