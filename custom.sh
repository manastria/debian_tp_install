### Ajouts de fonction tierces
##############################################################################


# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}


# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}


# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
# shellcheck disable=SC2034
function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}


# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty
# shellcheck disable=SC2034
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        readonly script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        exec 3>&1 4>&2 1> "$script_output" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 1
    fi
}

# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}

# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_print() function
# OUTS: None
function verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
            *)
                new_path="$new_path:$path_entry"
                ;;
        esac
        temp_path="${temp_path#*:}"
    done

    build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            verbose_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                    "${fg_red-}"
            else
                local test_euid
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function add_uniq_list() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to add_uniq_list()!' 2
    fi

    # make NAME a reference to the variable named by its value
    declare -n llist="$1"

    # local new_path path_entry temp_path

    if [[ -n ${2-} ]]; then
        llist+=([$2]=1)
    fi

    # deduplicate
    #for i in "${llist[@]}"; do tlist["$i"]=1; done

}


iscmd() {
    command -v >&- "$@"
}

checkdeps() {
    local -i not_found=0

    for cmd; do
        iscmd "$cmd" || {
            pretty_print "$cmd is not found" $fg_red
            let not_found++
        }
    done
    (( not_found == 0 )) || {
        script_exit $"Install dependencies listed above to use $__base" 2
    }
}


checkpackage() {
  local -i not_found=0
  ppackages=()

  for pck; do
    if dpkg -s ${pck} &> /dev/null
    then
      pretty_print "${pck} installé" $fg_green
    else
      pretty_print "${pck} manquant" $fg_red
      ppackages+=(${pck})
      let not_found++
    fi
  done

  if (( not_found == 0 ))
  then
    pretty_print "Pas de paquet à installer" $fg_blue
  else
    p="${ppackages[@]}"
    pretty_print "Paquet à installer : ${p}" $fg_blue
    aptitude install -y ${p}
  fi

}



function mytest {
    "$@"
    local status=$?
    if (( status != 0 )); then
        echo "error with $1" >&2
    fi
    return $status
}

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }
asuser() { sudo su - "$1" -c "${*:2}"; }










##################################################################################################
# Get a sane screen width
[ -z "${COLUMNS:-}" ] && COLUMNS=80
LOG_STEPS=""


# Read in our configuration
if [ -z "${BOOTUP:-}" ]; then
  if [ -f /etc/sysconfig/init ]; then
      . /etc/sysconfig/init
  else
    # This all seem confusing? Look in /etc/sysconfig/init,
    # or in /usr/doc/initscripts-*/sysconfig.txt
    BOOTUP=color
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \\033[0;39m"
    LOGLEVEL=1
  fi
fi

if [ "${BOOTUP:-}" != "verbose" ]; then
   INITLOG_ARGS="-q"
else
   INITLOG_ARGS=
fi

echo_success() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_SUCCESS
  echo -n $"  OK  "
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 0
}

echo_failure() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_FAILURE
  echo -n $"FAILED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_passed() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"PASSED"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}

echo_warning() {
  [ "$BOOTUP" = "color" ] && $MOVE_TO_COL
  echo -n "["
  [ "$BOOTUP" = "color" ] && $SETCOLOR_WARNING
  echo -n $"WARNING"
  [ "$BOOTUP" = "color" ] && $SETCOLOR_NORMAL
  echo -n "]"
  echo -ne "\r"
  return 1
}




# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
# Example:
#     step "Remounting / and /boot as read-write:"
#     try mount -o remount,rw /
#     try mount -o remount,rw /boot
#     next
step() {
    echo -n "$@"

    STEP_OK=0
    [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$
}

try() {
    # Check for `-b' argument to run command in the background.
    local BG=

    [[ $1 == -b ]] && { BG=1; shift; }
    [[ $1 == -- ]] && {       shift; }

    # Run the command.
    if [[ -z $BG ]]; then
        "$@"
    else
        "$@" &
    fi

    # Check if command failed and update $STEP_OK if so.
    local EXIT_CODE=$?

    if [[ $EXIT_CODE -ne 0 ]]; then
        STEP_OK=$EXIT_CODE
        [[ -w /tmp ]] && echo $STEP_OK > /tmp/step.$$

        if [[ -n $LOG_STEPS ]]; then
            local FILE=$(readlink -m "${BASH_SOURCE[1]}")
            local LINE=${BASH_LINENO[0]}

            echo "$FILE: line $LINE: Command \`$*' failed with exit code $EXIT_CODE." >> "$LOG_STEPS"
        fi
    fi

    return $EXIT_CODE
}

next() {
    [[ -f /tmp/step.$$ ]] && { STEP_OK=$(< /tmp/step.$$); rm -f /tmp/step.$$; }
    [[ $STEP_OK -eq 0 ]]  && echo_success || echo_failure
    echo

    return $STEP_OK
}

apt_update() {
    if [ -z "$(find /var/cache/apt/pkgcache.bin -mmin -60)" ]; then
        aptitude update
    fi
}
