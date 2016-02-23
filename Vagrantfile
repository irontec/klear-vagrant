# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'

    tags = ENV["ANSIBLE_TAGS"]

    if tags == nil
        tags = "all"
    end

################### Variables a configurar #############################################################################
  machinesHostName = "{{proyectName}}"
  machineOne = "default"
  machineOnePorts = {{dockerPhp5Ports}}
  machineTwo = "php7"
  machineTwoPorts = {{dockerPhp7Ports}}
########################################################################################################################

  config.vm.define machineOne do |php5|

    php5.ssh.port = 22
    php5.ssh.guest_port = {{dockerPhp5SshPort}}
    php5.ssh.username  = "vagrant"
    php5.ssh.password = "vagrant"
    php5.ssh.insert_key
  
    php5.vm.synced_folder "./", "/vagrant"
    php5.vm.synced_folder "/opt/klear-development", "/opt/klear-development"
    
    php5.vm.provider "docker" do |d|
        {{dImageLine}}
        {{dBuildDirLine}}
        d.name = machinesHostName + "_" + machineOne
        d.ports = machineOnePorts
        d.build_args = ["-t="+machinesHostName, "--build-arg", "uid={{uid}}"]
        d.create_args = ["-h", machinesHostName + "_" + machineOne, "-e", "APPLICATION_ENV=development"]
        d.cmd = ["/sbin/init"]
        d.has_ssh = true
    end

     php5.vm.provision "ansible" do |ansible|
         ansible.playbook = "Provision/playbook.yml"
         ansible.tags = tags
         ansible.verbose = "vvvv"
         ansible.extra_vars = {
            phpVersion: 5
         }
     end
  end

  config.vm.define machineTwo, autostart: false do |php7|
    
    php7.ssh.port = 22
    php7.ssh.guest_port = {{dockerPhp7SshPort}}
    php7.ssh.username  = "vagrant"
    php7.ssh.password = "vagrant"
    php7.ssh.insert_key
  
    php7.vm.synced_folder "./", "/vagrant"
    php7.vm.synced_folder "/opt/klear-development", "/opt/klear-development"
    
    php7.vm.provider "docker" do |d|
        {{dImageLine}}
        {{dBuildDirLine}}
        d.name = machinesHostName + "_" + machineTwo
        d.ports = machineTwoPorts
         d.build_args = ["-t="+machinesHostName, "--build-arg", "uid={{uid}}"]
        d.create_args = ["-h", machinesHostName + "_" + machineTwo, "-e", "APPLICATION_ENV=development"]
        d.cmd = ["/sbin/init"]
        d.has_ssh = true
    end
    
    php7.vm.provision "ansible" do |ansible|
         ansible.playbook = "Provision/playbook.yml"
         ansible.tags = tags
         ansible.verbose = "vvvv"
         ansible.extra_vars = {
            phpVersion: 7
         }
    end
  end

end
