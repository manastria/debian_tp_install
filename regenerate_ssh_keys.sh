#!/usr/bin/env sh

rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

