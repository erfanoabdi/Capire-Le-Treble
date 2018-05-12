#/bin/bash

# Convert AB to A-only by Erfan Abdi <erfangplus@gmail.com>

declare -a abfiles=(
etc/init/bufferhubd.rc
etc/init/cppreopts.rc
etc/init/otapreopt.rc
etc/init/performanced.rc
etc/init/recovery-persist.rc
etc/init/recovery-refresh.rc
etc/init/update_engine.rc
etc/init/update_verifier.rc
etc/init/virtual_touchpad.rc
etc/init/vr_hwc.rc
bin/update_engine
bin/update_verifier
)

usage()
{
    echo "Usage: $0 <Path to AB system> <System Partition Size> <Output File>"
    echo -e "\tPath to AB system : Mount AB system image and set mount point"
    echo -e "\tSystem Partition Size : set system Partition Size"
    echo -e "\tOutput File : set Output file path (system.img)"
}

if [ "$3" == "" ]; then
echo "ERROR: Enter all needed parameters"
usage
exit 1
fi

ab="$1/system"
syssize=$2
output=$3

LOCALDIR=`pwd`
tempdirname="tmp"
tempdir="$LOCALDIR/$tempdirname"
systemdir="$tempdir/system"
toolsdir="$LOCALDIR/../tools"

echo "Create Temp dir"
mkdir -p "$systemdir"

echo "Copy AB Rom Files"
( cd "$ab" ; sudo tar cf - . ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

for abfile in "${abfiles[@]}"
do
    rm -rf "$systemdir/$abfile"
done

echo "Prepare File Contexts"
p="/plat_file_contexts"
n="/nonplat_file_contexts"
for f in "$systemdir/etc/selinux" "$systemdir/vendor/etc/selinux"; do
    if [[ -f "$f$p" ]]; then
        sudo cat "$f$p" >> "$tempdir/file_contexts"
    fi
    if [[ -f "$f$n" ]]; then
        sudo cat "$f$n" >> "$tempdir/file_contexts"
    fi
done

if [[ -f "$tempdir/file_contexts" ]]; then
    fcontexts="-S $tempdir/file_contexts"
fi

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
sudo $make_ext4fs -T 0 $fcontexts -l $syssize -L system -a system -s "$output" "$systemdir/"

echo "Remove Temp dir"
sudo rm -rf "$tempdir"

