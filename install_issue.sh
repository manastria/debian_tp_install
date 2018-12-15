#/bin/bash

. /etc/os-release

cat > /etc/issue << EOF
${NAME} ${VERSION} \\\\n \\l
${text}
${text}SSH : \\4{enp0s8}
EOF
