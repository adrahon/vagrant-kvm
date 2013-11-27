# Vagrant KVM Example Box

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

You need a base MAC address like in the example.
