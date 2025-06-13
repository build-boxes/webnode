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
  default = "eagle01"
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
data "proxmox_virtual_environment_vms" "windows_templates" {
  tags = ["windows", "template", "winserver", "2025"]
}

# see https://registry.terraform.io/providers/bpg/proxmox/0.75.0/docs/data-sources/virtual_environment_vm
data "proxmox_virtual_environment_vm" "windows_template" {
  node_name = data.proxmox_virtual_environment_vms.windows_templates.vms[0].node_name
  vm_id     = data.proxmox_virtual_environment_vms.windows_templates.vms[0].vm_id
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
    filename     = "initialize-disks.ps1"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #ps1_sysnative
      # initialize all (non-initialized) disks with a single NTFS partition.
      # NB we have this script because disk initialization is not yet supported by cloudbase-init.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      Get-Disk `
        | Where-Object {$_.PartitionStyle -eq 'RAW'} `
        | ForEach-Object {
          Write-Host "Initializing disk #$($_.Number) ($($_.Size) bytes)..."
          $volume = $_ `
            | Initialize-Disk -PartitionStyle MBR -PassThru `
            | New-Partition -AssignDriveLetter -UseMaximumSize `
            | Format-Volume -FileSystem NTFS -NewFileSystemLabel "disk$($_.Number)" -Confirm:$false
          Write-Host "Initialized disk #$($_.Number) ($($_.Size) bytes) as $($volume.DriveLetter):."
        }
      EOF
  }
  part {
    filename     = "AdministratorPWD.ps1"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #ps1_sysnative
      # this is a PowerShell script.
      # NB this script will be executed as the cloudbase-init user (which is in the Administrators group).
      # NB this script will be executed by the cloudbase-init service once, but to be safe, make sure its idempotent.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      Start-Transcript -Append "C:\cloudinit-config-example.ps1.log"
      # Define the new password
      $SecurePassword = ConvertTo-SecureString "${var.superuser_password}" -AsPlainText -Force
      
      # Get the administrator account
      $AdminAccount = Get-LocalUser -Name "Administrator"
      
      # Set the new password for the administrator account
      Set-LocalUser -Name "Administrator" -Password $SecurePassword
      
      # Confirm the password was updated
      Write-Output "Administrator password has been updated successfully."
      EOF
  }  
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      hostname: ${var.prefix}
      timezone: America/Toronto
      users:
        - name: ${jsonencode(var.superuser_username)}
          passwd: ${jsonencode(var.superuser_password)}
          primary_group: Administrators
          # ssh_authorized_keys:
          #   - ${jsonencode(trimspace(file("${var.pub_key_file}")))}
      # these runcmd commands are concatenated together in a single batch script and then executed by cmd.exe.
      # NB this script will be executed as the cloudbase-init user (which is in the Administrators group).
      # NB this script will be executed by the cloudbase-init service once, but to be safe, make sure its idempotent.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      runcmd:
        - "echo # Script path"
        - "echo %~f0"
        - "echo # Sessions"
        - "query session"
        - "echo # whoami"
        - "whoami /all"
        - "echo # Windows version"
        - "ver"
        - "echo # Environment variables"
        - "set"
      EOF
  }
  part {
    filename     = "example.ps1"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #ps1_sysnative
      # this is a PowerShell script.
      # NB this script will be executed as the cloudbase-init user (which is in the Administrators group).
      # NB this script will be executed by the cloudbase-init service once, but to be safe, make sure its idempotent.
      # NB the output of this script appears on the cloudbase-init.log file when the
      #    debug mode is enabled, otherwise, you will only have the exit code.
      # Set up Administrators SSH Authorized Keys
      Add-Content -Force -Path "C:\ProgramData\ssh\administrators_authorized_keys" -Value ${jsonencode(trimspace(file("${var.pub_key_file}")))};icacls.exe "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"
      Start-Transcript -Append "C:\cloudinit-config-example.ps1.log"
      function Write-Title($title) {
        Write-Output "`n#`n# $title`n#"
      }
      Write-Title "Script path"
      Write-Output $PSCommandPath
      Write-Title "Sessions"
      query session | Out-String
      Write-Title "whoami"
      whoami /all | Out-String
      Write-Title "Windows version"
      cmd /c ver | Out-String
      Write-Title "Environment Variables"
      dir env:
      Write-Title "TimeZone"
      Get-TimeZone
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
  tags      = sort(["windows-2025", "example", "terraform"])
  clone {
    vm_id = data.proxmox_virtual_environment_vm.windows_template.vm_id
    full  = true
  }
  cpu {
    type  = "host"
    #type  = "x86-64-v2-AES"
    cores = 2
  }
  memory {
    dedicated = 4 * 1024
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
    size        = 32     # minimum size of the Template image disk.
  }
  ## Add additional Disks here, if required.
  ##
  ##
  agent {
    enabled = true
    trim    = true
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
        address = "192.168.4.70/24"
        gateway = "192.168.4.1"
      }
    }
    dns {
      servers = ["192.168.4.1"]
    }
    # # >>> Fixed IP -- End
  }
}

resource "time_sleep" "wait_12_minutes" {
  depends_on = [proxmox_virtual_environment_vm.example]
  # 12 minutes sleep. I have a slow Proxmox Host :(
  create_duration = "12m"
}

# # NB this can only connect after about 3m15s (because the ssh service in the
# #    windows base image is configured as "delayed start").
resource "null_resource" "ssh_into_vm" {
  depends_on = [time_sleep.wait_12_minutes]
  provisioner "remote-exec" {
    connection {
      target_platform = "windows"
      type            = "ssh"
      host            = coalesce(try(split("/",proxmox_virtual_environment_vm.example.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0] )
      user            = var.superuser_username
      password        = var.superuser_password
      private_key = file("${var.pvt_key_file}")
      agent = false
      timeout = "2m"
    }
    # NB this is executed as a batch script by cmd.exe.
    inline = [
      <<-EOF
      whoami.exe /all
      EOF
    ]
  }
}


output "ip" {
  value = coalesce(try(split("/",proxmox_virtual_environment_vm.example.initialization[0].ip_config[0].ipv4[0].address)[0], null),proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0] )
  #proxmox_virtual_environment_vm.example.ipv4_addresses[index(proxmox_virtual_environment_vm.example.network_interface_names, "Ethernet")][0]
}
