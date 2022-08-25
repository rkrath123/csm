#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

hours=( "1" "4" "8" "12" "24" )
messages=0
content_type="Content-Type: application/json"

function usage()
{
    echo "usage: $0"
    echo
    echo "This command checks if SMA log aggregation services appear healthy."
    echo "$0 > sma_LOG_HEALTH-\`date +%Y%m%d.%H%M\`"
	echo
    exit 1
}

function check_value() {
	if [ -n "$(printf '%s\n' "$1" | sed 's/[0-9]//g')" ]; then
		echo 0
	else
		echo $1
	fi
}

while getopts hm: option
do
	case "${option}"
	in
		m) messages=${OPTARG};;
		h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

url="$(kubectl -n sma get services | grep elasticsearch | grep -v elasticsearch-curator | awk '{ print $3 }'):9200"
# url="$(kubectl -n sma get services | grep elasticsearch | grep NodePort | awk '{print $3}'):9200"

errs=0

show_shasta_config

echo
is_rsyslog_on_computes
if [ $? -eq 0 ]; then
	echo "Rsyslog configuration on computes looks ok"
else
	echo "Rsyslog configuration on computes is not okay"
fi

echo
kubectl -n services get pods -owide | grep kibana
kibana_health=$(curl -s -S -XGET "${SMA_API_GATEWAY}/sma-kibana/api/status?pretty=true")
if [ $? -eq 0 ]; then
	echo "Kibana looks healthy"
else
	echoerr "Kibana is not healthy"
	errs=$((errs+1))
fi

rsyslog_pods=( "rsyslog-aggregator" "rsyslog-collector" )
for rsyslog in "${rsyslog_pods[@]}"
do
	echo
	kubectl -n sma get pods -owide | grep ${rsyslog}
	count=$(kubectl -n sma get pods | grep ${rsyslog} | wc -l)
	running=$(kubectl -n sma get pods | grep ${rsyslog} | grep Running | wc -l)
	if [ "${count}" -eq "${running}" ]; then
		echo "${rsyslog} looks healthy"
	else
		echoerr "${rsyslog} is not healthy"
		errs=$((errs+1))
	fi
done

echo
kubectl -n sma get pods -owide | grep elasticsearch
es_version=$(curl -s -S -XGET "${url}" | jq .version.number  2>/dev/null)
if [ $? -eq 0 ]; then
	echo "Elasticsearch looks healthy"
else
	echoerr "Elasticsearch is not healthy"
	exit 1
fi

echo
echo "elasticsearch url is ${url}"
echo "elasticsearch version is ${es_version}"

echo
elasticsearch_pods=( "elasticsearch-0" )
for pod in "${elasticsearch_pods[@]}"
do
    echo "${pod} top memory usage"
	kubectl -n sma exec ${pod} -- sh -c 'COLUMNS=1000 top -o RES -U elasticsearch -c -n 1 -b | grep -v top'
	echo
    echo "${pod} top %cpu"
	kubectl -n sma exec ${pod} -- sh -c 'COLUMNS=1000 top -o %CPU -U elasticsearch -c -n 1 -b | grep -v top'
	kubectl -n sma exec ${pod} -- sh -c 'ps aux'
    echo

	${BINPATH}/sma_cgroup_stats.sh ${pod}
	echo

done

track_total_hits=""
hits_value=".hits.total"
if [[ $es_version = *"7"* ]]; then
	track_total_hits="\"track_total_hits\": true,"
	hits_value=".hits.total.value"
fi

container_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container\", \"analyze_wildcard\": true } } ] } } }" | jq ${hits_value})
container_logs="$(check_value $container_logs)"
printf "Container logs: %'d\n" ${container_logs}
if [ "$container_logs" -eq 0 ]; then
	echoerr "no container logs found in Elasticsearch"
	errs=$((errs+1))
fi

stdout_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container AND stream:stdout\", \"analyze_wildcard\": true } } ] } } }" | jq ${hits_value})
stdout_logs="$(check_value $stdout_logs)"
printf "STDOUT container logs: %'d\n" ${stdout_logs}

stderr_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container AND stream:stderr\", \"analyze_wildcard\": true } } ] } } }" | jq ${hits_value})
stderr_logs="$(check_value $stderr_logs)"
printf "STDERR container logs: %'d\n" ${stderr_logs}

illformed_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"*:* -tag:[* TO ""zzzzzzzzzz""]\", \"analyze_wildcard\": true } } ] } } }" | jq ${hits_value})
illformed_logs="$(check_value $illformed_logs)"
printf "Ill-formed container logs: %'d\n" ${illformed_logs}

