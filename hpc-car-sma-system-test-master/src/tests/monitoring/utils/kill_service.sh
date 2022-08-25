#!/bin/bash
# set -x

# -o jsonpath={.spec.containers[*].name}
# -o jsonpath={.status.containerStatuses[*].name}
# -o jsonpath={.status.containerStatuses[*].ready}
# nodeName

# operators FIXME
# kill vs delete FIXME

sleeptime=300
duration="60 minute"

kafka=('cluster-kafka-0' 'cluster-kafka-1' 'cluster-kafka-2')
zookeeper=('cluster-zookeeper-0' 'cluster-zookeeper-1' 'cluster-zookeeper-2')
logging=('rsyslog-aggregator' 'rsyslog-collector')
database=('postgres-persister')
ldms=('sma-ldms-aggr')
cstream=('cstream')
telemetry=('telemetry')

while getopts i:S: option
do
    case "${option}"
    in
		i) duration=${OPTARG};;     # how long to issue failovers
        S) sleeptime=${OPTARG};;    # number of seconds to sleep between killing a service
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ]; then
	echo "missing service name(s): kafka, zookeeper, database, ldms, cstream, telemetry"
	exit 1
fi

# Seed random generator
RANDOM=$$$(date +%s)

failover=()
for type in "$@"
do
	case "$type" in
		kafka)
			service=${kafka[$RANDOM % ${#kafka[@]} ]}
			;;
		zookeeper)
			service=${zookeeper[$RANDOM % ${#zookeeper[@]} ]}
			;;
		logging)
			service=${logging[$RANDOM % ${#logging[@]} ]}
			;;
		database)
			service=${database[$RANDOM % ${#database[@]} ]}
			;;
		ldms)
			service=${ldms[$RANDOM % ${#ldms[@]} ]}
			;;
		cstream)
			service=${cstream[$RANDOM % ${#cstream[@]} ]}
			;;
		telemetry)
			service=${telemetry[$RANDOM % ${#telemetry[@]} ]}
			;;
	esac
	failover+=(${service})
done

echo "service(s): ${failover[@]}"
echo "delay between: $sleeptime"
echo "start time: `date`"
echo
kubectl -n sma get pods -o wide

# random if more than 1 pod (rsyslog aggr) head -[1-3]

endtime=$(date -ud "$duration" +%s)
while [[ $(date -u +%s) -le $endtime ]]
do
	for uid in "${failover[@]}"; do
		uid=$(kubectl -n sma get pods | grep $service | head -1 | awk '{print $1}')
		echo
		kubectl -n sma get pods -o wide | grep ${uid}
		p_nodename=$(kubectl -n sma get pod ${uid} -o jsonpath={.spec.nodeName})
		echo "killing $service ($uid) on $p_nodename at `date`"
		kubectl -n sma delete pod ${uid} --grace-period=0 --force
		sleep 5

		# Wait for service to become ready
		while true
		do
			uid=$(kubectl -n sma get pods | grep $service | head -1 | awk '{print $1}')
			echo "checking for ${service} found ${uid}"
			if [ ! -z "${uid}" ]; then
				phase=$(kubectl -n sma get pod ${uid} -o jsonpath={.status.phase})
				names=$(kubectl -n sma get pod ${uid} -o jsonpath={.status.containerStatuses[*].name})
				echo "${uid} phase is ${phase}"
				if [ "$phase" == "Running" ]; then
					echo $names
					kubectl -n sma get pod ${uid} -o jsonpath={.status.containerStatuses[*].ready} | grep false
					if [ $? -ne 0 ]; then
						break
					fi
				fi
				kubectl -n sma get pods -o wide | grep ${uid}
			fi
			sleep 5
		done
		uid=$(kubectl -n sma get pods | grep $service | head -1 | awk '{print $1}')
		nodename=$(kubectl -n sma get pod ${uid} -o jsonpath={.spec.nodeName})
		echo "$service ($uid) is available again on $nodename at `date`"
		if [ "$p_nodename" != "$nodename" ]; then
			echo "${service} moved from node ${p_nodename} to ${nodename}"
		fi
	done
	sleep $sleeptime
done

echo
kubectl -n sma get pods -o wide
echo "end time: `date`"

# kubectl -n sma exec -t POD_NAME -c CONTAINER_NAME -- /bin/sh -c "kill 1"

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
