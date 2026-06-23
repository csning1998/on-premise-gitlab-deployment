# Troubleshooting

## DNS Host Update Failure on Existing Networks

When a new service is added to `00-foundation-metadata`, running `terraform apply` in this layer will fail with the following error on one or more existing networks:

> Provider produced inconsistent result after apply
> .dns.host: element N has vanished.

### Root Cause

The `dmacvicar/libvirt` provider uses `virNetworkDefineXML()` to update existing networks. For networks that are currently active, this call updates only the persistent on-disk configuration. The provider then reads back the result using `virNetworkGetXMLDesc()` with `flags=0`, which returns the active in-memory configuration.

Because the active configuration is not reloaded by `DefineXML`, the newly added DNS host entry is absent in the read-back, and Terraform reports the inconsistency.

Newly created networks are not affected because creation uses `DefineXML` followed by `virNetworkCreate()`, which activates the network with the full configuration including the new entry.

### Recovery Procedure

1. **Confirm that the persistent XML was updated.**

    Run the following for one of the failing networks:

    ```bash
    sudo virsh net-dumpxml --inactive core-gitlab-minio | grep -c "<ip address>"
    ```

    If the count matches the expected number of DNS host entries, the persistent configuration is correct and only the active configuration needs updating.

2. **Update the active configuration of all existing networks.**

    Replace the `XML` value with the DNS host block for the newly added service, then run the script. All 40 existing networks (20 hostonly + 20 NAT) require the update.

    ```bash
    XML='<host ip="<NEW_SERVICE_VIP>"><hostname><HOSTNAME_1></hostname></host>'
    ```

    If the service has $k$ hostnames, then $k$ sets of `<hostname><HOSTNAME_i></hostname>` XML blocks are required, where $i \in [1, k]$. Refer to the Reference Values sections at the bottom of this document for concrete examples of filled-in XML blocks.

    ```bash
    for net in \
        core-central-lb-frontend \
        core-gitlab-postgres core-gitlab-etcd \
        core-gitlab-redis core-gitlab-minio \
        core-gitlab-frontend core-gitlab-runner \
        core-gitlab-gitaly core-gitlab-praefect \
        core-gitlab-praefect-patroni \
        core-harbor-bootstrapper-frontend \
        core-harbor-postgres core-harbor-etcd \
        core-harbor-redis core-harbor-minio \
        core-harbor-frontend \
        core-keycloak-frontend core-vault-frontend \
        core-observability-frontend \
        core-observability-minio; \
    do
        sudo virsh net-update "$net"       add dns-host --xml "$XML" --live
        sudo virsh net-update "${net}-nat" add dns-host --xml "$XML" --live
    done
    ```

    When a new service is provisioned and its network is added to this list, add both the hostonly and NAT network names to the loop.

3. **Synchronise the Terraform state.**

    ```bash
    terraform plan -refresh-only
    ```

    Review the output to confirm only the expected DNS drift is reported, then apply:

    ```bash
    terraform apply -refresh-only
    ```

4. **Verify the plan is clean.**

    ```bash
    terraform apply -auto-approve
    ```

    The plan should show no changes. If any network still reports a DNS diff, rerun step 2 for that specific network and repeat steps 3 and 4.

---

## Cloud Init ISO Replacement

### Timing of Operation

`libvirt_volume.cloud_init_iso` does not support in-place updates. The following events trigger a cloud-init configuration change that requires replacement:

- **Adding a new service to `00-foundation-metadata`**: the Central Load Balancer receives a new NIC for the new service segment, which regenerates the cloud-init network configuration.
- **KVM host reboot**: libvirt loses the in-memory cloud-init disk state, causing Terraform to detect a diff and attempt an unsupported update.

Without replacement, `terraform apply` will fail with:

> Error: Update Not Supported
> Storage volumes cannot be updated. All changes require replacement.

### Affected Layers

This applies to L10, L15, and all L30 layers. The script below discovers `cloud_init_iso` resources from each layer's Terraform state and replaces them.

1. **Navigate to the Layer base**:

    ```bash
    cd /terraform/layers
    ```

2. **Execute the following script:**

    ```bash
    for layer_dir in \
        10-shared-load-balancer-frontend \
        15-shared-vault-frontend \
        30-infra-*/; do
        layer=$(basename "$layer_dir")
        echo "=== $layer ==="

        replace_args=()
        while IFS= read -r res; do
            [[ -n "$res" ]] && replace_args+=("-replace=${res}")
        done < <(cd "$layer_dir" && terraform state list 2>/dev/null | grep 'cloud_init_iso' || true)

        if [[ ${#replace_args[@]} -eq 0 ]]; then
            echo "  no cloud_init_iso resources found, skipping"
            continue
        fi

        echo "  replacing: ${replace_args[*]}"
        (cd "$layer_dir" && terraform apply -auto-approve "${replace_args[@]}")
    done
    ```

---

### Reference Values for `observability.frontend` (`cidr_index` 143)

The following values were used when the `observability.frontend` component was added:

```text
VIP:        172.16.143.250
Hostnames:  core-observability-frontend.production.homelab-infra.dev
            grafana.observability.production.homelab-infra.dev
            observability.production.homelab-infra.dev
```

XML block:

```xml
<host ip="172.16.143.250">
    <hostname>core-observability-frontend.production.homelab-infra.dev</hostname>
    <hostname>grafana.observability.production.homelab-infra.dev</hostname>
    <hostname>observability.production.homelab-infra.dev</hostname>
</host>
```

### Reference Values for `observability.minio` (`cidr_index` 144)

The following values were used when the `observability.minio` component was added:

```text
VIP:        172.16.144.250
Hostnames:  core-observability-minio.production.homelab-infra.dev
```

XML block:

```xml
<host ip="172.16.144.250">
    <hostname>core-observability-minio.production.homelab-infra.dev</hostname>
</host>
```
