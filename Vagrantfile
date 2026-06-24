# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Utilisation d'Ubuntu 24.04 pour correspondre aux scripts master.sh/worker.sh
  config.vm.box = "bento/ubuntu-24.04"

  # --- Configuration du Master ---
  config.vm.define "master" do |master|
    master.vm.hostname = "controlplane"
    master.vm.network "private_network", ip: "10.10.10.10"
    
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "master"
    end

    # Exécution du script de provisionnement master
    master.vm.provision "shell", path: "master.sh"
  end

  # --- Configuration des Workers ---
  (1..2).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.hostname = "worker#{i}"
      # IP 10.10.10.11 pour worker1, 10.10.10.12 pour worker2
      worker.vm.network "private_network", ip: "10.10.10.#{10 + i}"

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
        vb.cpus = 2
        vb.name = "node#{i}"
      end

      # Exécution du script de provisionnement worker
      worker.vm.provision "shell", path: "node.sh"
    end
  end
end
