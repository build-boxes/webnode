#! /bin/bash
sudo sed -i 's/PermitRootLogin no/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
# Disable following line if not needed - Allow any (non-root) user to ssh into this server, possibly with passwords instead of SSH key.
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo mkdir /root/.ssh
sudo chmod 700 /root/.ssh
sudo touch /root/.ssh/authorized_keys
sudo chmod 600 /root/.ssh/authorized_keys
echo "${public_key}" > /root/.ssh/authorized_keys
sudo systemctl restart sshd
