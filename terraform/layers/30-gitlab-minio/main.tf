
module "minio_gitlab" {
  source = "../../middleware/ha-service-kvm-general"

  use_minio_hypervisor = true

  # Identity & Service Definitions
  cluster_name = local.svc_cluster_name

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # System Credentials
  credentials_system = local.sec_system_creds

  # Generic Ansible Configuration
  ansible_inventory_content = local.ansible_inventory_content
  ansible_extra_vars        = local.ansible_extra_vars
  ansible_playbook_file     = "20-provision-data-services.yaml"
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_gitlab]
  create_duration = "30s"
}

module "minio_gitlab_config" {
  source     = "../../modules/configuration/minio-bucket-setup"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials"
  minio_server_url         = "https://${local.net_service_vip}:${local.net_minio.lb_config.ports["api"].frontend_port}"
}
