
output "storage_infrastructure_map" {
  description = "Physical realization of the global volume map. Ready to be plugged into KVM instances."
  value       = local.global_volume_map
}
