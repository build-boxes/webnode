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
variable "api_access_token" {
  type = string
  sensitive = true
}


terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      version = "2.18.0"
    }
  }
}

provider "linode" {
  # Please get your Own Linode.com API-TOKEN/PERSONAL-ACCESS-TOKEN
  token = var.api_access_token
}

provider "local" {
  
}

resource "linode_instance" "webnode" {
        image = "linode/debian12"
        label = "debian-webnode"
        region = "us-east"
        type = "g6-nanode-1"
        # Replace following with your SSH public keys, it is a list [].
        authorized_keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDrIccxxZq5CJwjUxjKnAr5z1c4cJjffrLFcR5tlv++eam5BXKJcM7dTMdm0xjDEq2aG2N5w5hjMICxOMeD4CU00hZzp35/ogAEDbBXQoQjEWYyfGJV37B/gVOhE4MEX+mPURUc18yFE30PoWoh5bEsQw8gmb2yeCWnNb8n1Guk9ZxmbEFhsus1M9vtcJjvpCyzKdhtcOJMjPMfWt5YIvxBwTrP9RFALut3ZU+LEv/9iNzujsE2yoznXW9BWDaFo9EODpVpu0a6Wg628RWkRry1VqsZoox2EHpAnEMCH/voWDcKyG0XhNMDfUi1mUoWdkJHIV5uPi4waUnnVSW96sCmd8XNchKLRUB5h/HR6X4TGYBMxN8N9ikFlBJL3qjQJcsg85f9TS183vJefmqrZ9sfl8t4BO+dDnSEUKCja9vE3egiqSnlqebnOlkclayTdOwOc8GbuGuGlOwBeL/h/7/eXoQ/lrNrmkEBfAe1Otjl9Omo1yFuwZALyb380OQGv2ZpdHCkbYJAMeS7h5tXF0+D0e1sTOY4f+OxkNgHfPkP3dfQuTm0Hw39tOpq+f0qjMSkIeN4+B48ZZuqstnOAlul7wMUxtNkUNgXBzduGw80LyhDkkwwGdi9zANKpKQMkTpqkj5JDvQgguqkUtrABuRcWb8FZ6SaIstSBRr2pe4TQ== rauf.hammad@gmail.com" ]
        root_pass = var.root_password

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = ".."
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${self.ip_address},' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' main.yml"
  }

}

output "node_ip_address" {
  value = linode_instance.webnode.ip_address
}
