# Development Note

Supported ruby version is 2.0.x on vagrant 1.4.0 and later.
You may need to use a recent OS version for development base
such as Ubuntu Saucy(13.10), Trusy(14.04) or Fedora 19,20.

If you're Mac user and you have Vagrant and VMware Fusion,
you can use bundled box for development.

If you're Linux user(of cource, you try to use KVM),
You are lucky to run development version of vagrant-kvm on Vagrant,
QEMU/KVM and vagrant-kvm itself.

Unfortunately VirtualBox don't support nested virtualization.
We cannot use it for vagrant-kvm development.

## Requirement

This plugin requires additional packages for development.

- For source:
 * `git`

- For KVM:
 * `qemu-utils` `libvirt-dev`

- For File share:
 * `apparmor-utils` (Ubuntu)

- For Ruby:
 * `ruby2.0` `ruby2.0-dev` `libxml2-dev` `libxslt-dev`
 * gems: `rake` `bundler`
 
- For box development:
 * `bsdtar` `libguestfs-tools`

It is better to use `rvm` or `rbenv` to control ruby version as same as one
vagrant bundled.

## Test vagrant-kvm with vagrant-kvm

You can run vagrant-kvm on kvm/qemu guest OS with vagrant-kvm.
It is required to run KVM with 64bit Operating System and configure
`kvm-intel` or `kvm-amd` kernel module to allow it.

Please add a file and reboot in order to use kvm with nested virtulization support.

/etc/modprobe.d/kvm.conf:
```
options kvm-intel nested=1
options kvm-amd   nested=1
```

### Vagrantfile and configs

There are two `Vagrantfile` to help developers.

- `spec/Vagrantfile` make an environment on Ubuntu guest.
- `spec/fedora/Vagrantfile` make an alternative environment on Fedora guest.


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

## Travis-CI

TBD


