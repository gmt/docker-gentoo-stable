# gentoo-stable
#
# VERSION               0.0.1

FROM    aegypius/gentoo:latest
MAINTAINER Greg Turner "gmt@be-evil.net"

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
ENV PROV_EMERGE_JOBS 1
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
RUN rm -v /tmp/prov.sh
RUN rm -rvf /usr/portage/*
RUN rm -rvf /var/tmp/portage
RUN rm -rvf /tmp/*
RUN rm -rvf /var/log/*
RUN echo
RUN echo remaining stuff:
RUN echo ================
RUN find /

# FIXME: change root password on run
# RUN echo "root:$(openssl rand -base64 32)" | chpasswd

WORKDIR /root
ENTRYPOINT ["/bin/bash", "-l"]

VOLUME /usr/portage
ONBUILD RUN cat /proc/mounts && echo "maybe emerge-webrsync?"

