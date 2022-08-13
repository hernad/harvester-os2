FROM registry.opensuse.org/isv/rancher/harvester/baseos/main/baseos:latest AS base

COPY files/etc/luet/luet.yaml /etc/luet/luet.yaml

ARG ARCH=amd64
ENV ARCH=${ARCH}

RUN zypper ar http://download.opensuse.org/distribution/leap/15.3/repo/oss/ oss
RUN zypper ar http://download.opensuse.org/update/leap/15.3/oss/ oss-update
RUN zypper ar http://download.opensuse.org/update/leap/15.3/sle/ sle-update



#RUN zypper lr -d
#RUN zypper mr --disable repo-non-oss repo-update-non-oss
RUN zypper --no-gpg-checks ref
RUN zypper update -y

RUN zypper in -y  dracut \
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

#RUN zypper --no-gpg-checks ref
RUN zypper addrepo https://download.opensuse.org/repositories/filesystems/15.3/filesystems.repo
RUN zypper --gpg-auto-import-keys refresh
RUN zypper install -y zfs zfs-kmp-default


# rancher:/ # zypper wp /lib/modules/5.3.18-150300.59.76-default/kernel/drivers/scsi/hpsa.ko.xz
# kernel-default | The Standard Kernel | package

# custom kernel
ENV KERNEL_MAJOR_VERSION=5.3
ENV KERNEL_VERSION=5.3.18-150300.59.87-default
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
RUN rm -rf /usr/share/info
RUN rm -rf /usr/lib/sysimage/

#RUN rm -rf /usr/lib/locale/zh_TW.euctw
#RUN rm -rf /usr/lib/locale/wa_BE.utf8
#RUN rm -rf /usr/lib/locale/wa_BE@euro
#RUN rm -rf /usr/lib/locale/uz_UZ.utf8
#RUN rm -rf /usr/lib/locale/uk_UA.utf8
#RUN rm -rf /usr/lib/locale/tr_CY.utf8
#RUN rm -rf /usr/lib/locale/tg_TJ.utf8
#RUN rm -rf /usr/lib/locale/szl_PL
#RUN rm -rf /usr/lib/locale/sq_AL.utf8
#RUN rm -rf /usr/lib/locale/shs_CA
#RUN rm -rf /usr/lib/locale/mr_IN
#RUN rm -rf /usr/lib/locale/mt_MT.utf8
#RUN rm -rf /usr/lib/locale/mi_NZ.utf8
#RUN rm -rf /usr/lib/locale/lt_LT.utf8
#RUN rm -rf /usr/lib/locale/kw_*
#RUN rm -rf /usr/lib/locale/ja_*
#RUN rm -rf /usr/lib/locale/fi_*
#RUN rm -rf /usr/lib/locale/es_*
#RUN rm -rf /usr/lib/locale/br_*
RUN mkdir /tmp/locale ; mv /usr/lib/locale/en_US* /tmp/locale/ ;  rm -rf /usr/lib/locale/* ; mv /tmp/locale/* /usr/lib/locale/

RUN rm -rf /usr/include
RUN zypper clean

RUN echo "options hpsa hpsa_use_nvram_hba_flag=1" > /etc/modprobe.d/hpsa.conf
RUN echo "allow_unsupported_modules 1" > /etc/modprobe.d/10-unsupported-modules.conf



# Necessary for luet to run
RUN mkdir -p /run/lock

ARG CACHEBUST
RUN luet install -y \
    toolchain/yip \
    system/cos-setup \
    system/immutable-rootfs \
    system/grub2-config \
    selinux/k3s \
    selinux/rancher \
    utils/nerdctl \
    toolchain/yq

# Create the folder for journald persistent data
RUN mkdir -p /var/log/journal

# Create necessary cloudconfig folders so that elemental cli won't show warnings during installation
RUN mkdir -p /usr/local/cloud-config
RUN mkdir -p /oem

COPY files/ /

# cos-immutable-rootfs - add dracut zfs dependency
# cos dependencies are: rootfs-block, dm, zfs
RUN sed -i 's/echo rootfs-block dm/echo rootfs-block dm zfs/g' /usr/lib/dracut/modules.d/30cos-immutable-rootfs/module-setup.sh

RUN mkinitrd

RUN lsinitrd /boot/initrd-${KERNEL_VERSION} | grep hpsa.conf
 

# Append more options
COPY os-release /tmp
RUN cat /tmp/os-release >> /usr/lib/os-release && rm -f /tmp/os-release

# Remove /etc/cos/config to use default values
RUN rm -f /etc/cos/config

# Download rancherd
ARG RANCHERD_VERSION=v0.0.1-alpha13-harvester1
RUN curl -o /usr/bin/rancherd -sfL "https://github.com/harvester/rancherd/releases/download/${RANCHERD_VERSION}/rancherd-amd64" && chmod 0755 /usr/bin/rancherd
