#!/bin/bash

if [ -z "$CERTBOT_DOMAIN" ] || [ -z "$CERTBOT_VALIDATION" ]
then
echo "EMPTY DOMAIN OR VALIDATION"
exit -1
fi

HOST="_acme-challenge"

BASE_DOMAIN=$(echo ${CERTBOT_DOMAIN} | awk -F'.' '{print $(NF-1) "." $NF}')


echo "Send DNS update"

/usr/bin/nsupdate -k /etc/letsencrypt/scripts/bind.key << EOM
server 10.0.3.21
zone ${BASE_DOMAIN}
update delete ${HOST}.${CERTBOT_DOMAIN} TXT
update add ${HOST}.${CERTBOT_DOMAIN} 300 TXT "${CERTBOT_VALIDATION}"
send
EOM

date > /tmp/letsencrypt.log
echo "Creating challenge for ${CERTBOT_DOMAIN}"
numberofservers=$(dig +short NS ${BASE_DOMAIN} | wc -l)
echo "Number of servers is ${numberofservers}" >> /tmp/letsencrypt.log
for seconds in {1..60}
do
        i=0
        for dns in $(dig +short NS ${BASE_DOMAIN})
        do
		echo "Testing ${dns}" >> /tmp/letsencrypt.log
                output=$(dig +short TXT ${HOST}.${CERTBOT_DOMAIN} @${dns})
                if [[ $output == "\"${CERTBOT_VALIDATION}\"" ]]
                then
			echo "$dns has an up to date record" >> /tmp/letsencrypt.log
                        ((i++))
                else
			echo "$dns has $output as record" >> /tmp/letsencrypt.log
                fi

        done
                if [[ $i -ge ${numberofservers} ]]
                then
                        echo "Record is availlable on all DNS servers continue" >> /tmp/letsencrypt.log
			sleep 20
                        exit
                else
			echo "only ${i} servers have the correct record" >> /tmp/letsencrypt.log
                        echo -n '.'
                        sleep 5
                fi
done