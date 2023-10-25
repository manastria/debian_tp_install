#!/usr/bin/env bash
# This file:
#
#  - Demos BASH3 Boilerplate (change this for your script)
#
# Usage:
#
#  LOG_LEVEL=7 ./example.sh -f /tmp/x -d (change this for your script)
#
# Based on a template by BASH3 Boilerplate v2.3.0
# http://bash3boilerplate.sh/#authors
#
# The MIT License (MIT)
# Copyright (c) 2013 Kevin van Zonneveld and contributors
# You are not obligated to bundle the LICENSE file with your b3bp projects as long
# as you leave these references intact in the header comments of your source files.


### BASH3 Boilerplate (b3bp) Header
##############################################################################

# Commandline options. This defines the usage page, and is used to parse cli
# opts & defaults from. The parsing is unforgiving so be precise in your syntax
# - A short option must be preset for every long option; but every short option
#   need not have a long option
# - `--` is respected as the separator between options and arguments
# - We do not bash-expand defaults, so setting '~/app' as a default will not resolve to ${HOME}.
#   you can use bash variables to work around this (so use ${HOME} instead)

read -r -d '' __usage <<-'EOF' || true # exits non-zero when EOF encountered
  -v               Enable verbose mode, print script as it is executed
  -d --debug       Enables debug mode
  -h --help        This page
  -n --no-color    Disable color output
  -g --git   [arg] Active le proxy pour Git (true/false)
  -z --gnome [arg] Active le proxy pour Gnome (true/false)
  -p --apt   [arg] Active le proxy pour APT (true/false)
  -e --env   [arg] Active le proxy pour env (true/false)
  -a --all   [arg] Active le proxy pour tout (true/false)
EOF

# (true pour activer, false pour désactiver)

read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
 Ceci est l'aide pour l'activation du proxy pour le réseau SIO.
 ...
EOF

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/custom.sh"

LOG_LEVEL="0"


### Signal trapping and backtracing
##############################################################################

function __b3bp_cleanup_before_exit () {
  info "Cleaning up. Done"
}
trap __b3bp_cleanup_before_exit EXIT

# requires `set -o errtrace`
__b3bp_err_report() {
    local error_code=${?}
    error "Error in ${__file} in function ${1} on line ${2}"
    exit ${error_code}
}
# Uncomment the following line for always providing an error backtrace
# trap '__b3bp_err_report "${FUNCNAME:-.}" ${LINENO}' ERR


### Command-line argument switches (like -d for debugmode, -h for showing helppage)
##############################################################################

# debug mode
if [[ "${arg_d:?}" = "1" ]]; then
  set -o xtrace
  PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  LOG_LEVEL="7"
  # Enable error backtracing
  trap '__b3bp_err_report "${FUNCNAME:-.}" ${LINENO}' ERR
fi

# verbose mode
if [[ "${arg_v:?}" = "1" ]]; then
  set -o verbose
fi

# no color mode
if [[ "${arg_n:?}" = "1" ]]; then
  NO_COLOR="true"
fi

# help mode
if [[ "${arg_h:?}" = "1" ]]; then
  # Help exists with code 1
  help "Help using ${0}"
fi


### Validation. Error out if the things required for your script are not present
##############################################################################

[[ "${arg_g:-}" || "${arg_z:-}" || "${arg_p:-}" || "${arg_e:-}" || "${arg_a:-}" ]] || help
[[ "${LOG_LEVEL:-}" ]] || emergency "Cannot continue without LOG_LEVEL. "


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
  script_init
  #cron_init
  colour_init
  #lock_init system
}



### Runtime
##############################################################################

main "$@"


# Ne pas quitter en cas d'erreurs
set +o errexit
set +o errtrace



##############################################################################
#
#            Début du script
#
##############################################################################


_DOMAIN="172.16.0.1"
_PORT=3128
_IGNORE_PROXY="'*.ssn.net'"
_ENV_FILE_PATH="/etc/bashrc"
_APT_FILE_PATH="/etc/apt/apt.conf.d/30proxy"

_MODE_MANUAL="manual"
_MODE_NONE="none"

_APT_CONF_DATA=$(cat <<EOF
Acquire::http::proxy  "http://$_DOMAIN:$_PORT/";
Acquire::https::proxy "https://$_DOMAIN:$_PORT/";
Acquire::ftp::proxy   "ftp://$_DOMAIN:$_PORT/";
Acquire::socks::proxy "socks://$_DOMAIN:$_PORT/";

EOF
)

_ENV_CONF_DATA=$(cat <<EOF
http_proxy="http://$_DOMAIN:$_PORT/"
https_proxy="https://$_DOMAIN:$_PORT/"
ftp_proxy="ftp://$_DOMAIN:$_PORT/"
socks_proxy="socks://$_DOMAIN:$_PORT/"

EOF
)

#
# GIT
################################################################################

set_git_proxy() {
  step "Activer le proxy pour Git"
	try git config --global http.proxy $_DOMAIN:$_PORT
	try git config --global https.proxy $_DOMAIN:$_PORT
	next
}

unset_git_proxy () {
  step "Désactiver le proxy pour Git"
	try git config --global --unset http.proxy
	try git config --global --unset https.proxy
	next
}



