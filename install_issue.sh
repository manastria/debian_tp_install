#/bin/bash
# Update screen : systemctl restart getty@tty1

. /etc/os-release

cat > /etc/issue << EOF
${NAME} ${VERSION} \\n \\l
${text}

EOF

cp /etc/issue /etc/issue.std

cat > /etc/network/if-up.d/sh-update-address <<"EOF"
#!/bin/bash
#
# /etc/network/if-up.d/sh-update-address
#
# Checks to see if the current folder is on a file system with less than the
# specified percentage of free space and prints a warning if it is.
#
# For a description of the environment vairables  that can be sued by network
# scripts refer to 'man interfaces'.
#
# 24 Nov 16 - 0.1   - Initial version - MEJT
# 26 Jul 17 - 0.2   - Updated for Debian (stretch) - MEJT
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>
#
# If '/etc/issue.std' does not exist then create if from '/etc/issue'.
if [ ! -e /etc/issue.std ]; then
  if [ -e /etc/issue ]; then mv /etc/issue /etc/issue.std; fi
fi

if [ "$METHOD" != loopback ]; then # Ignore the loop back adapter.
  if [ "$MODE" = start ]; then
    # Check that an IP address is defined
    if [ "$ADDRFAM" = inet ] || [ "$ADDRFAM" = inet6 ]; then
      if [ -e /etc/issue.std ]; then # Update banner text if it exists
        cp /etc/issue.std /etc/issue
        for iface in $(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')
        do
            addr=$(ip -o -4 addr list $iface | awk '{print $4}' | cut -d/ -f1)
            # printf "%-10s %-25s\n" "${iface}" "${addr}" >> /etc/issue
            printf "%s - %s\n" "${iface}" "${addr}" >> /etc/issue
        done

        printf "\n" >> /etc/issue
      fi
    fi
  else
    if [ "$MODE" = stop ]; then
      if [ -e /etc/issue.std ]; then cp /etc/issue.std /etc/issue ; fi
    fi
  fi
fi
EOF

chmod +x /etc/network/if-up.d/sh-update-address
[ -e /etc/network/if-down.d/sh-update-address ] && rm /etc/network/if-down.d/sh-update-address
ln /etc/network/if-up.d/sh-update-address /etc/network/if-down.d/sh-update-address

