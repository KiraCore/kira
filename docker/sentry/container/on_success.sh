#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

# (rm -fv $KIRA_INFRA/docker/validator/container/on_success.sh) && nano $KIRA_INFRA/docker/validator/container/on_success.sh

#echo "Fetching external IP of the current instance"
#EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null)
#echo "Assigning '$ROUTE53_RECORD_NAME' DNS name in the zone $ROUTE53_ZONE to $EXTERNAL_IP with ${ROUTE53_TTY}s TTY"
#AWSHelper route53 upsert-a-record --name="$ROUTE53_RECORD_NAME" --zone=$ROUTE53_ZONE --value="$EXTERNAL_IP" --ttl=$ROUTE53_TTY
#
#echo "Fetching internal IP of the current instance"
#INTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip 2>/dev/null)
#echo "Assigning 'internal-$ROUTE53_RECORD_NAME' DNS name in the zone $ROUTE53_ZONE to $EXTERNAL_IP with ${ROUTE53_TTY}s TTY"
#AWSHelper route53 upsert-a-record --name="internal-$ROUTE53_RECORD_NAME" --zone=$ROUTE53_ZONE --value="$INTERNAL_IP" --ttl=$ROUTE53_TTY

echo "Restarting services..."
systemctl2 restart nginx || systemctl2 status nginx.service || echo "Failed to re-start nginx service" || true
systemctl2 restart sekaid || systemctl2 status sekaid.service || echo "Failed to re-start sekaid service" && echo "$(cat /etc/systemd/system/sekaid.service)" || true
#systemctl2 restart lcd || systemctl2 status lcd.service || echo "Failed to re-start lcd service" && echo "$(cat /etc/systemd/system/lcd.service)" || true
#systemctl2 restart faucet || systemctl2 status faucet.service || echo "Failed to re-start faucet service" && echo "$(cat /etc/systemd/system/faucet.service)" || true




