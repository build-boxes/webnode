# WebNode
It is a Vagrant and Ansible Playbook that builds a local host with Apache2, MariaDB, PHP, Wordpress and Postfix Relay Roles. It can also be used to deploy it on Public Cloud providers. Currently 4 Public Cloud provider (Linode, Azure, AWS, GCP) scripts are included.

## Disclaimer
1. There are no Guarantee of anything about this script, please use of your own accord.
2. Hosting on Public-Cloud is NOT free. See Linode/Azure/AWS/GCP pricing before usage of this script.
3. If you are testing this script, then make sure that all resources created on the public cloud are also deleted after the testing is completed. Otherwise you may be surprised by a costly bill from Azure or Linode or other Public Cloud provider.

## Copy VMHDK to Physical Disk
VirtualBox VMHDK disk images can be converted into Physical Disk images. General Process is as follows:  
1. Convert VMHDK to VDI Image.

  ```
  VBoxManage clonehd source.vmdk target.vhd --format vhd
  ```

2. On Windows 10/ Windows 11, mount VDI image file as a Disk using Windows Disk Management tool.
  
  ![Disk Management Tool - Attach VHD file](pictures/Disk-Attach-VHD.png)

3. Using a free/good Disk cloning software make a clone of the mounted Disk Image from Step 2 above to target Disk (Note: All data on target disk will be erased).
  
  ![AOMEI tool - Clone sector by sector](pictures/Clone-sector-by-sector.png)

