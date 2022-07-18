FROM quay.io/costoolkit/releases-green:luet-toolchain-0.21.2 AS luet

FROM opensuse/leap:15.3 AS base

# Copy luet from the official images
COPY --from=luet /usr/bin/luet /usr/bin/luet

ARG ARCH=amd64
ENV ARCH=${ARCH}
RUN zypper mr --disable repo-non-oss repo-update-non-oss
RUN zypper --no-gpg-checks ref
RUN zypper update -y
COPY files/etc/luet/luet.yaml /etc/luet/luet.yaml

FROM base as tools
ENV LUET_NOLOCK=true
RUN zypper in -y docker squashfs xorriso
COPY tools /
RUN luet install -y toolchain/luet-makeiso

FROM base
ARG RANCHERD_VERSION=v0.0.1-alpha13
RUN zypper in -y \
    bash-completion \
    conntrack-tools \
    coreutils \
    curl \
    device-mapper \
    dosfstools \
    dracut \
    e2fsprogs \
    findutils \
    gawk \
    gptfdisk \
    grub2-i386-pc \
    grub2-x86_64-efi \
    haveged \
    iproute2 \
    iptables \
    iputils \
    issue-generator \
    jq \
    kernel-default \
    kernel-firmware-bnx2 \
    kernel-firmware-i915 \
    kernel-firmware-intel \
    kernel-firmware-iwlwifi \
    kernel-firmware-mellanox \
    kernel-firmware-network \
    kernel-firmware-platform \
    kernel-firmware-realtek \
    less \
    lsscsi \
    lvm2 \
    mdadm \
    multipath-tools \
    nano \
    nfs-utils \
    open-iscsi \
    open-vm-tools \
    parted \
    pigz \
    policycoreutils \
    procps \
    python-azure-agent \
    qemu-guest-agent \
    rng-tools \
    rsync \
    squashfs \
    strace \
    systemd \
    systemd-sysvinit \
    tar \
    timezone \
    vim \
    which \
    lshw \
    fio \
    qemu \
    qemu-kvm \
    qemu-ovmf-x86_64 \
    qemu-ipxe \
    qemu-block-iscsi \
    qemu-block-nfs \
    qemu-block-ssh \
    qemu-chardev-spice \
    qemu-guest-agent \
    qemu-ksm \
    qemu-seabios \
    htop \
    iperf \
    net-tools-deprecated \
    bridge-utils \
    telnet \
    unzip \
    zsync \
    usbutils \
    tmux \
    python3-setuptools \
    the_silver_searcher \
    smartmontools \
    xfsprogs

#python3-yamllint \
#cryptsetup

   
# Additional firmware packages
RUN zypper in -y kernel-firmware-chelsio \
    kernel-firmware-liquidio \
    kernel-firmware-mediatek \
    kernel-firmware-marvell \
    kernel-firmware-qlogic \
    kernel-firmware-usb-network \
    kernel-firmware-amdgpu kernel-firmware-nvidia kernel-firmware-radeon \
    ucode-intel ucode-amd

# Harvester needs these packages
RUN zypper in -y apparmor-parser \
    zstd \
    nginx

# Additional useful packages
RUN zypper in -y traceroute \
    tcpdump \
    lsof \
    sysstat \
    iotop \
    hdparm \
    pciutils \
    ethtool \
    dmidecode \
    numactl \
    ipmitool \
    kdump \
    supportutils

#RUN zypper --no-gpg-checks ref
RUN zypper addrepo https://download.opensuse.org/repositories/filesystems/15.3/filesystems.repo
RUN zypper --gpg-auto-import-keys refresh
RUN zypper install -y zfs zfs-kmp-default


# rancher:/ # zypper wp /lib/modules/5.3.18-150300.59.76-default/kernel/drivers/scsi/hpsa.ko.xz
# kernel-default | The Standard Kernel | package

# custom kernel
ENV KERNEL_MAJOR_VERSION=5.3
ENV KERNEL_VERSION=5.3.18-150300.59.76-default
RUN zypper in -y -t pattern devel_basis 
RUN zypper in -y bc openssl openssl-devel dwarves rpm-build libelf-devel
RUN zypper in -y kernel kernel-source git
RUN zypper in -y wget xz
RUN ls -ld /usr/src/linux*
RUN cp /boot/config* /usr/src/linux/.config
RUN unset ARCH && cd /usr/src/linux &&\
    echo CONFIG_SCSI_HPSA=m >> .config &&\
    make -C /usr/src/linux O=$(pwd) clean oldconfig &&\
    git clone https://github.com/artizirk/hpsahba &&\
    cd hpsahba && make ; chmod +x hpsahba && cp -av hpsahba /usr/local/sbin/ && cd .. &&\
    cd hpsahba/contrib/dkms &&\
    export VERSION=$KERNEL_MAJOR_VERSION &&\
    ./patch.sh &&\
    cp *.h *.c /usr/src/linux/drivers/scsi/ &&\
    cd /usr/src/linux && make drivers/scsi/ 

