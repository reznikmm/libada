#!/bin/bash

set -e

if [ $# -lt 2 ] ; then
    echo "Usage: $0 gcc-version src-adainclude [dst-adainclude]"
    echo " where gcc-version is the GCC version like 8.4.0"
    echo " where src-adainclude is RTS adainclude to make a copy"
    echo " where dst-adainclude is where to copy the RTS (src-adainclude by default)"
    exit 1;
elif [[ ! "${3:-$2}" =~ .*/adainclude$ ]] ; then
    echo "dst-adainclude should be <something>/adainclude"
    exit 1;
fi

DST="${3:-$2}"
VER="$1"
CACHE="${TMP:-/tmp}"
GCC="$CACHE/gcc-$VER"

if [ ! -d $GCC ] ; then
    echo "Downloading gcc-$VER"
    URL="https://gcc.gnu.org/pub/gcc/releases/gcc-$VER/gcc-$VER.tar.gz"
    curl -L $URL |  tar xzf - -C "$CACHE"
fi

if [ ! -f "$DST/system.ads" ] ; then
    echo "Copying adainclude"
    mkdir -v -p "$DST"
    cp -r "$2"/*.ad[sb] $DST/
fi

TARGET="$(grep Target_Name $DST/s-oscons.ads|cut -d\" -f2)"
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
cp "$DST"/*.ad[sb] "$CACHE/libgnat/"
cp -v `dirname $0`/{gpr,c}/* "$DST"

echo "Look for sources matched objects in libgnarl.a"
for J in `$AR t $2/../adalib/libgnarl.a |sed -e s/\.o$//`; do
    if stat -t "$CACHE"/libgnat/$J.* > /dev/null 2>&1; then
        mv -v "$CACHE"/libgnat/$J.* "$CACHE"/libgnarl/
    else
        cp -v "$GCC"/gcc/ada/libgnarl/$J.[ch] "$CACHE"/libgnarl/
        cp "$GCC"/gcc/ada/libgnarl/$J.[ch] "$DST"
    fi
done

echo "Look for subunits sources in GCC gcc/ada/libgnarl/"
for J in `grep -l '^separate (' "$GCC"/gcc/ada/libgnarl/*.ad[sb]` ; do
    FILE=`basename $J`
    if [ -f "$CACHE"/libgnat/"$FILE" ] ; then
        mv -v "$CACHE"/libgnat/"$FILE" "$CACHE"/libgnarl/
    fi
done

echo "Look for libgnat C sources in GCC gcc/ada/"
for J in `$AR t $2/../adalib/libgnat.a |sed -e s/\.o$//`; do
    if stat -t "$GCC"/gcc/ada/$J.[ch] > /dev/null 2>&1; then
        cp -v "$GCC"/gcc/ada/$J.[ch] "$DST"
        cp "$GCC"/gcc/ada/$J.[ch] "$CACHE"/libgnat/
    fi
done

echo "Look for libgnat Ada sources in adainclude"
LIBGNAT_LST="$CACHE"/libgnat.lst
(cd "$CACHE"/libgnat; ls *.[ch]) > "$LIBGNAT_LST"
for J in `$AR t $2/../adalib/libgnat.a |sed -e s/\.o$//`; do
    if stat -t "$CACHE"/libgnat/$J.ad[sb] > /dev/null 2>&1; then
        basename -a "$CACHE"/libgnat/$J.ad[sb] >> "$LIBGNAT_LST"
        rm -v "$CACHE"/libgnat/$J.ad[sb]
    fi
done

echo "Append any subunits in adainclude to libgnat"
SUBUNUTS=`grep -l -R '^separate (' "$CACHE"/libgnat`
basename -a $SUBUNUTS >> "$LIBGNAT_LST"
rm -v $SUBUNUTS

echo "Copy extra C includes"
for J in tb-gcc.c runtime.h gsocket.h ; do
   [ -f "$GCC"/gcc/ada/$J ] && cp -v "$GCC"/gcc/ada/$J "$DST"
done
cp -v "$GCC"/libgcc/unwind-pe.h "$DST"

echo "Creating libgnarl.lst, libgnat.lst"
(cd "$CACHE"/libgnarl/; ls | sort > $DST/libgnarl.lst)
sort "$LIBGNAT_LST" > $DST/libgnat.lst

echo "Turn s-oscons.ads into s-oscons.h"
sed -e '/: constant/s/ *\([a-zA-Z0-9_]*\) *: constant [^:]*:= \([^;]*\);.*/#define \1 \2/' \
  -e '/subtype/s/ *subtype \([a-zA-Z0-9_]*\) is Interfaces.C.\([^;]*\);/#define \1 \2/' \
  "$2"/s-oscons.ads | grep '^#def'> "$DST"/s-oscons.h

echo "Unused files:"
(cd "$CACHE"/libgnat; ls *.ad[sb])

MAJOR=`echo $VER | cut -f1 -d.`
PLUGIN="/usr/lib/gcc/$TARGET/$MAJOR/plugin/include"

if [ -d "$PLUGIN" -a "$2" != "$3" ] ; then
    CPATH="$PLUGIN" gprbuild -j0 -P "$DST"/libada.gpr -p
    echo "Compare file list of libgnat.a"
    $AR t $2/../adalib/libgnat.a | sort > $CACHE/libgnat.orig.txt
    $AR t $DST/../adalib/libgnat.a | sort > $CACHE/libgnat.next.txt
    diff -u $CACHE/libgnat.orig.txt $CACHE/libgnat.next.txt

    echo "Compare file list of libgnarl.a"
    $AR t $2/../adalib/libgnarl.a | sort > $CACHE/libgnarl.orig.txt
    $AR t $DST/../adalib/libgnarl.a | sort > $CACHE/libgnarl.next.txt
    diff -u $CACHE/libgnarl.orig.txt $CACHE/libgnarl.next.txt
else
    echo "Try to install gcc plugin dev package for you target:"
    echo "apt install gcc-$MAJOR-plugin-dev"
    echo "or"
    echo "apt install gcc-$MAJOR-plugin-dev-$TARGET"
    echo "Then build RTS with"
    echo "CPATH="$PLUGIN" gprbuild --target=$TARGET -j0 -P "$DST"/libada.gpr -p"
fi

rm -rf "$CACHE"/libgnarl" "$CACHE"/libgnat"
echo "(You may delete $GCC folder if you are done)"