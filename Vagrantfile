# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "debian" do |debian|
    debian.vm.box = "raufhammad/debian12"
    debian.vm.network "private_network", ip: "192.168.56.6"
  end

  config.vm.define "rokylin8" do |rockylin8|
    rockylin8.vm.box = "raufhammad/rockylinux8"
    rockylin8.vm.network "private_network", ip: "192.168.56.7"
  end

  #config.vm.box = "raufhammad/debian12"
  #config.vm.network "private_network", ip: "192.168.56.6"
  ##config.vm.synced_folder ".", "/vagrant", disabled: true
  ##config.ssh.insert_key=false
  config.vm.provision "file", source: "/home/#{ENV['USER']}/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
  ##config.vm.provision "shell", path: "vagrant_script.sh"
  config.vm.provision :ansible do |ansible|
    ansible.playbook = "main.yml"
    ansible.raw_arguments = [
      "--vault-password-file=./vars/.vault_pass"
    ]
  end
end
