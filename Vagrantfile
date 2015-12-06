# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'

    environment = ENV["VAGRANT_ENVIRONMENT"]

    if environment == nil || environment == ""
        environment = "development"
    end

    tags = ENV["ANSIBLE_TAGS"]

    if tags == nil
        tags = "all"
    end

    config.vm.provider "docker" do |d|
        {{dImageLine}}
        {{dBuildDirLine}}
        d.has_ssh = true
        d.name = "{{proyectName}}"
        d.ports = {{dockerPorts}}
        d.build_args = ["-t={{proyectNameToLowwer}}", "--build-arg", "uid={{uid}}"]
        d.create_args = ["-h", "{{proyectName}}", "-e", "APPLICATION_ENV=development"]
        d.cmd = ["/sbin/init"]
    end

    config.ssh.port = 22
    config.ssh.username  = "vagrant"
    config.ssh.password = "vagrant"
    config.ssh.insert_key

  config.vm.synced_folder "./", "/vagrant"
  {{klearSyncedFolder}}

  config.vm.provision "ansible" do |ansible|
     ansible.playbook = "Provision/playbook.yml"
     ansible.tags = tags
     ansible.verbose = "vvvv"
  end

end
