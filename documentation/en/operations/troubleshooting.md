# Troubleshooting Index

Layer-specific READMEs live next to their code. This page is a symptom-based index — find the error, follow the link.

## TLS / PKI

| Symptom                                                                          | Layer                           | Reference                                                                   |
| -------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------- |
| `tls: failed to find any PEM data in certificate input` during `terraform apply` | `40-provision-gitlab-databases` | [README](../../../terraform/layers/40-provision-gitlab-databases/README.md) |
| Same error on Harbor database layer                                              | `40-provision-harbor-databases` | [README](../../../terraform/layers/40-provision-harbor-databases/README.md) |

Both cases follow the same pattern: the Vault-issued leaf certificate has expired or been rotated. Use `-target` to force a certificate-only apply before running the full apply.

## GitLab Application

| Symptom                                                   | Layer                         | Reference                                                                 |
| --------------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------- |
| `OpenSSL::Cipher::CipherError` in `gitlab-migrations` pod | `50-platform-gitlab-frontend` | [README](../../../terraform/layers/50-platform-gitlab-frontend/README.md) |

Caused by `rails-secret` / `db_key_base` being regenerated (via `terraform destroy + apply` on L50) while the Postgres database is preserved from a previous deployment. The README contains the full HCL-native reset procedure.

## OIDC / Identity

| Symptom                                                      | Layer                          | Reference                                                                  |
| ------------------------------------------------------------ | ------------------------------ | -------------------------------------------------------------------------- |
| Duplicate user conflict after OIDC re-login (Identity Drift) | `60-provision-harbor-platform` | [README](../../../terraform/layers/60-provision-harbor-platform/README.md) |

## Harbor Bootstrapper

| Symptom                                           | Layer                                       | Reference                                                                               |
| ------------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------- |
| `/data/harbor` at 100%, multiple service failures | `40-provision-harbor-bootstrapper-frontend` | [README](../../../terraform/layers/40-provision-harbor-bootstrapper-frontend/README.md) |

Full disk exhaustion recovery runbook: stops services, expands partition or prunes images/blobs, restores Harbor.

---

## Layer Operation Guides

First-time setup steps that don't fit neatly into the main provisioning flow.

### GitLab Platform (L60)

[`60-provision-gitlab-platform/README.md`](../../../terraform/layers/60-provision-gitlab-platform/README.md)

Covers:

- Bootstrapping the first GitLab Admin PAT (cannot be issued via API; requires manual UI step)
- Pushing a local repository to the on-premise GitLab instance (HTTPS and SSH)
- SSH NodePort workaround (GitLab Shell exposed on port `32022` because VIP:22 is occupied by the host daemon)
- Clearing stale SSH host key after GitLab redeployment

### GitLab.com Mirror Meta (L90)

[`90-meta-gitlab/README.md`](../../../terraform/layers/90-meta-gitlab/README.md)

Covers:

- First-time `terraform import` for the mirror project
- Applies project settings and branch protection rules to the GitLab.com mirror

> [!NOTE]
> PAT generation and Vault storage steps are in [Initialization → GitLab.com Credentials](../getting-started/03-initialization.md#gitlabcom-credentials-for-mirror-management).

---

## Architecture Reference

| Layer                        | Topic                                                                                                        | Reference                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| `40-provision-keycloak-oidc` | OIDC client management, RBAC group hierarchy, UUID-based identity anchors, downstream SSoT for GitLab/Harbor | [README](../../../terraform/layers/40-provision-keycloak-oidc/README.md) |
