# gentoo-stable
#
# VERSION               0.0.1

FROM    danthedispatcher/gentoo-nomultilib
MAINTAINER Greg Turner "gmt@be-evil.net"

RUN echo "root:$(openssl rand -base64 32)" | chpasswd
RUN emerge-webrsync
RUN emerge -1 sys-apps/portage
RUN eselect news read

ENV CONFIG_PROTECT_MASK /etc

RUN emerge sys-kernel/gentoo-sources
COPY kernel.config /usr/src/linux/.config

RUN cd /usr/src/linux && make oldconfig
RUN cd /usr/src/linux && make prepare archprepare prepare0 prepare1 prepare2 prepare3 modules_prepare

RUN ( echo && echo "MAKEOPTS=\"-j6\"" ) >> /etc/portage/make.conf
