LISTEN_PORT=$1
PROXY_PASS=$2

echo "------------------------------------------------"
echo " STARTED: NGINX PROXY GRPC CONFIGURATION"
echo "------------------------------------------------"
echo "LISTEN_PORT: $LISTEN_PORT"
echo "PROXY_PASS: $PROXY_PASS"
echo "------------------------------------------------"

read -r -d '' SERVER_BLOCK <<-EOL
server {
listen $LISTEN_PORT http2;
server_name localhost;

add_header 'Access-Control-Allow-Origin' '*';
add_header 'Access-Control-Allow-Credentials' 'true';
add_header 'Access-Control-Allow-Headers' 'Authorization,Accept,Origin,DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range';
add_header 'Access-Control-Allow-Methods' 'GET,POST,OPTIONS,PUT,DELETE,PATCH';

location / {

if (\$request_method = 'OPTIONS') {
      add_header 'Access-Control-Max-Age' 1728000;
      add_header 'Content-Type' 'text/plain charset=UTF-8';
      add_header 'Content-Length' 0;
      return 204;
    }

grpc_pass grpc://localhost:$PROXY_PASS;
grpc_set_header X-Real-IP \$remote_addr;

}
}
#server{}
EOL

echo "Testing LISTEN_PORT..."
if [ "$LISTEN_PORT" -ge 1 -a "$LISTEN_PORT" -le 65535 ]
then
  echo "Writing server block..."
  CDHelper text replace --old="#server{}" --new="$SERVER_BLOCK" --input="/etc/nginx/nginx.conf"

  systemctl2 start nginx
  systemctl2 status nginx.service || echo "nginx setup failed"
  systemctl2 stop nginx

else
	echo "FAILED to setup nginx configuration, LISTEN_PORT ($LISTEN_PORT) is invalid."
  exit 1
fi

echo "------------------------------------------------"
echo " FINISHED: NGINX PROXY GRPC CONFIGURATION"
echo "------------------------------------------------"
