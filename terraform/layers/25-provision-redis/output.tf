output "redis_ip_list" {
  description = "List of Redis node IPs"
  value = [
    for node in module.provisioner_kvm.all_nodes_map : node.ip
  ]
}