#
# Gnome
################################################################################
set_gnome_proxy () {
  check_binary gsettings 1
  step "Activer le proxy pour Gnome"
	try gsettings set org.gnome.system.proxy mode $_MODE_MANUAL
	try gsettings set org.gnome.system.proxy.http host $_DOMAIN
	try gsettings set org.gnome.system.proxy.http port $_PORT
	try gsettings set org.gnome.system.proxy.https host $_DOMAIN
	try gsettings set org.gnome.system.proxy.https port $_PORT
	try gsettings set org.gnome.system.proxy.ftp host $_DOMAIN
	try gsettings set org.gnome.system.proxy.ftp port $_PORT
	try gsettings set org.gnome.system.proxy.socks host $_DOMAIN
	try gsettings set org.gnome.system.proxy.socks port $_PORT
	try gsettings set org.gnome.system.proxy ignore-hosts "['localhost', '127.0.0.0/8', '10.0.0.0/8', '192.168.0.0/16', '172.16.0.0/12',  $_IGNORE_PROXY ]"
  next
}

unset_gnome_proxy () {
  check_binary gsettings 1
  step "Désactiver le proxy pour Gnome"
	try gsettings set org.gnome.system.proxy mode $_MODE_NONE
  next
}


#
# APT
################################################################################
remove_apt_proxy () {
  #awk 'BEGIN{IGNORECASE = 1}!/^Acquire::\w+::proxy/' $_APT_FILE_PATH > temp && chmod 0644 temp && mv -f temp $_APT_FILE_PATH
  sed -r -i -e '\|^[[:blank:]]*Acquire::\w+::proxy|d' $_APT_FILE_PATH
}

unset_apt_proxy () {
  step "Désactiver le proxy pour APT"
	try remove_apt_proxy
  next
}

set_apt_proxy () {
  step "Activer le proxy pour APT"
  try touch ${_APT_FILE_PATH}
	try remove_apt_proxy
	try printf "$_APT_CONF_DATA\n" | cat >> $_APT_FILE_PATH
  next
}




#
# Environment proxy settings
################################################################################
remove_env_proxy () {
  #awk '!/^\w+_proxy/' $_ENV_FILE_PATH > temp && chmod 0644 temp && sudo mv -f temp $_ENV_FILE_PATH
  if [[ -r $_ENV_FILE_PATH ]]; then
    sed -r -i -e '\|^[[:blank:]]*\w+_proxy[[:blank:]]*=|d' $_ENV_FILE_PATH
  else
    return 2
  fi
}

unset_env_proxy () {
  step "Désactiver le proxy pour les variables d'environment"
	try remove_env_proxy
  next
}

set_env_proxy () {
  step "Activer le proxy pour les variables d'environment"
  try touch ${_APT_FILE_PATH}
	try remove_env_proxy
	try printf "$_ENV_CONF_DATA\n" | cat >> $_ENV_FILE_PATH
  printf "\n"
  try pretty_print "Vous devez vous reconnecter pour que les modifications prennent effet."
  next
}



###### All proxies ######
proxy_stat () {

	echo "STATUS:\n-----------\n***** System proxy ******\n"
	env | grep -i "_proxy"
	echo "\n***** Git proxy ******\n[http]"
	git config --global --get http.proxy
	echo "[https]"
	git config --global --get https.proxy

}

if [[ "${arg_g:-}" ]]; then
  if [[ "${arg_g:?}" = "true" ]]; then
    ## Active GIT
    set_git_proxy
  fi

  if [[ "${arg_g:?}" = "false" ]]; then
    ## Désactive GIT
    unset_git_proxy
  fi
fi


if [[ "${arg_z:-}" ]]; then
  if [[ "${arg_z:?}" = "true" ]]; then
    ## Active Gnome
    set_gnome_proxy
  fi

  if [[ "${arg_z:?}" = "false" ]]; then
    ## Désactive Gnome
    unset_gnome_proxy
  fi
fi

if [[ "${arg_p:-}" ]]; then
  if [[ "${arg_p:?}" = "true" ]]; then
    ## Active APT
    set_apt_proxy
  fi

  if [[ "${arg_p:?}" = "false" ]]; then
    ## Désactive APT
    unset_apt_proxy
  fi
fi

if [[ "${arg_e:-}" ]]; then
  if [[ "${arg_e:?}" = "true" ]]; then
    ## Active Environnement
    set_env_proxy
  fi

  if [[ "${arg_e:?}" = "false" ]]; then
    ## Désactive Environnement
    unset_env_proxy
  fi
fi

if [[ "${arg_a:-}" ]]; then
  if [[ "${arg_a:?}" = "true" ]]; then
    ## Active Tout
    set_git_proxy
    set_apt_proxy
    set_env_proxy
    if check_binary gsettings; then
      set_gnome_proxy
    fi
  fi

  if [[ "${arg_a:?}" = "false" ]]; then
    ## Désactive Tout
    unset_git_proxy
    unset_apt_proxy
    unset_env_proxy
    if check_binary gsettings; then
      unset_gnome_proxy
    fi
  fi
fi
