
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
  }
}

locals {
  # 1. Flatten the nested identity topology into a single map
  # Use identity.cluster_name as the primary O(1) key — NO string concatenation here.
  global_identity_map = merge([
    for s_name, components in local.state.metadata.global_topology_identity : {
      for c_name, identity in components : identity.cluster_name => identity
    }
  ]...)

  # 2. Inherit Layer 00's Pure MECE Volume Map
  global_volume_map = local.state.metadata.global_volume_map

  # 3. Extract unique pool names required for physical storage realization.
  # This includes pools for segments without data disks (root disk pools) 
  # and specific data volume pools.
  unique_pools = toset(distinct(concat(
    [for key, identity in local.global_identity_map : identity.storage_pool_name],
    [for vol_key, vol_data in local.global_volume_map : vol_data.pool_name]
  )))
}
