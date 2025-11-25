
output "ansible_log" {
  description = "Path to Ansible execution log (standard convention)"
  value       = "${var.ansible_config.root_path}/logs/ansible-latest.log"
}

output "provision_id" {
  description = "ID of the null_resource, useful for depends_on"
  value       = null_resource.run_playbook.id
}
