[![Build Status](https://travis-ci.org/adrahon/vagrant-kvm.png)](https://travis-ci.org/adrahon/vagrant-kvm)

# Vagrant KVM Provider

This is a [Vagrant](http://www.vagrantup.com) 1.4+ plugin that adds a KVM
provider to Vagrant, allowing Vagrant to control and provision KVM/QEMU VM.

## Requirements

This plugin requires QEMU 1.1+, it has only been tested on Fedora 18+,
Debian Wheezy, Ubuntu 12.04(LTS) Precise and Ubuntu 13.04 Raring at the moment.

This plugin requires several library and helper utils packages.
Consult the [Requirements section in INSTALL.md](https://github.com/adrahon/vagrant-kvm/blob/master/INSTALL.md)

## Recent changes

Default image format is now qcow2 instead of sparsed raw imagei, with qcow2
`vagrant-kvm` uses the box volume as a backing volume so that VM creation is
a lot faster. In most cases you want to use qcow2.

OVF boxes conversion as been removed, you should use `vagrant-mutate` instead.

Synced folders are now provided by a QEMU/KVM Virtfs in default.
You can also use NFS for file share using `type: "nfs"` option.

There was a known libvirt bug in Ubuntu host:
https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/943680
It was solved in Ubuntu 14.04(Trusty) and a backported libvirt provided by PPA above.

## Features/Limitations

* Provides the same workflow as the Vagrant VirtualBox provider.
* Uses Virtfs for sync folders
* Only works with 1 VM per Vagrantfile for now
* Requires "libvirtd" group membership to run Vagrant (Debian/Ubuntu only)
* Requires backporting qemu and libvirt from experimental (Debian) or trusty (Ubuntu)
* Use qcow2 backing image by default, which should make VM creation very fast

## Known issues

* Some versions of Ubuntu kernel has a bug that vagrant-kvm fails
  to do `vagrant up` with permission error.
  If you catch it, please run following command to work around.
  It is a kernel bug on AppArmor security framework,
  the command disables access control for libvirt helper.

```bash
sudo aa-complain /usr/lib/libvirt/virt-aa-helper
```

## Usage

Install using standard Vagrant 1.4+ plugin installation methods. After
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
* `customize` - Customize virtual machine with virsh command. Similar functionality with virtualbox provider.
* `disk_bus` - disk interface to show virtual disk to guest: 'virtio' or 'sata', 'scsi'
  A box, which is 'mutate'-ed from virtualbox/vmware box, may specify sata/ide for disk bus.
  It may be useful to specify 'virtio' for performance, even when box defaults disk bus as sata/ide/scsi.


## Comparison with [Vagrant-libvirt](https://github.com/pradels/vagrant-libvirt)

Vagrant-kvm is a KVM/Qemu provider for single local host.
Vagrant-kvm is simple, local host only, qemu/kvm only provider that is
intend to alternate VirtualBox with KVM/Qemu in same work flow.

Vagrant-libvirt is a libvirt provider to control machines via libvirt toolkit.
Vagrant-libvirt is, in design, for local and remote hosts and multiple hypervisors,
such as Xen, LXC and KVM/qemu.

In early 2014, Varant-libvirt only support kvm/qemu in local host,
there is no big feature difference.

In technical view, vagrant-kvm control kvm/qemu via ruby-libvirt,libvirt and qemu.

In contrast, vagrant-libvirt control machines via fog, a cloud abstraction
library in ruby, that is also used by vagrant-aws.
A fog library control virtual machines on supported platforms and provide
control of qemu/kvm machines through ruby-libvirt and libvirt.

