
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.credentials_vm.ssh_public_key_path)
}

resource "libvirt_network" "nat_networks" {

  for_each = var.create_networks ? var.network_infrastructure : {}

  name      = each.value.nat.name
  bridge    = each.value.nat.bridge_name
  mode      = "nat"
  autostart = true

  ips = [{
    address = each.value.nat.gateway
    prefix  = each.value.nat.prefix
    dhcp = {
      enabled = true
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
  bridge    = each.value.hostonly.bridge_name
  mode      = "route"
  autostart = true

  ips = [{
    address = each.value.hostonly.gateway
    prefix  = each.value.hostonly.prefix
  }]
}

resource "libvirt_network" "service_networks" {

  for_each = var.create_networks ? { for seg in var.lb_cluster_service_segments : seg.name => seg } : {}

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

resource "libvirt_volume" "base_image" {
  for_each = local.base_image_map

  name   = "base-${each.key}"
  pool   = var.lb_cluster_vm_config.storage_pool_name
  format = "qcow2"

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
  format   = "qcow2"
  capacity = each.value.os_disk_capacity_gib * 1024 * 1024 * 1024

  backing_store = {
    path   = libvirt_volume.base_image[basename(abspath(each.value.base_image_path))].path
    format = "qcow2"
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
      nat_mac     = each.value.interfaces[0].mac
      nat_ip_cidr = try(each.value.interfaces[0].addresses[0], "")
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
  format   = "iso"

  create = {
    content = {
      url = libvirt_cloudinit_disk.cloud_init[each.key].path
    }
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
          pool   = var.lb_cluster_vm_config.storage_pool_name
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
          pool   = var.lb_cluster_vm_config.storage_pool_name
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
