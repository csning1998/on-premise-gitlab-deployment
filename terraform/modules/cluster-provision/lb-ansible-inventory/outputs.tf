
output "ansible_inventory_data" {
  description = "Ansible inventory structure for the LB cluster, ready for ansible-runner."
  value       = local.ansible_inventory_data
}
