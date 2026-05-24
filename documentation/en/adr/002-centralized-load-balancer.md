# ADR 002: Centralized Load Balancer with Policy-Based Routing

**Status:** Accepted

**Context:**

In a single-host KVM deployment with ~15 network segments, each service cluster needs its own VIP (HAProxy + Keepalived). Running a dedicated load balancer VM per service would consume excessive RAM. A shared load balancer must handle traffic for multiple segments without routing conflicts.

**Decision:**

Deploy a shared Central LB (CLB) with 2 VMs in HA pair (`172.16.125.0/24`). Each service VIP is hosted on the CLB. Traffic is forwarded via HAProxy TCP passthrough to the appropriate backend cluster.

For response routing, implement **Policy-Based Routing (PBR)** on the CLB:

- Each service segment gets a dedicated routing table (`rt_<service>`) keyed to that service's VIP source address.
- Standard segments route return packets via the Libvirt bridge gateway (`.1`).
- **Exception: Vault segment** (`172.16.136.0/24`) uses `scope link` for all subnets — direct L2 return without going through the router — because Vault uses mTLS and requires low-latency direct paths.

**Consequences:**

- Saves ~7 GiB RAM compared to per-service LB VMs.
- Requires asymmetric routing support on the Host OS: `rp_filter=2` (loose mode).
- Requires `bridge-nf-call-iptables=0` to prevent double-processing of L2 traffic.
- PBR configuration in Ansible must be maintained as segments are added.
- Vault's L2 exception pattern is unique and must be documented carefully to avoid confusion.

**Related:** [Network Topology](../architecture/network-topology.md), [Kernel Tuning](../configuration/kernel-tuning.md)
