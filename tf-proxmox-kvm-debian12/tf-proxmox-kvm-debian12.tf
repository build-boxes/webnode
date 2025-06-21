# Adapted from: https://github.com/build-boxes/terraform-proxmox-windows-example/blob/main/main.tf
#
#
# see https://github.com/hashicorp/terraform
terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/cloudinit
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.6"
    }
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.75.0"
    }
    time = {
          source = "hashicorp/time"
          version = "0.13.1"
    }
  }
}

provider "proxmox" {
    endpoint = var.PROXMOX_VE_ENDPOINT
    username = var.PROXMOX_VE_USERNAME
    password = var.PROXMOX_VE_PASSWORD
    insecure = var.PROXMOX_VE_INSECURE
  ssh {
    agent = true
    node {  
      name    = var.proxmox_node_name
      address = var.proxmox_node_address
    }
  }
}

variable "proxmox_node_name" {
  type    = string
  default = "pve"
}

variable "proxmox_node_address" {
  type = string
}

variable "PROXMOX_VE_ENDPOINT" {
    type = string
    default = "https://192.168.4.20:8006/api2/json"
}

variable "PROXMOX_VE_USERNAME" {
    type = string
    sensitive = true
    default = "admin@pve"
}

variable "PROXMOX_VE_PASSWORD" {
    type = string
    sensitive = true
    default = "PassW0rd123!!"
}

variable "PROXMOX_VE_INSECURE" {
    type = bool
    default = false
}


variable "prefix" {
  # This is used to rename the host to this name.description
  # also used as a prefix for text and log files names.
  type    = string
  default = "falcon01"
}

variable "pub_key_file" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "pvt_key_file" {
  type = string
  default = "~/.ssh/id_rsa"
  sensitive = true
}

variable "superuser_username" {
  type    = string
  default = "terraform"
}

