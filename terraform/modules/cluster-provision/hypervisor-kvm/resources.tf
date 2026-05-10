
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.credentials.ssh_public_key_path)
}

resource "libvirt_network" "nat_net" {

  for_each = var.create_networks ? {
    for k, v in var.libvirt_infrastructure : k => v
    if v.network.nat.mode != "route"
  } : {}

  name      = each.value.network.nat.name_network
  autostart = true

  bridge = {
    name = each.value.network.nat.name_bridge
  }

  forward = {
    mode = each.value.network.nat.mode
  }

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
  autostart = true

  bridge = {
    name = each.value.network.hostonly.name_bridge
  }

  forward = {
    mode = each.value.network.hostonly.mode
  }

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

resource "libvirt_volume" "base_image" {
  for_each = local.base_image_map

  name = "base-${each.key}"
  pool = values(var.libvirt_infrastructure)[0].storage_pool_name
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = each.value
    }
  }
}

resource "libvirt_volume" "os_disk" {
  depends_on = [libvirt_volume.base_image]

  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-os.qcow2"
  pool     = values(var.libvirt_infrastructure)[0].storage_pool_name
  capacity = each.value.os_disk_capacity_gib * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  # Use Copy-on-Write
  backing_store = {
    path = libvirt_volume.base_image[basename(abspath(each.value.base_image_path))].path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "cloud_init" {

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
    mtu              = var.libvirt_infrastructure[each.value.network_tier].network.hostonly.mtu
  })
}

resource "libvirt_volume" "cloud_init_iso" {
  for_each = var.vm_config.all_nodes_map

  name = "${each.key}-cloud-init.iso"
  pool = values(var.libvirt_infrastructure)[0].storage_pool_name

  target = {
    format = {
      type = "iso"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.cloud_init[each.key].path
    }
  }
}

resource "libvirt_domain" "nodes" {

  depends_on = [
    libvirt_volume.os_disk,
    libvirt_cloudinit_disk.cloud_init,
    libvirt_volume.cloud_init_iso
  ]

  for_each = var.vm_config.all_nodes_map

  # 1. Basic Configuration (Required)
  name        = each.key
  type        = "kvm"
  vcpu        = each.value.vcpu
  memory      = each.value.ram_size
  memory_unit = "MiB"
  autostart   = false
  running     = true

  # 2. OS Configuration
  os = {
    type = "hvm"
    arch = "x86_64"
  }

  cpu = {
    mode = "host-passthrough"
  }

  # 3. Hardware Device Configuration (Attributes)
  devices = {
    disks = concat(
      # 1. OS Disk (vda)
      [{
        device = "disk"
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          volume = {
            pool   = values(var.libvirt_infrastructure)[0].storage_pool_name
            volume = libvirt_volume.os_disk[each.key].name
          }
        }
        driver = {
          type = "qcow2"
        }
        boot = {
          order = 1
        }
      }],

      # 2. Attached Data Volumes (vdb, vdc...)
      [for vol in each.value.attached_volumes : {
        device = "disk"
        target = {
          dev = trimprefix(vol.device_name, "/dev/")
          bus = "virtio"
        }
        source = {
          volume = {
            pool   = vol.pool
            volume = vol.volume
          }
        }
        driver = {
          type = "qcow2"
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
          volume = {
            pool   = values(var.libvirt_infrastructure)[0].storage_pool_name
            volume = libvirt_volume.cloud_init_iso[each.key].name
          }
        }
        boot = {
          order = 3
        }
      }]
    )

    # Network Interfaces search by network tier
    interfaces = [
      # 1. NAT Interface
      {
        type = "network"
        source = {
          network = {
            network = var.libvirt_infrastructure[each.value.network_tier].network.nat.name_network
          }
        }
        mac = {
          address = local.nodes_config[each.key].nat_mac
        }
        model = {
          type = "virtio"
        }
      },
      # 2. HostOnly Interface
      {
        type = "network"
        source = {
          network = {
            network = var.libvirt_infrastructure[each.value.network_tier].network.hostonly.name_network
          }
        }
        mac = {
          address = local.nodes_config[each.key].hostonly_mac
        }
        model = {
          type = "virtio"
        }
      }
    ]

    # Other Peripherals
    consoles = [
      {
        type = "pty"
        target = {
          port = 0
          type = "serial"
        }
      },
      {
        type = "pty"
        target = {
          port = 1
          type = "virtio"
        }
      }
    ]

    graphics = [{
      vnc = {
        listen   = "0.0.0.0"
        autoport = "yes"
      }
    }]

    videos = [{
      model = {
        type    = "vga"
        vram    = 16384
        primary = "yes"
        heads   = 1
      }
    }]
  }

  # 4. Lifecycle Management: Ignore Changes for Devices
  lifecycle {
    ignore_changes = [
      devices,
    ]
  }
}
