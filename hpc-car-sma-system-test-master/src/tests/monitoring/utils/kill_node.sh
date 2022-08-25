#!/bin/bash
# set -x

# kubectl get node sms02-nmn -o jsonpath={.status.conditions[*].ready}
# JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}' \
#  && kubectl get nodes -o jsonpath="$JSONPATH"

nodes=("sms02-nmn" "sms03-nmn" "sms04-nmn")

sleeptime=300
duration="60 minute"

while getopts i:S: option
do
    case "${option}"
    in
		i) duration=${OPTARG};;     # how long to issue failovers
        S) sleeptime=${OPTARG};;    # number of seconds to wait between failovers
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# Seed random generator
RANDOM=$$$(date +%s)

echo "SMS node(s): ${nodes[@]}"
echo "delay between: $sleeptime"
echo "start time: `date`"

endtime=$(date -ud "$duration" +%s)
while [[ $(date -u +%s) -le $endtime ]]
do
	echo
	date
	kubectl get nodes -o wide
	kubectl -n sma get pods -o wide
	echo
	kubectl get nodes -o wide | grep $failover
	kubectl -n sma get pods -o wide | grep $failover

	failover=${nodes[$RANDOM % ${#nodes[@]} ]}
	echo "rebooting $failover"
#	ssh ${failover} 'date; reboot'
#   crayctl node 2 cycle
	sleep 120

	# Wait for node to become ready
	while true
	do
		ping -w 10 ${failover}
		if [ $? -eq 0 ]; then
			status=$(kubectl get nodes | grep $failover | awk '{print $2}')
			if [ "$status" == "Ready" ]; then
				echo
				date
				kubectl get nodes -o wide
				kubectl -n sma get pods -o wide
				break
			fi
		fi
		sleep 30
	done
# check if pods running? skip hms-
	sleep $sleeptime
done

echo
kubectl get nodes -o wide
kubectl -n sma get pods -o wide
echo "end time: `date`"

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
