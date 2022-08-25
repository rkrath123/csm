#!/bin/bash
# set -x

ITERS=${1:-10}
DELAY=${2:-}2
KAFKA_HOST="cluster-kafka-bootstrap.sma.svc.cluster.local"

for i in $(seq 1 $ITERS)
do
	IFS=$'\n' 
	for line in `kubectl -n sma -o wide get pods  | grep telemetry`
	do
		service=$(echo $line | awk '{print $1}')
		host=$(echo $line | awk '{print $7}')
		echo "----- $service ($host)"
		kubectl -n sma exec -it ${service} -- ping -c 3 ${KAFKA_HOST} | grep "3 packets transmitted, 3 packets received, 0% packet loss"
		if [ $? -ne 0 ]; then
			echo "FAIL: iteration= ${i}"
			exit 1
		fi
	done
	sleep ${DELAY}
done
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
