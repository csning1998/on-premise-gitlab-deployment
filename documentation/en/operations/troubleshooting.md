# Troubleshooting Index

Layer-specific READMEs live next to their code. This page is a symptom-based index, find the error, follow the link.

## TLS / PKI

| Symptom                                                                          | Layer                        | Reference                                                                |
| -------------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------ |
| `tls: failed to find any PEM data in certificate input` during `terraform apply` | `provision-gitlab-databases` | [README](../../../terraform/layers/provision-gitlab-databases/README.md) |
| Same error on Harbor database layer                                              | `provision-harbor-databases` | [README](../../../terraform/layers/provision-harbor-databases/README.md) |

Both cases follow the same pattern: the Vault-issued leaf certificate has expired or been rotated. Use `-target` to force a certificate-only apply before running the full apply.

## GitLab Application

| Symptom                                                   | Layer                      | Reference                                                              |
| --------------------------------------------------------- | -------------------------- | ---------------------------------------------------------------------- |
| `OpenSSL::Cipher::CipherError` in `gitlab-migrations` pod | `platform-gitlab-frontend` | [README](../../../terraform/layers/platform-gitlab-frontend/README.md) |

Caused by `rails-secret` / `db_key_base` being regenerated (via `terraform destroy + apply` on `platform-gitlab-frontend`) while the Postgres database is preserved from a previous deployment. The README contains the full HCL-native reset procedure.

## OIDC / Identity

| Symptom                                                      | Layer                        | Reference                                                                |
| ------------------------------------------------------------ | ---------------------------- | ------------------------------------------------------------------------ |
| Duplicate user conflict after OIDC re-login (Identity Drift) | `platform-harbor-governance` | [README](../../../terraform/layers/platform-harbor-governance/README.md) |

## Harbor Origin

| Symptom                                           | Layer                                                    | Reference                                                                                                                                                        |
| ------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/data/harbor` at 100%, multiple service failures | `platform-foundation` `provision-harbor-origin-frontend` | [README](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation/-/blob/main/terraform/layers/provision-harbor-origin-frontend/README.md) |

Full disk exhaustion recovery runbook: stops services, expands partition or prunes images/blobs, restores Harbor.

---

## Layer Operation Guides

First-time setup steps that don't fit neatly into the main provisioning flow.

### GitLab Platform (platform-gitlab-governance)

[`platform-gitlab-governance/README.md`](../../../terraform/layers/platform-gitlab-governance/README.md)

Covers:

- Bootstrapping the first GitLab Admin PAT (cannot be issued via API; requires manual UI step)
- Pushing a local repository to the on-premise GitLab instance (HTTPS and SSH)
- SSH NodePort workaround (GitLab Shell exposed on port `32022` because VIP:22 is occupied by the host daemon)
- Clearing stale SSH host key after GitLab redeployment

### GitLab.com Project Governance (governance-gitlab-project)

Covers:

- First-time `terraform import` of the project and the `main` branch protection
- Project settings, code reviewer variables, and workload identity federation bindings of the GitLab.com project

> [!NOTE]
> Credential sources are in [Initialization: GitLab.com Project Governance](../getting-started/02-initialization.md#gitlabcom-project-governance).

---

## Architecture Reference

| Layer                                           | Topic                                                                                                        | Reference                                                                                                                                               |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `platform-foundation` `provision-keycloak-oidc` | OIDC client management, RBAC group hierarchy, UUID-based identity anchors, downstream SSoT for GitLab/Harbor | [README](https://gitlab.com/csning1998-lab/platform-engineering-lab/platform-foundation/-/blob/main/terraform/layers/provision-keycloak-oidc/README.md) |
