#!/bin/bash

cp tftp/default_tftpd-hpa /etc/default/tftpd-hpa
chown root:root /etc/default/tftpd-hpa
chmod 0644 /etc/default/tftpd-hpa
chown tftp:tftp /srv/tftp/




