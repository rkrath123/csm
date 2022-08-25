#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

function usage()
{
    echo "usage: $0"
    echo
    echo "This command checks if the SMA kafka cluster appears healthy."
    echo "$0 > sma_KAFKA_HEALTH-\`date +%Y%m%d.%H%M\`"
    echo
    exit 1
}

while getopts h option
do
    case "${option}"
    in
        h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

kafka_pods=("cluster-kafka-0" "cluster-kafka-1" "cluster-kafka-2")
zookeeper_pods=("cluster-zookeeper-0" "cluster-zookeeper-1" "cluster-zookeeper-2")

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echoerr "unable to talk to kubectl"
	exit 3
fi

show_shasta_config
echo

kubectl -n sma get pods -owide | grep kafka
kubectl -n sma get pods -owide | grep zookeeper
echo

#for pod in "${kafka_pods[@]}"
#do
#	kubectl -n sma exec ${pod} -c kafka -t -- sh -c 'ps -e -u kafka -o cmd' | grep java
#	kubectl -n ${SMA_NAMESPACE} exec ${pod} -c kafka -t -- java -XX:+PrintFlagsFinal -version | grep HeapSize
#	echo
#done

echo
echo "Strimzi operator RES Mem"
pod=$(kubectl -n sma get pods | grep cluster-entity-operator | awk '{ print $1 }' )

kubectl -n sma exec ${pod} -c topic-operator -- sh -c 'COLUMNS=1000 top -o RES -c -n 1 -b'
container_memory=$(kubectl -n sma exec ${pod} -c topic-operator -t -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
echo "Container memory= ${container_memory} bytes"
echo
kubectl -n sma exec ${pod} -c user-operator -- sh -c 'COLUMNS=1000 top -o RES -c -n 1 -b'
container_memory=$(kubectl -n sma exec ${pod} -c user-operator -t -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
echo "Container memory= ${container_memory} bytes"

echo
for pod in "${kafka_pods[@]}"
do
    echo "${pod} top memory usage"
	kubectl -n sma exec ${pod} -c kafka -- sh -c 'COLUMNS=1000 top -o RES -U kafka -c -n 1 -b | grep -v top'
	echo

    echo "${pod} top %cpu"
	kubectl -n sma exec ${pod} -c kafka -- sh -c 'COLUMNS=1000 top -o %CPU -U kafka -c -n 1 -b | grep -v top'
	echo

	${BINPATH}/sma_cgroup_stats.sh ${pod} kafka
	echo

    echo "${pod} kafka processes"
	kubectl -n sma exec ${pod} -c kafka -- sh -c 'ps -e -u kafka -o pid,lstart,comm,args'

	echo
	max_memory_maps=$(kubectl -n sma exec ${pod} -c kafka -- sh -c 'cat /proc/sys/vm/max_map_count')
	num_memory_maps=$(kubectl -n sma exec ${pod} -c kafka -- sh -c 'pmap 1 | wc -l')
	echo "number of memory maps: ${num_memory_maps} (max is ${max_memory_maps})"
	echo
done

kafka_persistent_dir="/var/lib/kafka/data"
for pod in "${kafka_pods[@]}"
do
	kafka_data=$(kubectl -n sma exec ${pod} -c kafka -- df -k ${kafka_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo "${pod} data usage= ${kafka_data}%"
	kubectl -n sma exec ${pod} -c kafka -- sh -c "df -h ${kafka_persistent_dir}"
	echo
	kubectl -n sma exec ${pod} -c kafka -- sh -c "du -hs ${kafka_persistent_dir}/kafka-log*/* | sort -rh"
	echo
done
echo

errs=0

for pod in "${kafka_pods[@]}"
do
	cmd="kubectl -n ${SMA_NAMESPACE} exec ${pod} -c kafka -t -- /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092"
	${cmd} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
			echoerr "Kafka (${pod}) is not healthy"
			errs=$((errs+1))
	else
		echo "Kafka (${pod}) looks healthy"
	fi
done

leader=0
port=21810

echo
for pod in "${zookeeper_pods[@]}"
do
	mode=$(kubectl -n ${SMA_NAMESPACE} exec ${pod} -c zookeeper -t -- /bin/sh -c "echo stat | nc 127.0.0.1 ${port} | grep Mode | sed 's/Mode: //'")
	if [ -z "$mode" ]; then
		echoerr "Zookeeper (${pod}) mode was not set.  Zookeeper is not healthy"
		errs=$((errs+1))
	else
		echo "Zookeeper (${pod}) mode is ${mode}"
	fi
	echo ${mode} | grep leader >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		leader=$((leader+1))
	fi
	port=$((port+1))
done

if [ "$leader" -ne 1 ]; then
	echoerr "Zookeeper leader for cluster not found"
	errs=$((errs+1))
fi

if [ "$errs" -gt 0 ]; then
	echo
	echoerr "Kafka cluster is not healthy"
	exit 1
fi

echo
echo "Kafka cluster looks healthy"

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
