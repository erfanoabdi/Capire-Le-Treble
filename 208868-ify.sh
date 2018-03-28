#/bin/bash

# Project 208868 by Erfan Abdi <erfangplus@gmail.com>

LOCALDIR=`pwd`
lineage="/Volumes/system 1"
gsi="/Volumes/system"
proptxt=$1
tempfile="208868temp"
tempdir="$lineage/208868temp"
mkdir "$tempdir"

# Make Backup of Prop Files
while read -r line
do
    line=`echo "$line" | grep -v vendor/`
    [[ $line = \#* ]] && continue
    [ -z "$line" ] && continue
    if [[ $line = '-'* ]]
    then
        line=`echo "$line" | cut -c2-`
    fi
    file=`echo "$line" | cut -d ":" -f 2 | cut -d "|" -f 1`
    propfiles+=($file)
    filedir=`echo $file | rev | cut -d "/" -f 2- | rev`
    mkdir -p "$tempdir/$filedir"
    sudo mv "$lineage/$file" "$tempdir/$filedir/"
done < "$proptxt"

# Move Vendor Dir to Temp
sudo mv "$lineage/vendor" "$tempdir/"

# Clean lineage image
cd "$lineage"
shopt -s extglob
sudo rm -rf !("$tempfile")
cd "$LOCALDIR"

# Copy GSI Rom files
( cd "$gsi" ; sudo tar cf - . ) | ( cd "$lineage" ; sudo tar xf - )
cd "$LOCALDIR"

# Remove vendor symlink
sudo rm -rf "$lineage/vendor"

# Move Back vendor
mv "$tempdir/vendor" "$lineage/"

# Restore Prop Files
for pfile in "${propfiles[@]}"
do
    pfiledir=`echo $pfile | rev | cut -d "/" -f 2- | rev`
    mkdir -p "$lineage/$pfiledir"
    sudo mv "$tempdir/$pfile" "$lineage/$pfiledir/"
done

# remove tempdir
rm -rf "$tempdir"
