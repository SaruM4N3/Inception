# -*- mode: ruby -*-
# vi: set ft=ruby :

LOGIN = "zsonie"

Vagrant.configure("2") do |config|
  # Debian's penultimate stable release (bookworm/12) — solid Docker support,
  # matches the Alpine/Debian requirement the project allows for the containers.
  config.vm.box = "debian/bookworm64"

  config.vm.hostname = "#{LOGIN}.42.fr"

  # Static private-network IP so login.42.fr can be pointed at it from /etc/hosts.
  config.vm.network "private_network", ip: "192.168.56.10"

  # Only the Inception entrypoint (NGINX/TLS) needs to be reachable from the host.
  config.vm.network "forwarded_port", guest: 443, host: 4433, host_ip: "127.0.0.1"

  # Project sources synced into the VM.
  config.vm.synced_folder ".", "/vagrant", disabled: false

  config.vm.provider "virtualbox" do |vb|
    vb.name = "#{LOGIN}-inception"
    vb.memory = 2048
    vb.cpus = 2
    # Belt and suspenders: even if the global VBox setting changes later,
    # this VM's disk/state still lands in goinfre.
    vb.customize ["modifyvm", :id, "--snapshotfolder", "/goinfre/#{LOGIN}/VirtualBox VMs/#{LOGIN}-inception/snapshots"]
  end

  config.vm.provision "shell", inline: <<-SHELL
    set -e
    apt-get update
    apt-get install -y ca-certificates curl gnupg make

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker vagrant
    echo "127.0.0.1 #{LOGIN}.42.fr" >> /etc/hosts
  SHELL
end
