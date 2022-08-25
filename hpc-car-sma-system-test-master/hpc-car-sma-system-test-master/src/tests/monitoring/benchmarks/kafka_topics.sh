#!/bin/bash
# set -x

binpath=`dirname "$0"`
. ${binpath}/kafka_config

function usage()
{
	echo "usage: $0 [ create | describe | delete ]"
	exit 1
}

function create_topics()
{
	for i in $(seq 1 ${TOPICS}); do
		topic_name=$(get_topic_name $i)
		echo "creating topic ${topic_name}"
		run_cmd "kubectl -n sma exec cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic ${topic_name} --partitions ${PARTITIONS} --replication-factor ${REPLICAS}"
		if [ "$?" -ne 0 ]; then
		 	echo "ERROR: failed to create topic ${topic}"
		 	exit 1
		fi
		run_cmd "kubectl -n sma exec cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic ${topic_name}"
	done
}

function delete_topics()
{
	for i in $(seq 1 ${TOPICS}); do
		topic_name=$(get_topic_name $i)
		echo "deleting topic ${topic_name}"
		run_cmd "kubectl -n sma exec cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic ${topic_name}"
		if [ "$?" -ne 0 ]; then
		 	echo "WARN: failed to delete topic ${topic}"
		fi
	done
}

function describe_topics()
{
	for i in $(seq 1 ${TOPICS}); do
		topic_name=$(get_topic_name $i)
		echo "describe topic ${topic_name}"
		run_cmd "kubectl -n sma exec cluster-kafka-0 -c kafka -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic ${topic_name}"
		if [ "$?" -ne 0 ]; then
		 	echo "WARN: describe topic ${topic}"
		fi
	done
}

if [ $# -ne 1 ]; then
        usage
fi

echo "topics         ${TOPICS}"
echo "partitions     ${PARTITIONS}"
echo "replicas       ${REPLICAS}"
echo

if [[ $1 == "create" ]]; then
	create_topics
elif [[ $1 == "delete" ]]; then
	delete_topics
elif [[ $1 == "describe" ]]; then
	describe_topics
else
	usage
fi

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
