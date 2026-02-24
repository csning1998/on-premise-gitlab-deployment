
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.credentials.ssh_public_key_path)
}

resource "libvirt_network" "nat_net" {

  for_each = var.create_networks ? {
    for k, v in var.libvirt_infrastructure : k => v
    if v.network.nat.mode != "route"
  } : {}

  name      = each.value.network.nat.name_network
  mode      = each.value.network.nat.mode
  bridge    = each.value.network.nat.name_bridge
  autostart = true

  ips = [
    {
      address = each.value.network.nat.ips.address
      prefix  = each.value.network.nat.ips.prefix
      dhcp = each.value.network.nat.ips.dhcp != null ? {
        ranges = [
          {
            start = each.value.network.nat.ips.dhcp.start
            end   = each.value.network.nat.ips.dhcp.end
          }
        ]
      } : null
    }
  ]
}

resource "libvirt_network" "hostonly_net" {

  for_each = var.create_networks ? {
    for k, v in var.libvirt_infrastructure : k => v
    if v.network.hostonly.mode != "route"
  } : {}

  name      = each.value.network.hostonly.name_network
  mode      = each.value.network.hostonly.mode
  bridge    = each.value.network.hostonly.name_bridge
  autostart = true

  ips = [
    {
      address = each.value.network.hostonly.ips.address
      prefix  = each.value.network.hostonly.ips.prefix

      dhcp = each.value.network.hostonly.ips.dhcp != null ? {
        ranges = [
          {
            start = each.value.network.hostonly.ips.dhcp.start
            end   = each.value.network.hostonly.ips.dhcp.end
          }
        ]
      } : null
    }
  ]
}

resource "libvirt_pool" "storage_pool" {
  name = values(var.libvirt_infrastructure)[0].storage_pool_name
  type = "dir"
  target = {
    path = abspath("/var/lib/libvirt/images/${values(var.libvirt_infrastructure)[0].storage_pool_name}")
  }

  lifecycle {
    precondition {
      condition     = length(distinct([for k, v in var.libvirt_infrastructure : v.storage_pool_name])) <= 1
      error_message = "All network tiers must use the same storage_pool_name when using this module."
    }
  }
}

resource "libvirt_volume" "os_disk" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-os.qcow2"
  pool     = libvirt_pool.storage_pool.name
  format   = "qcow2"

  create = {
    content = {
      url = abspath(each.value.base_image_path)
    }
  }
}

resource "libvirt_volume" "data_disk" {
  depends_on = [libvirt_pool.storage_pool]
  for_each   = local.data_disks_flat

  name     = "${each.key}.qcow2"
  pool     = libvirt_pool.storage_pool.name
  format   = "qcow2"
  capacity = each.value.capacity
}

resource "libvirt_cloudinit_disk" "cloud_init" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-cloud-init.iso"

  meta_data = yamlencode({})
  user_data = templatefile("${path.module}/../../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.credentials.username
    vm_password    = var.credentials.password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.module}/../../../templates/network_config.tftpl", {
    nat_mac          = local.nodes_config[each.key].nat_mac
    nat_ip_cidr      = local.nodes_config[each.key].nat_ip_cidr
    hostonly_mac     = local.nodes_config[each.key].hostonly_mac
    hostonly_ip_cidr = local.nodes_config[each.key].hostonly_ip_cidr
    nat_gateway      = var.libvirt_infrastructure[each.value.network_tier].network.nat.ips.address
    hostonly_gateway = var.libvirt_infrastructure[each.value.network_tier].network.hostonly.ips.address
  })
}

resource "libvirt_volume" "cloud_init_iso" {
  for_each = var.vm_config.all_nodes_map

  name   = "${each.key}-cloud-init.iso"
  pool   = libvirt_pool.storage_pool.name
  format = "iso"

  create = {
    content = {
      url = libvirt_cloudinit_disk.cloud_init[each.key].path
    }
  }
}

resource "libvirt_domain" "nodes" {

  depends_on = [
    libvirt_pool.storage_pool,
    libvirt_volume.os_disk,
    libvirt_volume.data_disk,
    libvirt_cloudinit_disk.cloud_init,
    libvirt_volume.cloud_init_iso
  ]

  for_each = var.vm_config.all_nodes_map

  # 1. Basic Configuration (Required)
  name      = each.key
  vcpu      = each.value.vcpu
  memory    = each.value.ram
  unit      = "MiB"
  autostart = false
  running   = true

  # 2. OS Configuration
  os = {
    type = "hvm"
    arch = "x86_64"
  }

  # 3. Hardware Device Configuration (Attributes)
  devices = {
    # Sequence: OS(vda) -> Data(vdb...) -> CloudInit(sda)
    disks = concat(
      # 1. OS Disk (vda)
      [{
        device = "disk"
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          pool   = libvirt_pool.storage_pool.name
          volume = libvirt_volume.os_disk[each.key].name
        }
      }],

      # 2. Data Disks (vdb, vdc...)
      [for idx, disk in each.value.data_disks : {
        device = "disk"
        target = {
          # idx=0 -> vdb, idx=1 -> vdc
          dev = "vd${substr("bcdefghijklmnopqrstuvwxyz", idx, 1)}"
          bus = "virtio"
        }
        source = {
          pool   = libvirt_pool.storage_pool.name
          volume = libvirt_volume.data_disk["${each.key}-${disk.name_suffix}"].name
        }
      }],

      # 3. Cloud-Init (sda)
      [{
        device = "cdrom"
        target = {
          dev = "sda"
          bus = "sata"
        }
        source = {
          pool   = libvirt_pool.storage_pool.name
          volume = libvirt_volume.cloud_init_iso[each.key].name
        }
      }]
    )

    # Network Interfaces search by network tier
    interfaces = [
      # 1. NAT Interface
      {
        type = "network"
        source = {
          network = var.libvirt_infrastructure[each.value.network_tier].network.nat.name_network
        }
        mac = local.nodes_config[each.key].nat_mac
      },
      # 2. HostOnly Interface
      {
        type = "network"
        source = {
          network = var.libvirt_infrastructure[each.value.network_tier].network.hostonly.name_network
        }
        mac = local.nodes_config[each.key].hostonly_mac
      }
    ]

    # Other Peripherals
    consoles = [
      {
        type        = "pty"
        target_type = "serial"
        target_port = 0
      },
      {
        type        = "pty"
        target_type = "virtio"
        target_port = 1
      }
    ]

    graphics = {
      vnc = {
        listen   = "0.0.0.0"
        autoport = "yes"
      }
    }

    video = {
      type = "vga"
    }
  }

  # 4. Lifecycle Management: Ignore Changes for Devices
  lifecycle {
    ignore_changes = [
      devices,
    ]
  }
}
