# ADR 005: Harbor Bootstrapper as Seed Registry

**Status:** Accepted

**Context:**

Deploying a production Harbor registry on Kubernetes requires pulling container images. But the production Harbor is not yet available — it is the thing being deployed. Pulling directly from the public internet (Docker Hub, Quay.io, GitHub Container Registry) introduces availability risk, rate-limit failures, and network latency during cluster initialization. This is a classic chicken-and-egg problem.

**Decision:**

Deploy a **Bootstrapper Harbor** (`172.16.137.0/24`) as a seed registry before any Kubernetes cluster is provisioned. The Bootstrapper Harbor:

1. Runs on a standalone Docker Engine VM (not Kubernetes).
2. Is provisioned in L30 and configured in L40.
3. Pre-loads all required images (Kubeadm bootstrap images, Harbor Helm chart images, GitLab Helm chart images, cert-manager, Calico/Tigera, etc.) via `helm pull` + `helm push` and `docker pull` + `docker push`.
4. Serves as the OCI registry source for all subsequent Kubernetes cluster bootstraps.

After production Harbor is live, it becomes the primary registry and Bootstrapper Harbor is retained only for re-provisioning scenarios.

**Consequences:**

- Adds one additional VM and Terraform/Ansible layer to the deployment sequence.
- `L30-infra-harbor-bootstrapper-frontend` and `L40-provision-harbor-bootstrapper-frontend` must complete before any Kubernetes cluster layer.
- Helm Chart versions must be explicitly pinned and pre-loaded; this list requires maintenance as versions are updated.
- Eliminates public internet dependency during cluster bootstrap — critical for air-gapped or bandwidth-constrained environments.

**Related layers:** `L30-infra-harbor-bootstrapper-frontend`, `L40-provision-harbor-bootstrapper-frontend`