# compute log query is: filter= tag is not dock_container,  query= hostname:nid*
#
query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"nid*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"

compute_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
compute_logs="$(check_value $compute_logs)"
printf "Compute logs: %'d\n" ${compute_logs}

# Internally we've been using x1000 for mountain cabinets, x3000 for river cabinets and x5000 for mountain TDS cabinets
# switch log query: filter= tag is not dock_container, query=hostname=x*
#
query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"x*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"

switch_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
switch_logs="$(check_value $switch_logs)"
printf "Switch logs: %'d\n" ${switch_logs}

# ncn log query: filter= tag is not dock_container,  query=  hostname:sms* OR hostname:ncn*
#
query="{\"track_total_hits\":true,\"sort\":[{\"timereported\":{\"order\":\"asc\",\"unmapped_type\":\"boolean\"}}],\"query\":{\"bool\":{\"filter\":[{\"bool\":{\"should\":[{\"bool\":{\"should\":[{\"query_string\":{\"fields\":[\"hostname\"],\"query\":\"ncn*\"}}],\"minimum_should_match\":1}},{\"bool\":{\"should\":[{\"query_string\":{\"fields\":[\"hostname\"],\"query\":\"sms*\"}}],\"minimum_should_match\":1}}],\"minimum_should_match\":1}}],\"must_not\":[{\"match_phrase\":{\"tag\":{\"query\":\"docker_container\"}}}]}}}"

ncn_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
ncn_logs="$(check_value $ncn_logs)"
printf "NCN logs: %'d\n" ${ncn_logs}

clusterstor_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/clusterstor-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"match_all\": {}} } ] } } }" | jq ${hits_value})
clusterstor_logs="$(check_value $clusterstor_logs)"
printf "ClusterStor logs: %'d\n" ${clusterstor_logs}

echo
echo "Container logs in last X hours:"
for hour in "${hours[@]}"
do
	lte=$(date +%s%N | cut -b1-13)
	gte=$(date +%s%N -d "${hour} hour ago" | cut -b1-13)
	count_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container\", \"analyze_wildcard\": true } }, { \"range\": { \"timereported\": { \"gte\" : ${gte}, \"lte\": ${lte}, \"format\": \"epoch_millis\" } } } ] } } }" | jq ${hits_value})
	count_logs="$(check_value $count_logs)"
	printf "\t%s hours: %'d\n" ${hour} ${count_logs}
	if [ "$count_logs" -eq 0 ] && [ "${hour}" -eq "1" ]; then
		echoerr "no container logs found in Elasticsearch"
		errs=$((errs+1))
	fi
done

echo
echo "Compute logs in last X hours:"
for hour in "${hours[@]}"
do
	lte=$(date +%s%N | cut -b1-13)
	gte=$(date +%s%N -d "${hour} hour ago" | cut -b1-13)

	query="{\"track_total_hits\":true,\"sort\":[{\"timereported\":{\"order\":\"asc\",\"unmapped_type\":\"boolean\"}}],\"query\":{\"bool\":{\"must\":[{\"range\":{\"timereported\":{\"format\":\"epoch_millis\",\"gte\": ${gte},\"lte\":${lte}}}}],\"filter\":[{\"bool\":{\"should\":[{\"query_string\":{\"fields\":[\"hostname\"],\"query\":\"nid*\"}}],\"minimum_should_match\":1}}],\"should\":[],\"must_not\":[{\"match_phrase\":{\"tag\":{\"query\":\"docker_container\"}}}]}}}"

	count_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
	count_logs="$(check_value $count_logs)"
	printf "\t%s hours: %'d\n" ${hour} ${count_logs}

done

echo
echo "Switch logs in last X hours:"
for hour in "${hours[@]}"
do
	lte=$(date +%s%N | cut -b1-13)
	gte=$(date +%s%N -d "${hour} hour ago" | cut -b1-13)

	query="{\"track_total_hits\":true,\"sort\":[{\"timereported\":{\"order\":\"asc\",\"unmapped_type\":\"boolean\"}}],\"query\":{\"bool\":{\"must\":[{\"range\":{\"timereported\":{\"format\":\"epoch_millis\",\"gte\": ${gte},\"lte\":${lte}}}}],\"filter\":[{\"bool\":{\"should\":[{\"query_string\":{\"fields\":[\"hostname\"],\"query\":\"x*\"}}],\"minimum_should_match\":1}}],\"should\":[],\"must_not\":[{\"match_phrase\":{\"tag\":{\"query\":\"docker_container\"}}}]}}}"

	count_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
	count_logs="$(check_value $count_logs)"
	printf "\t%s hours: %'d\n" ${hour} ${count_logs}
