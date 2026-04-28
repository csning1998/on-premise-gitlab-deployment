
output "ansible_log" {
  description = "Path to Ansible execution log (standard convention)"
  value       = "${path.cwd}/ansible-deployment.log"
}

/*
output "provision_id" {
  description = "IDs of the ansible_playbook resources"
  value       = jsonencode([ansible_playbook_run.run_playbook.id])
}
*/
