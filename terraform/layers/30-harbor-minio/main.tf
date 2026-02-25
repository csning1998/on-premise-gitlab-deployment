
module "minio_harbor" {
  source = "../../middleware/ha-service-kvm-general"

  use_minio_hypervisor = true

  # Identity & Service Definitions
  svc_identity = local.svc_minio_identity
  node_identities = {
    "minio" = local.svc_minio_identity
  }

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure
  network_infrastructure_map = local.network_infrastructure_map

  # System Credentials
  credentials_system = local.sec_system_creds

  # Generic Ansible Configuration
  ansible_inventory_template_file = "inventory-minio-cluster.yaml.tftpl"
  ansible_template_vars           = local.ansible_template_vars
  ansible_extra_vars              = local.ansible_extra_vars
  ansible_playbook_file           = "20-provision-data-services.yaml"
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_harbor]
  create_duration = "30s"
}

module "minio_harbor_config" {
  source     = "../../modules/configuration/minio-bucket-setup"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${local.net_service_vip}:${local.net_minio.lb_config.ports["api"].frontend_port}"
}