4. Place the Target disk in an actual AMD64/x86_64 computer, remove all other disks for protection of those disks.
5. Also place a Debian12/Ubuntu/RockyLinux8 Installation media in the same target computer.
6. Boot from the Installtion media and go to Rescue Mode. Mount the Target disk from Step 4 above, Also mount its boot partition. Then using the rescue Media, install/re-install GRUB boot Loader on that disk. Then Shutdown/Reboot. Remove the Installation Media.
7. Once the computer successfully boots from the Target Disk, you can login using vmuser1, vmuser2 or Vagrant (If account was not removed earlier) credentials.
8. Check Network connectivity. You may need to add Network Drivers available in the webNode VMHDK image. Try adding the following (public network) to the Vagrantfile. This will add a Bridged Network Controller in the VirtualBox VM. This should enable Physical Network Card Drivers in the VM Image on disk.
```
  config.vm.define "debian" do |debian|
    debian.vm.box = "raufhammad/debian12"
    debian.vm.network "private_network", ip: "192.168.56.6"
    debian.vm.network "public_network"
  end 
```
9. Short-Commings
  * Only MBR Disk Image is created, supporting Old BIOS. No GPT Disk Image, No UEFI BIOS.
  * Smaller sized disks images only, less then 1 TB.
  * Maybe able to convert the Underlying Vagrant Box image to use EFI Disk (In the seperate project [Github Repo: build-boxes/packer-boxes](https://github.com/build-boxes/packer-boxes) ).

## Local Images Creation - On VirtualBox
It can be used in Windows 10/11 (a bit difficult to setup), or you can use Debian/Ubuntu host environemnt.
1. Install VirtualBox
2. Install Vagrant, Ansible (Use Windows Subsystem for Linux 2)
3. Install some plugins in WSL2 to allow Ansible and Vagrant to access Windows VirtualBox (Google Search, also [this link https://slavid.github.io/2021/11/28/running-vagrant-ansible-windows-through-wsl2/#configuration ](https://slavid.github.io/2021/11/28/running-vagrant-ansible-windows-through-wsl2/#configuration) ).
4. Change into the project root folder.
5. Download required roles with the following command:
    ```
    rm -rf ~/.ansible/roles/
    ansible-galaxy install --force -r ./roles/requirements.yml
    ```
6. Run:
    ```
    vagrant up debian

    OR

    vagrant up centos
    ```
7. To Destroy run:
    ```
    vagrant destroy -f debian

    OR

    vagrant destroy -f centos
    ```

## Cloud Image Creation - Linode, Azure, AWS or GCP
It can be used in Windows 10/11 (a bit difficult to setup), or you can use Debian/Ubuntu host environemnt.
1. Install Ansible, Terraform (Use Windows Subsystem for Linux 2)
2. Install some plugins in WSL2 for Ansible (Google Search, also [this link https://slavid.github.io/2021/11/28/running-vagrant-ansible-windows-through-wsl2/#configuration ](https://slavid.github.io/2021/11/28/running-vagrant-ansible-windows-through-wsl2/#configuration) )
3. See your Cloud Provider specific steps...
    1. For Azure, install Azure-CLI, see the section [below](#azure-cli).
    2. For GCP, install GCloud-CLI, see the section [below](#google-gcloud).
4. Install some ansible collections.
    ```
    ansible-galaxy collection install ansible.utils
    ```
5. Change into the project root folder.
6. Download required roles with the following command:
    ```
    rm -rf ~/.ansible/roles/
    ansible-galaxy install --force -r ./roles/requirements.yml
    ```
7. Change into "tf-<<Public-Cloud>>*" subfolder. For Example Change into "tf-azure*" or "tf-linode*",  subfolder.
8. Run:
    ```
    terraform init
    terraform plan
    terraform apply -auto-approve
    ```
9. To Destroy run:
    ```
    terraform destroy -auto-approve
    ```
    NOTE:  
    The above destroy command can fail, so you may need to login to the public-cloud portal to delete all resources.  

10. To ssh into the Terraform remote host use:
    ```
    ssh -i /path/to/User/.ssh-folder/id_rsa_Linode ${UserName}@${IPAddress}
    ```
    * Where:
        - ${UserName} = [User name given in ./vars/secrets.yml](https://github.com/build-boxes/webnode/blob/main/vars/secrets_shadow.yml#L20) OR [var.username](https://github.com/build-boxes/webnode/blob/main/tf-azure-debian12/terraform-azure-webnode-debian12.tf#L202)
        - ${IPAddress} = IP returned at successfull completeion of 'terraform apply -auto-approve'

## <a name="azure-cli">Installing Azure-Cli on Ubuntu and WSL2 - For Terraform</a>
For using Terraform on Azure Cloud, Azure-CLI needs to be installed on the local computer where these scripts will be executed. The 
following are steps for installing Azure-CLI on Ubuntu/Debian and WSL2.

### Azure-CLI Links
- [Install Azure-CLI on Linux](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
- [Terraform AzureRM Provider - Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure)
- [Tf AzureRM Auth - Service Principal with Client Secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)
- [Tf AzureRM Auth - Service Principal with Client Certificate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_certificate)
- [Tf AzureRM Auth - Service Principal with Managed ID (Active Directory)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity)
- [Tf AzureRM Auth - Azure CLI (login)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)

### Steps using Option 1 for Installation
- Install Azure-CLI if not already installed.
    ```
    $ curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    ```
- Then login to Azure-CLI
    ```
    $ az login
    ```
- Then create a Service Principal with Secret
    ```
    $ az account list
    [
      {
        "cloudName": "AzureCloud",
        "id": "20000000-0000-0000-0000-000000000000",
        "isDefault": true,
        "name": "PAYG Subscription",
        "state": "Enabled",
        "tenantId": "10000000-0000-0000-0000-000000000000",
        "user": {
          "name": "user@example.com",
          "type": "user"
        }
      }
    ]

    $ az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/20000000-0000-0000-0000-000000000000"
    {
      "appId": "00000000-0000-0000-0000-000000000000",
      "displayName": "azure-cli-2017-06-05-10-41-15",
      "name": "http://azure-cli-2017-06-05-10-41-15",
      "password": "0000-0000-0000-0000-000000000000",
      "tenant": "00000000-0000-0000-0000-000000000000"
    }
    ```
    These values map to the Terraform variables like so:  
      - appId is the client_id defined above.  
      - password is the client_secret defined above.  
      - tenant is the tenant_id defined above.  
- Then save these values in ./tf-azure-*/Terraform.tfvars as follows. Note: the default configuration of '.gitignore' in this repsoitory will ignore this file when commiting to git remote repository.
    ```
    (ansible) wsl01@XYZ:/mnt/c/Users/PQR/Source/webnode/tf-azure-debian12$ cat Terraform.tfvars
    pub_key="/mnt/c/Users/PQR/.ssh/id_rsa_4096_Azure.pub"
    pvt_key="/mnt/c/Users/PQR/.ssh/id_rsa_4096_Azure"
    root_password="XXXXXXXXXXXX"
    az_app_sp_id="00000000-0000-0000-0000-000000000000"
    az_sp_secret="0000-0000-0000-0000-000000000000"
    az_tenant="00000000-0000-0000-0000-000000000000"
    az_subscription_id="20000000-0000-0000-0000-000000000000"
    (ansible) wsl01@XYZ:/mnt/c/Users/PQR/Source/webnode/tf-azure-debian12$
    ```

## <a name="google-gcloud">Setting up Google Cloud Platform and Using it with Terraform</a>
For using Terraform on Google Cloud Platform (GCP), 'gcloud CLI' needs to be installed on the local computer where these scripts will be executed. On a Windows 
computer you can either install using Windows 11 Installation method, or use WSL2 and use a suitable Linux Installation method. These instllation steps are documented on [this Google website link](https://cloud.google.com/sdk/docs/install). Windows installed gcloud also works with WSL2 linux.

OR use an adminisistrative CMD/PowerShell prompt and use 'winget' Windows Package Manager to list and then install it. 
```
PS C:\Windows\System32> winget search Google.CloudSDK
PS C:\Windows\System32> winget install Google.CloudSDK
```

### Gcloud CLI - Links
* [link 1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference)
* [link 2](https://cloud.google.com/sdk/gcloud/reference/auth/application-default)
* [link actual](https://blog.avenuecode.com/how-to-use-terraform-to-create-a-virtual-machine-in-google-cloud-platform)
  
### Some usefull Gcloud CLI commands
```
gcloud auth login

gcloud config set project terraform-webnode

gcloud auth revoke    # Logout

# -- Create Service Account and Assign Key(json file with key is downloaded upon creation only)

gcloud iam service-accounts create svcaccount-terraform
gcloud iam service-accounts keys create "${HOME}/.ssh/gcloud-svcaccount-key.json" --iam-account=svcaccount-terraform@terraform-webnode.iam.gserviceaccount.com

# -- Assign/List Roles to the new service account.

# List all roles assigned - run as top level owner permissions
gcloud projects get-iam-policy "terraform-webnode" --flatten="bindings[].members" --filter="bindings.members:serviceAccount:svcaccount-terraform@terraform-webnode.iam.gserviceaccount.com" --format="table(bindings.role)"
# reponse:
# ROLE
# roles/compute.admin
# roles/iam.serviceAccountUser

# Assign the minimum Required Roles to the service account - run as owner.
gcloud projects add-iam-policy-binding "terrform-webnode" --member="user:svcaccount-terraform@terraform-webnode.iam.gserviceaccount.com" --role="roles/compute.admin"

gcloud projects add-iam-policy-binding "terrform-webnode" --member="user:svcaccount-terraform@terraform-webnode.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser"

#-- Move Service Account key to a well known location, for ease in pointing in *.tfvars file.
mv gcloud-svcaccount-key.json ~/.ssh/

# Login using service-account manually. Do not need to login manually if Terraform *.tf script - svc account is defined/setup correctly.
gcloud auth activate-service-account --key-file="${HOME}/.ssh/gcloud-svcaccount-key.json"
gcloud auth list
gcloud auth revoke    # Logout

# -- List VM Images available (need - roles/compute.viewer - role at least)
gcloud compute images list

# -- To SSH into VM using gcloud default Service-Account:
gcloud compute ssh --zone "us-east1-b" "webnode" --project "terraform-webnode"

# -- OR if root login (and/or user login) is enabled in the image, and SSH-Key has been placed then:
ssh root@<<External (Ephemeral) IP>>

```

## <a name="amazon-aws">Setting up Amazon AWS and Using it with Terraform</a>
For using Terraform on Amazon Cloud (AWS), 'aws CLI' needs to be installed on the local computer where these scripts will be executed. On a Windows 
computer you can either install using Windows 11 Installation method. These instllation steps are documented on [this Amazon website link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

OR use an adminisistrative CMD/PowerShell prompt and use 'winget' Windows Package Manager to list and then install it. 
```
PS C:\Windows\System32> winget search Amazon.AWSCLI
PS C:\Windows\System32> winget install Amazon.AWSCLI
```

### AWS CLI - Links
* [link 1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* [link 2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-using.html)
* [link 3](https://medium.com/@shanmorton/set-up-terraform-tf-and-aws-cli-build-a-simple-ec2-1643bcfcb6fe)
  
### Some usefull AWS CLI commands
```
# Create a New User for Terraform
PS C:\Users\PQRS>  aws iam create-user --user-name terraform2
{
    "User": {
        "Path": "/",
        "UserName": "terraform2",
        "UserId": "AAAAAABBBBBCCCCC",
        "Arn": "arn:aws:iam::12456789753:user/terraform2",
        "CreateDate": "2025-02-21T05:38:54+00:00"
    }
}

# Create Access-Key for this new user. Note down Access Key ID and SecretAccessKey.
PS C:\Users\PQRS>  aws iam create-access-key --user-name terraform2
{
    "AccessKey": {
        "UserName": "terraform2",
        "AccessKeyId": "QQQQQAAAAATTTTTT",
        "Status": "Active",
        "SecretAccessKey": "SOME_RANDOM_SECRET_KEY",
        "CreateDate": "2025-02-21T05:39:14+00:00"
    }
}

# Create a IAM Group for Organizing PowerUsers
PS C:\Users\PQRS>  aws iam create-group --group-name PowerUsers2
{
    "Group": {
        "Path": "/",
        "GroupName": "PowerUsers2",
        "GroupId": "AGPATRLD7BEGYLAIBILQ5",
        "Arn": "arn:aws:iam::12456789753:group/PowerUsers2",
        "CreateDate": "2025-02-21T05:43:11+00:00"
    }
}

# Add the new User to this Group
PS C:\Users\PQRS>  aws iam add-user-to-group --group-name PowerUsers2 --user-name terraform2
PS C:\Users\PQRS>

# Get the Full 'PowerUserAccess' Policy ARN Name.
PS C:\Users\PQRS>  aws iam list-policies --query 'Policies[?PolicyName == `PowerUserAccess`].{PolicyName: PolicyName,Arn: Arn}'
[
    {
        "PolicyName": "PowerUserAccess",
        "Arn": "arn:aws:iam::aws:policy/PowerUserAccess"
    }
]

# Attach this Policy to the Group and hence to the user.
PS C:\Users\PQRS> aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/PowerUserAccess --group-name PowerUsers2
PS C:\Users\PQRS>
```

## Linux User Password Hashing
Linux User accounts name and passwords are saved in the './vars/secrets.yml' (Default-of-this-repo: It is ignored by git commits) file. The
password to be saved in this file should be Hash-encoded, as a safe best practice. This avoids the raw password from appearing in Log files
and accidentally being commited into the git remote server.

### Hashing on Ubuntu / Debian
```
$ sudo apt update
$ sudo apt install whois 
$ mkpasswd --method="sha-512" --salt="Thisisarandomsaltingstring"
Password: 
$6$ieMLxPFShvi6rao9$XEAU9ZDvnPtL.sDuSdRi6M79sgD9254b/0wZvftBNvMOjj3pHJBCIe04x2M.JA7gZ7MwpBWat1t4WQDFziZPw1
```
### Hashing on CentOS / Fedora
```
$ sudo dnf install expect
$ mkpasswd --method="sha-512" --salt="Thisisarandomsaltingstring"
Password: 
$6$ieMLxPFShvi6rao9$XEAU9ZDvnPtL.sDuSdRi6M79sgD9254b/0wZvftBNvMOjj3pHJBCIe04x2M.JA7gZ7MwpBWat1t4WQDFziZPw1
```

## External Roles Used in this Project
The following external ansible roles are used in this project to make it modular. Details of Role specific variables can be explored in the respective role documentation.  
* [hammadrauf.sudousers](https://github.com/hammadrauf/sudousers)
* [fauust.mariadb](https://github.com/fauust/ansible-role-mariadb)
* [hammadrauf.apache2](https://github.com/hammadrauf/apache2)    
For upto date list of roles used please check [roles/requirements.yml](https://github.com/build-boxes/webnode/blob/main/roles/requirements.yml) file.  

## Using the Installed MariaDB instance
Make sure the user password for MariaDB contains only alpha-numeric characters. Passwords with symbols will fail to login. Currently the 
password cannot be hashed by SHA256/512. Check later versions if hashing of passwords is enabled.    
To connect to the mariadb instance use the command:  
```
$ mysql -uUSERNAME -pPASSWORD -PPORTNUMBER
```

## Icon Attribution Link
* [Beach-ball icons created by Freepik - Flaticon](https://www.flaticon.com/free-icons/beach-ball)

## About this Project
- [Andromedabay - Experiments in IAC](https://andromedabay.ddns.net/experiments-with-iac-automation/)

## RedHat / CentOS errors (TO DO)
```
$ ansible-playbook -i 192.168.0.12, -u root -k main.yml   # RedHat9.4

TASK [geerlingguy.certbot : Enable DNF module for Rocky/AlmaLinux.] *********************************************************************************************************************************************
fatal: [192.168.0.12]: FAILED! => {"changed": false, "cmd": "dnf config-manager --set-enabled crb\n", "delta": "0:00:01.272953", "end": "2024-08-09 16:10:49.498680", "msg": "non-zero return code", "rc": 1, "start": "2024-08-09 16:10:48.225727", "stderr": "Error: No matching repo to modify: crb.", "stderr_lines": ["Error: No matching repo to modify: crb."], "stdout": "Updating Subscription Management repositories.", "stdout_lines": ["Updating Subscription Management repositories."]}
```

```
$ vagrant up centos   # centos9 CentOS-Stream-9-20240415.0-x86_64-dvd1.iso

TASK [geerlingguy.certbot : Generate new certificate if one doesn't exist.] ****
fatal: [centos]: FAILED! => {"msg": "The task includes an option with an undefined variable. The error was: {{ certbot_script }} certonly --{{ certbot_create_method  }} {{ '--hsts' if certbot_hsts else '' }} {{ '--test-cert' if certbot_testmode else '' }} --noninteractive --agree-tos --email {{ cert_item.email | default(certbot_admin_email) }} {{ '--webroot-path ' if certbot_create_method == 'webroot'  else '' }} {{ cert_item.webroot | default(certbot_webroot) if certbot_create_method == 'webroot' else '' }} {{ certbot_create_extra_args }} -d {{ cert_item.domains | join(',') }} {{ '--pre-hook /etc/letsencrypt/renewal-hooks/pre/stop_services'\n  if certbot_create_standalone_stop_services and certbot_create_method == 'standalone'\nelse '' }} {{ '--post-hook /etc/letsencrypt/renewal-hooks/post/start_services'\n  if certbot_create_standalone_stop_services and certbot_create_method == 'standalone'\nelse '' }}: 'certbot_create_extra_args' is undefined. 'certbot_create_extra_args' is undefined. {{ certbot_script }} certonly --{{ certbot_create_method  }} {{ '--hsts' if certbot_hsts else '' }} {{ '--test-cert' if certbot_testmode else '' }} --noninteractive --agree-tos --email {{ cert_item.email | default(certbot_admin_email) }} {{ '--webroot-path ' if certbot_create_method == 'webroot'  else '' }} {{ cert_item.webroot | default(certbot_webroot) if certbot_create_method == 'webroot' else '' }} {{ certbot_create_extra_args }} -d {{ cert_item.domains | join(',') }} {{ '--pre-hook /etc/letsencrypt/renewal-hooks/pre/stop_services'\n  if certbot_create_standalone_stop_services and certbot_create_method == 'standalone'\nelse '' }} {{ '--post-hook /etc/letsencrypt/renewal-hooks/post/start_services'\n  if certbot_create_standalone_stop_services and certbot_create_method == 'standalone'\nelse '' }}: 'certbot_create_extra_args' is undefined. 'certbot_create_extra_args' is undefined\n\nThe error appears to be in '/home/wsl01/.ansible/roles/geerlingguy.certbot/tasks/create-cert-standalone.yml': line 40, column 3, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n\n- name: Generate new certificate if one doesn't exist.\n  ^ here\n"}
```
## ToDo
- [Integrate postfix-dovecot](https://github.com/StackFocus/ansible-role-postfix-dovecot/tree/master)
- [Integrate Optional Rclone](https://github.com/stefangweichinger/ansible-rclone)
  - (Rclone is a command-line program to sync files and directories to and from different cloud storage providers)
- Wordpress restore from backup.
- Solution for Wordpress App IP Address for Vagrant/Public Cloud
- Testing on RHEL9/Centos9
- This error:
  ```
  TASK [Comment out old Network config - Debian family] **************************
  fatal: [34.73.105.50]: FAILED! => {"changed": false, "msg": "Path /etc/network/interfaces does not exist !", "rc": 257}
  ```
-  
