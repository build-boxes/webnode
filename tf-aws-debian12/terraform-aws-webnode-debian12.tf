variable "pub_key" {
  type = string
}
variable "pvt_key" {
  type = string
  sensitive = true
}
variable "aws_access_id" {
  type = string
  sensitive = true
}
variable "aws_secret_key" {
  type = string
  sensitive = true
}
variable "aws_region" {
  type = string
}


terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.61.0"
    }
  }
}

provider "aws" {
  # Please get your Own AWS ACCESS-KEY and SECRET-KEY
  region = var.aws_region
  access_key = var.aws_access_id
  secret_key = var.aws_secret_key
}

provider "local" {
  
}

resource "aws_key_pair" "deployer" {
  key_name   = "aws_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDrIccxxZq5CJwjUxjKnAr5z1c4cJjffrLFcR5tlv++eam5BXKJcM7dTMdm0xjDEq2aG2N5w5hjMICxOMeD4CU00hZzp35/ogAEDbBXQoQjEWYyfGJV37B/gVOhE4MEX+mPURUc18yFE30PoWoh5bEsQw8gmb2yeCWnNb8n1Guk9ZxmbEFhsus1M9vtcJjvpCyzKdhtcOJMjPMfWt5YIvxBwTrP9RFALut3ZU+LEv/9iNzujsE2yoznXW9BWDaFo9EODpVpu0a6Wg628RWkRry1VqsZoox2EHpAnEMCH/voWDcKyG0XhNMDfUi1mUoWdkJHIV5uPi4waUnnVSW96sCmd8XNchKLRUB5h/HR6X4TGYBMxN8N9ikFlBJL3qjQJcsg85f9TS183vJefmqrZ9sfl8t4BO+dDnSEUKCja9vE3egiqSnlqebnOlkclayTdOwOc8GbuGuGlOwBeL/h/7/eXoQ/lrNrmkEBfAe1Otjl9Omo1yFuwZALyb380OQGv2ZpdHCkbYJAMeS7h5tXF0+D0e1sTOY4f+OxkNgHfPkP3dfQuTm0Hw39tOpq+f0qjMSkIeN4+B48ZZuqstnOAlul7wMUxtNkUNgXBzduGw80LyhDkkwwGdi9zANKpKQMkTpqkj5JDvQgguqkUtrABuRcWb8FZ6SaIstSBRr2pe4TQ== rauf.hammad@gmail.com"
}


resource "aws_security_group" "websg" {
  name = "web-sg01"
  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress  {
     cidr_blocks      = [ "0.0.0.0/0" ]
     description      = ""
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
  }
}

resource "aws_instance" "webnode" {
        # Debian 12 Image (ami) reference
        ami= "ami-0002aa901e88cc81d" 
        instance_type = "t2.micro"
        key_name= "aws_key"
        vpc_security_group_ids = [ aws_security_group.websg.id ]
        tags = {
            Name = "WebNode"
        }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "admin"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = ".."
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u admin -i '${self.public_ip},' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' main.yml"
  }

}

output "node_ip_address" {
  value = aws_instance.webnode.public_ip
}
