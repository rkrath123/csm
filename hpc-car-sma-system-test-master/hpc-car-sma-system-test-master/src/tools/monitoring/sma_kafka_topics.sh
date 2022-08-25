#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "unable to talk to kubectl"
	exit 3
fi

cmd="kubectl -n ${SMA_NAMESPACE} get kafkatopic"
runit ${cmd}

echo
pod=$(get_kafka_pod)
cmd="kubectl -n ${SMA_NAMESPACE} exec ${pod} -c kafka -i -t -- /opt/kafka/bin/kafka-topics.sh --list --zookeeper localhost:2181"
runit ${cmd}

echo
for topic in "$@"
do
	cmd="kubectl -n ${SMA_NAMESPACE} exec ${pod} -c kafka -i -t -- /opt/kafka/bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic ${topic}"
	runit ${cmd}
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
