# gentoo-stable
#
# VERSION               0.0.1

FROM    aegypius/gentoo:latest
MAINTAINER Greg Turner "gmt@be-evil.net"

RUN mkdir -p /usr/portage/metadata
RUN echo "masters = gentoo" > /usr/portage/metadata/layout.conf
RUN chown -Rc portage:portage /usr/portage

# Setup the (virtually) current runlevel
RUN echo "default" > /run/openrc/softlevel

# Setup the rc_sys
RUN sed -e 's/#rc_sys=""/rc_sys="lxc"/g' -i /etc/rc.conf

# Setup the net.lo runlevel
RUN ln -s /etc/init.d/net.lo /run/openrc/started/net.lo

# Setup the net.eth0 runlevel
RUN ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
RUN ln -s /etc/init.d/net.eth0 /run/openrc/started/net.eth0

# By default, UTC system
RUN echo 'UTC' > /etc/timezone

RUN emerge-webrsync

# portage
RUN emerge --nospinner sys-apps/portage --oneshot
RUN eselect news read

# kernel
RUN USE=symlink emerge --nospinner sys-kernel/gentoo-sources
COPY kernel.config /usr/src/linux/.config
RUN cd /usr/src/linux && { make olddefconfig || { ls -la ; /bin/false ; } ; }
RUN cd /usr/src/linux && make prepare

# let some things fail in case kernel changes
RUN cd /usr/src/linux && make archprepare || /bin/true
RUN cd /usr/src/linux && make prepare0 || /bin/true
RUN cd /usr/src/linux && make prepare1 || /bin/true
RUN cd /usr/src/linux && make prepare2 || /bin/true
RUN cd /usr/src/linux && make prepare3 || /bin/true
RUN cd /usr/src/linux && make modules_prepare

COPY prov.sh /tmp/prov.sh

# make.conf
ENV PROV_EMERGE_PARALLELISM 1
RUN . /tmp/prov.sh && hack_up_make_conf

# locale
ENV PROV_LOCALE en_US.UTF-8 UTF-8
RUN . /tmp/prov.sh && prov_locale

# update world
RUN fixpackages
RUN . /tmp/prov.sh && PROV_AUTOUNMASK=1 try_emerge -DuN --keep-going=y '@world'

# portage utils
RUN . /tmp/prov.sh && try_emerge app-portage/{eix,gentoolkit,layman,mirrorselect,portage-utils}

# vim (somehow brings in conflicting deptree atoms without this)
RUN . /tmp/prov.sh && try_emerge -DN --complete-graph --with-bdeps=y app-editors/vim
# but don't depclean nano either
RUN . /tmp/prov.sh && try_emerge --noreplace app-editors/nano

# depclean / -e world scrub/rinse cycle
RUN . /tmp/prov.sh && try_emerge -DuN --with-bdeps=y --complete-graph --keep-going=y '@world'
RUN . /tmp/prov.sh && try_emerge -D --with-bdeps=y --complete-graph --depclean
RUN . /tmp/prov.sh && try_emerge -e '@world'

#cleanup
RUN emerge -C sys-kernel/gentoo-sources --deselect=n
RUN rm -f /tmp/prov.sh
RUN rm -rf /usr/portage/*
RUN rm -rf /var/tmp/portage
RUN rm -rf /tmp/*
RUN rm -rf /var/log/*
RUN rm -rf /usr/portage_distfiles/* $(ls -da /usr/portage/distfiles/.* 2>/dev/null |tail -n +3)
RUN rm -rf /usr/portage_packages $(ls -da /usr/portage/packages/.* 2>/dev/null | tail -n +3)

WORKDIR /root
ENTRYPOINT ["/bin/bash", "-l"]

VOLUME /usr/portage

# Used when this image is the base of another
#
# Setup the portage directory and permissions
ONBUILD RUN [[ -f /usr/portage/profiles/repo_name ]] || { mkdir -p /usr/portage/metadata && echo "masters = gentoo" > /usr/portage/metadata/layout.conf && chown -R portage:portage /usr/portage && emerge-webrsync && env-update; }
