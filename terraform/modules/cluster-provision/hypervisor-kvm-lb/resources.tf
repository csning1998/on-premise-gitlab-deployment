
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.credentials_vm.ssh_public_key_path)
}

resource "libvirt_network" "nat_networks" {

  for_each = var.create_networks ? var.network_infrastructure : {}

  name      = each.value.nat.name
  autostart = true

  bridge = {
    name = each.value.nat.bridge_name
  }

  forward = {
    mode = "nat"
  }

  ips = [{
    address = each.value.nat.gateway
    prefix  = each.value.nat.prefix
    dhcp = {
      ranges = each.value.nat.dhcp != null ? [{
        start = each.value.nat.dhcp.start
        end   = each.value.nat.dhcp.end
      }] : []
    }
  }]
}

resource "libvirt_network" "hostonly_networks" {

  for_each = var.create_networks ? var.network_infrastructure : {}

  name      = each.value.hostonly.name
  autostart = true

  bridge = {
    name = each.value.hostonly.bridge_name
  }

  forward = {
    mode = "route"
  }

  ips = [{
    address = each.value.hostonly.gateway
    prefix  = each.value.hostonly.prefix
  }]
}

resource "libvirt_network" "service_networks" {

  for_each = var.create_networks ? { for seg in var.lb_cluster_service_segments : seg.name => seg } : {}

  name      = each.value.name
  autostart = true

  bridge = {
    name = each.value.bridge_name
  }

  forward = {
    mode = "route"
  }

  ips = [
    {
      address = cidrhost(each.value.cidr, 1)
      prefix  = tonumber(split("/", each.value.cidr)[1])
    }
  ]
}

resource "libvirt_volume" "base_image" {
  for_each = local.base_image_map

  name = "base-${each.key}"
  pool = var.lb_cluster_vm_config.storage_pool_name
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
  for_each = var.lb_cluster_vm_config.nodes

  pool     = var.lb_cluster_vm_config.storage_pool_name
  name     = "${each.key}-os.qcow2"
  capacity = each.value.os_disk_capacity_gib * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.base_image[basename(abspath(each.value.base_image_path))].path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "cloud_init" {

  for_each = var.lb_cluster_vm_config.nodes
  name     = "${each.key}-cloud-init.iso"

  meta_data = yamlencode({})
  user_data = templatefile("${path.module}/../../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.credentials_vm.username
    vm_password    = var.credentials_vm.password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.module}/../../../templates/network_config_lb.tftpl", {
    config = {
      mtu         = var.lb_cluster_network_config.network.hostonly.mtu
      nat_mac     = each.value.interfaces[0].mac
      nat_ip_cidr = try(each.value.interfaces[0].addresses[0], "") # Use try to handle the case where the interface has no IP address
      nat_gateway = var.lb_cluster_network_config.network.nat.ips.address

      hostonly_mac     = each.value.interfaces[1].mac
      hostonly_ip_cidr = each.value.interfaces[1].addresses[0]
      hostonly_gateway = var.lb_cluster_network_config.network.hostonly.ips.address

      service_interfaces = [
        for idx, iface in slice(each.value.interfaces, 2, length(each.value.interfaces)) : {
          index       = idx
          os_dev_name = "ens${5 + idx}" # ens3=NAT, ens4=HostOnly, Service start from ens5
          mac_address = iface.mac
          ip_cidr     = iface.addresses[0]
          alias       = iface.alias
        }
      ]
    }
  })
}

resource "libvirt_volume" "cloud_init_iso" {
  for_each = var.lb_cluster_vm_config.nodes
  pool     = var.lb_cluster_vm_config.storage_pool_name
  name     = "${each.key}-cloud-init.iso"

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

  lifecycle {
    replace_triggered_by = [libvirt_cloudinit_disk.cloud_init[each.key]]
  }
}

resource "libvirt_domain" "nodes" {

  depends_on = [
    libvirt_network.service_networks,
    libvirt_network.nat_networks,
    libvirt_network.hostonly_networks,
    libvirt_volume.os_disk,
    libvirt_cloudinit_disk.cloud_init
  ]

  for_each = var.lb_cluster_vm_config.nodes

  # 1. Basic Configuration (Required)
  name        = each.key
  type        = "kvm"
  vcpu        = each.value.vcpu
  memory      = each.value.ram
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
    disks = [
      # First Disk: Operating System
      {
        device = "disk"
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          volume = {
            pool   = var.lb_cluster_vm_config.storage_pool_name
            volume = libvirt_volume.os_disk[each.key].name
          }
        }
        driver = {
          type = "qcow2"
        }
        boot = {
          order = 1
        }
      },
      # Second Disk: Cloud-Init ISO
      {
        device = "cdrom"
        target = {
          dev = "sda"
          bus = "sata"
        }
        source = {
          volume = {
            pool   = var.lb_cluster_vm_config.storage_pool_name
            volume = libvirt_volume.cloud_init_iso[each.key].name
          }
        }
        boot = {
          order = 2
        }
      }
    ]

    # Network Interfaces
    # Lookup the network ID from the map then assign MAC and relative properties to the interface
    interfaces = [
      for iface in each.value.interfaces : {
        type = "network"
        source = {
          network = {
            network = iface.network_name
          }
        }
        mac = {
          address = iface.mac
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
