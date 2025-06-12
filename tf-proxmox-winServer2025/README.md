# WinServer2025 - Template - Notes
Proxmox VE can store Qemu KVM VM (Virtual Machine) images and LXC Container Images (CT templates) as template for quick deployment. LXC Containers (light weight VMs) share kernel with the Proxmox host, so only Linux is a possibility.

## WinServer2025 - Minimum Requirements
- Disk size - 32GB
- RAM - 4 GB
- TPM - true
- Cores - Minimum 2 cores - 1 GHz or faster.


## WinServer2025 - Sysprep
[Refernce 1 - https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation?view=windows-11](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation?view=windows-11)  
[Reference 2 - https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/boot-windows-to-audit-mode-or-oobe?view=windows-11](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/boot-windows-to-audit-mode-or-oobe?view=windows-11)  
```cmd
%WINDIR%\system32\sysprep\sysprep.exe /generalize /oobe /shutdown
```
  

## Refernce Links
1. [Poor Provider Docs: https://registry.terraform.io/providers/Telmate/proxmox/latest/docs](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
1. [Tutorial: https://spacelift.io/blog/terraform-proxmox-provider#4-configure-terraform-proxmox-provider](https://spacelift.io/blog/terraform-proxmox-provider#4-configure-terraform-proxmox-provider)
1. [Good Provider Docs: https://registry.terraform.io/providers/bpg/proxmox/latest/docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)

## Setup On Proxmox:
```
pveum role add TerraformProv -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```
## Create SSH User for Good Promox Provider (bpg/proxmox)
```bash
useradd terraform-prov -m
passwd terraform-prov
groupadd special
usermod -a -G special,root terraform-prov
nano /etc/sudoers.d/pvecommands
cat /etc/sudoers.d/pvecommands
## Cmnd alias specification
Cmnd_Alias PVE_COMMANDS = /usr/sbin/qm
#
## Members of the special group may gain some privileges
%special ALL=(ALL) NOPASSWD: PVE_COMMANDS

root@pve:~#
```

## Windows Server 2025 - Template Creation

1. Install Windows Server 2025

1. Login as Administrator and Install 'virtio-win-gt-x64'
    - This will install all Qemu drivers for Windows.

1. Instal Qemu-Agent
    1. Go to the mounted ISO in explorer
    1. The guest agent installer is in the directory guest-agent
    1. Execute the installer with double click (either qemu-ga-x86_64.msi (64-bit) or qemu-ga-i386.msi (32-bit)
    After that the qemu-guest-agent should be up and running. You can validate this in the list of Window Services, or in a PowerShell with:
    ```
    PS C:\Users\Administrator> Get-Service QEMU-GA
    
    Status   Name               DisplayName
    ------   ----               -----------
    Running  QEMU-GA            QEMU Guest Agent
    ```
    If it is not running, you can use the Services control panel to start it and make sure that it will start automatically on the next boot.

1. Install OpenSSH Server
    ```
    PS C:\Users\Administrator> Add-WindowsCapability -Online -Name OpenSSH
    PS C:\Users\Administrator> Add-WindowsCapability -Online -Name OpenSSH.Server
    PS C:\Users\Administrator> Set-Service -Name sshd -StartupType Automatic
    PS C:\Users\Administrator> Set-Service -Name ssh-agent -StartupType Automatic
    PS C:\Users\Administrator> netsh advfirewall firewall add rule name="SSH Port" dir=in action=allow protocol=TCP localport=22 remoteip=any
    PS C:\Users\Administrator> Start-Service sshd
    PS C:\Users\Administrator> get-service sshd
    ```

1. Enable Remote RDP Sessions
    ```
    PS C:\Users\Administrator> Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
    PS C:\Users\Administrator> Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    ```

1. Download Cloudbase-init Installer. Do not launch it yet.  
    - Download Link: [https://cloudbase.it/cloudbase-init/#download](https://cloudbase.it/cloudbase-init/#download)

1. Shutdown the VM. Remove all CD Roms while stopped.

1. Start the VM and Login again as Adminstrator. Temporarily release Network.
    ```
    PS C:\Users\Administrator> ipconfig /release
    ```

1. Install Cloudbase-init as a Service, in the end select Sysprep and Shutdown option.
    - If Errors due to Packages, then remove that package and retry.
    ```
    PS C:\Users\Administrator> Remove-AppxPackage -Package Microsoft.WidgetsPlatformRuntime_1.6.1.0_x64__8wekyb3d8bbwe -allusers
    ```

1. After sucessfull shutdown, convert the QEMU VM to Template.

## Using Terraform to Clone Qemu VM template on Proxmox
```
terraform init
terraform plan
terraform apply -auto-approve
terrform destroy -auto-approve
```

## Terraform Apply - Errors
- Proxmox Snippets folder permission
    - Folder permissions are automatically reset after few hours
    - Permanent Fix - To Do
    - Temporary Fix:
        - SSH to Promox Host
            ```
            root@pve:~# ls -lart /var/lib/vz/snippets/
            total 16
            drwxr-xr-x 6 root           root           4096 Jun 12 16:30 ..
            drwxr-xr-x 2 root           root           4096 Jun 12 16:31 .
            root@pve:~# chmod -R 775 /var/lib/vz/snippets/
            root@pve:~# ls -lart /var/lib/vz/snippets/
            total 16
            drwxr-xr-x 6 root           root           4096 Jun 12 16:30 ..
            drwxrwxr-x 2 root           root           4096 Jun 12 16:31 .
            ```
