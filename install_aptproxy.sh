#/bin/bash

# echo -e "IP et port du proxy (example : 172.16.0.1:3128) ?"
# read -r IPPROXY
# echo "Acquire::http::Proxy \"http://${IPPROXY}\";" > /etc/apt/apt.conf.d/01proxy

rm -f /etc/apt/apt.conf.d/30detectproxy

cat > /etc/apt/apt.conf.d/30proxy <<EOF
# Fail immediately if a file could not be retrieved. Comment if you have a bad
# Internet connection
Acquire::Retries 0;

# undocumented feature which was found in the source. It should be an absolute
# path to the program, no arguments are allowed. stdout contains the proxy
# server, stderr is shown (in stderr) but ignored by APT
Acquire::http::Proxy-Auto-Detect "/etc/apt/detect-http-proxy";
EOF

cat > /etc/apt/detect-http-proxy <<'EOF'
#!/bin/bash
# detect-http-proxy - Returns a HTTP proxy which is available for use

# Author: Lekensteyn <lekensteyn@gmail.com>

# Supported since APT 0.7.25.3ubuntu1 (Lucid) and 0.7.26~exp1 (Debian Squeeze)
# Unsupported: Ubuntu Karmic and before, Debian Lenny and before

# Put this file in /etc/apt/detect-http-proxy and create and add the below
# configuration in /etc/apt/apt.conf.d/30detectproxy
#    Acquire::http::ProxyAutoDetect "/etc/apt/detect-http-proxy";

# APT calls this script for each host that should be connected to. Therefore
# you may see the proxy messages multiple times (LP 814130). If you find this
# annoying and wish to disable these messages, set show_proxy_messages to 0
show_proxy_messages=1

# on or more proxies can be specified. Note that each will introduce a routing
# delay and therefore its recommended to put the proxy which is most likely to
# be available on the top. If no proxy is available, a direct connection will
# be used
try_proxies=(
172.16.0.1:3128
192.168.1.81:9999
)

print_msg() {
    # \x0d clears the line so [Working] is hidden
    [ "$show_proxy_messages" = 1 ] && printf '\x0d%s\n' "$1" >&2
}

for proxy in "${try_proxies[@]}"; do
    # if the host machine / proxy is reachable...
    if nc -w 1 -z ${proxy/:/ }; then
        proxy=http://$proxy
        print_msg "Proxy that will be used: $proxy"
        echo "$proxy"
        exit
    fi
done
print_msg "No proxy will be used"

# Workaround for Launchpad bug 654393 so it works with Debian Squeeze (<0.8.11)
echo DIRECT
EOF

chmod a+x /etc/apt/detect-http-proxy