done

echo
echo "NCN logs in last X hours:"
for hour in "${hours[@]}"
do
	lte=$(date +%s%N | cut -b1-13)
	gte=$(date +%s%N -d "${hour} hour ago" | cut -b1-13)

	query="{\"track_total_hits\":true,\"sort\":[{\"timereported\":{\"order\":\"asc\",\"unmapped_type\":\"boolean\"}}],\"query\":{\"bool\":{\"must\":[{\"range\":{\"timereported\":{\"format\":\"epoch_millis\",\"gte\": ${gte},\"lte\":${lte}}}}],\"filter\":[{\"bool\":{\"should\":[{\"query_string\":{\"fields\":[\"hostname\"],\"query\":\"ncn*\"}}],\"minimum_should_match\":1}}],\"should\":[],\"must_not\":[{\"match_phrase\":{\"tag\":{\"query\":\"docker_container\"}}}]}}}"

	count_logs=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq ${hits_value})
	count_logs="$(check_value $count_logs)"
	printf "\t%s hours: %'d\n" ${hour} ${count_logs}
done

echo
echo "ClusterStor logs in last X hours:"
for hour in "${hours[@]}"
do
	lte=$(date +%s%N | cut -b1-13)
	gte=$(date +%s%N -d "${hour} hour ago" | cut -b1-13)
	count_logs=$(curl -S -s -XGET -H "${content_type}" "${url}/clusterstor-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"match_all\": {}}, { \"range\": { \"timereported\": { \"gte\" : ${gte}, \"lte\": ${lte}, \"format\": \"epoch_millis\" } } } ] } } }" | jq ${hits_value})
	count_logs="$(check_value $count_logs)"
	printf "\t%s hours: %'d\n" ${hour} ${count_logs}
done


echo
if [ "$container_logs" -gt 0 ]; then
	oldest=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container\", \"analyze_wildcard\": true } } ] } } }" | jq .hits.hits[]._source.timereported)
	latest=$(curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"bool\": { \"must\": [ { \"query_string\": { \"query\": \"tag:docker_container\", \"analyze_wildcard\": true } } ] } } }" | jq .hits.hits[]._source.timereported)

	echo "Container logs timereported: oldest= ${oldest} latest= ${latest}"
fi

if [ "$compute_logs" -gt 0 ]; then
	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"nid*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	oldest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"nid*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	latest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	echo "Compute logs timereported: oldest= ${oldest} latest= ${latest}"
fi

if [ "$switch_logs" -gt 0 ]; then
	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"x*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	oldest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"x*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	latest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	echo "Switch logs timereported: oldest= ${oldest} latest= ${latest}"
fi

