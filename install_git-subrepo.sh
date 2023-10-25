#!/usr/bin/env bash

INSTALL_DIR=${HOME}/git-subrepo
SCRIPT_DIR=${HOME}/.shellrc/rc.d/git-subrepo.sh


#git clone https://github.com/ingydotnet/git-subrepo ${INSTALL_DIR}
cp -a git-subrepo/ ${INSTALL_DIR}
echo "source ${INSTALL_DIR}/.rc" > ${SCRIPT_DIR}

