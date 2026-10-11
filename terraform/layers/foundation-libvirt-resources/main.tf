
# The domain suffix and the network baseline are global facts owned by platform-foundation.
module "foundation_libvirt_resources" {
  source = "../../../../platform-foundation/terraform/modules/kvm-provisioning/configure/foundation-resources"

  domain_suffix    = local.state.platform_foundation.foundation_network_global.domain_suffix
  network_baseline = local.state.platform_foundation.foundation_network_global.network_baseline
  service_catalog  = local.service_catalog
}

# Local SSH client configuration resources MUST be materialized in this foundation layer
# because known_hosts verification requires live guest network connectivity realized in later stages.
module "ssh_identity_bootstrap" {
  source = "git::https://gitlab.com/csning1998-lab/platform-engineering-lab/utilities/terraform-provider-sshclient.git//terraform/modules/ssh-identity-bootstrap?ref=49d7d402b9b40183649139fe0eba8be88856f29d"

  identity_hosts = module.foundation_libvirt_resources.ssh_identity.hosts
}

# The catalog module keys every entry by project_code, which this layer injects from a single input.
locals {
  service_catalog = { for name, s in var.service_catalog : name => merge(s, { project_code = var.project_code }) }
}
