
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

resource "libvirt_pool" "storage_pool" {
  name = var.libvirt_infrastructure.storage_pool_name
  type = "dir"
  target = {
    path = abspath("/var/lib/libvirt/images/${var.libvirt_infrastructure.storage_pool_name}")
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
  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-cloud-init.iso"

  meta_data = yamlencode({})
  user_data = templatefile("${path.root}/../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.credentials.username
    vm_password    = var.credentials.password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.root}/../../templates/network_config.tftpl", {
    nat_mac          = local.nodes_config[each.key].nat_mac
    nat_ip_cidr      = local.nodes_config[each.key].nat_ip_cidr
    hostonly_mac     = local.nodes_config[each.key].hostonly_mac
    hostonly_ip_cidr = local.nodes_config[each.key].hostonly_ip_cidr
    nat_gateway      = var.libvirt_infrastructure.network.nat.ips.address
    hostonly_gateway = var.libvirt_infrastructure.network.hostonly.ips.address
  })
}

resource "libvirt_volume" "cloud_init_iso" {
  depends_on = [libvirt_pool.storage_pool]
  for_each   = var.vm_config.all_nodes_map

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
  for_each = var.vm_config.all_nodes_map

  name    = each.key
  vcpu    = each.value.vcpu
  memory  = each.value.ram
  unit    = "MiB"
  running = true
  type    = "kvm"

  os = {
    type         = "hvm"
    arch         = "x86_64"
    boot_devices = ["hd", "cdrom"]
  }

  devices = {
    emulator = "/usr/bin/qemu-system-x86_64"

    # Sequence: OS(vda) -> Data(vdb...) -> CloudInit(sda)
    disks = concat(
      # 1. OS Disk (vda)
      [{
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

    interfaces = [
      {
        type  = "network"
        model = "virtio"
        mac   = local.nodes_config[each.key].nat_mac
        source = {
          network = libvirt_network.nat_net.name
        }
      },
      {
        type  = "network"
        model = "virtio"
        mac   = local.nodes_config[each.key].hostonly_mac
        source = {
          network = libvirt_network.hostonly_net.name
        }
      }
    ]

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

    video = {
      type = "vga"
    }

    graphics = {
      vnc = {
        listen   = "0.0.0.0"
        autoport = "yes"
      }
    }
  }
}
