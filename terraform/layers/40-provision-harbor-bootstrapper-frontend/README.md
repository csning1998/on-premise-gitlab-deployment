# Harbor Bootstrapper Recovery for Disk Exhaustion

## Problem Diagnosis: Disk Exhaustion

The `/data/harbor` partition reaching 100% capacity (e.g., 47GB/49GB) results in multiple service failures:

- **`harbor-db` (Postgres)**: Failure to write transaction checkpoints, leading to a constant restart loop.
- **`redis`**: `MISCONF` errors and blocked writes due to persistence failure.
- **`harbor-core` / `harbor-jobservice`**: Initialization failure resulting from underlying database and Redis issues.

In this instance, the primary driver of disk usage was the `helm-charts/tigera/operator` repository, which contained over **2,300 artifacts** and associated blobs.

### Step A. Manual Filesystem Recovery

> [!CAUTION]
> **LAST RESORT ONLY**: Manually deleting blobs from the filesystem bypasses Harbor's metadata management and can lead to database inconsistencies or "manifest unknown" errors. This action should **only** be performed as an emergency measure when disk exhaustion (100%) prevents services (Postgres/Redis) from starting. The preferred method for reclaiming space is deleting artifacts via the Harbor UI/API followed by a formal **Garbage Collection** run.

To restore service health, the largest OCI blobs in `/data/harbor/registry/docker/registry/v2/blobs/sha256/` were identified using the `du` and `find` commands.

**Execution Commands:**

1.  Identify top 10 largest blob directories

    ```bash
    sudo du -sh /data/harbor/registry/docker/registry/v2/blobs/sha256/* | sort -rh | head -n 10
    ```

2.  Find and delete specific blobs exceeding a size threshold (e.g., 50MB)

    ```bash
    sudo find /data/harbor/registry/docker/registry/v2/blobs/sha256/ -type f -size +50M -delete
    ```

    Manual deletion of these blobs freed approximately 1.5GB of space, enabling Postgres to complete its crash recovery process.

### Step B. Disabling Automated Replication

The L40 configuration was modified to disable the aggressive replication schedule defined in `replication.tf`:

- The `schedule` attribute was removed from `harbor_replication` resources.
- The `sync-tigera` policy was set to `Disabled` via the API.

**Step 0: List all replication policies to find the correct ID:**

```bash
curl -s -k -u admin:<password> \
    https://localhost/api/v2.0/replication/policies | jq '.[].id, .[].name'
```

**Step 1: Fetch existing policy configuration:**

```bash
# Get current policy details using the ID found in Step 0
curl -s -k -u admin:<password> \
    https://localhost/api/v2.0/replication/policies/<ID> > policy.json
```

**Step 2: Update and Disable the policy:**
Edit `policy.json` to set `"enabled": false` and `"trigger": {"type": "manual"}`, then send it back:

```bash
curl -s -k -X PUT -u admin:<password> \
    -H 'Content-Type: application/json' \
    -d @policy.json \
    https://localhost/api/v2.0/replication/policies/<ID>
```

### Step C. Direct Postgres Intervention

During the cleanup process, it was observed that `harbor-jobservice` persistently re-created the `tigera/operator` artifacts despite API deletion attempts. To terminate this cycle, direct database operations were performed on the `harbor-db` container.

**Rationale for DB Intervention:**

- **API Limitation**: The Harbor API `stop` endpoint for replication executions returned 404/403 errors during the unstable state.
- **Job Persistence**: The Job Service maintains a persistent queue; restarting containers did not prevent workers from resuming the 2,300-artifact synchronization task.
- **Synchronization Loop**: Deletion of the repository triggered the active background worker to detect missing metadata and re-push it from the buffer.

**SQL Execution Command:**

```bash
docker exec -it harbor-db psql -U postgres -d registry -c "
    UPDATE execution SET status = 'Stopped'
    WHERE vendor_type = 'REPLICATION' AND status IN ('Running', 'Pending');

    UPDATE task SET status = 'Stopped'
    WHERE vendor_type = 'REPLICATION' AND status IN ('Running', 'Pending');
"
```

**Cleanup of Metadata (Optional API Delete):** Delete repository record using double-encoded slash (`%252F`)

```bash
curl -s -k -X DELETE -u <harbor_username>:<harbor_password> \
    https://localhost/api/v2.0/projects/helm-charts/repositories/tigera%252Foperator
```

where `<harbor_username>` and `<harbor_password>` are the username and password for the Harbor admin account.

## Final State Verification

- **Service Health**: All containers are in a `healthy` state and the Harbor UI is accessible.
- **Repository Cleanup**: `helm-charts/tigera/operator` has been completely removed from both the filesystem and the database.
- **Terraform Compatibility**: `terraform plan` executes successfully and reconciles with the restored API.

> [!IMPORTANT]
> **Action Required**: A manual **Garbage Collection** must be executed from the Harbor UI. While metadata cleanup has restored service stability, physical disk space is only reclaimed once the Garbage Collection process removes unreferenced blobs from the shared pool.

## Problem Diagnosis: Duplicate User Conflict (OIDC Identity Drift)

During Keycloak OIDC integration, a login failure may occur with the following JSON error response:

```json
{
    "errors": [
        {
            "code": "UNKNOWN",
            "message": "failed to create user record: user ___ or email ___ already exists"
        }
    ]
}
```

Assume that the duplicated user is `somebody@example.com` with username `somebody`

### Rationale & Trigger Condition

1. **IdP Re-provisioning (UUID Drift)**: If Keycloak users are recreated or the Keycloak provider is redeployed, the underlying user UUID (`sub` claim) changes.
2. **Database Constraint Violation**: Harbor identifies OIDC users uniquely using a concatenation of `sub` and `issuer` in the `oidc_user` table. If the `sub` UUID drifts, Harbor treats the user as new and attempts to auto-onboard them. This triggers a unique constraint violation on `username` or `email` in the `harbor_user` table because the old local record still exists under the old UUID.
3. **Defense in Depth**: Harbor prevents automatic account merging/mapping when `sub` does not match, ensuring that malicious or misconfigured external identities cannot hijack existing local admin or member accounts.

### Resolution Steps

> [!WARNING]
> Prior to deleting the user, ensure no production data or manual projects are uniquely tied to the old local account without a backup. For OIDC-driven environments, all identities should be treated as ephemeral shadow accounts managed by Keycloak.

1. Query the `harbor-db` container inside the bootstrapper host (`core-harbor-bootstrapper-frontend-node-00`) to find the exact `user_id`:

    ```bash
    docker exec harbor-db psql -U postgres -d registry -c "
        SELECT user_id, username, email FROM harbor_user WHERE username = 'somebody';
    "
    ```

    _Assume the returned `user_id` is `<user_id>` (e.g., `3`)._

2. Execute database operations to remove the drifted OIDC mapping and the conflicting user record, respectively

    ```bash
    docker exec harbor-db psql -U postgres -d registry -c "DELETE FROM oidc_user WHERE user_id = <user_id>;"
    docker exec harbor-db psql -U postgres -d registry -c "DELETE FROM harbor_user WHERE user_id = <user_id>;"
    ```

3. Re-login via OIDC on Harbor UI.
