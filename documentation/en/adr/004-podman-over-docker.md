# ADR 004: Podman Over Docker for IaC Controller

**Status:** Accepted

**Context:**

The IaC controller container (`iac-runner`) needs to connect to the Libvirt UNIX socket (`/var/run/libvirt/libvirt-sock`) to manage KVM resources via the Terraform libvirt provider. On Fedora/RHEL systems with SELinux enforcing, Docker containers run under the `container_t` SELinux domain.

The SELinux policy prohibits `container_t` from connecting to the `virt_var_run_t` UNIX socket, even when the socket is mounted with correct `0770` permissions and group ownership. This results in **Permission denied** errors for `virsh` or the Terraform libvirt provider inside Docker containers.

**Decision:**

Use Podman (rootless) as the container runtime for the IaC controller. In rootless Podman, the process context (`task_struct`) is the host user's `unconfined_t` or similar SELinux type, rather than being restricted to `container_t`. Assuming the user is a member of the `libvirt` group, connection to the Libvirt socket proceeds successfully without additional SELinux policy adjustments.

**Consequences:**

- No SELinux policy customization required.
- `podman compose` replaces `docker compose` for all container operations.
- Users on non-SELinux systems (Ubuntu, Debian) can use Docker with standard socket mounting; Podman remains recommended for consistency.
- If Docker must be used on SELinux systems, alternatives include: disabling SELinux (not recommended), custom SELinux modules, or enabling TCP connections for `libvirtd` at the cost of reduced security.

**Related:** [Environment Setup](../getting-started/02-environment-setup.md)
