#!/usr/bin/bash

./apt.sh
./baseV10.sh
./install_tp.sh
./install_virt.sh
./install_eth0.sh
#./install_network-manager.sh
./make_rclocal.sh
./install_issue.sh
./ssh_authkey.sh
tar -x -C / -f ndg_unhatched.tar.bz2
chown -R sysadmin:sysadmin /home/sysadmin
./install_bashtop.sh
./install_goto.sh
./install_bat.sh
