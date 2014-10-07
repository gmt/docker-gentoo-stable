# gentoo-stable
#
# VERSION               0.0.1

FROM    danthedispatcher/gentoo-nomultilib
MAINTAINER Greg Turner "gmt@be-evil.net"

ENV PROV_LOCALE en_US.UTF-8 UTF-8
ENV PROV_EMERGE_JOBS 6

RUN emerge-webrsync

COPY prov.sh /tmp/prov.sh

# make.conf
RUN . /tmp/prov.sh && hack_up_make_conf

# locale
RUN . /tmp/prov.sh && prov_locale

# portage
RUN . /tmp/prov.sh && PROV_AUTOUNMASK=1 try_emerge sys-apps/portage --oneshot
RUN eselect news read

# kernel
RUN . /tmp/prov.sh && PROV_AUTOUNMASK=1 USE=symlink try_emerge sys-kernel/gentoo-sources --oneshot
COPY kernel.config /usr/src/linux/.config
RUN cd /usr/src/linux && { make oldconfig || { ls -la ; /bin/false ; } ; }
RUN cd /usr/src/linux && make prepare

# let some things fail in case kernel changes
RUN cd /usr/src/linux && make archprepare || /bin/true
RUN cd /usr/src/linux && make prepare0 || /bin/true
RUN cd /usr/src/linux && make prepare1 || /bin/true
RUN cd /usr/src/linux && make prepare2 || /bin/true
RUN cd /usr/src/linux && make prepare3 || /bin/true
RUN cd /usr/src/linux && make modules_prepare

# update world
RUN fixpackages
RUN . /tmp/prov.sh && PROV_AUTOUNMASK=1 try_emerge -DuN --keep-going=y '@world'

# portage utils
RUN . /tmp/prov.sh && try_emerge app-portage/{eix,gentoolkit,layman,mirrorselect,portage-utils}

# vim (somehow brings in conflicting deptree atoms without this)
RUN . /tmp/prov.sh try_emerge -DN --complete-graph --with-bdeps=y app-editors/vim
# but don't depclean nano either
RUN . /tmp/prov.sh try_emerge --noreplace app-editors/nano

# depclean / -e world scrub cycle
RUN . /tmp/prov.sh && try_emerge -DuN --with-bdeps=y --complete-graph --keep-going=y '@world'
RUN . /tmp/prov.sh && try_emerge -D --with-bdeps=y --complete-graph --depclean
RUN . /tmp/prov.sh && try_emerge -e '@world'

#cleanup
RUN rm -v /tmp/prov.sh
RUN rm -rvf /usr/portage/*
RUN rm -rvf /var/tmp/portage

# FIXME: change root password on run
# RUN echo "root:$(openssl rand -base64 32)" | chpasswd

WORKDIR /root
ENTRYPOINT ["/bin/bash", "-l"]
ONBUILD emerge-webrsync


