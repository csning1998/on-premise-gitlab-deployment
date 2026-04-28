
output "inventory_content" {
  value = local_file.inventory.content
}

output "inventory_file_path" {
  value = local_file.inventory.filename
}
