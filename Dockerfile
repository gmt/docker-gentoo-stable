# gentoo-stable
#
# VERSION               0.0.1

FROM    danthedispatcher/gentoo-nomultilib
MAINTAINER Greg Turner "gmt@be-evil.net"

RUN echo "root:$(openssl rand -base64 32)" | chpasswd
RUN emerge-webrsync
RUN emerge -1 sys-apps/portage

