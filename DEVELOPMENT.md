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


## Tests

We use Rspec and Travis-CI for continous integration and unit test.

Tests are located in `spec` directory.
Every PR should be tested and passes Travis-CI test before merging.

## Specs

To run specs, you first need to add and prepare the Vagrant box which will be used.

```bash
$ bundle exec rake box:add
$ bundle exec rake box:prepare
```

Once box is added and prepared, you can run specs:

```bash
$ bundle exec rspec spec/vagrant-kvm/
```

When you're done, feel free to remove the box.

```bash
$ bundle exec rake box:remove
```

## Milestones and versions

### Milestones
We set milestones for future releases. Vagrant-KVM is under active development and still in development status. The next several milestones are targeted to implement new features such as support of new vagrant versions, multi-vm support, virtfs support, and so on.

### Versions

We use (major).(minor).(patchlevel) versioning.
In development status, major version is 0.
When Implementing major features, we increment minor version such as 0.2.0.

When it reaches beta status, it may be 0.9.x.

When it reaches production status, it become 1.0.0.

Before 0.9.x, APIs, configuration parameters and other behaviors will be changed without caution or migration pass.

## Branches

We basically use `master` branch for development in 0.x series.
It is an exception when we need to release interim release to previous version that includes only single or some fixes. When necessary we make `-maint` branch such as `v0.1.5-maint`.
It becomes next release and planed version is incremented.

Here is an example.

We have released v0.1.5 in March, 2014. We started development for v0.1.6 to add more feature and merged several changes just after releasing v0.1.5. We found v0.1.5 is not working with Vagrant 1.5 that is released in March, 2014. Because it is not welcome to wait to a normal v0.1.6 release for Vagrant 1.5 support, we decided to release interim fix release as v0.1.6. 
We start release branch 'v0.1.5-maint' for v0.1.6 release.
The release number of new features on `master` is changed to v0.1.7 not v0.1.6.


### How To Contribute

* Clone: git clone git://github.com/adrahon/vagrant-kvm.git

* Get Setup

* Create a topic branch: git checkout -b awesome_feature

* Hack and Commit away.

* Keep up to date: git fetch && git rebase origin/master

* Test with Rspec

Once you’re ready:

* Fork the project on GitHub

* Add your repository as a remote: git remote add your_remote your_repo

* (Optional) setup Travis-CI for your repository

* Push up your branch: git push your_remote awesome_feature

* (Optional) check your Travis score whether passed

* Create a Pull Request for the topic branch, asking for review.

* Check your PR is passed on Travis

* If not, fix your commit and push to your repository: git push your_remote awesome_feature

## Travis-CI

TBD


