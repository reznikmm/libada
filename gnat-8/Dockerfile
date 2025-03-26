FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
 gnat-8 \
 gcc-8 \
 g++-8 \
 gcc-8-plugin-dev \
 libc-dev \
 make \
 curl \
 gprbuild \
 g++-8-arm-linux-gnueabi \
 gnat-8-arm-linux-gnueabi \
 gcc-8-plugin-dev-arm-linux-gnueabi \
 && \
 update-alternatives \
  --install /usr/bin/arm-linux-gnueabi-gcc arm-linux-gnueabi-gcc \
    /usr/bin/arm-linux-gnueabi-gcc-8 800 \
  --slave /usr/bin/arm-linux-gnueabi-g++ arm-linux-gnueabi-g++ \
    /usr/bin/arm-linux-gnueabi-g++-8 \
 && \
 update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 \
  --slave /usr/bin/g++ g++ /usr/bin/g++-8 \
  --slave /usr/bin/gnatls gnatls /usr/bin/gnatls-8 \
 && \
  ln -s /usr/lib/gcc-cross /usr/lib/gcc-lib && \
  ln -s 8 /usr/lib/gcc-cross/arm-linux-gnueabi/8.4.0  && \
  ln -v -s 8 /usr/lib/gcc/x86_64-linux-gnu/8.4.0 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
