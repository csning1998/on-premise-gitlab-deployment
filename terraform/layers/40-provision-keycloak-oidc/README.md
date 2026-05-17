# Layer 40: Keycloak OIDC Identity Foundation

This layer serves as the identity core of the entire infrastructure. It is responsible for configuring the Keycloak Realm, OIDC Clients, hierarchical groups (RBAC), and user accounts.

## Core Architecture

### OIDC Client Management

This layer automatically provisions OIDC clients for the following services and generates random `Client Secrets`:

- **Vault**: For access control (ACL).
- **GitLab**: For platform development collaboration.
- **Harbor**: For container image registry.
- **MinIO**: For object storage console.

All `Client ID` and `Client Secret` pairs are automatically synced to **Vault** under the path `secret/on-premise-gitlab-deployment/oidc/clients/`, allowing downstream layers to read them automatically.

### Hierarchical Group Management (RBAC)

To avoid Terraform circular dependencies, groups are divided into two levels:

- **Root Groups**: Top-level organizational units (e.g., `engineering`, `finance`).
- **Subgroups**: Child teams (e.g., `engineering/infra`, `engineering/dev-a`).

**Attribute Injection**: Through the `group-mapper` protocol mapper, all group paths a user belongs to are injected into the `groups` claim of the OIDC token.

### Users and Identity Anchors

- **Employee ID**: Uses the `E-xxxx` format as the resource key to ensure uniqueness and immutability of identity identifiers.
- **UUID Export**: This layer exports Keycloak’s internal **UUID**. This serves as the key for identity linking with GitLab and prevents login failures caused by changes in email or username.

## Collaboration with Downstream Layers (Single Source of Truth)

### Support for GitLab (Layer 60)

1. **Password Synchronization**: The `initial_password` set in this layer is passed to GitLab via remote state to create “shadow accounts”.
2. **Automated Permission Assignment**: GitLab reads the group mapping table from this layer to automatically assign development team memberships.

## Maintenance Guide

### Updating User Passwords

Since the `initial_password` attribute of `keycloak_user` only takes effect during creation, to force a password update through Terraform, run:

```bash
terraform apply -replace='keycloak_user.users["E-xxxx"]'
```

### Querying User Information

To view the complete list exported to downstream layers (including UUIDs), run:

```bash
terraform output -json oidc_users
```
