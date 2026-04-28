
output "ansible_inventory" {
  description = "The rendered Ansible inventory data and file info."
  value = {
    data      = local.ansible_inventory_data
    content   = module.ansible_runner.inventory_content
    file_path = module.ansible_runner.inventory_file_path
  }
}

output "ansible_extra_vars" {
  description = "The consolidated extra variables for Ansible."
  sensitive   = true
  value       = local.ansible_extra_vars
}
