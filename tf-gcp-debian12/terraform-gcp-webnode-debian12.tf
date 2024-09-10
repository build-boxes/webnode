variable "pub_key" {
  type = string
}
variable "pvt_key" {
  type = string
  sensitive = true
}
variable "gcp_access_key_path" {
  type = string
  sensitive = true
}
variable "gcp_region" {
  type = string
  default = "us-east1"
}
variable "gcp_zone" {
  type = string
  default = "us-east1-c"
}
variable "gcp_svc_account" {
  type = string
}

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.1.0"
    }
  }
}

provider "google" {
  # Please get your Own Google Cloud Console Service account, with following Permissions/Roles:
  #   - "Compute Engine --> Compute Admin"
  #   - "IAM --> Service Account User"
  credentials = file(var.gcp_access_key_path)
  project = "terraform-webnode"
  region = var.gcp_region
}

resource "google_compute_instance" "webnode" {
  name         = "webnode"
  machine_type = "n1-standard-1"
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "debian-12-bookworm-v20240815"
      # Possible Other Images:
      #"rhel-9-v20240815"
      #"centos-stream-9-v20240815"
      #"ubuntu-2204-jammy-v20240904"
      #"ubuntu-minimal-2404-noble-amd64-v20240903"
      #"fedora-coreos-40-20240808-3-0-gcp-x86-64"
    }
  }

  network_interface {
    network = "default"
    # Following is needed for Google's simple External IP (Ephemeral IP)
    access_config {
    }
  }

  service_account {
  # Please get your Own Google Cloud Console Service account, with following Permissions/Roles:
  #   - "Compute Engine --> Compute Admin"
  #   - "IAM --> Service Account User"    
    email = var.gcp_svc_account
    scopes = [
              "https://www.googleapis.com/auth/cloud-platform",
              "https://www.googleapis.com/auth/devstorage.read_only",
              "https://www.googleapis.com/auth/logging.write",
              "https://www.googleapis.com/auth/monitoring.write",
              "https://www.googleapis.com/auth/service.management.readonly",
              "https://www.googleapis.com/auth/servicecontrol",
              "https://www.googleapis.com/auth/trace.append"
    ]
  }

  metadata = {
      enable-oslogin = "TRUE"
      ssh-keys = "root:${file(var.pub_key)}"
  }

  metadata_startup_script = templatefile("boot_script.sh", {public_key = file(var.pub_key)})

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Done!"]
    connection {
      host        = self.network_interface[0].access_config[0].nat_ip
      type        = "ssh"
      user        = "root"
      private_key = file(var.pvt_key)
    }
  }

  provisioner "local-exec" {
    #interpreter = ["/bin/bash"]
    working_dir = ".."
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root -i '${self.network_interface[0].access_config[0].nat_ip},' --private-key ${var.pvt_key} -e 'pub_key=${var.pub_key}' main.yml"
  }

}

output "node_ip_address" {
  # Google's simple External IP are ephemeral, will change on VM reboot. - about --> google_compute_instance.webnode.network_interface[0].access_config[0].nat_ip
  value = google_compute_instance.webnode.network_interface[0].access_config[0].nat_ip
}