RUN unset ARCH && cd /usr/src/linux && make -C /usr/src/linux M=drivers/scsi hpsa.ko

RUN xz /usr/src/linux/drivers/scsi/hpsa.ko && cp -av /usr/src/linux/drivers/scsi/hpsa.ko.xz /lib/modules/$KERNEL_VERSION/kernel/drivers/scsi/ &&\
    depmod $KERNEL_VERSION 
RUN ls -lh /lib/modules/$KERNEL_VERSION/kernel/drivers/scsi/hpsa.ko*
RUN rm -rf /usr/src/linux*

RUN rm -rf /usr/share/man
RUN rm -rf /usr/share/zfs
RUN rm -rf /usr/share/pibs
RUN rm -rf /usr/share/mime
RUN rm -rf /usr/share/mibs
RUN rm -rf /usr/share/X11
RUN rm -rf /usr/share/bash-completion
RUN rm -rf /usr/share/autoconf
RUN rm -rf /usr/share/automake-1.5
RUN rm -rf /usr/share/doc
RUN rm -rf /usr/share/emacs
RUN rm -rf /usr/share/fish
RUN rm -rf /usr/share/fontconfig
RUN rm -rf /usr/share/zoneinfo/right
RUN rm -rf /usr/share/zoneinfo/Asia
RUN rm -rf /usr/lib/sysimage/
RUN rm -rf /usr/lib/locale/zh_TW.euctw
RUN rm -rf /usr/lib/locale/wa_BE.utf8
RUN rm -rf /usr/lib/locale/wa_BE@euro
RUN rm -rf /usr/lib/locale/uz_UZ.utf8
RUN rm -rf /usr/lib/locale/uk_UA.utf8
RUN rm -rf /usr/lib/locale/tr_CY.utf8
RUN rm -rf /usr/lib/locale/tg_TJ.utf8
RUN rm -rf /usr/lib/locale/szl_PL
RUN rm -rf /usr/lib/locale/sq_AL.utf8
RUN rm -rf /usr/lib/locale/shs_CA
RUN rm -rf /usr/lib/locale/mr_IN
RUN rm -rf /usr/lib/locale/mt_MT.utf8
RUN rm -rf /usr/lib/locale/mi_NZ.utf8
RUN rm -rf /usr/lib/locale/lt_LT.utf8
RUN rm -rf /usr/lib/locale/kw_*
RUN rm -rf /usr/lib/locale/ja_*
RUN rm -rf /usr/lib/locale/fi_*
RUN rm -rf /usr/lib/locale/es_*
RUN rm -rf /usr/lib/locale/br_*

RUN rm -rf /usr/include

RUN zypper clean

ARG CACHEBUST
RUN luet install -y \
    toolchain/yip \
    toolchain/luet \
    utils/installer \
    system/cos-setup \
    system/immutable-rootfs \
    system/grub2-config \
    selinux/k3s \
    selinux/rancher \
    utils/k9s \
    utils/nerdctl \
    toolchain/yq

RUN echo "options hpsa hpsa_use_nvram_hba_flag=1" > /etc/modprobe.d/hpsa.conf
RUN echo "allow_unsupported_modules 1" > /etc/modprobe.d/10-unsupported-modules.conf


# Download rancherd binary to pin the version
RUN curl -o /usr/bin/rancherd -sfL "https://github.com/rancher/rancherd/releases/download/${RANCHERD_VERSION}/rancherd-amd64" && chmod 0755 /usr/bin/rancherd

# Create the folder for journald persistent data
RUN mkdir -p /var/log/journal

# Create necessary cloudconfig folders so that elemental cli won't show warnings during installation
RUN mkdir -p /usr/local/cloud-config
RUN mkdir -p /oem

COPY files/ /

RUN mkinitrd
# mkinitrd koristi perl
RUN rm -rf /usr/lib/perl5

RUN lsinitrd /boot/initrd-${KERNEL_VERSION} | grep hpsa.conf

COPY os-release /usr/lib/os-release
