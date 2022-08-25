#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. ${BINPATH}/sma_tools

function usage()
{
	echo "usage: $0 [EMAIL_ADDR]"
	echo
	echo "This scripts checks if SMA monitoring services appear healthy and optionally sending an email to report health."
	echo "$0 > sma_HEALTHCHECK-\`date +%Y%m%d.%H%M\` 2>&1"
	echo
	echo "Add to crontab on BIS NCN node (ncn-w001), for example check every 4 hours."
	echo "0 */4 * * * /tmp/sma-sos/sma_healthcheck.sh [EMAIL_ADDR] >> /tmp/sma-sos/sma_HEALTHREPORT.log 2>&1"
	echo "check every day at 5am"
	echo "0 5 * * * /tmp/sma-sos/sma_healthcheck.sh [EMAIL_ADDR] >> /tmp/sma-sos/sma_HEALTHREPORT.log 2>&1"
	exit 1
}

# Check for optional email address to send report.
email=
if [ $# -ge 1 ]; then
	if [[ $1 == *"@"* ]]; then
		email=$1
	else
		usage
	fi
fi

# Only one optional argument.
if [ $# -ge 2 ]; then
	usage
fi

binpath=`dirname "$0"`

system=$(get_system_name)
tag="(${system} sma_healthcheck)"
sma_status="${binpath}/sma_status.sh -q"
sma_log_health="${binpath}/sma_log_health.sh"
sma_postgres_health="${binpath}/sma_postgres_health.sh"
sma_kafka_health="${binpath}/sma_kafka_health.sh"
sma_svc_health="${binpath}/sma_svc_health.sh"
sma_telemetry_api_health="${binpath}/sma_telemetry_api_health.sh"
sma_postgres_dump="${binpath}/sma_postgres_dump.sh"
sma_ui_health="${binpath}/sma_ui_health.sh"

header1="An error has been detected in SMA on system ${system}.  Below is a list of reported errors.\n"
message="${header1}"

cpu_usage_timer=60
memory_usage_limit=80
root_used_space=50
sma_used_space=75
jvm_heap_space=80
high_job_latency_time=15

errors=()

function exists()
{
	command -v "$1" >/dev/null 2>&1
}

function run_cmd () {
	echo $@
	eval $@
}

function get_cstream_uid {
	kubectl -n sma get configmap cstream-config > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		unset uid
	else
		uid=$(kubectl -n sma get pods | grep sma-cstream | grep -v setup | awk '{ print $1 }')
		if [ $? -ne 0 ] ; then
			unset uid
		fi
	fi
	echo $uid
}

# Pod uids
mysql_uid=$(kubectl -n sma get pods | grep mysql |  grep -v init | grep -v monasca-mysql | awk '{ print $1 }')
postgres_uid=$(get_postgres_leader)
kafka_uid=$(get_kafka_pod)
ldms_aggr_compute_uid=$(kubectl -n sma get pods | grep sma-ldms-aggr-compute | awk '{ print $1 }')
ldms_aggr_sms_uid=$(kubectl -n sma get pods | grep sma-ldms-aggr-sms | awk '{ print $1 }')
ldms_aggr_pods=( ${ldms_aggr_compute_uid} ${ldms_aggr_sms_uid} )
telemetry_uid=$(kubectl -n sma get pods | grep telemetry | awk '{ print $1 }' | head -1 )
cstream_uid=$(get_cstream_uid)

kafka_pods=( "cluster-kafka-0" "cluster-kafka-1" "cluster-kafka-2" )
zoo_pods=( "cluster-zookeeper-0" "cluster-zookeeper-1" "cluster-zookeeper-2" )
#elasticsearch_pods=( "elasticsearch-0" "elasticsearch-data-0" "elasticsearch-master-0" )
elasticsearch_pods=( "elasticsearch-0" )
postgres_pods=( "craysma-postgres-cluster-0" "craysma-postgres-cluster-1" )
postgres_persister_pods=( "postgres-persister-node" "postgres-persister-job" "postgres-persister-lustre" )

elasticsearch_url="$(kubectl -n sma get services | grep elasticsearch | grep -v elasticsearch-curator | awk '{ print $3 }'):9200"
# elasticsearch_url="$(kubectl -n sma get services | grep elasticsearch | grep NodePort | awk '{print $3}'):9200"

exists "mailx"
if [ $? -ne 0 ]; then
	echo
	echo "Your system does not have mailx installed, mail notification disabled"
	email=
fi

echo "Health check report generated at `date`"
echo
cat /etc/motd
echo
show_shasta_config

if [ -f "/etc/cray-release" ]; then
	echo
	stream=$(cat /etc/cray-release | grep STREAM)
	version=$(cat /etc/cray-release | grep version)
	uid=$(cat /etc/cray-release | grep UID)
	install_date=$(cat /etc/cray-release | grep DOI)
	install_time=$(cat /etc/cray-release | grep TOI)
	echo ${tag} "Release ${stream} ${version}"
	echo ${tag} "Install ${install_date} ${install_time}"
	echo ${tag} "Blob ${uid}"
fi

all_ncn_nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)

echo
show_shasta_config

echo
# node uptimes/load average
for node in ${all_ncn_nodes}
do
	ping -c 3 $node
	if [ $? -eq 0 ]; then
		uptime=$(ssh -o "StrictHostKeyChecking=no" $node uptime)
		echo "${tag} ${node} uptime is ${uptime}"
	else
		echo "${tag} ${node} is unreachable"
	fi
done

# Kubernetes version (kubectl version -o yaml)
echo
server_version=$(kubectl version --short | grep Server)
client_version=$(kubectl version --short | grep Client)
docker_version=$(docker version --format '{{.Server.Version}}')

echo "kubernetes ${server_version} ${client_version}"
echo "docker server version ${docker_version}"

echo
if [ -n "${cstream_uid-}" ]; then
	echo "Your system has ClusterStor monitoring configured"
else
	echo "Your system does not have ClusterStor monitoring configured"
fi

echo
kubectl get nodes

# Check for notready node.  Could be intermittent so check it more than once.
for ((i=1;i<=25;i++));
do
	notready=$(kubectl get nodes | grep NotReady)
	if [ $? -eq 0 ]; then
		echo ${notready}
		node=$(echo ${notready} | awk '{ print $1 }' | head -1)
		errors=("${errors[@]}" "NCN node ${node} is not ready\n")
		break
	fi
done

echo
echo "----- pods "
kubectl -n sma get pods -o wide
echo
kubectl -n services get pods -o wide | egrep -i 'kibana|grafana|telemetry-api'

echo
echo "----- jobs "
kubectl -n sma get jobs -o wide
echo
kubectl -n services get jobs -o wide | egrep -i 'grafana'

echo
echo "----- services "
kubectl -n sma get services -o wide  --sort-by=.metadata.name

echo
echo "----- storage "
kubectl -n sma get pvc

# echo
# echo "----- resources "
# kubectl -n sma get pods -o yaml
# kubectl -n services get pods -o yaml

echo
docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -v NAME | sort -k 1 | grep sma

dangling_images=$(docker images -q -f dangling=true | wc -l)
dangling_volumes=$(docker volume ls -qf dangling=true | wc -l)

echo
echo "----- docker images/volumes"
echo "Dangling docker images=  ${dangling_images}"
echo "Dangling docker volumes= ${dangling_volumes}"
echo

# sma status includes checks for container restarts
echo
if [[ -x "${sma_status}" ]]; then
	echo "----- service status"
	sma_services="ok"
	${sma_status} -q
	if [ $? -ne 0 ]; then
		if [ $? -eq 1 ]; then
			errors=("${errors[@]}" "Not all SMA service(s) are running.  For details run '${sma_status}' on ${system}\n")
		else
			errors=("${errors[@]}" "Unexpected restarts of SMA service(s).  For details run '${sma_status}' on ${system}\n")
		fi
		sma_services="failed"
	fi
	echo "${tag} SMA services= ${sma_services}"
fi

echo
echo "----- kubernetes node resources"
for node in ${all_ncn_nodes}
do
	kubectl -n sma describe node ${node}
	echo
done

echo
kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n"

conditions=0
ready=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n" | grep "Ready=False")
conditions=$((conditions+ready))

memory_pressure=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n" | grep "MemoryPressure=True")
conditions=$((conditions+memory_pressure))

disk_pressure=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n" | grep "DiskPressure=True")
conditions=$((conditions+disk_pressure))

pid_pressure=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n" | grep "PIDPressure=True")
conditions=$((conditions+pid_pressure))

network=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}'| tr ';' "\n" | grep "NetworkUnavailable=True")
conditions=$((conditions+network))

