# ADR 006: Two-Stage Packer Image Build

**Status:** Accepted

**Context:**

Building all VM images from scratch, starting from a raw Ubuntu ISO and ending at a fully configured service image, in a single Packer pass is slow and brittle. Every time a service configuration changes, the entire OS base (APT updates, locale, kernel tuning) must be re-built. On a single host with limited bandwidth, this is expensive in both time and reliability.

**Decision:**

Implement a two-stage Packer build pipeline:

1. **Stage 1: Distro Layer** (`packer/distro/` of `platform-foundation`): Starts from a raw Ubuntu 24.04 ISO. Performs OS-level setup: APT updates, locale, cloud-init configuration, SSH hardening, and base system packages. Produces the `ubuntu-24-updated` golden image in the `packer/output` directory of `platform-foundation`.

2. **Stage 2: Service Layer**: Uses the Stage 1 image as a source. `platform-foundation` builds the shared service images `base-baremetal-postgres`, `base-baremetal-redis`, `base-baremetal-etcd`, `base-baremetal-minio`, `base-kubernetes-kubeadm`, and `base-kubernetes-microk8s`. This repository builds only `base-baremetal-gitaly-praefect` in `packer/services/`, because Gitaly and Praefect are specific to GitLab. Each service image is a separate Packer build.

Stage 1 is rebuilt infrequently (OS security patches, Ubuntu point releases). Stage 2 is rebuilt when service versions change.

**Consequences:**

- Significant reduction in build time for service image updates (skip OS setup entirely).
- Stage 1 in `platform-foundation` must be built before Stage 2 in this repository, which is enforced by the Packer `source_image` reference.
- Adding a new service requires only a new Stage 2 template, and Stage 1 is unchanged.
- Packer state is managed separately per stage, and the `entry.sh` purge option clears the Stage 2 artifacts of this repository without affecting the Stage 1 base image of `platform-foundation`.

**Related:** [Packer Build](../operations/packer-build.md)
