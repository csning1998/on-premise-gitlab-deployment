# ADR 006: Two-Stage Packer Image Build

**Status:** Accepted

**Context:**

Building all VM images from scratch (raw Ubuntu ISO → fully configured service image) in a single Packer pass is slow and brittle. Every time a service configuration changes, the entire OS base (APT updates, locale, kernel tuning) must be re-built. On a single host with limited bandwidth, this is expensive in both time and reliability.

**Decision:**

Implement a two-stage Packer build pipeline:

1. **Stage 1 — Base OS Layer** (`packer/00-base-os/`): Starts from a raw Ubuntu 24.04 ISO. Performs OS-level setup: APT updates, locale, cloud-init configuration, SSH hardening, and base system packages. Produces a `ubuntu-24-updated` golden image stored in the Libvirt storage pool.

2. **Stage 2 — Service Layer** (`packer/10-services/`): Uses the Stage 1 image as a source (`source.qemu.base`). Installs service-specific binaries: `base-postgres`, `base-redis`, `base-vault`, `base-etcd`, `base-haproxy`, `base-minio`, `base-kubeadm`, `base-microk8s`, `docker-harbor`. Each service image is a separate Packer build.

Stage 1 is rebuilt infrequently (OS security patches, Ubuntu point releases). Stage 2 is rebuilt when service versions change.

**Consequences:**

- Significant reduction in build time for service image updates (skip OS setup entirely).
- Stage 1 must be built before Stage 2 — enforced by `entry.sh` menu structure and Packer `source` references.
- Adding a new service requires only a new Stage 2 template; Stage 1 is unchanged.
- Packer state is managed separately per stage; `entry.sh` option `10` clears Stage 2 artifacts without affecting the Stage 1 base image.

**Related:** [Packer Build](../operations/packer-build.md)
