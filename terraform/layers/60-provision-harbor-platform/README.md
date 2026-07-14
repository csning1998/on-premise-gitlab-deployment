# Layer 60: Production Harbor Frontend

## Problem Diagnosis: Duplicate User Conflict (OIDC Identity Drift)

Refer to [40-provision-harbor-databases/README.md](../40-provision-harbor-databases/README.md) with the same title for more information.

For the production Harbor instance running on MicroK8s, the database is hosted externally on Patroni (`core-harbor-postgres-node-00`).

1. Retrieve the Postgres superuser password from the Patroni configuration on the Patroni node:

    ```bash
    sudo grep -A 5 'superuser:' /etc/patroni.yml
    ```

2. Log in using the TCP interface and perform the same deletion:

    ```bash
    # Connect to Patroni VIP/Host and execute cleanup
    PGPASSWORD='<superuser_password>' psql -h 172.16.132.200 -U postgres -d registry -c "
        DELETE FROM oidc_user WHERE user_id = <user_id>;
        DELETE FROM harbor_user WHERE user_id = <user_id>;
    "
    ```

3. Re-login via OIDC on Harbor UI.

## Harbor Project and RBAC Provisioning

`resources.tf` provisions the project layout, the OIDC group bindings, the proxy caches, and the per team CI robots. The structure is driven by Keycloak groups, where a group whose `type` attribute is `team` owns artifacts and a group whose `type` is `role` such as `dev-leads` holds cross team access.

1. **Shared project**. A private `shared` project that every team can pull from with the Developer role, while leads hold the Maintainer role for cross team oversight.
2. **Team projects**. One private `team-{name}` project per team group. Only the owning team can push and pull.
3. **OIDC group registration**. Harbor side group objects of OIDC type that map to the Keycloak group claims, created for both team groups and role groups.
4. **Project member mappings**. On the shared project each team gets Developer and dev-leads gets Maintainer. On each team project the owning team gets Developer and dev-leads gets Maintainer across all team projects. The numeric group id is extracted from the `/usergroups/{n}` string returned by the group resource.
5. **Proxy cache projects**. Each proxy project pulls external images on demand directly from its upstream registry such as `gcr.io` or `docker.io`, and Production Harbor caches the image on first pull. The upstream endpoint and provider type are inherited from the Bootstrapper proxy cache definitions so both Harbors target the same upstreams.
6. **Per team CI robots**. Each team has a dedicated `ci-{team}` robot that can push, pull, and tag on its own `team-{name}` project and can only pull from the shared project.
7. **Robot credentials in Vault**. Each robot username and secret is written to Vault at `secret/on-premise-gitlab-deployment/harbor/robots/{team}` so the GitLab layer can consume them. See [60-provision-gitlab-platform/README.md](../60-provision-gitlab-platform/README.md) for how they become CI/CD variables.

## Known Issue: Use `-parallelism=2` for `plan`/`apply`

This layer refreshes a large number of `harbor_project`, `harbor_group`, `harbor_registry`, and `harbor_project_member_group` resources. At Terraform's default parallelism (10), the production Harbor API intermittently returns `401 Unauthorized` or `500 Internal Server Error` on some of the concurrent refresh calls, causing the plan to fail outright. This is a load/concurrency limitation on the Harbor side, not a configuration error; retrying with fewer concurrent requests resolves it reliably.

Always run:

```bash
terraform plan -parallelism=2
terraform apply -parallelism=2
```

If a run still fails with scattered `401`/`500` errors during the refresh phase (before any `Error: [ERROR] unexpected status code got: 409` conflict), just retry the same command; nothing was mutated yet at that point.
