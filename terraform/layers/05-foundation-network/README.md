# Troubleshooting

## DNS Host Update Failure on Existing Networks

When a new service is added to `00-foundation-metadata`, `terraform apply` in this layer will fail on one or more existing networks with the following error:

> Provider produced inconsistent result after apply
> .dns.host: element N has vanished.

### Root Cause

The `dmacvicar/libvirt` provider uses `virNetworkDefineXML()` to update existing networks. For networks that are currently active, this call only updates the persistent on-disk configuration. The provider then reads the result back using `virNetworkGetXMLDesc()` with `flags=0`, which returns the active in-memory configuration rather than the updated persistent one.

Because `DefineXML` does not reload the active configuration, the newly added DNS host entry is absent from the read-back, and Terraform reports the inconsistency.

Newly created networks are not affected. Creation uses `DefineXML` followed by `virNetworkCreate()`, which starts the network with the full updated configuration already in place.

### Recovery Procedure

1. **Confirm that the persistent XML was updated.**

    Run the following for one of the failing networks:

    ```bash
    sudo virsh net-dumpxml --inactive core-gitlab-minio | grep -c "<ip address>"
    ```

    If the count matches the expected number of DNS host entries, the persistent configuration is correct and only the active configuration needs to be updated.

2. **Update the active configuration of all existing networks.**

    Set the `XML` variable to the DNS host block for the newly added service, then run the script. All 40 existing networks (20 hostonly + 20 NAT) require the update.

    ```bash
    XML='<host ip="<NEW_SERVICE_VIP>"><hostname><HOSTNAME_1></hostname></host>'
    ```

    If the service has $k$ hostnames, include $k$ `<hostname><HOSTNAME_i></hostname>` elements in the block, where $i \in [1, k]$. The Reference Values sections at the bottom of this document provide filled-in examples.

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
        sudo virsh net-update "$net"       add dns-host --xml "$XML" --live --config
        sudo virsh net-update "${net}-nat" add dns-host --xml "$XML" --live --config
    done
    ```

    When a new service is provisioned, add both its hostonly and NAT network names to this loop.

3. **Synchronise the Terraform state.**

    ```bash
    terraform plan -refresh-only
    ```

    Review the output to confirm that only the expected DNS drift is reported, then apply:

    ```bash
    terraform apply -refresh-only
    ```

4. **Verify the plan is clean.**

    ```bash
    terraform apply -auto-approve
    ```

    The plan should show no changes. If any network still reports a DNS diff, rerun step 2 for that specific network and repeat steps 3 and 4.

---

## DNS Host Insertion-Order Mismatch

When two or more services are added to `00-foundation-metadata` in the same commit and applied together, `terraform apply` in this layer may fail with:

> Provider produced inconsistent result after apply
> .dns.host[N].ip: was cty.StringVal("A"), but now cty.StringVal("B").
> .dns.host[N+1].ip: was cty.StringVal("B"), but now cty.StringVal("A").
> .dns.host[N].hostnames: element M has vanished.

The error reports two adjacent host entries with swapped IPs, and a hostname count mismatch at one of those positions.

### Cause

The `global_dns_hosts` local in L05 sorts host entries by IP using Terraform's `sort()` function. However, when Terraform first creates or updates the networks, the `for_each` on `net_infrastructure` processes map keys in a non-deterministic order (Go map iteration is randomised at runtime). The resulting insertion order in the libvirt active configuration may differ from the sorted order Terraform expects.

Since `GetXMLDesc(flags=0)` returns the active configuration (in insertion order), and Terraform plans against the sorted order, every subsequent apply detects a diff, calls `DefineXML`, and reads back the same insertion-order active config. This creates a permanent mismatch loop: `DefineXML` updates the persistent config to sorted order, but `GetXMLDesc` always returns the active config in its original insertion order.

**Observed instance (2026-06-24)**: When `observability-frontend` (`172.16.143.250`) and `observability-minio` (`172.16.144.250`) were deployed in the same apply, the provider inserted `172.16.144.250` before `172.16.143.250` in all 40 networks. Terraform's `sort()` expects `143.250` at index 18 and `144.250` at index 19; the active config had them reversed.

Confirmed via:

```bash
sudo virsh net-dumpxml core-keycloak-frontend-nat | grep "143.250\|144.250"
# Output showed 144.250 before 143.250
```

### Recovery

Delete the out-of-order entry from all networks and re-add it. `virsh net-update add dns-host` always appends to the end of the list, so deleting and re-adding the higher-IP entry moves it after the lower-IP entry, restoring sorted order.

In the observed instance, `172.16.144.250` must be moved after `172.16.143.250`:

```bash
XML_144='<host ip="172.16.144.250"><hostname>core-observability-minio.production.homelab-infra.dev</hostname></host>'

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
    sudo virsh net-update "$net"       delete dns-host --xml "$XML_144" --live --config
    sudo virsh net-update "$net"       add    dns-host --xml "$XML_144" --live --config
    sudo virsh net-update "${net}-nat" delete dns-host --xml "$XML_144" --live --config
    sudo virsh net-update "${net}-nat" add    dns-host --xml "$XML_144" --live --config
done
```

Then synchronise state and verify:

```bash
terraform apply -refresh-only
terraform apply -auto-approve
```

The plan should show no changes.

**General pattern**: When this error appears for two adjacent IPs after a multi-service deploy, compare the swapped positions against the expected `sort()` order to identify which IP is displaced. Delete and re-add the higher IP to push it past the lower one. Only `--live` is strictly required to fix the active config, but passing `--config` as well keeps persistent and active in sync.

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

### Post-Domain-Replace Cloud-Init Resync

Replacing `cloud_init_iso` updates the ISO file on disk, but that alone does not cause cloud-init to re-apply its configuration to an already-running or newly-started VM.

When `libvirt_domain` is replaced via `terraform apply -replace` without also replacing the OS disk (`libvirt_volume`), the new VM boots from the existing OS disk. That disk still holds the cached cloud-init state at `/var/lib/cloud/`, including the `instance-id` from the original run. On startup, cloud-init compares the ISO's `instance-id` against the cached value, and if they match, it skips all reconfiguration, including the network-config stage, even if the ISO now contains updated NIC definitions.

Two conditions can trigger this:

- A new service segment is added to the SSoT and L10 is re-applied to update the `libvirt_domain` NIC definitions.
- The `libvirt_domain` is force-replaced to work around a provider diff-detection bug.

**Recovery**: After Ansible provisioning finishes on the affected nodes, clear the instance cache to force a full cloud-init run on the next reboot:

```bash
sudo cloud-init clean --logs && sudo reboot
```

After the reboot, confirm that all expected interfaces appear in `/etc/netplan/50-cloud-init.yaml` with addresses assigned before running any further Ansible plays.

---

### Reference Values for `observability.frontend` (`cidr_index` 143)

The following values reflect the current state after adding the `mimir` ingress subdomain. When a new subdomain is added to an existing VIP (rather than a new service being introduced), use `modify dns-host` instead of `add dns-host` to update the active configuration.

```text
VIP:        172.16.143.250
Hostnames:  core-observability-frontend.production.homelab-infra.dev
            grafana.observability.production.homelab-infra.dev
            mimir.observability.production.homelab-infra.dev
            observability.production.homelab-infra.dev
```

XML block:

```xml
<host ip="172.16.143.250">
    <hostname>core-observability-frontend.production.homelab-infra.dev</hostname>
    <hostname>grafana.observability.production.homelab-infra.dev</hostname>
    <hostname>mimir.observability.production.homelab-infra.dev</hostname>
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
