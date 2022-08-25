#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests that the zookeeper pod modes are configured such that there is one leader and multiple followers."
    echo "$0 > sma_component_kafka_zk_pod_mode-\`date +%Y%m%d.%H%M\`"
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

declare -a failures
errs=0


#################################
# Test case: ZK Podmode
leader=0
port=21810

echo
for pod in $(kubectl -n sma get pods | grep zookeeper | awk '{print $1}');
do
	mode=$(kubectl -n sma exec -t ${pod} -c zookeeper -- /bin/sh -c "echo stat | nc 127.0.0.1 ${port} | grep Mode | sed 's/Mode: //'")
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

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Kafka is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Kafka zookeeper pods are in the expected mode"

exit 0