variable "superuser_password" {
  type      = string
  sensitive = true
  # NB the password will be reset by the cloudbase-init SetUserPasswordPlugin plugin.
  # NB this value must meet the Windows password policy requirements.
  #    see https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
  # Password with @ symbol has issues in cloudbase-init scripts escape-sequencing in terraform ".tf" files
  default = "HeyH0Password"
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/data-sources/virtual_environment_vms
data "proxmox_virtual_environment_vms" "debian12_templates" {
  tags = ["debian", "debian12", "desktop", "docker", "gnome", "template"]
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "debian12_template" {
  node_name = data.proxmox_virtual_environment_vms.debian12_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.debian12_templates.vms[0].vm_id
}

# the virtual machine cloudbase-init cloud-config.
# NB the parts are executed by their declared order.
# see https://github.com/cloudbase/cloudbase-init
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#cloud-config
# see https://cloudbase-init.readthedocs.io/en/1.1.6/userdata.html#userdata
# see https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config.html
# see https://developer.hashicorp.com/terraform/language/expressions#string-literals
data "cloudinit_config" "example" {
  gzip          = false
  base64_encode = false
  part {
    filename     = "initialize-disks.sh"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #!/bin/bash
      
      # Identify all disks without partitions and initialize them for LVM
      n=2
      for disk in $(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
        if ! lsblk /dev/$disk | grep -q part; then
          echo "Found raw disk: /dev/$disk"
      
          # Create an MBR partition table
          parted -s /dev/$disk mklabel msdos
      
          # Create a single primary partition that spans the entire disk
          parted -s /dev/$disk mkpart primary ext4 0% 100%
      
          # Wait for the kernel to re-read partition table
          partprobe /dev/$disk
      
          # Prepare the partition for LVM (create PV)
          pvcreate /dev/$disk1
      
          # Optional: add to VG (example: vgname)
          vgcreate my_vg_edisk$n /dev/$disk1
          ((n++))
      
          echo "Initialized /dev/$disk1 for LVM"
        fi
      done
      EOF
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_file
resource "proxmox_virtual_environment_file" "example_ci_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node_name
  source_raw {
    file_name = "${var.prefix}-ci-user-data.txt"
    data      = data.cloudinit_config.example.rendered
  }
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "example" {
  name      = var.prefix
  node_name = var.proxmox_node_name
  tags      = sort(["debian12", "example", "terraform"])
  clone {
    vm_id = data.proxmox_virtual_environment_vm.debian12_template.vm_id
    full  = true
  }
  cpu {
    type  = "host"
    #type  = "x86-64-v2-AES"
    cores = 2
  }
  memory {
    dedicated = 3 * 1024
  }
  network_device {
    bridge = "vmbr0"
  }
  disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = 20     # minimum size of the Template image disk.
  }
  ## Add additional Disks here, if required.
  ##
  ##
  disk {      # Boot Disk, Size can be increased here. Then manually Increase Volume size inside Windows-2025.
    interface   = "scsi1"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = 16     # minimum size of the Template image disk.
  }

  agent {
    enabled = true
    #trim    = true
  }
  # NB we use a custom user data because this terraform provider initialization
  #    block is not entirely compatible with cloudbase-init (the cloud-init
  #    implementation that is used in the windows base image).
  # see https://pve.proxmox.com/wiki/Cloud-Init_Support
  # see https://cloudbase-init.readthedocs.io/en/latest/services.html#openstack-configuration-drive
  # see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/resources/virtual_environment_vm#initialization
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.example_ci_user_data.id
    # # >>> Fixed IP -- Start
    # # Use following if need fixed IP Address, otherwise comment out
    ip_config {
      ipv4 {
        address = "192.168.4.80/24"
        gateway = "192.168.4.1"
      }
    }
    dns {
      servers = ["192.168.4.1"]
    }
    # # >>> Fixed IP -- End
  }
}

resource "time_sleep" "wait_1_minutes" {
  depends_on = [proxmox_virtual_environment_vm.example]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "1m"
}

# # NB this can only connect after about 3m15s (because the ssh service in the
# #    windows base image is configured as "delayed start").
resource "null_resource" "ssh_into_vm" {
  depends_on = [time_sleep.wait_1_minutes]
  provisioner "remote-exec" {
    connection {
      target_platform = "unix"
      type            = "ssh"
      host            = coalesce(try(split("/",proxmox_virtual_environment_vm.example.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.example.ipv4_addresses[1][0] )
      user            = var.superuser_username
      password        = var.superuser_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "2m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      echo "Sucessfully logged in as user: '$(whoami)'";
      USERID="${var.superuser_username}";
      BASHRC="/home/${var.superuser_username}/.bashrc";
      if [ -d "/home/${var.superuser_username}" ] && [ -f "$BASHRC" ]; then
        grep -q "/usr/sbin" "$BASHRC" || echo 'export PATH="/usr/sbin:$PATH"' >> "$BASHRC"
        echo "Added /usr/sbin to user PATH variable"
      fi;
      gnome-extensions enable dash-to-dock@micxgx.gmail.com
      echo "Enabled dash-to-dock extension for user."
      # Set dock position to LEFT
      gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
      # Make the dock extend to full height (panel-like)
      gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
      # Disable autohide if you want it always visible
      gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
      # Enable Intellihide
      gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
      # Optional: Set fixed icon size
      gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 32
      # Optional: Make background fully opaque
      gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
      gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.4
      echo "Dash to Dock configured as a left-side panel."
      # Set Windows Buttons
      gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
      echo "Window buttons updated: minimize and maximize enabled."
      # Fix Flathub inclusion in gnome-software app for user
      gnome-software --quit
      flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      echo "Fixed Flathub inclusion in gnome-software App store for User"
      EOF
    ]
  }
}


output "ip" {
  value = coalesce(try(split("/",proxmox_virtual_environment_vm.example.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.example.ipv4_addresses[1][0] )
  #proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0]
}
