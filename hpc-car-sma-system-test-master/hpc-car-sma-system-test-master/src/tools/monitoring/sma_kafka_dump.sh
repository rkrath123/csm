#!/bin/bash
# set -x

# other options of interest:
#  --from-beginning --csv-reporter-enabled --max-messages

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

uid="cluster-kafka-0"
if [ $# -eq 0 ]; then
	echo "no topic specified"
	exit 1
fi
topic=$1

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "unable to talk to kubectl"
	exit 3
fi

cmd="kubectl -n ${SMA_NAMESPACE} exec ${uid} -c kafka -i -t -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $topic"
runit ${cmd}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
