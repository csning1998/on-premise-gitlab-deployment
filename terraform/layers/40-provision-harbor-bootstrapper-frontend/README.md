# Harbor Bootstrapper Recovery for Disk Exhaustion

## Example Problem Diagnosis: Disk Exhaustion

The `/data/harbor` partition reaching 100% capacity (e.g., 47GB/49GB) results in multiple service failures:

- **`harbor-db` (PostgreSQL)**: Failure to write transaction checkpoints, leading to a constant restart loop.
- **`redis`**: `MISCONF` errors and blocked writes due to persistence failure.
- **`harbor-core` / `harbor-jobservice`**: Initialization failure resulting from underlying database and Redis issues.

In this instance, the primary driver of disk usage was the `helm-charts/tigera/operator` repository, which contained over **2,300 artifacts** and associated blobs.

## Resolution Steps

### 1. Manual Filesystem Recovery

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

    Manual deletion of these blobs freed approximately 1.5GB of space, enabling PostgreSQL to complete its crash recovery process.

### 2. Disabling Automated Replication

The L40 configuration was modified to disable the aggressive replication schedule defined in `replication.tf`:

- The `schedule` attribute was removed from `harbor_replication` resources.
- The `sync-tigera` policy was set to `Disabled` via the API.

**API Execution Command:** # Disable replication policy (Example: Policy ID 2). Note that the full policy object must be sent in PUT request

```bash
curl -s -k -X PUT -u admin:<password> \
    -H 'Content-Type: application/json' \
    -d '{"id":2, "name":"sync-tigera", "enabled":false, "trigger":{"type":"manual"}, ...}' \
    https://localhost/api/v2.0/replication/policies/2
```

### 3. Direct PostgreSQL Intervention

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
