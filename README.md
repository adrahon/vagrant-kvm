# Vagrant KVM Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds a KVM
provider to Vagrant, allowing Vagrant to control and provision KVM/QEMU VM.

**NOTE:** This plugin requires Vagrant 1.1+

**NOTE:** This plugin requires QEMU 1.2+, it has only been tested on Fedora 18,
Debian Wheezy, Ubuntu 12.04(LTS) Precise and Ubuntu 13.04 Raring at the moment.

**NOTE:** This plugin requires redir package, and`libvirt-dev` to be installed
(as in Debian/Ubuntu) or `libvirt-devel` (Fedora/openSUSE)

**NOTE** You can use a backported KVM/QEMU 1.4 with Private Package Archive(PPA)
for Ubuntu 12.04(LTS) at https://launchpad.net/~miurahr/+archive/vagrant

**NOTE** There is another plugin `vagrant-libvirt` that makes breakage for
`vagrant-kvm` because of a bug of `vagrant-libvirt(0.0.6)`. This will be fixed
in `vagrant-libvirt(0.0.7 and after)`.

**NOTE** Change default box image as qcow2 instead of sparsed raw image from
vagrant-kvm version 0.1.5. Please take care what type are your box images.

## Features/Limitations

* Provides the same workflow as the Vagrant VirtualBox provider.
* Uses VirtualBox boxes almost seamlessly (see below).
* Uses NFS for sync folders
* Only works with 1 VM per Vagrantfile for now
* Only works with port forward and private networking for now
* Requires "libvirtd" group membership to run vagrant (Debian/Ubuntu only)
* Requires backporting qemu and libvirt from experimental (Debian) or raring (Ubuntu)
* Use qcow2 backing image in default, that make boot speed up.

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `kvm` provider. An example is
shown below.

```bash
$ vagrant plugin install vagrant-kvm
$ vagrant up --provider=kvm
```

Of course prior to doing this, you'll need to obtain a KVM-compatible
box file for Vagrant.

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to use a VirtualBox box and change the provider manually. For
example:

```bash
$ vagrant box add precise32 http://files.vagrantup.com/precise32.box
```

The box will be installed in `~/.vagrant.d/boxes/precise32/virtualbox`, you
need to change this to `~/.vagrant.d/boxes/precise32/kvm` and change the
provider in `metadata.json`. For example:

```bash
$ mv ~/.vagrant.d/boxes/precise32/virtualbox ~/.vagrant.d/boxes/precise32/kvm
$ cat <<EOF >~/.vagrant.d/boxes/precise32/kvm/metadata.json
> {"provider": "kvm"}
> EOF
```

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

## Box Format

Vagrant providers each require a custom provider-specific box format.
This folder shows the example contents of a box for the `kvm` provider.

There are two box formats for the `kvm` provider:

1. VirtualBox box - you need to change the provider to `kvm` in the
   `metadata.json` file, the box will be converted on the fly at first boot.
   It will convert original .vmdk disk to qcow2 image and remove the orginal.
2. "Native" box - you need a box.xml file (libvirt domain format) and a qcow2
   image file (you can convert a .vmdk with qemu-img)

To turn VirtualBox box into a Native box, you need to create a vagrant image first
and test it, then run package command;

```bash
$ vagrant package
```

## Configuration

There are some provider specific parameter to control VM definition.

* `cpu_model` - cpu architecture: 'i686' or 'x86_64': default is x86_64.
  When importing VirtualBox box it may fails to recognize cpu architecture.
  you can set it for such case.
* `core_number` - cpu core number.
* `memory_size` - memory size such as 512m, 1GiB, 100000KiB etc.
  if only number supplied, use it in KiB.
* `gui` - boolean for starting VM with VNC enabled.
* `vnc_port` - The port the VNC server listens to. Default is automatic port
assignment.
* `vnc_autoport` - if true, KVM will automatically assign a port for VNC
to listen to. Defaults to false, but the default vnc_port is -1, which results
in this flag being automatically turned on by KVM. 
* `vnc_password ` - A password used to protect the VNC session.
* `image_type` - an image format for vm disk: 'raw' or 'qcow2': default is "qcow2"
  When choosing 'raw', vagrant-kvm always convert box image into storage-pool,
  it requires disk space and duration to boot. Recommendation is 'qcow2'.
* `machine_type` - The type of machine to boot. Default is pc-1.2.
* `network_model` - The model of the network adapter you want to use. Defaults
to virtio. Can be set to `:default` if you want to use the KVM default setting.
Possible values include: ne2k_isa i82551 i82557b i82559er ne2k_pci pcnet rtl8139 e1000 virtio.

## Specs

To run specs, you first need to add and prepare Vagrant box which will be used.

```bash
$ bundle exec rake box:add
$ bundle exec rake box:prepare
```

Once box is added and prepared, you can run specs:

```bash
$ bundle exec rake spec
```

When you're done, feel free to remove the box.

```bash
$ bundle exec rake box:remove
```

If you're Mac user and you have Vagrant and VMware Fusion, you can use bundled box for development. See `spec/Vagrantfile` for details.
