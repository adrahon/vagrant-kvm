Vagrant.configure('2') do |config|
  # You should use VMware (Workstation or Fusion) to run this box
  # because VirtualBox doesn't support nested virtualization, which
  # is required to run KVM (https://www.virtualbox.org/ticket/4032)
  config.vm.provider :vmware_fusion do |vmware, override|
    override.vm.box = 'vagrant-kvm'
    override.vm.box_url = 'https://s3.amazonaws.com/life360-vagrant/raring64.box'
    vmware.vmx['vhv.enable'] = true # nested virtualization
  end

  config.vm.provision :shell, inline: <<-SH
    set -x

    sudo apt-get update

    sudo apt-get install -y ruby1.9.1-dev
    sudo apt-get install -y libvirt-dev libvirt-bin
    sudo apt-get install -y qemu qemu-kvm
    sudo apt-get install -y git
    sudo apt-get install -y nfs-kernel-server
    sudo apt-get install -y bsdtar
    sudo apt-get install -y libxml2-dev libxslt-dev

    [[ `sudo gem list | grep bundler` ]] || sudo gem install bundler
  SH
end
