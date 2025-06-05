
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
  admin_username = var.root_username
  admin_password = var.root_password

  identity {
    type = "SystemAssigned"
  }

}


resource "azurerm_virtual_machine_extension" "script_ps1_combined_installer" {
  name                 = "RunPS1Script_Combined"
  virtual_machine_id   = azurerm_windows_virtual_machine.myvm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell.exe -Command \"if (-Not (Test-Path -Path 'C:\\Temp')) { New-Item -ItemType Directory -Path 'C:\\Temp' }; $cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My; $thumbprint = $cert.Thumbprint; $certPath = 'C:\\Temp\\winrm-cert.cer'; Export-Certificate -Cert \\\"Cert:\\LocalMachine\\My\\$thumbprint\\\" -FilePath $certPath; Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\\LocalMachine\\Root; New-Item -Path WSMan:\\localhost\\Listener -Transport HTTPS -Address * -CertificateThumbprint $thumbprint -Force; Set-Item -Path WSMan:\\localhost\\Service\\Auth\\Basic -Value $true; New-NetFirewallRule -Name \\\"WinRM_HTTPS\\\" -DisplayName \\\"WinRM over HTTPS\\\" -Protocol TCP -LocalPort 5986 -Action Allow; if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) { Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing | Invoke-Expression }; choco install python --version=3.12 -y; exit 0\""
  })
}

## Setup Ansible

resource "ansible_host" "mywebpc" {
  name   = azurerm_windows_virtual_machine.myvm.public_ip_address
  groups = ["webpc"]
  variables = {
    "ansible_connection"                   = "winrm"
    "ansible_user"                         = var.root_username
    "ansible_password"                     = var.root_password
    "ansible_port"                         = "5986"
    "ansible_winrm_scheme"                 = "https"
    "ansible_winrm_server_cert_validation" = "ignore"
    "ansible_winrm_transport"              = "basic"
  }
  depends_on = [azurerm_virtual_machine_extension.script_ps1_combined_installer]
}

resource "ansible_playbook" "install_notepad_plus_plus" {
  name       = ansible_host.mywebpc.name
  playbook   = "install_notepad_plus_plus.yml"
  groups     = ["all"]
  replayable = true
  extra_vars = {
    "ansible_connection"                   = "winrm"
    "ansible_user"                         = var.root_username
    "ansible_password"                     = var.root_password
    "ansible_port"                         = "5986"
    "ansible_winrm_scheme"                 = "https"
    "ansible_winrm_server_cert_validation" = "ignore"
    "ansible_winrm_transport"              = "basic"
    
  }
  depends_on = [ansible_host.mywebpc]
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

##

variable "pub_key" {
  type = string
}

variable "pvt_key" {
  type = string
  sensitive = true
}

variable "root_username" {
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

output "ansible_outputs" {
  value = ansible_playbook.install_notepad_plus_plus.ansible_playbook_stdout
}

output "ansible_errors" {
  value = ansible_playbook.install_notepad_plus_plus.ansible_playbook_stderr
}
