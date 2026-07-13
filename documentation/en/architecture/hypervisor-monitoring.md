# Physical Hypervisor Monitoring

## Section 0: Context

Every layer's libvirt provider connects to a single physical KVM host, and every VM this project provisions runs on it, but the host itself sat entirely outside the Terraform and Ansible automation. Its baseline configuration (libvirt socket permissions, kernel sysctls, firewall rules, memlock limits) was documented as manual steps in [Environment Setup](../getting-started/02-environment-setup.md) and [Kernel Tuning](../configuration/kernel-tuning.md), and it had no metrics collection at all, leaving CPU steal time, host-level memory and swap pressure, physical disk I/O contention shared across every VM, and per-VM resource allocation from the hypervisor's own point of view completely invisible. This work converts the manual baseline into idempotent Ansible state and adds two exporters, wired into the same observability pipeline every guest VM already uses.

## Section 1: Host Baseline Automation

1. A new role, `80-hypervisor-baseline`, targets the physical host directly through a local Ansible connection (`hosts: localhost`, `connection: local`), since the host is not a member of any existing VM inventory. The playbook number, `80-playbook-hypervisor.yaml`, and the role's own number reuse the `80-89` range already established for utility roles not tied to a specific service's VM lifecycle, rather than the `00`/`10`/`30`/`40`/`90` numbers that map to Terraform layers, since this host corresponds to no layer at all.
2. The role converts every manual step from Environment Setup and Kernel Tuning into idempotent tasks: libvirt group membership and the `libvirtd.conf` socket delegation plus its systemd socket override, the loose-mode reverse path filtering and conntrack sysctls needed for the project's asymmetric routing design, the TCPMSS clamp firewalld direct rules (verified with `--query-rule` before adding, since direct rules have no dedicated idempotent module), and the memlock limits rootless Podman needs for Vault's `mlock()` calls.
3. One firewalld direct rule found on the live host, an unconditional accept for connection-tracking-invalid packets within the internal subnet, was deliberately left out of this automation. Its packet counter read zero matched packets, indicating it has never actually been needed against real traffic, so it was treated as defensive dead code rather than ported forward.
4. Resolving which user account "the operator" is required an explicit fallback (`SUDO_USER`, then `USER`), since on a local-connection play with privilege escalation, the acting user identity is already root by the time facts are gathered.

## Section 2: Host and Domain Level Exporters

1. Fedora's `node-exporter` package (distinct from the Debian `prometheus-node-exporter` package baked into every guest VM's golden image) is installed directly from the OS repository and exposes host OS metrics on port 9100, the same default port used everywhere else in this project.
2. No Fedora package exists for a libvirt domain-level exporter. `prometheus-libvirt-exporter` is installed from its upstream RPM release asset instead, checksum-verified against the release's own checksums file, on port 9177. Its packaged systemd unit runs as root with no dedicated service user, so it needs no additional group membership to reach the libvirt socket.
3. The two exporters answer different questions from different vantage points. Node exporter reports what the physical machine itself experiences; the libvirt exporter reports what each VM is allocated and consuming from the hypervisor's side, which can diverge from what that same VM's own node_exporter reports about itself when the host is under contention.

## Section 3: Scrape Target Wiring

1. The host's own address on the observability cluster's hostonly bridge is not itself a Terraform-managed resource, so it cannot be read from any layer's remote state the way every other scrape target in this project is. It is, however, already computed correctly by the existing network topology math: the physical host owns the gateway address of every hostonly bridge this project creates, and that gateway address was already available two layers upstream through `module.context.primary_net_config.network.hostonly.gateway`, unused until now.
2. Layer 30 exposes this address as a new output, threaded through Layer 40's existing passthrough pattern to Layer 50, exactly like the cross-route probe targets added earlier. No value is hardcoded; if this segment's `cidr_index` ever changes, the address recomputes correctly with no edit required here.
3. Two entries join the observability cluster's `vm_static_targets`, both labeled with a `hypervisor` component and pointed at the host's gateway address on ports 9100 and 9177. Because that address is on-link for the observability cluster's own network, no static route, no policy-based routing rule, and no ingress hop is needed to reach it, unlike the cross-cluster paths documented in [Loki Log Pipeline](loki-log-pipeline.md).

## Section 4: Verification

1. `terraform output hypervisor_host_ip` at Layer 40 returns the host's actual gateway address on the observability segment, matching what `ip addr` shows on the host itself.
2. `systemctl is-active node_exporter prometheus-libvirt-exporter` on the host reports both active, and each exporter's `/metrics` endpoint returns data locally.
3. Querying Mimir's observability tenant for `up{job=~"hypervisor.*"}` returns two series, `hypervisor-node` and `hypervisor-libvirt`, both with a value of 1 and an `instance` label matching the host's gateway address on each exporter's port.

## Section 5: Out of Scope

Dashboards and alerting rules built on these two new metric sources are not covered here. The defensive firewalld rule found but not automated (Section 1.3) remains manually present on the current host; it is not removed, only left out of the new Ansible-managed baseline.
