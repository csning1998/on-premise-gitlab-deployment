
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.credentials.ssh_public_key_path)
}

resource "libvirt_network" "nat_net" {
  name      = var.libvirt_infrastructure.network.nat.name_network
  mode      = var.libvirt_infrastructure.network.nat.mode
  bridge    = var.libvirt_infrastructure.network.nat.name_bridge
  autostart = true

  ips = [
    {
      address = var.libvirt_infrastructure.network.nat.ips.address
      prefix  = var.libvirt_infrastructure.network.nat.ips.prefix

      dhcp = var.libvirt_infrastructure.network.nat.ips.dhcp != null ? {
        ranges = [
          {
            start = var.libvirt_infrastructure.network.nat.ips.dhcp.start
            end   = var.libvirt_infrastructure.network.nat.ips.dhcp.end
          }
        ]
      } : null
    }
  ]
}

resource "libvirt_network" "hostonly_net" {
  name      = var.libvirt_infrastructure.network.hostonly.name_network
  mode      = var.libvirt_infrastructure.network.hostonly.mode
  bridge    = var.libvirt_infrastructure.network.hostonly.name_bridge
  autostart = true

  ips = [
    {
      address = var.libvirt_infrastructure.network.hostonly.ips.address
      prefix  = var.libvirt_infrastructure.network.hostonly.ips.prefix

      dhcp = var.libvirt_infrastructure.network.hostonly.ips.dhcp != null ? {
        ranges = [
          {
            start = var.libvirt_infrastructure.network.hostonly.ips.dhcp.start
            end   = var.libvirt_infrastructure.network.hostonly.ips.dhcp.end
          }
        ]
      } : null
    }
  ]
}

resource "libvirt_network" "service_networks" {
  for_each = { for seg in var.service_segments : seg.name => seg }

  name      = each.value.name        # e.g., "gitlab-frontend"
  bridge    = each.value.bridge_name # e.g., "br-gitlab-front"
  mode      = "route"
  autostart = true

  ips = [
    {
      address = cidrhost(each.value.cidr, 1)
      prefix  = tonumber(split("/", each.value.cidr)[1])
    }
  ]
}

resource "libvirt_pool" "storage_pool" {
  name = var.libvirt_infrastructure.storage_pool_name
  type = "dir"
  target = {
    path = abspath("/var/lib/libvirt/images/${var.libvirt_infrastructure.storage_pool_name}")
  }
}

resource "libvirt_volume" "os_disk" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config
  name     = "${each.key}-os.qcow2"
  pool     = libvirt_pool.storage_pool.name
  format   = "qcow2"

  create = {
    content = {
      url = abspath(each.value.base_image_path)
    }
  }
}

resource "libvirt_cloudinit_disk" "cloud_init" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config
  name     = "${each.key}-cloud-init.iso"

  meta_data = yamlencode({})
  user_data = templatefile("${path.module}/../../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.credentials.username
    vm_password    = var.credentials.password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.module}/../../../templates/network_config_lb.tftpl", {
    config = {
      nat_mac     = each.value.interfaces[0].mac
      nat_ip_cidr = try(each.value.interfaces[0].addresses[0], "")
      nat_gateway = var.libvirt_infrastructure.network.nat.ips.address

      hostonly_mac     = each.value.interfaces[1].mac
      hostonly_ip_cidr = try(each.value.interfaces[1].addresses[0], "")
      hostonly_gateway = var.libvirt_infrastructure.network.hostonly.ips.address

      service_interfaces = [
        for idx, iface in slice(each.value.interfaces, 2, length(each.value.interfaces)) : {
          index       = idx
          os_dev_name = "ens${5 + idx}" # ens3=NAT, ens4=HostOnly, Service start from ens5
          mac_address = iface.mac
          ip_cidr     = try(iface.addresses[0], "")
          alias       = iface.alias
        }
      ]
    }
  })
}

resource "libvirt_volume" "cloud_init_iso" {
  for_each = var.vm_config

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
    libvirt_network.service_networks,
    libvirt_network.nat_net,
    libvirt_network.hostonly_net,
    libvirt_volume.cloud_init_iso,
    libvirt_volume.os_disk,
    libvirt_cloudinit_disk.cloud_init,
    libvirt_pool.storage_pool
  ]

  for_each = var.vm_config

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
    disks = [
      # First Disk: Operating System
      {
        device = "disk"
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          pool   = libvirt_pool.storage_pool.name
          volume = libvirt_volume.os_disk[each.key].name
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
          pool   = libvirt_pool.storage_pool.name
          volume = libvirt_volume.cloud_init_iso[each.key].name
        }
      }
    ]

    # Network Interfaces
    # Lookup the network ID from the map then assign MAC and relative properties to the interface
    interfaces = [
      for iface in each.value.interfaces : {
        type   = "network"
        source = { network = iface.network_name }
        mac    = iface.mac
      }
    ]

    # Other Peripherals
    consoles = [
      {
        type        = "pty"
        target_port = 0
        target_type = "serial"
      },
      {
        type        = "pty"
        target_port = 1
        target_type = "virtio"
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
