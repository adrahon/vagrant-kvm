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
for Ubuntu 12.04(LTS) at
 [launchpad-ppa](https://launchpad.net/~miurahr/+archive/vagrant)

### Debian/Ubuntu preparation

Before starting plugin installation, you need to configure your user id.
Access to the management layer of libvirt is controlled through membership
to the libvirtd unix group.

To enable libvirt management access for a user, add them to this group:

```bash
$ sudo usermod -G libvirtd  -a ~~usrname~~
```

### Fedora/CentOS/RedHat/openSUSE requirements

- For KVM:
  * `qemu-kvm` `libvirt` `libvirt-daemon-kvm.x86_64`

- For NFS:
 * `nfs-utils`

- For Networking:
 * `redir`

- For `ruby-libvirt` gems installation dependency:
 * `gcc` `make` `ruby-devel` `libvirt-devel` `libxslt-devel` `libxml2-devel`

### Fedora preparation

To start libvirt:

```bash
$ sudo systemctl enable libvirt
$ sudo systemctl start libvirt
$ sudo systemctl enable libvirt-guests
$ sudo systemctl start libvirt-guests
```

It uses PolicyKit for management access to libvirt,
an additional polkit rules file may be required.
Following sample configure that user who is in ~~virt~~ group
can access libvirt in user previlege.

/etc/polkit-1/rules.d/10.virt.rules
```
polkit.addRule(function(action, subject) {
  polkit.log("action=" + action);
  polkit.log("subject=" + subject);
  var now = new Date();
  polkit.log("now=" + now)
  if ((action.id == "org.libvirt.unix.manage" || action.id == "org.libvirt.unix.monitor") && subject.isInGroup("virt")) {
    return polkit.Result.YES;
  }
  return null;
});
```
And Polkit user configuration

```bash
$ sudo groupadd virt
$ sudo usermod -a -G virt ~~username~~
```

Then restart polkit service
```bash
$ systemctl restart polkit.service
```


In alternate way, you can use polkit local authority compatibirity configuration

```bash
$ sudo yum install -y polkit-pkla-compat
```

/etc/polkit-1/localauthority/50-vagrant-libvirt-access.pkla:
```
[libvirt Management Access]
Identity=unix-group:virt
Action=org.libvirt.unix.manage;org.libvirt.unix.monitor
ResultAny=yes
ResultInactive=yes
ResultActive=yes
```

And Polkit user configuration

```bash
$ sudo groupadd virt
$ sudo usermod -a -G virt ~~username~~
```

Then restart polkit service
```bash
$ systemctl restart polkit.service
```

Consult the polkit section of [libvirt document](http://libvirt.org/auth.html#ACL_server_polkit) for details.
Here is also a good [reference blog post](https://niranjanmr.wordpress.com/2013/03/20/auth-libvirt-using-polkit-in-fedora-18/)

###CentOS6/RedHat6 preparation

Add SELinux label to vagrant standard storage-pool directory
and box directory.It may be a bug in libvirt selinux handler that
sometimes fails to handle a VM image with backing-images.

```bash
$ sudo yum install policycoreutils-python
$ semanage fcontext -a -t virt_image_t "~/.vagrant.d/tmp/storage-pool(/.*)?"
$ restorecon -R ~/.vagrant.d/tmp/storage-pool
$ semanage fcontext -a -t virt_image_t "~/.vagrant.d/boxes(/.*)?"
$ restorecon -R ~/.vagrant.d/boxes
```

Add polkit configuration file to allow non-root user to access libvirt.

/etc/polkit-1/localauthority/50-local.d/50-libvirt-remote-access.pkla:
```
[libvirt Management Access]
Identity=unix-user:username
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes
```

Restart libvirtd

```bash
$ sudo /etc/init.d/libvirtd restart
```


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

