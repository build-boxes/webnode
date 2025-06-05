
#############
# providers.tf
#############

terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }    
  }
}

provider "azurerm" {
  features {}

  client_id       = var.az_app_sp_id
  client_secret   = var.az_sp_secret
  tenant_id       = var.az_tenant
  subscription_id = var.az_subscription_id
}

provider "local" {
  
}

############
# main.tf
############


resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                        = "RDP"
    priority                    = 1000
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "3389"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

security_rule {

  name                        = "winRM"
  priority                    = 1005
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5986"
  source_address_prefix       = "*" 
  destination_address_prefix  = "*"
}

  security_rule {
    name                       = "HTTP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

    security_rule {
    name                       = "HTTPS"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}


# Create virtual machine
resource "azurerm_windows_virtual_machine" "myvm" {
  name                  = "myWin11pro"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_F2s_v2"

  os_disk {
    name                 = "myWin11proDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "microsoftwindowsdesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }

  computer_name = "hostname"
  admin_username = var.username
  admin_password = var.root_password

  identity {
    type = "SystemAssigned"
  }

  # admin_ssh_key {
  #   username   = var.username
  #   public_key = file(var.pub_key)
  # }

  # provisioner "remote-exec" {
  #   inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

  #   connection {
  #     host        = azurerm_windows_virtual_machine.myvm.public_ip_address
  #     type        = "ssh"
  #     user        = var.username
  #     private_key = file(var.pvt_key)
  #   }
  # }

  #provisioner "local-exec" {
  #  #interpreter = ["/bin/bash"]
  #  working_dir = ".."
  #  command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u '${var.username}' -i '${azurerm_windows_virtual_machine.myvm.public_ip_address},' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' main.yml"
  #}

}


## Setup winRM

/*
  resource "azurerm_virtual_machine_extension" "setup_winrm" {
  count                = 1
  name                 = "enable-winrm-1"
  virtual_machine_id   = azurerm_windows_virtual_machine.myvm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell.exe -Command \"if (-Not (Test-Path -Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' }; $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My; $thumbprint = $cert.Thumbprint; $certPath = 'C:\\Temp\\winrm-cert.cer'; Export-Certificate -Cert \\\"Cert:\\LocalMachine\\My\\$thumbprint\\\" -FilePath $certPath; Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\\LocalMachine\\Root; New-Item -Path WSMan:\\localhost\\Listener -Transport HTTPS -Address * -CertificateThumbprint $thumbprint -Force; Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true; New-NetFirewallRule -Name \\\"WinRM_HTTPS\\\" -DisplayName \\\"WinRM over HTTPS\\\" -Protocol TCP -LocalPort 5986 -Action Allow; exit 0\""
  })
}
 */

# resource "azurerm_virtual_machine_extension" "setup_python3" {
#   count                = 1
#   name                 = "enable-python3"
#   virtual_machine_id   = azurerm_windows_virtual_machine.myvm.id
#   publisher            = "Microsoft.Compute"
#   type                 = "CustomScriptExtension"
#   type_handler_version = "1.10"

#   settings = jsonencode({
#     commandToExecute = "powershell.exe -Command \"winget install Python.Python.3.12 --disable-interactivity ; exit 0\""
#   })
# }

/*
  resource "azurerm_virtual_machine_extension" "run_powershell_script" {
  name                 = "RunPowerShellScript"
  virtual_machine_id   = azurerm_windows_virtual_machine.example.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    # A web Host is needed, or see 2nd method below.
    "fileUris": ["https://example.com/scripts/my_script.ps1"],
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File my_script.ps1"
  }
  SETTINGS
} */

/*
# PowerShell commands to convert *.ps1 file to Base64String
$scriptPath = "C:\path\to\your_script.ps1"
$base64Script = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $scriptPath -Raw)))
$base64Script
*/

resource "azurerm_virtual_machine_extension" "script_ps1_combined_installer" {
  name                 = "RunPS1Script_Combined"
  virtual_machine_id   = azurerm_windows_virtual_machine.myvm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell.exe -Command \"if (-Not (Test-Path -Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' }; $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My; $thumbprint = $cert.Thumbprint; $certPath = 'C:\\Temp\\winrm-cert.cer'; Export-Certificate -Cert \\\"Cert:\\LocalMachine\\My\\$thumbprint\\\" -FilePath $certPath; Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\\LocalMachine\\Root; New-Item -Path WSMan:\\localhost\\Listener -Transport HTTPS -Address * -CertificateThumbprint $thumbprint -Force; Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true; New-NetFirewallRule -Name \\\"WinRM_HTTPS\\\" -DisplayName \\\"WinRM over HTTPS\\\" -Protocol TCP -LocalPort 5986 -Action Allow; if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) { Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing | Invoke-Expression }; choco install python --version=3.12 -y; pip install ansible; exit 0\""
  })
}




## Setup Ansible

resource "ansible_group" "ansible_inventory_group" {
  name = "all"
}

resource "ansible_host" "windows_vms" {
  count = 1
  name   = azurerm_windows_virtual_machine.myvm.public_ip_address
  groups = ["ansible_inventory_group"]
  variables = {
    "ansible_connection"                   = "winrm"
    "ansible_user"                         = var.username
    "ansible_password"                     = var.root_password
    "ansible_port"                         = "5986"
    "ansible_winrm_scheme"                 = "https"
    "ansible_winrm_server_cert_validation" = "ignore"
    "ansible_winrm_transport"              = "basic"
  }
}

resource "ansible_playbook" "install_notepad_plus_plus" {
  count      = 1
  name       = ansible_host.windows_vms[0].name
  playbook   = "install_notepad_plus_plus.yml"
  groups     = ["ansible_inventory_group"]
  replayable = true
  extra_vars = {
    "ansible_connection"                   = "winrm"
    "ansible_user"                         = var.username
    "ansible_password"                     = var.root_password
    "ansible_port"                         = "5986"
    "ansible_winrm_scheme"                 = "https"
    "ansible_winrm_server_cert_validation" = "ignore"
    "ansible_winrm_transport"              = "basic"
  }
  depends_on = [azurerm_virtual_machine_extension.script_ps1_combined_installer]
}

#############
# variables.tf
#############

variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}


variable "resource_group_name" {
  type        = string
  default     = "rg-windows-desktop"
  description = "Resource group name, should be unique in your Azure subscription."
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "terraform"
}

##

variable "pub_key" {
  type = string
}

variable "pvt_key" {
  type = string
  sensitive = true
}

variable "root_password" {
  type = string
  sensitive = true
}

variable "az_app_sp_id" {
  type = string
  sensitive = true
}

variable "az_sp_secret" {
  type = string
  sensitive = true
}

variable "az_tenant" {
  type = string
  sensitive = true
}

variable "az_subscription_id" {
  type = string
  sensitive = true
}


#############
# outputs.tf
#############

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_windows_virtual_machine.myvm.public_ip_address
}
