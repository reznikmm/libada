#!/bin/bash

set -e

if [ $# -lt 3 ] ; then
    echo "Usage: $0 gcc-version src-adainclude dst-adainclude"
    echo " where gcc-version is the GCC version like 8.4.0"
    echo " where src-adainclude is RTS adainclude to make a copy"
    echo " where dst-adainclude is where to copy the RTS"
    exit 1;
fi

VER="$1"
CACHE="${TMP:-/tmp}"
GCC="$CACHE/gcc-$VER"
SRC_RTS=`dirname $2`
DST_RTS=`dirname $3`

if [ ! -d $GCC ] ; then
    echo "Downloading gcc-$VER"
    URL="https://gcc.gnu.org/pub/gcc/releases/gcc-$VER/gcc-$VER.tar.gz"
    curl -L $URL |  tar xzf - -C "$CACHE"
fi

if [ ! -f "$3/system.ads" ] ; then
    echo "Copying adainclude"
    mkdir -v -p "$3"
    cp -r "$2" "$DST_RTS"
fi

TARGET="$(grep Target_Name $3/s-oscons.ads|cut -d\" -f2)"
echo "Target is $TARGET"

if [[ "$TARGET" =~ [^-]*-[^-]*-[^-]*-[^-]* ]] ; then
    TARGET=`echo "$TARGET"|cut -f1,3,4 -d-`
    echo "Fix target to $TARGET"
fi

if type "$TARGET-ar" > /dev/null 2>&1 ; then
    AR="$TARGET-ar"
else
    AR="ar"
fi

echo "AR=$AR"
rm -rf "$CACHE/libgnat" "$CACHE/libgnarl"
mkdir -p "$CACHE/libgnat" "$CACHE/libgnarl"
cp "$3"/*.ad[sb] "$CACHE/libgnat/"
cp -v gpr/* "$3"
cp -v c/* "$3"

echo "Ignoring files with pragma Unimplemented_Unit"

for J in `grep -l 'pragma Unimplemented_Unit' "$CACHE/libgnat"/*`; do
  rm -v "$CACHE/libgnat"/`basename $J .ads`.ad[sb]
done

echo "Ignoring files with pragma Source_File_Name"

for J in `grep -l 'pragma Source_File_Name' "$CACHE/libgnat"/*`; do
  rm -v "$J"
done

echo "Ignoring files moved to SPARK"
for J in `grep -l 'This package has been moved to the SPARK' "$CACHE/libgnat"/*`; do
  rm -v "$J"
done

echo "Ignoring files with double underscores and extra"
rm -rf -v "$CACHE"/libgnat/*__*.ad[sb]
rm -rf -v "$CACHE"/libgnat/s-strops.ad[sb]
rm -rf -v "$CACHE"/libgnat/s-qnx.ads
rm -rf -v "$CACHE"/libgnat/s-tpobmu.ad[sb]

echo "Look for sources matched objects in libgnarl.a"
for J in `$AR t $2/../adalib/libgnarl.a |sed -e s/\.o$//`; do 
    if stat -t "$CACHE"/libgnat/$J.* > /dev/null 2>&1; then
        mv -v "$CACHE"/libgnat/$J.* "$CACHE"/libgnarl/
    else
        cp -v "$GCC"/gcc/ada/libgnarl/$J.[ch] "$CACHE"/libgnarl/
        cp "$GCC"/gcc/ada/libgnarl/$J.[ch] "$3"
    fi
done

echo "Look for sources in GCC gcc/ada/libgnarl/"
for J in "$GCC"/gcc/ada/libgnarl/*.ad[sb] ; do
    FILE=`basename $J`
    if [ -f "$CACHE"/libgnat/"$FILE" ] ; then
        mv -v "$CACHE"/libgnat/"$FILE" "$CACHE"/libgnarl/
    fi
done

echo "Look for libgnat C sources in GCC gcc/ada/"
for J in `$AR t $2/../adalib/libgnat.a |sed -e s/\.o$//`; do 
    if stat -t "$GCC"/gcc/ada/$J.[ch] > /dev/null 2>&1; then
        cp -v "$GCC"/gcc/ada/$J.[ch] "$CACHE"/libgnat/
        cp "$GCC"/gcc/ada/$J.[ch] "$3"
    fi
done

echo "Copy extra C includes"
cp -v "$GCC"/gcc/ada/tb-gcc.c "$GCC"/gcc/ada/gsocket.h "$GCC"/libgcc/unwind-pe.h "$3"

echo "Creating libgnarl.lst, libgnat.lst"
(cd "$CACHE"/libgnarl/; ls | sort > $3/libgnarl.lst)
(cd "$CACHE"/libgnat/;  ls | sort > $3/libgnat.lst)

echo "Turn s-oscons.ads into s-oscons.h"
sed -e '/: constant/s/ *\([a-zA-Z0-9_]*\) *: constant [^:]*:= \([^;]*\);.*/#define \1 \2/' \
  -e '/subtype/s/ *subtype \([a-zA-Z0-9_]*\) is Interfaces.C.\([^;]*\);/#define \1 \2/' \
  "$2"/s-oscons.ads | grep '^#def'> "$3"/s-oscons.h

MAJOR=`echo $VER | cut -f1 -d.`
PLUGIN="/usr/lib/gcc/$TARGET/$MAJOR/plugin/include"

if [ -d "$PLUGIN" ] ; then
    CPATH="$PLUGIN" gprbuild -j0 -P "$3"/libada.gpr -p
    echo "Compare libgnat.a"
    $AR t $2/../adalib/libgnat.a | sort > $CACHE/libgnat.orig.txt
    $AR t $3/../adalib/libgnat.a | sort > $CACHE/libgnat.next.txt
    diff -u $CACHE/libgnat.orig.txt $CACHE/libgnat.next.txt

    echo "Compare libgnarl.a"
    $AR t $2/../adalib/libgnarl.a | sort > $CACHE/libgnarl.orig.txt
    $AR t $3/../adalib/libgnarl.a | sort > $CACHE/libgnarl.next.txt
    diff -u $CACHE/libgnarl.orig.txt $CACHE/libgnarl.next.txt
else
    echo "Try to install gcc plugin dev package for you target:"
    echo "apt install gcc-$MAJOR-plugin-dev"
    echo "or"
    echo "apt install gcc-$MAJOR-plugin-dev-$TARGET"
    echo "Then build RTS with"
    echo "CPATH="$PLUGIN" gprbuild -j0 -P "$3"/libada.gpr -p"
fi

rm -rf "$CACHE"/libgnarl" "$CACHE"/libgnat"
echo "(You may delete $GCC folder)"