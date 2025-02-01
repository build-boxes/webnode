# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "debian" do |debian|
    debian.vm.box = "generic/debian12"
    debian.vm.provider :virtualbox do |vb|
      vb.name = "webnode-debian12"
    end    
    debian.vm.network "private_network", ip: "192.168.56.6"
    debian.vm.network "public_network", bridge: "Realtek Gaming 2.5GbE Family Controller"
  end

  config.vm.define "rocky" do |rocky|
    rocky.vm.box = "generic/rocky9"
    rocky.vm.network "private_network", ip: "192.168.56.7"
    rocky.vm.network "public_network"
  end

  config.vm.define "rhel" do |rhel|
    rhel.vm.box = "generic/rhel9"
    #rhel.vm.box = "raufhammad/rhel9_4"
    rhel.vm.network "private_network", ip: "192.168.56.8"
    rhel.vm.network "public_network"
  end

  config.vm.define "centos" do |centos|
    #centos.vm.box = "raufhammad/centos9"
	centos.vm.box = "eurolinux-vagrant/centos-stream-9"
    centos.vm.network "private_network", ip: "192.168.56.9"
    centos.vm.network "public_network"
  end

  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "generic/ubuntu2310"
    ubuntu.vm.network "private_network", ip: "192.168.56.10"
    ubuntu.vm.network "public_network"
  end

  config.vm.provision "file", source: "/home/#{ENV['USER']}/.ssh/id_rsa.pub", destination: "~/.ssh/me.pub"
  config.vm.provision :ansible do |ansible|
    ansible.playbook = "main.yml"
    ansible.raw_arguments = [
      "--vault-password-file=./vars/.vault_pass"
    ]
  end
end
