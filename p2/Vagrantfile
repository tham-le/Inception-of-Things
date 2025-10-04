Vagrant.configure("2") do |config|
  config.vm.box = "generic/alpine312"
  config.vm.box_check_update = false
  
  # Fix SSH key permissions issue on shared folders
  config.ssh.insert_key = false
  config.ssh.private_key_path = ["~/.vagrant.d/insecure_private_key"]

   ALPINE_COMMON_PACKAGES = [
    "curl",
    "ca-certificates",  # For HTTPS
    "sudo",
    "bash",
    "openrc", # Alpine's init system
    "net-tools"
  ].join(" ")

  #--- Server VM (K3s Controller) ---
  SERVER_HOSTNAME = "cqinS"
  SERVER_IP = "192.168.56.110"
  config.vm.define SERVER_HOSTNAME do |server|
      server.vm.hostname = SERVER_HOSTNAME
      server.vm.network "private_network", ip: SERVER_IP

      server.vm.synced_folder ".", "/vagrant", type: "virtualbox"
      server.vm.synced_folder "./confs", "/confs", type: "virtualbox"

      server.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus = 1
        vb.name = SERVER_HOSTNAME
        vb.gui = false
      end
      server.vm.provision "shell", path: "scripts/setup_server.sh"
    end
  end
