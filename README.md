# WebNode
It is a Vagrant and Ansible Playbook that builds a local host with Apache2, MariaDB, PHP, Wordpress and Postfix Relay Roles.

## Copy VMHDK to Physical Disk
VirtualBox VMHDK disk images can be converted into Physical Disk images. General Process is as follows:  
1. Convert VMHDK to VDI Image.
2. On Windows 10/ Windows 11, mount VDI image file as a Disk using Windows Disk Management tool.
3. Using a free/good Disk cloning software make a clone of the mounted Disk Image from Step 2 above to target Disk (Note: All data on target disk will be erased).
4. Place the Target disk in an actual AMD64/x86_64 computer, remove all other disks for protection of those disks.
5. Also place a Debian12/Ubuntu/RockyLinux8 Installation media in the same target computer.
6. Boot from the Installtion media and go to Rescue Mode. Mount the Target disk from Step 4 above, Also mount its boot partition. Then using the rescue Media, install/re-install GRUB boot Loader on that disk. Then Shutdown/Reboot. Remove the Installation Media.
7. Once the computer successfully boots from the Target Disk, you can login using vmuser1, vmuser2 or Vagrant (If account was not removed earlier) credentials.
8. Check Network connectivity. You may need to add Network Drivers available in the webNode VMHDK image.  
  