if [ "${conditions}" -gt 0 ]; then
	errors=("${errors[@]}" "Kubernetes is reporting failing one or more nodes with failing conditions.  For details run 'kubectl get nodes'.\n")
fi

echo
for node in ${all_ncn_nodes}
do
	requests=$(kubectl -n sma describe node $node | grep -A2 -E "\\s*Requests" | tail -n1)
	percent_cpu=$(echo $requests | awk -F "[()%]" '{print $2}')

	requests=$(kubectl describe node $n | grep -A3 -E "\\s*Requests" | tail -n1)
	percent_mem=$(echo $requests | awk -F "[()%]" '{print $2}')

	echo "${tag} Kube ${node} cpu= ${percent_cpu}% mem= ${percent_mem}%"

	if [ "${percent_cpu}" -gt "100" ]; then
		errors=("${errors[@]}" "Kubernetes is reporting cpu usage has reached ${percent_cpu}% on the $node.\n")
	fi

	if [ "${percent_mem}" -gt "100" ]; then
		errors=("${errors[@]}" "Kubernetes is reporting memory usage has reached ${percent_mem}% on the $node.\n")
	fi
done

# %us time spent in user mode by processes with a nice value above 0(applications)
# %sy time spent on system calls.
# %ni the time spent in user mode by processes with a nice value below 0 (background tasks)

