#!/bin/bash

# export ACCESS_TOKEN=$(cat auth_token)
# arg example: https://pepsi-ncn-w001:30443 or api-gw-service-nmn.local

while true
do
	date
	curl -k -H "Authorization: Bearer $ACCESS_TOKEN" $1/apis/sma-telemetry-api/v1/ping
	if [ "$?" -ne 0 ]; then
		echo "ping request failed...abort"
		exit 1
	fi
	curl -k -H "Authorization: Bearer $ACCESS_TOKEN" $1/apis/sma-telemetry-api/v1/stream
	if [ "$?" -ne 0 ]; then
		echo "stream request failed...abort"
		exit 1
	fi
	echo
	sleep 600
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
