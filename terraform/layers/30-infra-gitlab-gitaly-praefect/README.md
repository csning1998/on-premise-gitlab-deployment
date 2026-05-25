# Layer 30 — GitLab Gitaly / Praefect Infrastructure

Provisions Gitaly storage nodes, Praefect HA proxy nodes, and the Praefect-Patroni PostgreSQL cluster. Runs the corresponding Ansible playbook to configure all services.

## Gitaly HA Migration — Registering Existing Repositories with Praefect

When the Praefect layer is provisioned for the first time against a cluster that already has repositories on disk (e.g., after a fresh `terraform apply` or a Gitaly-to-Praefect topology change), Praefect's metadata database will be empty. The repositories exist on the Gitaly node's disk but are unknown to Praefect, causing GitLab to return `repository not found` errors in the web UI and on git operations.

### Why this happens

Praefect maintains its own metadata database that maps each repository to its primary and replica Gitaly nodes. A fresh Praefect deployment has an empty database — it does not automatically discover repositories already present on the Gitaly nodes' disks.

### Resolution

Run the following steps from a machine with SSH access to both `core-gitlab-gitaly-node-00` (the authoritative storage) and `core-gitlab-praefect-node-00`.

1. **Generate the input file from the authoritative Gitaly node's disk:**

    ```bash
    ssh core-gitlab-gitaly-node-00 \
        'sudo find /var/opt/gitlab/git-data/repositories/@hashed -name "*.git" -type d | \
        while read p; do \
            r="${p#/var/opt/gitlab/git-data/repositories/}"; \
            echo "{\"relative_path\":\"$r\",\"replica_path\":\"$r\",\"virtual_storage\":\"default\",\"authoritative_storage\":\"gitaly-0\"}"; \
        done' > /tmp/repos-to-track.json
    ```

    Verify the generated JSON before proceeding

    ```bash
    cat /tmp/repos-to-track.json
    ```

2. **Copy the input file to the Praefect node and register all repositories:**

    ```bash
    scp /tmp/repos-to-track.json core-gitlab-praefect-node-00:/tmp/

    ssh core-gitlab-praefect-node-00 \
        'sudo gitlab-ctl praefect track-repositories \
            --input-path /tmp/repos-to-track.json \
            --replicate-immediately'
    ```

    `--replicate-immediately` triggers Praefect to replicate from `gitaly-0` to `gitaly-1` and `gitaly-2` synchronously before returning, ensuring all nodes are in sync.

3. **Verify cluster health:**

    ```bash
    ssh core-gitlab-praefect-node-00 'sudo gitlab-ctl praefect check'
    ```

    All checks should pass. The GitLab web UI and git operations will work normally once the repositories are tracked.

### Migration Notes

- The `authoritative_storage` must match the Gitaly node that holds the actual data on disk — typically `gitaly-0` (the node mapped to `core-gitlab-gitaly-node-00`).
- If multiple Gitaly nodes have diverged data, choose the node with the most recent writes as the authoritative storage.
- This step is only required once after initial Praefect provisioning or after a topology change from standalone Gitaly to Praefect HA. Subsequent `terraform apply` runs that do not destroy the Gitaly VMs do not require re-registration.

---

## Praefect HA → Standalone Gitaly Downgrade

Reverting from Praefect HA back to a single standalone Gitaly node requires no data migration. Repository data stays on `gitaly-0`'s disk; GitLab's project records reference the virtual storage `"default"`, which maps directly to the standalone Gitaly storage name. No application database changes are needed.

### Downgrade Procedure

1.  **Update `terraform.tfvars` to remove Praefect topology:**

    ```hcl
    target_clusters = {
      "gitaly" = "core-gitlab-gitaly"
      # Remove or comment out "praefect" and "praefect-patroni" entries
    }
    ```

    In `service_config`, also comment out `gitaly` nodes `01` and `02` to keep only the single `node-00`.

2.  **Apply L30 to destroy Praefect and Patroni VMs:**

    ```bash
    cd terraform/layers/30-infra-gitlab-gitaly-praefect
    terraform apply -auto-approve
    ```

    Terraform destroys Praefect proxy VMs and Praefect-Patroni VMs. The `gitaly-node-00` VM and its data volume are preserved.

3.  **Re-apply L50 to switch GitLab's endpoint back to Gitaly VIP:**

    ```bash
    cd terraform/layers/50-platform-gitlab-frontend
    terraform apply -auto-approve
    ```

    L50 detects `has_praefect = false` (no Praefect nodes in L30 state) and updates the GitLab Helm release to:
    - Point `gitaly.external_address` at the Gitaly VIP instead of the Praefect VIP
    - Use `gitaly_token` (instead of `praefect_external_token`) for the `gitaly-secret` Kubernetes secret

4.  **Verify:**

    GitLab web UI should load repositories without errors, where `git push/pull` should work against the Gitaly VIP endpoint

    ```bash
    ssh core-gitlab-gitaly-node-00 'sudo gitlab-ctl status gitaly'
    ```

### Downgrade Notes

- **No `track-repositories` needed on the way back.** Standalone Gitaly does not use a metadata database; it reads directly from disk.
- **Data volume is preserved.** As long as `gitaly-node-00` is not destroyed, all repository data survives the topology change.
- **Replica Gitaly nodes (`gitaly-1`, `gitaly-2`) are destroyed** by the Terraform apply. Their data is lost; `gitaly-0` becomes the sole source of truth. Ensure `gitaly-0` is fully up-to-date (Praefect replication lag = 0) before downgrading if data integrity matters.
