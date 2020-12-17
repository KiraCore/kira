#!/bin/bash
set +e source "/etc/profile" &>/dev/null set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

KIRA_SETUP_NGINX="$KIRA_SETUP/nginx-v0.0.1"
if [ ! -f "$KIRA_SETUP_NGINX" ]; then
    echo "INFO: Setting up NGINX..."
    cat >$NGINX_CONFIG <<EOL
worker_processes 1;
events { worker_connections 512; }
http { 
#server{} 
}
#EOF
EOL

    mkdir -p -v $NGINX_SERVICED_PATH
    printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" >$NGINX_SERVICED_PATH/override.conf

    # systemctl2 enable nginx.service
    touch $KIRA_SETUP_NGINX
else
    echo "INFO: NGINX was already installed"
fi
