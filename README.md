# Vagrant KVM Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds a KVM
provider to Vagrant, allowing Vagrant to control and provision KVM/QEMU VM.

**NOTE:** This plugin requires Vagrant 1.1+

**NOTE:** This plugin requires QEMU 1.2+, it has only been tested on Fedora 18
and Debian Wheezy at the moment.

**NOTE:** This plugin requires `libvirt-dev` package to be installed (Ubuntu 13.04) or `libvirt-devel` (openSUSE)

## Features/Limitations

* Provides the same workflow as the Vagrant VirtualBox provider.
* Uses VirtualBox boxes almost seamlessly (see below).
* Uses NFS for sync folders
* Only works with 1 VM per Vagrantfile for now
* Only works with private networking for now
* Requires "libvirt" group membership to run vagrant (Debian/Ubuntu only)
* Requires backporting qemu and libvirt from experimental (Debian) or raring (Ubuntu)

## Usage

Install using standard Vagrant 1.1+ plugin installation methods. After
installing, `vagrant up` and specify the `kvm` provider. An example is
shown below.

```
$ vagrant plugin install vagrant-kvm
...
$ vagrant up --provider=kvm
...
```

Of course prior to doing this, you'll need to obtain a KVM-compatible
box file for Vagrant.

## Quick Start

After installing the plugin (instructions above), the quickest way to get
started is to use a VirtualBox box and change the provider manually. For
example:

```
$ vagrant box add precise32 http://files.vagrantup.com/precise32.box
...
```

The box will be installed in `~/.vagrant.d/boxes/precise32/virtualbox`, you
need to change this to `~/.vagrant.d/boxes/precise32/kvm` and change the
provider in `metadata.json`. For example:

```
mv ~/.vagrant.d/boxes/precise32/virtualbox ~/.vagrant.d/boxes/precise32/kvm
cat <<EOF >~/.vagrant.d/boxes/precise32/kvm/metadata.json
> {"provider": "kvm"}
> EOF
```

You will need a private network specifying an IP address in your Vagrantfile,
the minimum Vagrantfile would then be:

```
Vagrant.configure("2") do |config|
  config.vm.box = "precise32"
  config.vm.network :private_network, ip: "192.168.192.10"
end
```

And then run `vagrant up --provider=kvm`.

If you always use kvm provider as default, please set it in your .bashrc:
```
export VAGRANT_DEFAULT_PROVIDER=kvm
```
then you can simply run `vagrant up` with kvm provider.

## Box Format

Vagrant providers each require a custom provider-specific box format.
This folder shows the example contents of a box for the `kvm` provider.

There are two box formats for the `kvm` provider:

1. VirtualBox box - you need to change the provider to `kvm` in the
   `metadata.json` file, the box will be converted on the fly.
2. "Native" box - you need a box.xml file (libvirt domain format) and a raw
   image file (you can convert a .vmdk with qemu-img)

To turn this into a native box, you need to create a vagrant image and do:

```
$ tar cvzf kvm.box ./metadata.json ./Vagrantfile ./box.xml ./box-disk1.img
```

You need a base MAC address and a private network like in the example.


## Configuration

There are no provider-specific parameters at the moment.
