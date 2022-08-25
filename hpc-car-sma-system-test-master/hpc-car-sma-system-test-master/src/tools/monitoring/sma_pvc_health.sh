#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

# Pod uids
postgres_uid=$(kubectl -n ${SMA_NAMESPACE} get pods | grep postgres- |  grep -v persister | awk '{ print $1 }')
mysql_uid=$(kubectl -n ${SMA_NAMESPACE} get pods | grep mysql |  grep -v init | awk '{ print $1 }')
cstream_uid=$(kubectl -n ${SMA_NAMESPACE} get pods | grep cstream | grep -v setup | awk '{ print $1 }')

kafka_pods=( "cluster-kafka-0" "cluster-kafka-1" "cluster-kafka-2" )
zoo_pods=( "cluster-zookeeper-0" "cluster-zookeeper-1" "cluster-zookeeper-2" )
es_pods=( "elasticsearch-0" "elasticsearch-data-0" "elasticsearch-master-0" )
postgres_pods=( "craysma-postgres-cluster-0" "craysma-postgres-cluster-1" )

date
echo
kubectl -n sma get pvc

server_persistent_dir="/var/sma/data"
postgres_persistent_dir="/home/postgres/pgdata"
es_persistent_dir="/usr/share/elasticsearch/data"
kafka_persistent_dir="/var/lib/kafka/data/"
mysql_persistent_dir="/var/lib/mysql"
zoo_persistent_dir="/var/lib/zookeeper/data"
cstream_logs="/var/log/cray-seastream"

server_data=`df -k ${server_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g'`
mysql_data=$(kubectl -n sma exec ${mysql_uid} -- df -k ${mysql_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
cstream_data=$(kubectl -n sma exec ${cstream_uid} -- df -k ${cstream_logs}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')

echo
echo "SMA data usage= ${server_data}%"
df -h  ${server_persistent_dir}
echo
du -sh ${server_persistent_dir}/*

echo
echo "MySQL data usage= ${mysql_data}%"
kubectl -n sma exec ${mysql_uid} -- df -h ${mysql_persistent_dir}
echo
kubectl -n sma exec ${mysql_uid} -- df -h

echo
for pod in "${kafka_pods[@]}"
do
	kafka_data=$(kubectl -n sma exec ${pod} -c kafka -- df -k ${kafka_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "Kafka (${pod}) data usage= ${kafka_data}%"
	kubectl -n sma exec ${pod} -c kafka -- df -h ${kafka_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -c kafka -- df -h
done

echo
for pod in "${es_pods[@]}"
do
	es_data=$(kubectl -n sma exec ${pod} -- df -k ${es_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "Elasticsearch (${pod}) data usage= ${es_data}%"
	kubectl -n sma exec ${pod} -- df -h ${es_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -- df -h
done

echo
for pod in "${postgres_pods[@]}"
do
	postgres_data=$(kubectl -n sma exec ${pod} -- df -k ${postgres_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "Postgres (${pod}) data usage= ${postgres_data}%"
	kubectl -n sma exec ${pod} -- df -h ${postgres_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -- df -h
done

echo
echo "Cstream log usage= ${cstream_data}%"
kubectl -n sma exec ${cstream_uid} -- df -h ${cstream_logs}
echo
kubectl -n sma exec ${cstream_uid} -- df -h

for pod in "${zoo_pods[@]}"
do
	zoo_data=$(kubectl -n sma exec ${pod} -c zookeeper -- df -k ${zoo_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "Zookeeper (${pod}) data usage= ${zoo_data}%"
	kubectl -n sma exec ${pod} -c zookeeper -- df -h ${zoo_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -c zookeeper -- df -h
done

echo
kubectl get pvc --all-namespaces

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
