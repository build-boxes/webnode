# KVM Debian12 - Template - Notes
Proxmox VE can store Qemu KVM VM (Virtual Machine) images and LXC Container Images (CT templates) as template for quick deployment. LXC Containers (light weight VMs) share kernel with the Proxmox host, so only Linux is a possibility.
  
This proxmox VM is based on the proxmox KVM Template given at [https://github.com/build-boxes/proxmox-kvm-debian12-cli/tree/main/pkr-proxmox-kvm-debian12](https://github.com/build-boxes/proxmox-kvm-debian12-cli/tree/main/pkr-proxmox-kvm-debian12)
  

## KVM Debian12 - Minimum Requirements
- Disk size - 16 GB
- RAM - 2 GB
- TPM - true
- Cores - Minimum 2 cores - 1 GHz or faster.

## Using Terraform to Clone Qemu VM template on Proxmox
```
terraform init
terraform plan
terraform apply -auto-approve
terrform destroy -auto-approve
```
