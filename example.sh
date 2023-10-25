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
  -f --file  [arg] Filename to process. Required.
  -t --temp  [arg] Location of tempfile. Default="/tmp/bar"
  -v               Enable verbose mode, print script as it is executed
  -d --debug       Enables debug mode
  -h --help        This page
  -n --no-color    Disable color output
  -1 --one         Do just one thing
  -i --input [arg] File to process. Can be repeated.
  -x               Specify a flag. Can be repeated.
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

[[ "${arg_f:-}" ]]     || help      "Setting a filename with -f or --file is required"
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

info "__i_am_main_script: ${__i_am_main_script}"
info "__file: ${__file}"
info "__dir: ${__dir}"
info "__base: ${__base}"
info "OSTYPE: ${OSTYPE}"

info "arg_f: ${arg_f}"
info "arg_d: ${arg_d}"
info "arg_v: ${arg_v}"
info "arg_h: ${arg_h}"
if [[ -n "${arg_i:-}" ]]; then
  info "arg_i: ${#arg_i[@]}"
  for input_file in "${arg_i[@]}"; do
    info " - ${input_file}"
  done
else
  info "arg_i: 0"
fi
[[ -n "${arg_x:-}" ]] && info "arg_x: ${#arg_x[@]}" || info "arg_x: 0"

info "$(echo -e "multiple lines example - line #1\\nmultiple lines example - line #2\\nimagine logging the output of 'ls -al /path/'")"

# All of these go to STDERR, so you can use STDOUT for piping machine readable information to other software
debug "Info useful to developers for debugging the application, not useful during operations."
info "Normal operational messages - may be harvested for reporting, measuring throughput, etc. - no action required."
notice "Events that are unusual but not error conditions - might be summarized in an email to developers or admins to spot potential problems - no immediate action required."
warning "Warning messages, not an error, but indication that an error will occur if action is not taken, e.g. file system 85% full - each item must be resolved within a given time. This is a debug message"
error "Non-urgent failures, these should be relayed to developers or admins; each item must be resolved within a given time."
critical "Should be corrected immediately, but indicates failure in a primary system, an example is a loss of a backup ISP connection."
alert "Should be corrected immediately, therefore notify staff who can fix the problem. An example would be the loss of a primary ISP connection."
# emergency "A \"panic\" condition usually affecting multiple apps/servers/sites. At this level it would usually notify all tech staff on call."


pretty_print "rrrr" $fg_blue 0
pretty_print "zzzz" $fg_red

mytest true
mytest false



step "Installing XFS filesystem tools:"
try true
next

step "Configuring udev:"
try true
try false
next

step "Adding rc.postsysinit hook:"
try false
next

pretty_print "aaaa" $fg_red





# checkdeps tetezrt


declare -A b

# a=(aa ac aa ad "ac ad")
# for i in "${a[@]}"; do b["$i"]=1; done


add_uniq_list b toto
add_uniq_list b titi
add_uniq_list b titi
add_uniq_list b titi tata
add_uniq_list b bind9
add_uniq_list b byobu


printf '%s\n' "${!b[@]}"

echo "Pack : " ${!b[@]}



checkpackage ${!b[@]}
