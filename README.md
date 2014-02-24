[![Build Status](https://travis-ci.org/adrahon/vagrant-kvm.png)](https://travis-ci.org/adrahon/vagrant-kvm)

# Vagrant KVM Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds a KVM
provider to Vagrant, allowing Vagrant to control and provision KVM/QEMU VM.

## Requirements

This plugin requires QEMU 1.1+, it has only been tested on Fedora 18+,
Debian Wheezy, Ubuntu 12.04(LTS) Precise and Ubuntu 13.04 Raring at the moment.

This plugin requires redir package, and `libvirt-dev` (Debian/Ubuntu) or
`libvirt-devel` (openSUSE)

You can use a backported KVM/QEMU 1.4 with Private Package Archive(PPA)
for Ubuntu 12.04(LTS) at https://launchpad.net/~miurahr/+archive/vagrant

## Recent changes

Default image format is now qcow2 instead of sparsed raw imagei, with qcow2
`vagrant-kvm` uses the box volume as a backing volume so that VM creation is
a lot faster. In most cases you want to use qcow2.

OVF boxes conversion as been removed, you should use `vagrant-mutate` instead.

## Features/Limitations

* Provides the same workflow as the Vagrant VirtualBox provider.
* Uses NFS for sync folders
* Only works with 1 VM per Vagrantfile for now
* Requires "libvirtd" group membership to run Vagrant (Debian/Ubuntu only)
* Requires backporting qemu and libvirt from experimental (Debian) or raring (Ubuntu)
* Use qcow2 backing image by default, which should make VM creation very fast

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `kvm` provider. An example is
shown below.

```bash
$ vagrant plugin install vagrant-kvm
$ vagrant up --provider=kvm
```

Of course prior to doing this, you'll need to obtain a KVM-compatible
box file for Vagrant. You can convert a VirtualBox base box using
`vagrant-mutate` https://github.com/sciurus/vagrant-mutate or see the sample
box.

You will need a private network specifying an IP address in your Vagrantfile,
the minimum Vagrantfile would then be:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "precise32"
  config.vm.network :private_network, ip: "192.168.192.10"
end
```

And then run `vagrant up --provider=kvm`.

If you always use kvm provider as default, please set it in your .bashrc:

```bash
export VAGRANT_DEFAULT_PROVIDER=kvm
```
then you can simply run `vagrant up` with kvm provider.

## Configuration

There are some provider specific parameter to control VM definition.

* `cpu_model` - cpu architecture: 'i686' or 'x86_64': default is x86_64. Note
  that your base box should specify this.
* `core_number` - number of cpu cores.
* `memory_size` - memory size such as 512m, 1GiB, 100000KiB, unit is KiB if
  unspecified.
* `gui` - boolean for starting VM with VNC enabled.
* `vnc_port` - The port the VNC server listens to. Default is automatic port
assignment.
* `vnc_autoport` - if true, KVM will automatically assign a port for VNC
to listen to. Defaults to false, but the default vnc_port is -1, which results
in this flag being automatically turned on by KVM.
* `vnc_password ` - A password used to protect the VNC session.
* `image_type` - an image format for vm disk: 'raw' or 'qcow2': default is "qcow2"
  When choosing 'raw', vagrant-kvm always convert box image into storage-pool,
  which consumes disk space and is a longer process. Recommendation is 'qcow2'.
* `machine_type` - The type of machine to boot. Default is pc-1.2.
* `network_model` - The model of the network adapter you want to use. Defaults
to virtio. Can be set to `:default` if you want to use the KVM default setting.
Possible values include: ne2k_isa i82551 i82557b i82559er ne2k_pci pcnet rtl8139 e1000 virtio.
* `video_model` - The model of the video adapter. Default to cirrus. Can also be
set to vga.
* `image_mode` - Possible value are `clone` or `cow`, defaults to `cow`. If set
to `clone`, the image disk will be copied rather than use the original box
image. This is slower but allows multiple VMs to be booted at the same time.

## Specs

To run specs, you first need to add and prepare the Vagrant box which will be used.

```bash
$ bundle exec rake box:add
$ bundle exec rake box:prepare
```

Once box is added and prepared, you can run specs:

```bash
$ bundle exec rspec spec/vagrnt-kvm/
```

When you're done, feel free to remove the box.

```bash
$ bundle exec rake box:remove
```

Supported ruby version is 2.0.x on vagrant 1.4.0 and later. You may need to use a recent OS version for development base such as Ubuntu Saucy(13.10), Trusy(14.04) or Fedora 19,20.
If you're Mac user and you have Vagrant and VMware Fusion, you can use bundled box for development. See `spec/Vagrantfile` for details.
If you're Linux user(of cource, you try to use KVM), You are lucky to run development version of vagrant-kvm on Vagrant, QEMU/KVM and vagrant-kvm itself. You can use bundled box for development. See `spec/Vagrantfile` for details.
