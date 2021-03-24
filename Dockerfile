FROM centos:8 AS builder

ARG KVER

RUN dnf update -y && dnf makecache \  
#  && dnf group install "Development Tools" -y \
  && dnf install -y wget \
  && wget "http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/kernel-headers-$KVER.rpm" \
  && yum -y localinstall "kernel-headers-$KVER.rpm" \
  && wget "http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/kernel-devel-$KVER.rpm" \
  && yum -y localinstall "kernel-devel-$KVER.rpm" \
  && dnf install gcc make rpm-build -y \
  && dnf install -y elfutils-libelf-devel module-init-tools 

FROM builder AS compiler

WORKDIR /build/

ARG KMODVER=1.3.2
ARG KVER

RUN wget "https://sourceforge.net/projects/e1000/files/ice%20stable/$KMODVER/ice-$KMODVER.tar.gz" \
  && rpmbuild --define "_topdir `pwd`" -tb ice-$KMODVER.tar.gz 

FROM centos:8 AS runtime

WORKDIR /build/

ARG KMODVER=1.3.2
ARG KVER

LABEL io.k8s.display-name="ice driver $KMODVER" \
  io.k8s.description="Container to install version $KMODVER of the Intel ice driver"

RUN mkdir -p $builddir

COPY --from=compiler ./RPMS/x86_64/ice-$KMODVER-1.x86_64.rpm $builddir

RUN dnf makecache \
  && dnf install -y wget \
  && wget "http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/kernel-headers-$KVER.rpm" \
  && yum localinstall -y "kernel-headers-$KVER.rpm" \
  && wget "http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/kernel-core-$KVER.rpm" \
  && yum localinstall -y "kernel-core-$KVER.rpm" \
  && dnf install -y $builddir/ice-$KMODVER-1.x86_64.rpm \
  && dnf clean all

ADD load-kmod.sh /usr/local/bin
RUN chmod +x /usr/local/bin/load-kmod.sh
