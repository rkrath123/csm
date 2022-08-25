#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Kafka messaging bus in Cray's Shasta System Monitoring Application"
    echo "tests the ability to create a topic and send/receive messsages."
    echo "$0 > sma_component_kafka_topic_send_receive-\`date +%Y%m%d.%H%M\`"
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

###################
kafkapod="cluster-kafka-0"


#######################################
# Test case: Create Test Topic
createtopic=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --partitions 1 --topic test-topic --replication-factor 1|tr "\r" "\n")

if [[ "$createtopic" =~ "Created topic test-topic." ]]; then
  echo "test topic created";
else
  echo "test topic not created"
  errs=$((errs+1))
  failures+=("Kafka Service - test topic not created")
fi

#######################################
# Test case: Create Producer and Send Message
#   Create a producer and send a message to the previously created test topic
procreate=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- bash -c "echo test-message | /opt/kafka/bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test-topic" | grep Error)

if [[ ! $procreate ]]; then
  echo "test message sent";
else
  echo "test message send failed"
  errs=$((errs+1))
  failures+=("Kafka Producer - test message send failed")
fi

#######################################
# Test case: Create Consumer and Receive Message
#   In order to facilitate having the producer and consumer run serially, the consumer is set to get all messages ever
#   posted to the topic and then time out.

consumerout=$(kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning --timeout-ms 5000 | grep test-message | tr '\r' '\n')
if [[ "$consumerout" =~ "test-message" ]]; then
  echo "test message received";
else
  echo "test message read failed"
  errs=$((errs+1))
  failures+=("Kafka Consumer - test message read failed")
fi

#   Return the environment to the initial state. Logs are cleaned up automatically when the related topic is deleted.
#   Because the ability to delete topics is disabled by default, the server.properties file needs to be edited
#   in order to allow it, and then changed back after deletion.
kubectl -n sma exec -it ${kafkapod} -c kafka -- sed -n '/offsets.topic.replication.factor=/ a delete.topic.enable=true' /opt/kafka/config/server.properties
kubectl -n sma exec -it ${kafkapod} -c kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic test-topic
kubectl -n sma exec -it ${kafkapod} -c kafka -- sed -n '/delete.topic.enable=true/d' /opt/kafka/config/server.properties

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
echo "Kafka topic creation and message send & receive look good"

exit 0