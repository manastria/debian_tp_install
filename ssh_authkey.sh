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
EOF

read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
						 This is Bash3 Boilerplate's help text. Feel free to add any description of your
						 program or elaborate more on command-line arguments. This section is not
						 parsed and will be added as-is to the help.
EOF

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/main.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/custom.sh"

### Signal trapping and backtracing
##############################################################################

function __b3bp_cleanup_before_exit() {
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

function user_exist() {
    USER_TEST=$1

    getent passwd "${USER_TEST}" >/dev/null
    local _ret=$?
    return $_ret
}

function config_ssh() {
    HOME_PATH=$1
    USER=$2

    [ -d ${HOME_PATH} ] || script_exit "$LINENO:Répertoire inexistant : ${HOME_PATH} ! Interruption..." 2

    if ! user_exist ${USER}; then
        script_exit "$(printf 'The user %s does not exist\n' "${USER}")" 3
    fi

    ## Configure la clé SSH
    mkdir -p ${HOME_PATH}/.ssh
    touch ${HOME_PATH}/.ssh/authorized_keys
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== TP03" >>${HOME_PATH}/.ssh/authorized_keys
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDc+e2L7GFcoWgE2qhVpQmBq2jiCZtXj1vIpFG/+N7Yw TP04" >>${HOME_PATH}/.ssh/authorized_keys
    if [ -L ${HOME_PATH}/.ssh/authorized_keys -a -f ${HOME_PATH}/.ssh/authorized_keys2 ]; then rm ${HOME_PATH}/.ssh/authorized_keys && mv ${HOME_PATH}/.ssh/authorized_keys2 ${HOME_PATH}/.ssh/authorized_keys; fi
    if [ ! -e ${HOME_PATH}/.ssh/authorized_keys2 ]; then ln -s ${HOME_PATH}/.ssh/authorized_keys ${HOME_PATH}/.ssh/authorized_keys2; fi
    chmod -R 700 ${HOME_PATH}/.ssh
    chmod 0600 ${HOME_PATH}/.ssh/authorized_keys*

    cat /tmp/known_hosts >>${HOME_PATH}/.ssh/known_hosts
    sort -u -o ${HOME_PATH}/.ssh/known_hosts ${HOME_PATH}/.ssh/known_hosts
    sort -u -o ${HOME_PATH}/.ssh/authorized_keys ${HOME_PATH}/.ssh/authorized_keys
}

rm -rf /tmp/known_hosts
ssh-keyscan -H github.com >>/tmp/known_hosts
ssh-keyscan -H bitbucket.org >>/tmp/known_hosts

config_ssh /root root
config_ssh /home/sysadmin sysadmin
