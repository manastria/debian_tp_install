#!/bin/bash

apt -y install libgnutls-dev bzip2 make gettext texinfo gnutls-bin libgnutls28-dev build-essential libbz2-dev zlib1g-dev libncurses5-dev libsqlite3-dev libldap2-dev || apt-get -y install libgnutls28-dev bzip2 make gettext texinfo gnutls-bin build-essential libbz2-dev zlib1g-dev libncurses5-dev libsqlite3-dev libldap2-dev  && \


gpg2 --list-keys && \
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 249B39D24F25E3B6 && \
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 04376F3EE0856959 && \
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2071B08A33BD3F06 && \
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8A861B1C7EFD60D9 && \


mkdir -p /var/src/gnupg22 && cd /var/src/gnupg22
file=gnupg-2.2.17.tar.bz2      && url=https://www.gnupg.org/ftp/gcrypt/gnupg        && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=npth-1.6.tar.bz2          && url=https://www.gnupg.org/ftp/gcrypt/npth         && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=libgpg-error-1.36.tar.bz2 && url=https://www.gnupg.org/ftp/gcrypt/libgpg-error && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=libgcrypt-1.8.4.tar.bz2   && url=https://www.gnupg.org/ftp/gcrypt/libgcrypt    && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=libassuan-2.5.3.tar.bz2   && url=https://www.gnupg.org/ftp/gcrypt/libassuan    && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=libksba-1.3.5.tar.bz2     && url=https://www.gnupg.org/ftp/gcrypt/libksba      && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \
file=pinentry-1.1.0.tar.bz2    && url=https://www.gnupg.org/ftp/gcrypt/pinentry     && wget -c $url/$file && wget -c $url/$file.sig && gpg --verify $file.sig && tar -xjf $file && \






cd libgpg-error-1.36/ && ./configure && make && make install && cd ../ && \
cd libgcrypt-1.8.4 && ./configure && make && make install && cd ../ && \
cd libassuan-2.5.3 && ./configure && make && make install && cd ../ && \
cd libksba-1.3.5 && ./configure && make && make install && cd ../ && \
cd npth-1.6 && ./configure && make && make install && cd ../ && \
cd pinentry-1.1.0 && ./configure --enable-pinentry-curses --disable-pinentry-qt4 && make && make install && cd ../ && \
cd gnupg-2.2.17 && ./configure && make && make install && \
echo "/usr/local/lib" > /etc/ld.so.conf.d/gpg2.conf && ldconfig -v && \
echo "Complete!!!"

