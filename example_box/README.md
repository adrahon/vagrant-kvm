# Vagrant KVM Example Box

Vagrant providers each require a custom provider-specific box format.
This folder shows the example contents of a box for the `kvm` provider.

You need a box.xml file (libvirt domain format), you can use the example
supplied as a base or use one from a VM you created with other tools. Don't
forget to change the volume path to just the name of the volume. You should
use a qcow2 volume in most cases, raw is also supported if you have a good
reason to use this format.

To turn this into a native box, you need to create an tar archive:

```bash
$ tar cvzf kvm.box ./metadata.json ./Vagrantfile ./box.xml ./box-disk1.img
```

You need a base MAC address like in the example.
