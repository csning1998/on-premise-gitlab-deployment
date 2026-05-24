# ADR 003: Layer 00 as Single Source of Truth (SSoT)

**Status:** Accepted

**Context:**

With 33+ Terraform layers spanning multiple service clusters, maintaining consistency across IP addresses, MAC addresses, storage pool names, DNS SANs, and cluster names manually would be error-prone and brittle. Copy-pasting values between layer `terraform.tfvars` files creates subtle drift and makes refactoring painful.

**Decision:**

Designate `L00-foundation-metadata` as the Single Source of Truth (SSoT) for all infrastructure metadata. This layer:

1. **Global Naming Definitions**: Translates abstract `service_catalog` into specific component identifiers such as `cluster_name`, `storage_pool_name`, ensuring naming consistency.
2. **Automated Network Allocation**: Automatically calculates subnets, VIPs (`.250`), gateways, and host IP ranges for each service based on `cidr_index`. A `validation` mechanism is included to prevent IP conflicts from manual allocation.
3. **Deterministic Connection Attributes**: Generates fixed MAC addresses and DNS SANs for each VM. This ensures that physical characteristics and TLS certificate identification remain persistent even if resources are rebuilt.
4. **Cross-Layer Reference Standard**: Enables data-driven deployment via `terraform_remote_state` for all subsequent layers (e.g., `30-infra-xxx`).

All subsequent layers consume `L00` outputs via `terraform_remote_state`. No layer hardcodes an IP, MAC, or cluster name directly.

**Consequences:**

- `L00` must be applied before any other layer.
- Changes to `L00` (e.g., adding a new service segment) cascade to all dependent layers — which is the intended behavior.
- `terraform_remote_state` creates a hard dependency graph; layers cannot be applied out of order.
- Debugging requires tracing values back through `L00` outputs, adding one indirection step.

**Related layers:** `L00-foundation-metadata`, all `L30+` layers via `terraform_remote_state`