echo
echo "----- top node resources"
kubectl top node
echo
for node in ${all_ncn_nodes}
do
	ping -c 3 $node
	if [ $? -eq 0 ]; then
		kubectl describe node $node
		echo
#		cpu_usage=$(pdsh -w $node top -b -n 2 -d 1 | grep %Cpu | tail -n 1)
	 	cpu_usage=$(ssh -o "StrictHostKeyChecking=no" $node top -b -n 2 -d 1 | grep %Cpu | tail -n 1)
		cpu_usage_percent=$(echo ${cpu_usage} | awk '{print $3+$5+$7}')

		memory_usage=$(ssh -o "StrictHostKeyChecking=no" ${node} free -m | grep "Mem")
		avail_memory=$(echo ${memory_usage} | awk '{ print $3 }')
		used_memory=$(echo ${memory_usage} | awk '{ print $4 }')
		used_percent=$(expr $used_memory \* 100)
		mem_usage_percent=$(expr $used_percent / $avail_memory)

		echo
		echo "${tag} Top ${node} cpu= ${cpu_usage_percent}% mem= ${mem_usage_percent}%"
#		if [ "${mem_usage_percent}" -gt "${memory_usage_limit}" ]; then
#			errors=("${errors[@]}" "Memory usage has reached ${mem_usage_percent}% on the $node.\n")
#		fi
		echo
		echo ${cpu_usage}
		echo
		ssh -o "StrictHostKeyChecking=no" $node free -mh
		echo
		ssh -o "StrictHostKeyChecking=no" $node COLUMNS=1000 top -o RES -c -n 1 -b | head -15
		echo
	fi
done

echo
echo "------ mpstat"
for node in ${all_ncn_nodes}
do
	ping -c 3 $node
	if [ $? -eq 0 ]; then
		ssh -o "StrictHostKeyChecking=no" $node mpstat -u 2>/dev/null
	fi
done

# Memory requests and limits are associated with Containers, but it is useful to think of a Pod 
# as having a memory request and limit. The memory request for the Pod is the sum of the 
# memory requests for all the Containers in the Pod. Likewise, the memory limit for the Pod 
# is the sum of the limits of all the Containers in the Pod.
# The memory resource is measured in bytes.
# https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/

echo
echo "----- pod memory resources"
kubectl top pod -n sma --no-headers | sort --reverse --key 3 --numeric

