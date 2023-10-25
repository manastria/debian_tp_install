#!/usr/bin/env bash

apt install -y \
 aptitude \
 apt-file \
 bash-completion \
 build-essential \
 byobu \
 ccze \
 curl \
 command-not-found \
 exa \
 git \
 glances \
 gnupg2 \
 haveged \
 htop \
 less \
 linux-headers-$(uname -r) \
 lnav \
 locales-all \
 mlocate \
 most \
 multitail \
 reptyr \
 screen \
 screenfetch \
 sudo \
 tmux \
 tree \
 unzip \
 vim \
 yadm \
 zip \
 zsh


yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
yadm pull
yadm reset --hard origin/master
