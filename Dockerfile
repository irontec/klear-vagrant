FROM debian:jessie

MAINTAINER lfgarcia@irontec.com

ARG uid=1000

RUN rm /bin/sh && ln -s /bin/bash /bin/sh
RUN apt-get update
RUN apt-get upgrade --yes --force-yes
RUN apt-get install apt-utils --yes
RUN apt-get install sysvinit systemd- --yes
RUN apt-get install less sudo screen python curl openssh-server wget vim --yes --force-yes

RUN echo 'root:vagrant' | chpasswd

RUN mkdir /home/vagrant
RUN groupadd -r vagrant -g $uid && \
useradd -u $uid -r -g vagrant -d /home/vagrant -s /bin/bash -c "Docker image user" vagrant && \
chown -R vagrant:vagrant /home/vagrant && \
echo "vagrant:vagrant" | chpasswd && \
adduser vagrant sudo && \
echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant

RUN cp /etc/skel/.bash* /home/vagrant/
RUN cp /etc/skel/.profile /home/vagrant/

RUN echo "" >> /home/vagrant/.bashrc && \
echo "alias l='ls $LS_OPTIONS -l'" >> /home/vagrant/.bashrc && \
echo "alias ll='ls $LS_OPTIONS -lA'" >> /home/vagrant/.bashrc

RUN echo "" >> /root/.bashrc && \
echo "export LS_OPTIONS='--color=auto'" >> /root/.bashrc && \
echo 'eval "`dircolors`"'  >> /root/.bashrc && \
echo "alias l='ls $LS_OPTIONS -l'" >> /root/.bashrc && \
echo "alias ll='ls $LS_OPTIONS -lA'" >> /root/.bashrc

CMD [“/sbin/init”]

