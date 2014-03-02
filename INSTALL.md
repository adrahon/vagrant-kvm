# Installation

## Requirements

This plugin requires QEMU 1.1+.

It also requires libvirt development files to complete installation with
dependent ruby-libvirt gems.

### Debian/Ubuntu requirements

This plugin requires

- For KVM:
 * `qemu`, `qemu-kvm`,`libvirt-bin` packages
 * qemu 1.1 and after
 * libvirt 1.0 and after

- For NFS:
 * `nfs-kernel-server`,`nfs-common`,`portmap`

- For Networking:
 * `redir` `dnsmasq-base` `bridge-utils`

- For `ruby-libvirt` gems installation dependency:
 * `build-essential` `ruby2.0-dev` `libvirt-dev` `libxslt1-dev` `libxml2-dev`

Some kernel version has a bug that causes a permission error on image.
You are strongly recommended to upgrade a `linux-image` up-to-date.
If you have some reason not to update, you should install
`apparmor-profiles` and `apparmor-utils` and
consult the Known Issues section in README.md.
https://github.com/adrahon/vagrant-kvm/blob/master/README.md#known-issues

You can use a backported KVM/QEMU 1.4 with Private Package Archive(PPA)
for Ubuntu 12.04(LTS) at https://launchpad.net/~miurahr/+archive/vagrant

### Fedora/RedHat/openSUSE requirements

- For KVM:
  * `qemu-kvm` `libvirt`

- For NFS:
 * `nfs-utils`

- For Networking:
 * `redir`

- For `ruby-libvirt` gems installation dependency:
 * `libvirt-devel` `libxslt-devel` `libxml2-devel`

### ArchLinux requirements

This plugin requires

- For KVM:
 * `qemu-kvm`,`libvirt`

- For NFS:
  * `nfs-utils`

- For Networking:
 * `redir` `bridge-utils` `dnsmasq`

- For `ruby-libvirt` gems installation dependency:
 * `libvirt-dev`

To use with Vagrant, you must configure libvirt for non-root user to run KVM.
Consult [ArchLinux Wiki](https://wiki.archlinux.org/index.php/Libvirt#Configuration)
for details.

## Install procedure

As usual, you can install `vagrant-kvm` using `vagrant plugin install` command.
```bash
$ vagrant plugin install vagrant-kvm
```

