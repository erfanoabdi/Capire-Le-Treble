#/bin/bash

# Project Capire le treble (CLT) by Erfan Abdi <erfangplus@gmail.com>
# mount treblized lineage system image and set mount point to $lineage
# mount GSI and set mount point to $gsi
# set your proprietary-files.txt in $proptxt
# set your System Image size to $syssize

lineage="/media/erfanabdi/system"
gsi="/media/erfanabdi/system1"
proptxt="/home/erfanabdi/Desktop/CLT/proprietary-files.txt"
syssize="5704253440"
output="system.img"

LOCALDIR=`pwd`
tempdirname="tmp"
tempdir="$LOCALDIR/$tempdirname"
systemdir="$tempdir/system"

# Create temp dirs
mkdir -p "$systemdir"

# Copy GSI Rom files
( cd "$gsi" ; sudo tar cf - . ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

# Remove vendor symlink
sudo rm -rf "$systemdir/vendor"

# Copy Vendor Dir to Temp
( cd "$lineage" ; sudo tar cf - "vendor" ) | ( cd "$systemdir" ; sudo tar xf - )
cd "$LOCALDIR"

# Copy System Prop Files
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
        sudo mkdir -p "$systemdir/$filedir"
        sudo cp -npr "$lineage/$file" "$systemdir/$filedir/"
        continue
    fi
    file=`echo "$line" | cut -d ":" -f 2 | cut -d "|" -f 1`
    filedir=`echo $file | rev | cut -d "/" -f 2- | rev`
    sudo mkdir -p "$systemdir/$filedir"
    sudo cp -fpr "$lineage/$file" "$systemdir/$filedir/"
done < "$proptxt"

# Prepare File Contexts
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

if [[ $(getconf LONG_BIT) = "64" ]]; then
    make_ext4fs="$LOCALDIR/make_ext4fs_64"
else
    make_ext4fs="$LOCALDIR/make_ext4fs_32"
fi

# Create Image
sudo $make_ext4fs -T 0 $fcontexts -l $syssize -L system -a system -s "$output" "$systemdir/"

# remove tempdir
sudo rm -rf "$tempdir"
