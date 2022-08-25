#!/bin/bash
set -x
 
# Telemetry API 'stream' endpoint failed - interval server error

server="10.2.100.52"
port=8080

ITERS=100
for i in $(seq 1 $ITERS);
do 

	ping=$(curl -s -k https://${server}:${port}/v1/ping)
	echo ${ping} | grep "api_version"
	if [ $? -ne 0 ]; then
		exit 1
	fi

 	streams=$(curl -s -k https://${server}:${port}/v1/stream)
	echo ${streams} | grep "streams"
	if [ $? -ne 0 ]; then
		exit 1
	fi

done
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
