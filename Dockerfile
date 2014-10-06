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
RUN ( echo && echo "CFLAGS=\"\${CFLAGS} -mtune=core2\"" && echo "CXXFLAGS=\"\${CXXFLAGS} -mtune=core2\"" ) >> /etc/portage/make.conf
RUN ( echo && echo "USE=\"\${USE} vim-syntax\"" && echo "USE=\"\${USE} bash-completion\"" ) >> /etc/portage/make.conf
RUN ( echo && echo "EMERGE_DEFAULT_OPTS=\"\${EMERGE_DEFAULT_OPTS} --verbose\"" \
	&& echo "FEATURES=\"\${FEATURES} unmerge-orphans\"" \
	&& echo "FEATURES=\"\${FEATURES} parallel-fetch\"" \
	&& echo "FEATURES=\"\${FEATURES} sandbox\"" \
	&& echo "FEATURES=\"\${FEATURES} usersandbox\"" \
	&& echo "FEATURES=\"\${FEATURES} userpriv\"" \
	&& echo "FEATURES=\"\${FEATURES} ipc-sandbox\"" \
	&& echo "FEATURES=\"\${FEATURES} network-sandbox\"" \
	&& echo "FEATURES=\"\${FEATURES} usersync\"" \
	&& echo "FEATURES=\"\${FEATURES} userfetch\"" ) >> /etc/portage/make.conf
RUN ( echo && echo "LINGUAS=\"\"" && echo && echo "INPUT_DEVICES=\"evdev\"" ) >> /etc/portage/make.conf
RUN mkdir /usr/portage_distfiles
RUN mkdir /usr/portage_packages
RUN ( echo && echo "DISTDIR=\"/usr/portage_distfiles\"" && echo "PKGDIR=\"/usr/portage_packages\"" ) >> /etc/portage/make.conf
RUN ( echo && echo "RUBY_TARGETS=\"ruby19\"" \
	&& echo "PYTHON_TARGETS=\"python2_7 python3_3\"" \
	&& echo "PYTHON_SINGLE_TARGET=\"python2_7\"" && echo ) >> /etc/portage/make.conf

RUN cat /etc/portage/make.conf
