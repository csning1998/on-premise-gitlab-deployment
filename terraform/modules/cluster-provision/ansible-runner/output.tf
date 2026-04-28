
output "ansible_log" {
  description = "Path to Ansible execution log (standard convention)"
  value       = "${var.ansible_config.root_path}/logs/ansible-latest.log"
}

output "provision_id" {
  description = "IDs of the ansible_playbook resources"
  value       = jsonencode([for p in ansible_playbook.run_playbook : p.id])
}
