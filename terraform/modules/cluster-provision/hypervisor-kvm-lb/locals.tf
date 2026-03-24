
locals {
  # Extract a map of unique base images to avoid creating duplicate base volumes (Copy-on-Write)
  unique_base_images = toset([for k, v in var.lb_cluster_vm_config.nodes : abspath(v.base_image_path)])

  base_image_map = {
    for path in local.unique_base_images : basename(path) => path
  }
}
