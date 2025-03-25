# libada
Scripts to rebuild Ada Runtime on GNAT FSF


## Ubuntu 18.04

```shell
apt update
apt install -y gnat-8 gcc-8 g++-8 libc-dev make curl gprbuild gcc-8-plugin-dev

ln -v -s 8 /usr/lib/gcc/x86_64-linux-gnu/8.4.0

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8  --slave /usr/bin/gnatls gnatls /usr/bin/gnatls-8

cd /tmp/src/libada
./rebuild.sh 8.4.0 /usr/lib/gcc/x86_64-linux-gnu/8/adainclude /tmp/rts/adainclude
```