if [ "$ncn_logs" -gt 0 ]; then
	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"ncn*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	oldest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	query="{\"track_total_hits\": true, \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\"} } ], \"query\": { \"bool\": {\"filter\": [ { \"bool\": { \"should\": [ { \"query_string\": { \"fields\": [ \"hostname\" ], \"query\": \"ncn*\" } } ], \"minimum_should_match\": 1 } } ], \"must_not\": [ { \"match_phrase\": { \"tag\": { \"query\": \"docker_container\" } } } ] } } }"
	latest=$(curl -S -s -XGET -H 'Content-Type: application/json' "${url}/shasta-logs*/_search?size=1&pretty"  -d "${query}" | jq .hits.hits[]._source.timereported)

	echo "NCN logs timereported: oldest= ${oldest} latest= ${latest}"
fi

if [ "$clusterstor_logs" -gt 0 ]; then
	oldest=$(curl -S -s -XGET -H "${content_type}" "${url}/clusterstor-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"match_all\": {}} } ] } } }" | jq .hits.hits[]._source.timereported)
	latest=$(curl -S -s -XGET -H "${content_type}" "${url}/clusterstor-logs*/_search?size=1&pretty" -d "{ ${track_total_hits} \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\" } } ], \"query\": { \"match_all\": {}} } ] } } }" | jq .hits.hits[]._source.timereported)
	echo "ClusterStor logs timereported: oldest= ${oldest} latest= ${latest}"
fi

echo
es_persistent_dir="/usr/share/elasticsearch/data"
es_data=$(kubectl -n sma exec elasticsearch-0 -- df -k ${es_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
echo "Elasticsearch data usage= ${es_data}%"
kubectl -n sma exec elasticsearch-0 -- df -lh ${es_persistent_dir}

echo
curl -s -S -XGET "${url}/_cat/indices/shasta-logs*?v&s=index"
num_days=$(curl -s -S -XGET "${url}/_cat/indices/shasta-logs*?v&s=index" | grep open | wc -l)
echo "Number of days= ${num_days}"
echo
curl -s -S -XGET "${url}/_cat/indices/clusterstor-logs*?v&s=index"
num_days=$(curl -s -S -XGET "${url}/_cat/indices/clusterstor-logs*?v&s=index" | grep open | wc -l)
echo "Number of days= ${num_days}"

if [ "$messages" -gt 0 ]; then
	echo

	echo "Oldest ${messages} logs:"
	curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=${messages}&pretty" -d "{ \"sort\": [ { \"timereported\": { \"order\": \"asc\", \"unmapped_type\": \"boolean\" } } ] }"

	echo "Latest ${messages} logs:"
	curl -S -s -XGET -H "${content_type}" "${url}/shasta-logs*/_search?size=${messages}&pretty" -d "{ \"sort\": [ { \"timereported\": { \"order\": \"desc\", \"unmapped_type\": \"boolean\" } } ] }"
fi

echo
jvm_heap_used=$(curl -s -S -XGET "${url}/_cluster/stats" | jq .nodes.jvm.mem.heap_used_in_bytes)
jvm_heap_max=$(curl -s -S -XGET "${url}/_cluster/stats" | jq .nodes.jvm.mem.heap_max_in_bytes)
jvm_used_percent=`expr $jvm_heap_used \* 100`
jvm_usage_percent=`expr $jvm_used_percent / $jvm_heap_max`
echo "Elasticsearch JVM HEAP usage= ${jvm_usage_percent}%"

kafka_pods=( "cluster-kafka-0" "cluster-kafka-1" "cluster-kafka-2" )

healthy_kafka=""
for pod in "${kafka_pods[@]}"
do
	kubectl -n sma exec ${pod} -c kafka -t -- /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Kafka (${pod}) is not healthy"
	else
		healthy_kafka=${pod}
		break
	fi
done

max_messages=100
kafka_log_topics=( "cray-logs-containers" "cray-logs-syslog" )
# kafka_log_topics+=( "cray-logs-clusterstor" )
echo
echo "Kafka log consumer (max is ${max_messages}):"
echo
for topic in "${kafka_log_topics[@]}"
do
	tmpfile=$(mktemp /tmp/logging_health-${topic}.XXXXXX)
	start_time=$(date +%s)
	timeout -k 15 2m kubectl -n sma exec ${healthy_kafka} -c kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ${topic} --max-messages ${max_messages} > ${tmpfile} 2>/dev/null
	end_time=$(date +%s)
	count=$(cat $tmpfile | wc -l)
	len=$(cat $tmpfile | wc -c)
#	printf "\t%s: %'d\n" ${topic} ${count}
	echo "${count} ${topic} messages were found in $(($end_time - $start_time)) secs"
	if [ ${count} -eq 0 ]; then
		if [ "$topic" == "cray-logs-containers" ]; then
			echo "no container logs found in kafka"
			errs=$((errs+1))
		fi
	else
		echo "message length is ${len} bytes, $(( len / count )) bytes per message"
	fi
	echo
	rm ${tmpfile}
done

echo
kafka_persistent_dir="/var/lib/kafka/data"
for pod in "${kafka_pods[@]}"
do
	kafka_data=$(kubectl -n sma exec ${pod} -c kafka -- df -k ${kafka_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo "Kafka (${pod}) data usage= ${kafka_data}%"
	kubectl -n sma exec ${pod} -c kafka -- df -h ${kafka_persistent_dir}
	echo
	kubectl -n sma exec ${pod} -c kafka -- sh -c "du -hs ${kafka_persistent_dir}/kafka-log*/*" | grep cray-logs-containers | sort -rh
	echo
	kubectl -n sma exec ${pod} -c kafka -- sh -c "du -hs ${kafka_persistent_dir}/kafka-log*/*" | grep cray-logs-syslog | sort -rh
	echo
	kubectl -n sma exec ${pod} -c kafka -- sh -c "du -hs ${kafka_persistent_dir}/kafka-log*/*" | grep cray-logs-clusterstor | sort -rh
	echo
done

echo
if [ "$errs" -eq 0 ]; then
	echo "Log aggregation looks healthy"
else
	echoerr "Log aggregation is not healthy"
fi

exit ${errs}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