# CPU requests and limits are associated with Containers, but it is useful to think of a Pod 
# as having a CPU request and limit. The CPU request for a Pod is the sum of the CPU requests 
# for all the Containers in the Pod. Likewise, the CPU limit for a Pod is the sum of the CPU 
# limits for all the Containers in the Pod.
# 746m (the suffix m to mean milli) is milliCPU which is less than 1 CPU
# https://kubernetes.io/docs/tasks/configure-pod-container/assign-cpu-resource/#cpu-units

echo
echo "----- pod cpu resources"
kubectl top pod -n sma --no-headers | sort --reverse --key 2 --numeric

used_space=`df -k / | grep -v "Use" | awk '{ print $5}' | sed 's/%//g'`
docker_used_space=$(du -sh /var/lib/docker | sed -e 's?/var/lib/docker??')

# if [ -x "$(command -v ceph)" ]; then
ceph status >/dev/null 2>&1
if [ $? -eq 0 ]; then
	echo
	echo "---- ceph health"
	ceph status
	ceph osd stat
	ceph mon stat

	health=$(ceph health | awk '{ print $1}')
	if [ ${health} == "HEALTH_ERR" ]; then
		echo "Ceph cluster is not healthy"
		errors=("${errors[@]}" "Ceph cluster is not healthy.\n")
	fi

	ceph status| grep degraded
	if [ $? -eq 0 ]; then
		echo "Ceph cluster looks to be degraded"
		errors=("${errors[@]}" "Ceph cluster looks to be degraded.\n")
	fi
fi

echo
echo "---- root disk space"
echo "${tag} Root disk usage= ${used_space}%"
echo "${tag} Docker disk usage= ${docker_used_space}"
echo
df -h /
docker system df
if [ "${used_space}" -gt "${root_used_space}" ]; then
	errors=("${errors[@]}" "Disk space used on system's root partition has reached ${used_space}%.  For details run 'docker system df' on ${system}.\n")
	errors=("${errors[@]}" "\t'docker volume prune' can be run to remove all unused volumes.\n")
fi

mysql_persistent_dir="/var/lib/mysql"
cstream_logs="/var/log/cray-seastream"

