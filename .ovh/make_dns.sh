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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../main.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../custom.sh"

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


pretty_print "Mise à jour des paquets" $fg_blue
apt_update

pretty_print "Installation des paquets" $fg_blue
declare -A packages
add_uniq_list packages bind9
add_uniq_list packages bind9-host
add_uniq_list packages dnsutils
checkpackage ${!packages[@]}


BACKUP_FILE=${HOME}/backup_dns_$(date '+%Y%m%d%H%M%S').tar
tar cf - /etc/bind > ${BACKUP_FILE}

rm -rf /etc/bind/*



cat > /etc/bind/named.conf <<"EOF"
acl goodclients {
    // 10.0.0.0/8;
    // 192.168.0.0/16;
    // 172.16.0.0/12;
    // 172.25.0.0/16;
    localhost;
    localnets;
};

options {
    directory "/var/cache/bind";

    dnssec-validation no;
    dnssec-enable no;

    recursion no;
    allow-recursion { none; };
    allow-query     { any; };

	// Interdit les transferts de zone par défaut (requetes AXFR)
	allow-transfer {"none";};

    listen-on-v6 { none; };

    // forwarders {
    //     192.168.1.1;
    //     172.16.0.1;
    //     172.25.99.3;
    //     172.25.99.6;
    // };
};

// zone "." {
//     type hint;
//     file "/usr/share/dns/root.hints";
// };

zone "demo.manastria.ovh" {
    type master;
    file "/etc/bind/db.demo.manastria.ovh";
};

zone "test.manastria.ovh" {
    type master;
    file "/etc/bind/db.test.manastria.ovh";
};
EOF


cat > /etc/bind/db.demo.manastria.ovh <<"EOF"
$TTL 5m
@       IN      SOA     ns1.demo.manastria.ovh. sysadmin.manastria.ovh. (
        2020010101       ; serial
        8H               ; refresh
        2H               ; retry
        1W               ; expire
        1D               ; ttl
        )

@       IN       NS     ns1.manastria.ovh.
        IN       NS     sdns2.ovh.ca.
        IN       A      127.0.0.10
ns1     IN       A      54.39.21.116
h1      IN       A      127.0.0.11

; vim: ft=bindzone ts=4 sw=4 sts=4 et :
EOF

cat > /etc/bind/db.test.manastria.ovh <<"EOF"
$TTL 5m
@       IN      SOA     ns1.demo.manastria.ovh. sysadmin.manastria.ovh. (
        2020010101       ; serial
        8H               ; refresh
        2H               ; retry
        1W               ; expire
        1D               ; ttl
        )

@       IN       NS     ns1.manastria.ovh.
        IN       NS     sdns2.ovh.ca.
        IN       A      127.0.0.10
ns1     IN       A      54.39.21.116
h1      IN       A      127.0.0.12

; vim: ft=bindzone ts=4 sw=4 sts=4 et :
EOF


rndc-confgen -a -A hmac-sha512 -b 512 -k rndc-key
chown bind:bind /etc/bind/rndc.key


named-checkconf /etc/bind/named.conf
named-checkzone demo.manastria.ovh /etc/bind/db.demo.manastria.ovh
named-checkzone test.manastria.ovh /etc/bind/db.test.manastria.ovh



# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
