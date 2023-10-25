#!/usr/bin/bash

__prompt_command() {
    local EXIT="$?"             # This needs to be first
    PS1=""

    local RESTORE='\033[0m'
    
    local BLACK='\033[00;30m'
    local RED='\033[00;31m'
    local GREEN='\033[00;32m'
    local YELLOW='\033[00;33m'
    local BLUE='\033[00;34m'
    local PURPLE='\033[00;35m'
    local CYAN='\033[00;36m'
    local LIGHTGRAY='\033[00;37m'
    
    local LRED='\033[01;31m'
    local LGREEN='\033[01;32m'
    local LYELLOW='\033[01;33m'
    local LBLUE='\033[01;34m'
    local LPURPLE='\033[01;35m'
    local LCYAN='\033[01;36m'
    local WHITE='\033[01;37m'

    if [ $EXIT != 0 ]; then
        PS1+="${RED}\u${RESTORE}"      # Add red if exit code non 0
    else
        PS1+="${GREEN}\u${RESTORE}"
    fi

    PS1+="${BLACK}@${BLUE}\h ${PURPLE}\W${BLACK}\\$ ${BLACK}"
}

cp ~/debian_tp_install/ls_color/dircolors.gruvbox ~/.dircolors
eval "$(dircolors ~/.dircolors)"
