#/bin/bash

# Project Capire le treble (CLT) by Erfan Abdi <erfangplus@gmail.com>
# Modified for AB type devices by Pranav Bedre <bedrepranav@gmail.com>

usage()
{
    echo "Usage: $0 <Path to Orginal system> <Path to GSI system> <System Partition Size> <Output File> [proprietary-files.txt]"
    echo -e "\tPath to Orginal system : Mount treblized lineage system image and set mount point"
    echo -e "\tPath to GSI system : Mount GSI and set mount point"
    echo -e "\tSystem Partition Size : set system Partition Size"
    echo -e "\tOutput File : set Output file path (system.img)"
    echo -e "\tproprietary-files.txt : enter proprietary-files.txt if you want to copy any file from orginal system to target"
}

if [ "$4" == "" ]; then
    echo "ERROR: Enter all needed parameters"
    usage
    exit 1
fi

lineage=$1
gsi=$2
syssize=$3
output=$4

LOCALDIR=`pwd`
tempdirname="tmp"
tempdir="$LOCALDIR/$tempdirname"
systemdir="$tempdir/system"
toolsdir="$LOCALDIR/tools"

echo "Create Temp dir"
mkdir -p "$systemdir"

echo "Copy GSI Rom Files"
( cd "$gsi" ; sudo tar cf - . ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

echo "Remove Vendor Symlink"
sudo rm -rf "$systemdir/system/vendor"
sudo rm -rf "$systemdir/vendor"

echo "Copy Vendor Dir to Temp"
( cd "$lineage/system" ; sudo tar cf - "vendor" ) | ( cd "$systemdir/system" ; sudo tar xf - )
cd "$LOCALDIR"

echo "Create Vendor Symlink"
( cd "$lineage" ; sudo tar cf - "vendor" ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

if [ "$5" != "" ]; then
    echo "Copy System Prop Files"
    proptxt=$5
    while read -r line
    do
        line=`echo "$line" | grep -v vendor/`
        [[ $line = \#* ]] && continue
        [ -z "$line" ] && continue
        if [[ $line = '-'* ]]
        then
            line=`echo "$line" | cut -c2-`
        fi
        if [[ $line = '?'* ]]
        then
            line=`echo "$line" | cut -c2-`
            file=`echo "$line" | cut -d ":" -f 2 | cut -d "|" -f 1`
            filedir=`echo $file | rev | cut -d "/" -f 2- | rev`
            sudo mkdir -p "$systemdir/system/$filedir"
            sudo cp -npr "$lineage/system/$file" "$systemdir/system/$filedir/"
            continue
        fi
        file=`echo "$line" | cut -d ":" -f 2 | cut -d "|" -f 1`
        filedir=`echo $file | rev | cut -d "/" -f 2- | rev`
        sudo mkdir -p "$systemdir/system/$filedir"
        sudo cp -fpr "$lineage/system/$file" "$systemdir/system/$filedir/"
    done < "$proptxt"
fi

echo "Prepare File Contexts"
p="/plat_file_contexts"
n="/nonplat_file_contexts"
for f in "$systemdir/system/etc/selinux" "$systemdir/system/vendor/etc/selinux" "$systemdir"; do
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
