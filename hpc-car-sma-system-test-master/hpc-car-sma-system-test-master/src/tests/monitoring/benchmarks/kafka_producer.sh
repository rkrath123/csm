#!/bin/bash
# set -x

binpath=`dirname "$0"`
. ${binpath}/kafka_config

job_template="${binpath}/kafka-producer.yaml.j2"

function usage()
{
	echo "usage: $0 [-p PRODUCERS] [-t TOPICS] [-c COUNT] [-s SIZE] [-a ACKS]"
	echo
	echo "Kafka producer performance test to measure throughput."
	echo "  -p number of producers (default is ${PRODUCERS})"
	echo "  -t number of topics (default is ${TOPICS})"
	echo "  -c message count (default is ${CNT})"
	echo "  -s message size (default is ${SIZE})"
	echo "  -a acks (default is producer never waits)"
	echo
	exit 1
}

while getopts p:t:c:s:a:h option
do
    case "${option}"
    in
		p) PRODUCERS=${OPTARG};;
		t) TOPICS=${OPTARG};;
		c) COUNT=${OPTARG};;
		s) SIZE=${OPTARG};;
		a) ACKS=${OPTARG};;
		h) usage;;
	esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo "producers      ${PRODUCERS}"
echo "topics         ${TOPICS}"
echo "partitions     ${PARTITIONS}"
echo "replicas       ${REPLICAS}"
echo "cnt            ${CNT}"
echo "size           ${SIZE}"
echo "acks_required  ${ACKS}"
echo

errs=0
for i in $(seq 1 ${TOPICS}); do
	topic_name=$(get_topic_name $i)
	echo "checking topic ${topic_name}"
	run_cmd "kubectl -n sma exec cluster-kafka-0 -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --describe --topic ${topic_name}"
	if [ $? -ne 0 ]; then
		echo "topic ${topic_name} not found"
		errs=$((errs+1))
	fi
done
echo

if [ "$errs" -gt 0 ]; then
	exit 1
fi

rm -rf ${binpath}/jobs; mkdir ${binpath}/jobs
k8s_yaml_files=()

for i in $(seq 1 ${PRODUCERS}); do
	for j in $(seq 1 ${TOPICS}); do

		job_name=$(get_producer_job_name $i)
		topic_name=$(get_topic_name $j)

		k8s_yaml="${binpath}/jobs/${job_name}-${topic_name}.yaml"
		k8s_yaml_files+=( ${k8s_yaml} )

		echo "creating job ${k8s_yaml}"

		cat ${job_template} | sed "s/JOB/${job_name}/" > ${k8s_yaml}
		sed -i "s/TOPIC/${topic_name}/g" ${k8s_yaml}

		sed -i "s/CNT/${CNT}/g" ${k8s_yaml}
		sed -i "s/SIZE/${SIZE}/g" ${k8s_yaml}
		sed -i "s/ACKS/${ACKS}/g" ${k8s_yaml}
	done
done
echo
cat ${binpath}/jobs/*.yaml

echo
kafka_health

echo
start_time=$(date +'%s')
echo "starting jobs in ${binpath}/jobs"

#  run_cmd "kubectl create -f ${binpath}/jobs"
echo
for k8s_yaml in "${k8s_yaml_files[@]}"; do
	run_cmd "kubectl apply -f ${k8s_yaml}"
done

echo "wait for jobs to start"
sleep 60
echo

run_cmd "kubectl -n sma get pods -l jobgroup=kafka-producer"

for pod in $(kubectl -n sma get pods -l jobgroup=kafka-producer -o name); do
	echo "waiting for job ${pod} to complete"
	echo

	while true; do
		phase=$(kubectl -n sma get ${pod} -o jsonpath={.status.phase})
		if [ $? -eq 0 ] && [ ! -z "$phase" ]; then
			echo "[`date`] $phase"
			kubectl -n sma get pods -l jobgroup=kafka-producer --no-headers
			if [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ]; then
				echo
				run_cmd "kubectl -n sma logs ${pod} --timestamps  --all-containers"
				break
			fi
			sleep 30
		fi
	done
done

echo
echo "deleting jobs in ${binpath}/jobs"
run_cmd "kubectl -n sma get pods -l jobgroup=kafka-producer"
echo
for k8s_yaml in "${k8s_yaml_files[@]}"; do
	echo ${k8s_yaml}
	run_cmd "kubectl delete -f ${k8s_yaml}"
done

echo
kafka_health

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
