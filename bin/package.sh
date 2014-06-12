#!/usr/bin/env bash

error() {
    local msg="${1}"
    echo "${msg}"
    exit 1
}

usage() {
    echo "Usage: ${0} NAME IMAGE"
    echo
    echo "Package a kvm qcow2 image into a kvm vagrant reusable box"
    echo "It uses virt-install to do so"
}

if [ -z "$2" ]; then
    usage
    exit 1
fi

# defaults for virtual server
NAME="$1"
RAM=2048
VCPUS=2

IMG=$(readlink -e $2)
IMG_BASENAME=$(basename $IMG)
IMG_DIR=$(dirname $IMG)

# Create stuff in tmp dir
TMP_DIR=$IMG_DIR/_tmp_package
mkdir -p $TMP_DIR

# We move the image to the tempdir
# ensure that it's moved back again
# and the tmp dir removed
trap "mv $TMP_DIR/$IMG_BASENAME $IMG_DIR; rm -rf $TMP_DIR" EXIT

mv $IMG $TMP_DIR
IMG=$TMP_DIR/$IMG_BASENAME

cd $TMP_DIR

# generate box.xml

virt-install \
    --print-xml \
    --dry-run \
    --import \
    --name $NAME \
    --ram $RAM --vcpus=$VCPUS \
    --disk path="$IMG",bus=virtio,format=qcow2 \
    -w network=default,model=virtio > box.xml

# extract the mac for the Vagrantfile
MAC=$(cat box.xml | grep 'mac address' | cut -d\' -f2 | tr -d :)
IMG_ABS_PATH=$(cat box.xml | grep 'source file' | cut -d\' -f2)

# replace the absolute image path
sed -i "s#$IMG_ABS_PATH#$IMG_BASENAME#" box.xml

# Hmm. When not starting the vm (--print-xml) the memory attribute in
# the XML is missing the unit, which causes an exception in vagrant-kvm

# add the memory unit
sed -i "s/<memory>/<memory unit='KiB'>/" box.xml

cat > metadata.json <<EOF
{
    "provider": "kvm"
}
EOF

cat > Vagrantfile <<EOF
Vagrant.configure("2") do |config|
  config.vm.base_mac = "$MAC"
end
EOF

tar cvzf $NAME.box --totals ./metadata.json ./Vagrantfile ./box.xml ./$IMG_BASENAME
mv $NAME.box $IMG_DIR

echo "$IMG_DIR/$NAME.box created"
