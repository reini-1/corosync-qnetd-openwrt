FROM ubuntu:26.04

RUN apt update && apt install -y \
 build-essential clang flex bison g++ gawk gcc-multilib \
 gettext git libncurses-dev libssl-dev python3 python3-setuptools unzip zlib1g-dev \
 file wget rsync ca-certificates pkg-config autoconf automake libtool libnss3-tools \
 zstd

WORKDIR /opt

# RUN wget https://downloads.openwrt.org/releases/24.10.8/targets/armsr/armv8/openwrt-sdk-24.10.8-armsr-armv8_gcc-13.3.0_musl.Linux-x86_64.tar.zst \
# RUN https://downloads.openwrt.org/releases/24.10.8/targets/mediatek/filogic/openwrt-sdk-24.10.8-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst \
RUN https://downloads.openwrt.org/releases/24.10.2/targets/mediatek/filogic/openwrt-sdk-24.10.2-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst \
 && tar -xf openwrt-sdk-*.tar.zst \
 && rm openwrt-sdk-*.tar.zst \
 && mv openwrt-sdk-* sdk

WORKDIR /opt/sdk

COPY build.sh /build/build.sh
CMD ["/bin/bash", "/build/build.sh"]
