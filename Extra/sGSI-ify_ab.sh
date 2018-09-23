#!/bin/bash

# Project Capire le treble (CLT) by Erfan Abdi <erfangplus@gmail.com>

usage()
{
    echo "Usage: $0 <Path to GSI system> <System Partition Size> <Output File>"
    echo -e "\tPath to GSI system : Mount GSI and set mount point"
    echo -e "\tSystem Partition Size : set system Partition Size"
    echo -e "\tOutput File : set Output file path (system.img)"
}

if [ "$3" == "" ]; then
    echo "ERROR: Enter all needed parameters"
    usage
    exit 1
fi

gsi=$1
syssize=$2
output=$3

LOCALDIR=`pwd`
tempdirname="tmp"
tempdir="$LOCALDIR/$tempdirname"
systemdir="$tempdir/system"
toolsdir="$LOCALDIR/../tools"

echo "Create Temp dir"
mkdir -p "$systemdir"

echo "Copy GSI Rom Files"
( cd "$gsi" ; sudo tar cf - . ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

echo "Edit whatever you want and"
read -n 1 -s -r -p "Press any key to continue"

echo "Prepare File Contexts"
p="/plat_file_contexts"
n="/nonplat_file_contexts"
for f in "$systemdir/system/etc/selinux" "$systemdir/system/vendor/etc/selinux"; do
    if [[ -f "$f$p" ]]; then
        sudo cat "$f$p" >> "$tempdir/file_contexts"
    fi
    if [[ -f "$f$n" ]]; then
        sudo cat "$f$n" >> "$tempdir/file_contexts"
    fi
done

if [[ -f "$tempdir/file_contexts" ]]; then
    echo "/firmware(/.*)?         u:object_r:firmware_file:s0" >> "$tempdir/file_contexts"
    echo "/bt_firmware(/.*)?      u:object_r:bt_firmware_file:s0" >> "$tempdir/file_contexts"
    echo "/persist(/.*)?          u:object_r:persist_file:s0" >> "$tempdir/file_contexts"
    echo "/dsp                    u:object_r:rootfs:s0" >> "$tempdir/file_contexts"
    fcontexts="-S $tempdir/file_contexts"
fi
mkdir -p "$systemdir/bt_firmware"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if [[ $(getconf LONG_BIT) = "64" ]]; then
        make_ext4fs="$toolsdir/linux/bin/make_ext4fs_64"
    else
        make_ext4fs="$toolsdir/linux/bin/make_ext4fs_32"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    make_ext4fs="$toolsdir/mac/bin/make_ext4fs"
else
    echo "Not Supported OS for make_ext4fs"
    echo "Removing Temp dir"
    sudo rm -rf "$tempdir"
    exit 1
fi

echo "Create Image"
sudo $make_ext4fs -T 0 $fcontexts -l $syssize -L / -a / -s "$output" "$systemdir/"

echo "Remove Temp dir"
#sudo rm -rf "$tempdir"