mysql_data=$(kubectl -n sma exec ${mysql_uid} -- df -k ${mysql_persistent_dir}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')

echo
echo "${tag} MySQL data usage= ${mysql_data}%"
kubectl -n sma exec ${mysql_uid} -- df -h ${mysql_persistent_dir}
echo
kubectl -n sma exec ${mysql_uid} -- df -h

if [ -n "${cstream_uid-}" ]; then
	cstream_data=$(kubectl -n sma exec ${cstream_uid} -- df -k ${cstream_logs}| grep -v "Use" | awk '{ print $5}' | sed 's/%//g')
	echo
	echo "${tag} Cstream log usage= ${cstream_data}%"
	kubectl -n sma exec ${cstream_uid} -- df -h ${cstream_logs}
	kubectl -n sma exec ${cstream_uid} -- ls -lh ${cstream_logs}
	echo
	kubectl -n sma exec ${cstream_uid} -- df -h
fi

if [[ -x "${sma_svc_health}" ]]; then
	echo
	echo "----- sma services health"
	echo
	${sma_svc_health}
	health="ok"
	if [ $? -ne 0 ]; then
		errors=("${errors[@]}" "SMA services does not look healthy.  For details run '${sma_services_health}' on ${system}\n")
		health="failed"
	fi
	echo "${tag} SMA services health= ${health}"
fi

echo
echo "----- sma databases"
# postgres
postgres_tables=$(kubectl -n sma exec ${postgres_uid} -- /bin/sh -c "echo '\dt sma.*' | psql -d sma -U postgres")
expected_tables=( "ldms_data" "ldms_device" "ldms_host" "seastream_data" "seastream_device" "seastream_host" )
echo "PostgreSQL sma tables" 
for table in "${expected_tables[@]}"
do
	echo -n "${table} "
	echo ${postgres_tables} | grep -e ${table} >/dev/null
	if [ $? -eq 0 ]; then
		echo "...ok"
	else
		echo "...not found"
		errors=("${errors[@]}" "Postgres SMA table '${table}' was not found.\n")
	fi
done

echo
# mysql
mysql_databases=$(kubectl -n sma exec ${mysql_uid} -- /bin/sh -c "echo 'show databases;' | mysql -u root -psecretmysql")
expected_databases=( "keystone" "grafana" "jobevents" )
echo "----- mysql sma databases" 
for db in "${expected_databases[@]}"
do
	echo -n "${db} "
	echo ${mysql_databases} | grep -e ${db} >/dev/null
	if [ $? -eq 0 ]; then
		echo "...ok"
	else
		echo "...not found"
		errors=("${errors[@]}" "Mysql SMA database '${db}' was not found.\n")
	fi
done

echo
echo "----- logging services"
# elasticsearch
es_health=$(curl -s -S -XGET "${elasticsearch_url}?pretty=true" 2>/dev/null)
if [ $? -ne 0 ]; then
	echo "Elasticsearch is not healthy"
	errors=("${errors[@]}" "Elasticsearch is not healthy.\n")
else
	curl -s -S -XGET "${elasticsearch_url}/_cat/health?pretty=true"
	curl -s -S -XGET "${elasticsearch_url}/_cluster/stats?human&pretty&pretty"

	jvm_heap_used=$(curl -s -S -XGET "${elasticsearch_url}/_cluster/stats" | jq .nodes.jvm.mem.heap_used_in_bytes)
	jvm_heap_max=$(curl -s -S -XGET "${elasticsearch_url}/_cluster/stats" | jq .nodes.jvm.mem.heap_max_in_bytes)

	jvm_used_percent=`expr $jvm_heap_used \* 100`
	jvm_usage_percent=`expr $jvm_used_percent / $jvm_heap_max`

	echo "${tag} Elasticsearch JVM HEAP usage= ${jvm_usage_percent}%"
	echo "JVM heap used= ${jvm_heap_used} max= ${jvm_heap_max}"
	if [ "${jvm_usage_percent}" -gt "${jvm_heap_space}" ]; then
		curl -s -S -XGET "${elasticsearch_url}/_cluster/stats" | jq .nodes.jvm
		errors=("${errors[@]}" "Elasticsearch JVM heap space used on system has reached ${jvm_usage_percent}%.\n")
	fi

	echo
	expected_es_indices=( "shasta-logs" ".kibana" )
	if [ -n "${cstream_uid-}" ]; then
		expected_es_indices+=( "clusterstor-logs" )
	fi

	for index in "${expected_es_indices[@]}"
	do
		curl -s -S -XGET "${elasticsearch_url}/_cat/indices" | grep ${index}
		if [ $? -ne 0 ]; then
			errors=("${errors[@]}" "Elasticsearch index '${index}' was not found on ${system}.\n")
		else
			log_count=$(curl -s -S -XGET ${elasticsearch_url}/${index}*/_count | jq .count)
			num_shards=$(curl -s -S -XGET ${elasticsearch_url}/${index}*/_count | jq ._shards.total)
			failed_shards=$(curl -s -S -XGET ${elasticsearch_url}/${index}*/_count | jq ._shards.failed)
			if [ "${failed_shards}" -gt 0 ]; then
				errors=("${errors[@]}" "Elasticsearch index ${index} has failed shards ${failed_shards}.\n")
			fi
			echo
			echo "log count '${index}'= ${log_count} num of shards= ${num_shards}"
			curl -s -S -XGET ${elasticsearch_url}/${index}*/_count?pretty
		fi
	done

	if [[ -x "${sma_log_health}" ]]; then
		echo
		echo "----- log health"
		${sma_log_health} ${tag}
		health="ok"
		if [ $? -ne 0 ]; then
			errors=("${errors[@]}" "Log aggregation does not look healthy.  For details run '${sma_log_health}' on ${system}\n")
			health="failed"
		fi
		echo "${tag} Log aggregation health is ${health}"
	fi
fi

echo
echo "----- kibana health"
err=0
kibana_health=$(curl -s -S -XGET "${SMA_API_GATEWAY}/sma-kibana/api/status?pretty=true")
if [ $? -ne 0 ]; then
	mesg="Kibana is not healthy - failed to access"
	echo ${mesg}
	errors=("${errors[@]}" "${mesg}.\n")
	err=$((err+1))
else
	state=$(echo ${kibana_health} | jq .status.overall.state)
	echo ${state} | grep green >/dev/null 2>&1
	echo ${kibana_health} | jq .
	if [ $? -ne 0 ]; then
		mesg="Kibana is not healthy - status is ${state}"
		errors=("${errors[@]}" "${mesg}.\n")
		err=$((err+1))
	fi
fi
if [ "$err" -eq 0 ]; then
	echo "Kibana looks healthy"
fi

echo
echo "----- grafana health"
err=0
grafana_health=$(curl -s -S -XGET "${SMA_API_GATEWAY}/sma-grafana/api/health?pretty=true")
if [ $? -ne 0 ]; then
	mesg="Grafana is not healthy - failed to access"
	echo ${mesg}
	errors=("${errors[@]}" "${mesg}.\n")
	err=$((err+1))
fi
if [ "$err" -eq 0 ]; then
	echo "Grafana looks healthy"
fi

echo
echo "----- postgres cluster health"
echo
${sma_postgres_health}
health="ok"
if [ $? -eq 0 ]; then
	${sma_postgres_dump}
else
	errors=("${errors[@]}" "Postgres cluster does not look healthy.  For details run '${sma_postgres_health}' on ${system}\n")
	health="failed"
fi
echo
echo "${tag} Postgres cluster health is ${health}"

echo
echo "----- kafka cluster health"
echo
${sma_kafka_health}
health="ok"
if [ $? -ne 0 ]; then
	errors=("${errors[@]}" "Kafka cluster does not look healthy.  For details run '${sma_kafka_health}' on ${system}\n")
	health="failed"
fi
echo
echo "${tag} Kafka cluster health is ${health}"

echo
echo "----- telemetry api health"
echo
${sma_telemetry_api_health}
health="ok"
if [ $? -ne 0 ] ; then
	errors=("${errors[@]}" "Telemetry API does not look healthy.  For details run '${sma_telemetry_health}'  on ${system}.\n")
	health="failed"
fi
echo "${tag} Telemetry api health is ${health}"

echo
echo "----- ui health"
echo
${sma_ui_health}
health="ok"
if [ $? -ne 0 ] ; then
	errors=("${errors[@]}" "SMF ui does not look healthy.  For details run '${sma_ui_health}'  on ${system}.\n")
	health="failed"
fi
echo "${tag} SMF ui is ${health}"

postgres_persister_errors=( "Metric stream not supported in" "server terminated abnormally" "Unexpected Integer key" )
ldms_errors=( "Invalid required acks value" )
# ldms_errors=( "Invalid required acks value" "Local: Message timed out" "connection error" )

echo
for pod in "${postgres_persister_pods[@]}"
do
	postgres_persister_uid=$(kubectl -n sma get pods | grep ${pod} | awk '{ print $1 }' | head -1 )
	get_postgres_persister_logs="kubectl -n sma logs ${postgres_persister_uid}"
	for search in "${postgres_persister_errors[@]}"
	do
		echo
		echo "----- postgres-persister (${pod}) '${search}'"
		echo "${get_postgres_persister_logs} | grep '${search}'"
		found=`${get_postgres_persister_logs} 2> /dev/null | grep "${search}" | wc -l`
		echo "${found} '${search}' errors were found in the postgres persister logs"
		if [ ${found} -gt 0 ]; then
			errors=("${errors[@]}" "Postgres persister {${pod}) logs indicate ${found} '${search}' errors.  For details run '${get_postgres_persister_logs}' on ${system}.\n")
		fi
	done
done

for pod in "${ldms_aggr_pods[@]}"
do
	get_ldms_aggr_logs="kubectl -n sma logs ${pod}"
	for search in "${ldms_errors[@]}"
	do
		echo
		echo "----- ${pod} '${search}'"
		echo "${get_ldms_aggr_logs} | grep '${search}'"
		found=`${get_ldms_aggr_logs} 2> /dev/null | grep "${search}" | wc -l`
		echo "${found} '${search}' errors were found in the LDMS aggr logs"
		if [ ${found} -gt 0 ]; then
		    errors=("${errors[@]}" "LDMS aggr logs indicate ${found} '${search}' errors.  For details run '${get_ldms_aggr_logs}' on ${system}.\n")
		fi
	done
done

kafka_topics=( "cray-node" )
kafka_topics+=( "cray-telemetry-power" "cray-telemetry-temperature" "cray-telemetry-voltage" "cray-telemetry-pressure" "cray-telemetry-fan" "cray-telemetry-energy" )
kafka_topics+=( "cray-fabric-telemetry" "cray-fabric-perf-telemetry" "cray-fabric-crit-telemetry" )
if [ -n "${cstream_uid-}" ]; then
	kafka_topics+=( "cray-lustre" "cray-job" )
fi
max_messages=100
for topic in "${kafka_topics[@]}"
do
	echo
	echo "----- kafka ${topic} topic (max is ${max_messages})"
	tmpfile=$(mktemp /tmp/sma_healthcheck-${topic}.XXXXXX)
#	echo "starting dump (${max_messages} messages) at $(date -u) ($(date +%s))"
	start_time=$(date +%s)
	timeout -k 15 1m kubectl -n sma exec ${kafka_uid} -c kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ${topic} --max-messages ${max_messages} > ${tmpfile} 2>/dev/null
	end_time=$(date +%s)
	# LDMS kafka data has an extra new-line.
	if [ "$topic" == "cray-node" ]; then
		count=$(cat $tmpfile | grep metric | wc -l)
	else
		count=$(cat $tmpfile | wc -l)
	fi
	rc=$?
	echo "${count} ${topic} messages were found in $(($end_time - $start_time)) secs" 
	if [ $count -eq 0 ]; then
		errors=("${errors[@]}" "No ${topic} messages found in Kafka.\n")
	else
		if [ "$topic" == "cray-node" ]; then
			len=$(cat $tmpfile | grep metric | wc -c)
		else
			len=$(cat $tmpfile | wc -c)
		fi
		echo "message length is ${len} bytes, $(( len / count )) bytes per message"
	fi
	rm ${tmpfile}
done

echo
is_ldms_on_computes
if [ $? -eq 0 ]; then
	echo "Ldms configuration on computes looks ok"
else
	echo "Ldms configuration on computes is not okay"
fi
echo

topic="cray-node"
tmpfile=$(mktemp /tmp/sma_healthcheck-${topic}.XXXXXX)
max_messages=5000
timeout -k 15 1m kubectl -n sma exec ${kafka_uid} -c kafka -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic ${topic} --max-messages ${max_messages} > ${tmpfile} 2>/dev/null

ldms_system_name=( "ncn" "compute" )
for name in "${ldms_system_name[@]}"
do
	echo
	echo "----- ldms ${name} system name"
	count=$(cat $tmpfile | grep ${name} | wc -l)
	rc=$?
	echo "${count} ldms ${name} metrics were found"
	if [ $count -eq 0 ]; then
		errors=("${errors[@]}" "No ldms ${name} metrics found in Kafka.\n")
	else
		len=$(cat $tmpfile | grep "\"system\":\"${name}\"" | wc -c)
		echo "message length is ${len} bytes, $(( len / count )) bytes per message"
	fi
done

component_name=( "cray_iostat" "cray_vmstat" "cray_ethtool" "cray_mellanox" )
for name in "${component_name[@]}"
do
	echo
	echo "----- ldms ${name} component name"
	count=$(cat $tmpfile | grep "\"component\":\"${name}\"" | wc -l)
	rc=$?
	echo "${count} ldms ${name} metrics were found"
	if [ $count -eq 0 ]; then
		errors=("${errors[@]}" "No ldms ${name} metrics found in Kafka.\n")
	else
		len=$(cat $tmpfile | grep ${name} | wc -c)
		echo "message length is ${len} bytes, $(( len / count )) bytes per message"
	fi
done

rm ${tmpfile}

echo
if [ "${#errors[@]}" -gt 0 ]; then
	for error in "${errors[@]}"
	do
		message="${message} ${error}"
	done

	echo
	echo "${tag} Health check *FAILED*"
	echo -e ${message}
	if [ -n "${email}" ]; then
		echo "Sending mail to ${email}"
  		echo -e ${message} | mail -s "SMA monitoring services on ${system} are reporting errors" ${email}
	fi
	exit 1
fi
echo
echo "${tag} Health check passed"
if [ -n "${email}" ]; then
	echo "Sending mail to ${email}"
 	echo "Health check passed" | mail -s "SMA monitoring services on ${system} are healthy" ${email}
fi
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
