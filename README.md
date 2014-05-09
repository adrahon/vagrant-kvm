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

Default image format is now qcow2 instead of sparsed raw image, with qcow2
`vagrant-kvm` uses the box volume as a backing volume so that VM creation is
a lot faster. In most cases you want to use qcow2.

OVF boxes conversion has been removed, you should use `vagrant-mutate` instead.

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

### Vagrant 1.5 migration

Vagrant 1.5 changes a structure of user boxes directories.
vagrant-KVM handle box directory as libvirt/qemu temporary spool,
but Vagrant 1.5 changes it at first time launched.

Unfortunately vagrant-KVM 0.1.5 does not run on Vagrant-1.5.x.
Users who interested in vagrant-kvm 0.1.5 may use with Vagrant 1.4.x.

This caused problem when following sinario:

1. user use vagrant-kvm 0.1.5 with vagrant-1.4.x
2. user upgrade vagrant 1.5.x
3. user upgrade vagrant 0.1.5.1 and after

 We use transient pool instead of persistent one
in vagrant-kvm 0.1.5.x, 0.1.6 and after
Pools defined by vagrant-kvm will be removed after system reboot.

We recommend to use following combinations.

- Vagrant 1.3.x or before, and Vagrant-KVM 0.1.4

- Vagrant 1.5.x or after, and  Vagrant-KVM 0.1.5.1 or after

If you are joining test for vagrant-kvm or other reasons you use vagrant-kvm 0.1.5 with vagrant 1.4.x,
you got `Call to virStoragePoolCreate failed: cannot open path` error, please follow the instructions below.
Please take care when running commands as root.

1. Upgrade vagrant-kvm to vagrant-kvm  0.1.5.1 or after

2. Clear all storage definitions.

```bash
$ sudo ls /etc/libvirt/storage/vagrant*
$ sudo rm /etc/libvirt/storage/vagrant*
$ sudo ls /etc/libvirt/storage/vagrant*
```

alternative way:

* open virt-manager
* connect to localhost
* right click and open details
* click storage tab
* right click 'vagrant*' storage pool and delete it.

3. restart libvirt daemon

Ubuntu/Debian
```bash
$ sudo service libvirt-bin restart
```

Fedora/CentOS/SuSE/Arch
```bash
$ sudo systemctl restart libvirtd
```


### Ubuntu
Some versions of Ubuntu kernel has a bug that will cause vagrant-kvm
to fail with a permission error on `vagrant up`. It is a kernel bug with the AppArmor security framework.
As a workaround, please run following command to disable access control for libvirt helper.

```bash
sudo aa-complain /usr/lib/libvirt/virt-aa-helper
```

### Fedora and Arch
With Fedora and Arch, default home directory permissions are set to `drwx------`.
Qemu/kvm runs as 'qemu' user by default and cannot access your home directory.

To avoid this, please check and change your home directory and
child directories permission to permit qemu user access to `~/.vagrant.d/tmp/storage-pool/`

```bash
$ chmod go+x /home/<your account>
```

Another option is to run qemu/kvm as the root user by changing the
configuration in libvirt.

/etc/libvirt/qemu.conf
```
user = "root"
group = "root"
```

Then restart libvirtd.

```bash
$ sudo systemctl restart libvirtd
```

This may or may not be sufficient to make it work with Fedora, there are still
some issues for some users on Fedora 20.

## Usage

Install using the standard Vagrant 1.1+ plugin installation command. After
installation, use `vagrant up` and specify the `kvm` provider. An example is
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
then you can simply run `vagrant up` to use the kvm provider.

## Configuration

There are some provider specific parameter to control VM definition.

* `cpu_model` - cpu architecture: 'i686' or 'x86\_64': default is x86\_64. Note
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
Possible values include: ne2k\_isa i82551 i82557b i82559er ne2k\_pci pcnet rtl8139 e1000 virtio.
* `video_model` - The model of the video adapter. Default to cirrus. Can also be
set to vga.
* `image_mode` - Possible value are `clone` or `cow`, defaults to `cow`. If set
to `clone`, the image disk will be copied rather than use the original box
image. This is slower but allows multiple VMs to be booted at the same time.
* `customize` - Customize virtual machine with virsh command. Similar functionality with virtualbox provider.
* `disk_bus` - disk interface to show virtual disk to guest: 'virtio' or 'sata', 'scsi'
  A box, which is 'mutate'-ed from virtualbox/vmware box, may specify sata/ide for disk bus.
  It may be useful to specify 'virtio' for performance, even when box defaults disk bus as sata/ide/scsi.
* `force_pause` - use `pause` for `vagrant suspend` instead of `suspend`.
  It keeps resource online but execution is stopped.
  When VM has a device that is not supported `hibernate`, automatically use
  `pause` regardless of this.
* `virtio_rng` - boolean for optional virtio device of random number generator.
  QEMU 1.3.0 and after support this device. default `false`


## Comparison with [Vagrant-libvirt](https://github.com/pradels/vagrant-libvirt)

Vagrant-kvm is a KVM/Qemu provider for single local host.
Vagrant-kvm is simple, local host only, qemu/kvm only provider that is
intended as an alternative to VirtualBox while keeping the same workflow.

Vagrant-libvirt is a libvirt provider to control machines via the libvirt toolkit.
Vagrant-libvirt covers a lot more libvirt options, local and remote hosts and multiple hypervisors,
such as Xen, LXC and KVM/qemu.

In early 2014, Vagrant-libvirt only supports kvm/qemu in local host, there is no big feature difference.

Here are a few difference:

### 1. Travis CI and quality assurance

Vagrant-kvm tests every pull request and repository with Travis-CI;
https://travis-ci.org/adrahon/vagrant-kvm/
Vagrant-libvirt does not.

### 2. Copy-on-write

Vagrant-kvm by default uses the qcow2 format
and qcow2 disk image backing to create a new volume
from the box disk.
This makes creating a new vm very fast, with some performance penalties.
You can change this through configuration to clone(copy) disk image to pool instead.
This will make new vm creation slower, but give you better disk performance.
You can also configure vagrant-kvm to use raw images for an additional
performance gain.

Vagrant-libvirt use qcow2 as disk image.

### 3. VNC port/password

Vagrant-kvm allows you to configure how to connect with VNC, which provides virtual guest desktop.
Vagrant-libvirt does not.

### 4. Synced folder

Vagrant-kvm can provide synced folder with NFS only.
We plan to provide virtfs(p9share) to allow sharing local folders
without root privilege.

Vagrant-libvirt provide synced folder with Rsync and NFS.
They also plan to support virtfs in future.

It is neccesary to fix several bugs in libvirt/qemu to enable the
virtfs feature in both providers.

### 5. Snapshots via sahara

Vagrant-kvm plans to support snapshot via sahara.
We have already proposed to sahara project to add support
and are waiting for review.
https://github.com/jedi4ever/sahara/pull/32

Vagrant-libvirt is supported by sahara.

### 6. Use boxes from other Vagrant providers via vagrant-mutate

Both are supported by vagrant-mutate as convert target

### 7. Architecture

Vagrant-kvm controls kvm/qemu via ruby-libvirt, libvirt and qemu.

Vagrant-libvirt controls machines via fog,
a cloud abstraction library in ruby,
that is also used by vagrant-aws.
The fog library controls virtual machines on supported platforms and provides
control of qemu/kvm machines through ruby-libvirt and libvirt.

