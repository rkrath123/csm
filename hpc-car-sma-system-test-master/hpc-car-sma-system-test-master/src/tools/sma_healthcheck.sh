#!/bin/bash
# set -x

# This scripts checks if SMA looks healthy sending an email if not.

# Add to crontab, crontab -e
# check every 4 hours.
# 0 */4 * * * /root/sma-sos/sma_healthcheck.sh [EMAIL_ADDR] >> /tmp/sma_HEALTHREPORT.log 2>&1
# check every day at 5am
# 0 5 * * * /root/sma-sos/sma_healthcheck.sh [EMAIL_ADDR] >> /tmp/sma_HEALTHREPORT.log 2>&1

# Only one --ssa option or email option can be present.

# Check for optional -ssa option. If present always return 0 as the exit code.
ssa=false
if [ $# -ge 1 ]; then
	if [ $1 == "--ssa" ]; then
		ssa=true
	fi
fi

# Check for optional email address to send report.
email=
if [ $# -ge 1 ]; then
	if [[ $1 == *"@"* ]]; then
		email=$1
	fi
fi

# Only one optional argument.   Either EMAIL_ADDR or --saa.
if [ $# -ge 2 ]; then
	echo "$0: usage sma_healthcheck.sh [EMAIL_ADDR] | [--ssa]"
	exit 1
fi

header1="An error has been detected on VIEW for ClusterStor server ${server}.  Below is a list of reported errors.\n"
message="${header1}"

server=`hostname -f`
tag="($server sma_healthcheck)"
url="https://$server/auth"
cpu_usage_timer=60
memory_usage_limit=80
root_used_space=50
sma_used_space=75
jvm_heap_space=80
monasca_notification_restart_limit=10
seastream_zero_timestamp_limit=0
seastream_error_limit=10000
seastream_unpack_error_limit=0
seastream_metadata_error_limit=0
critical_alarms='Linux_node_metric_health|Loss_of_Job_Event_Daemon_Heartbeat'
jobstats_kafka_service_limit=300

sma_status="/root/sma-sos/sma_status.sh"
monasca_persister_logs="docker logs --tail all sma_monasca-persister_1"
monasca_notification_logs="docker logs --tail all sma_monasca-notification_1"
monasca_api_logs="docker logs --tail all sma_monasca_1"
seastream_logs="/etc/sma-data/seastream"
if [ ! -d ${seastream_logs} ]; then 
	seastream_logs="/var/log/sma/cray-seastream"
fi

errors=()

function exists()
{
	command -v "$1" >/dev/null 2>&1
}

function search_seastream_logs()
{
	echo "${seastream_logs} | grep $1"
	local count=`grep "$1" ${seastream_logs}/*.log | wc -l`
	return "$count"
}


exists "mailx"
if [ $? -ne 0 ]; then
	echo
	echo "Your system does not have mailx installed, mail notification disabled"
	email=
fi

start_time=$(date +'%s')
echo "Health check report generated at `date`"
echo
sma_release=$(cat /etc/opt/cray/release/sma-release)
sma_build=$(echo ${sma_release} | sed -e 's/ RPMS=.*//')
echo ${tag} ${sma_build}

install_log=$(ls -t /root/sma-install/*.log | head -n1)
install_date=$(stat -c "%y" ${install_log})
echo "${tag} INSTALL= ${install_date}"

# SMA configuration data
echo
retention_period=`cat /etc/sma-data/etc/.env | grep "RETENTION_POLICY_DURATION"`
alarm_recipient=`cat /etc/sma-data/etc/.env | grep "ALARM_RECIPIENT"`
system_names=$(docker exec sma_influxdb_1 influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "show tag values FROM /cray_job.d_open/ WITH KEY=\"system_name\"" | grep system_name | awk ' {print $2 }')
num_recv_bytes=$(docker exec sma_influxdb_1 influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_recv_bytes_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_xmit_bytes=$(docker exec sma_influxdb_1 influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_xmit_bytes_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_recv_pkts=$(docker exec sma_influxdb_1 influx --database 'mon'  --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_recv_pkts_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_xmit_pkts=$(docker exec sma_influxdb_1 influx --database 'mon'  --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_xmit_pkts_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)

echo "${tag} ${retention_period}"
echo "${tag} ${alarm_recipient}"

total_systems=0
total_osts=0
total_mdts=0

echo
echo "----- ClusterStor configs"
for system_name in ${system_names}
do
	num_mdts=$(docker exec sma_influxdb_1 influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "show tag values FROM /cray_job.d_open/ WITH KEY=\"device\" WHERE system_name='${system_name}'" | grep device | wc -l)
	num_osts=$(docker exec sma_influxdb_1 influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "show tag values FROM /cray_job.write_bytes_sec/ WITH KEY=\"device\" WHERE system_name='${system_name}'" | grep device | wc -l)
	echo "${system_name} (${num_mdts} MDTs ${num_osts} OSTs)"

	total_systems=$((total_systems+1))
	total_mdts=$((total_mdts+num_mdts))
	total_osts=$((total_osts+num_osts))
done
echo "${tag} ClusterStor systems: ${total_systems} (${total_mdts} MDTs ${total_osts} OSTs)"

echo
echo "----- site_config systems"
cat /etc/sma-data/etc/site_config.yaml | grep system

echo
echo "${tag} Infiniband guid/ports: ${num_recv_bytes} (${num_xmit_bytes} ${num_recv_pkts} ${num_xmit_pkts})"
echo

# server uptime and how long critical containers have been running
server_uptime=`uptime`

kafka_status=$(docker ps -f "name=sma_kafka_1" --format "table {{.Status}}")
influxdb_status=$(docker ps -f "name=sma_influxdb_1" --format "table {{.Status}}")
monasca_persister_status=$(docker ps -f "name=sma_monasca-persister_1" --format "table {{.Status}}")
elasticsearch_status=$(docker ps -f "name=sma_elasticsearch_1" --format "table {{.Status}}")

kafka_uptime=$(echo ${kafka_status} | sed -e 's/STATUS//')
influxdb_uptime=$(echo ${influxdb_status} | sed -e 's/STATUS//')
monasca_persister_uptime=$(echo ${monasca_persister_status} | sed -e 's/STATUS//')
elasticsearch_uptime=$(echo ${elasticsearch_status} | sed -e 's/STATUS//')

echo "${tag} SERVER uptime= ${server_uptime}"
echo "${tag} SMA uptimes= kafka:${kafka_uptime} influxdb:${influxdb_uptime} monasca-persister:${monasca_persister_uptime} elasticsearch:${elasticsearch_uptime}"

# Docker version
echo
docker_version=$(docker version --format '{{.Server.Version}}')
echo "docker server version ${docker_version}"
docker-compose -v

echo
docker ps -f name=sma_ --format "table {{.Names}}\t{{.CreatedAt}}\t{{.Status}}\t{{.RunningFor}}" | sort -k 1
echo
docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k 1
echo

# du -hs /var/log/sma/*
# du -hs /var/lib/docker/containers/*/*-json.log | sort -rh | head -10
# docker ps -qa | xargs docker inspect --format='{{.LogPath}}' | xargs ls -hl
# echo
# docker ps -qa | xargs docker inspect --format='{{println .Name}}{{println .Created}}{{println .Id}}'
# echo

dangling_images=$(docker images -q -f dangling=true | wc -l)
dangling_volumes=$(docker volume ls -qf dangling=true | wc -l)

echo "----- docker images/volumes"
echo "Dangling docker images=  ${dangling_images}"
echo "Dangling docker volumes= ${dangling_volumes}"
echo

# volumes=$(docker volume ls --format='{{.Name}}')
# for volume in ${volumes}; do
# 	echo ${volume}
# 	docker ps -a --filter volume=${volume} --format "table {{.Names}}\t{{.CreatedAt}}\t{{.Status}}\t{{.RunningFor}}"
# 	echo
# done

# sma status includes checks for unhealthy containers
echo "----- service status"
sma_services="ok"
${sma_status}
if [ $? -ne 0 ]; then
	errors=("${errors[@]}" "Not all SMA service(s) are running.  For details run '${sma_status}' on ${server}.\n")
	sma_services="failed"
fi
echo "${tag} SMA services= ${sma_services}"

echo
echo "----- ui availability"
wget --no-check-certificate -O /dev/null ${url} 2>/dev/null
if [ $? -ne 0 ]; then
	echo "${url} is not responding"
	errors=("${errors[@]}" "${url} is not responding.\n")
else
	echo "${url} is responding"
fi

# %us time spent in user mode by processes with a nice value above 0(applications)
# %sy time spent on system calls.
# %ni the time spent in user mode by processes with a nice value below 0 (background tasks)
cpu_usage=$(top -b -n 2 -d 1 | grep ^%Cpu | tail -n 1)
usage_percent=$(echo ${cpu_usage} | awk '{print $2+$4+$6}')

echo
echo "----- cpu"
echo "${tag} CPU usage= ${usage_percent}%"
echo ${cpu_usage}
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k 1
echo
echo "------ mpstat"
mpstat -u
echo
echo "------ pidstat"
pidstat -u -l -C "python|influx|java|docker|mysql"
echo
echo "------ top cpu usage%"
start_time=`date +%s`
while [ $(( $(date +%s) - ${cpu_usage_timer} )) -lt $start_time ]; do
        docker stats --no-stream --format \"{{.Name}}\\t{{.CPUPerc}}\" | sort -nrk 2 | head -n 5
		echo
done

memory_usage=`free -m | grep "^Mem"`
avail_memory=`echo ${memory_usage} | awk '{ print $2 }'`
used_memory=`echo ${memory_usage} | awk '{ print $3 }'`

used_percent=`expr $used_memory \* 100`
usage_percent=`expr $used_percent / $avail_memory`

echo
echo "----- memory"
echo "${tag} MEM usage= ${usage_percent}%"
echo ${memory_usage}
top -b -n 1 -p `pgrep influxd`
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | sort -k 1
if [ "${usage_percent}" -gt "${memory_usage_limit}" ]; then
	errors=("${errors[@]}" "Memory usage has reached ${usage_percent}% on the server.\n")
fi
echo

used_space=`df -k / | grep -v "Use" | awk '{ print $5}' | sed 's/%//g'`
docker_used_space=$(du -sh /var/lib/docker | sed -e 's?/var/lib/docker??')

echo
echo "---- root disk space"
echo "${tag} ROOT disk usage= ${used_space}%"
echo "${tag} DOCKER disk usage= ${docker_used_space}"
df -h /
docker system df
if [ "${used_space}" -gt "${root_used_space}" ]; then
	errors=("${errors[@]}" "Disk space used on server's root partition has reached ${used_space}%.  For details run 'docker system df' on ${server}.\n")
	errors=("${errors[@]}" "'docker volume prune' can be run to remove all unused volumes.\n")
fi

sma_data=`readlink /etc/sma-data`
used_space=`df -k ${sma_data} | grep -v "Use" | awk '{ print $5}' | sed 's/%//g'`

echo
echo "---- sma data disk space"
echo "${tag} SMA data usage= ${used_space}%"
df -h ${sma_data}
du -sh ${sma_data}/*
if [ "${used_space}" -gt "${sma_used_space}" ]; then
	errors=("${errors[@]}" "Disk space used on server's SMA data partition has reached ${used_space}%.\n")
fi

jobevents=$(docker exec sma_mysql_1 /bin/bash -c "echo select count\(*\),min\(start_app\),max\(start_app\) from jobevent_tbl | mysql -sN -t jobevents -u jobevent")
# Not sure why -s doesn't work with this query so strip grid with sed.
job_count=$(echo ${jobevents} | sed -e 's/[+\-]//g' | awk '{print $2}')

echo
echo "----- jobevent table"
echo "${tag} JOB count= ${job_count}"
docker exec sma_mysql_1 /bin/bash -c "echo select count\(*\),min\(start_app\),max\(start_app\) from jobevent_tbl | mysql -t jobevents -u jobevent"

# FIXME use kafkaconsumer script to search queue
if [ "$ssa" = false ] ; then
	echo
	echo "----- jobstats kafka service time"
	tmpfile=$(mktemp /tmp/sma_healthcheck-jobstats.XXXXXX)
	max_messages=10000
	echo "starting kafka dump (${max_messages} messages) at $(date -u) ($(date +%s))"
	start_time=$(date +%s)
	timeout -k 15 2m docker exec sma_kafka_1 /kafka/bin/kafka-console-consumer.sh --zookeeper zoo1:2181 --topic metrics --max-messages ${max_messages} | grep job_id > ${tmpfile}
	echo
	for system_name in ${system_names}
	do
			count=$(grep -c ${system_name} ${tmpfile})
			rc=$?
			echo "${system_name}: ${count} jobstat metrics were found"
			grep ${system_name} ${tmpfile} | tail -1
			if [ $rc -eq 0 ]; then
				metric_time=$(grep ${system_name} ${tmpfile} | tail -1 | python -m json.tool | grep timestamp | awk '{print $2}' | sed -e 's/.$//' | sed -e 's/000$//')
				delay_secs=$((${start_time} - ${metric_time}))
				delay_secs=${delay_secs#-}
				printf '%s %s jobstats to kafka service time is %dh:%dm:%ds\n' "$tag" "$system_name" $(($delay_secs/3600)) $(($delay_secs%3600/60)) $(($delay_secs%60))
				if [ "${delay_secs}" -gt "${jobstats_kafka_service_limit}" ]; then
					errors=("${errors[@]}" "Time for ${system_name} job metrics to reach kakfa has reached ${delay_secs} secs.  This is probably affecting usability of ${system_name} job metrics on ${server}.\n")
				fi
			fi
			echo
	done
	rm ${tmpfile}
fi

echo "----- monasca-persister influxdb client errors"
echo "${monasca_persister_logs} | grep InfluxDBClientError"
influxdb_errors=`${monasca_persister_logs} 2> /dev/null | grep InfluxDBClientError | wc -l`
echo "${influxdb_errors} influxdb client errors were found in the monasca persister logs"
if [ ${influxdb_errors} -gt 0 ]; then
	errors=("${errors[@]}" "Monasca persister logs indicate ${influxdb_errors} influxdb client errrors.  For details run '${monasca_persister_logs}' on ${server}.\n")
fi

echo
echo "----- monasca-persister influxdb server errors"
echo "${monasca_persister_logs} | grep InfluxDBServerError"
influxdb_errors=`${monasca_persister_logs} 2> /dev/null | grep InfluxDBServerError | wc -l`
echo "${influxdb_errors} influxdb server errors were found in the monasca persister logs"
if [ ${influxdb_errors} -gt 0 ]; then
	errors=("${errors[@]}" "Monasca persister logs indicate ${influxdb_errors} influxdb server errrors.  For details run '${monasca_persister_logs}' on ${server}.\n")
fi

echo
echo "----- monasca-persister kafka unavailable"
echo "${monasca_persister_logs} | grep KafkaUnavailableError"
kafka_unavailable=`${monasca_persister_logs} 2> /dev/null | grep KafkaUnavailableError | wc -l`
echo "${kafka_unavailable} kafka unavailable errors were found in the monasca persister logs"
if [ ${kafka_unavailable} -gt 0 ]; then
	errors=("${errors[@]}" "Monasca persister logs indicate ${kafka_unavailable} kafka unavailable errrors.  For details run '${monasca_persister_logs}' on ${server}.\n")
fi

echo
echo "----- monasca-notification restarts"
#echo "${monasca_notification_logs} | grep \"Waiting for MySQL to become available\""
#restarts=`${monasca_notification_logs} 2> /dev/null | grep "Waiting for MySQL to become available" | wc -l`
echo "${monasca_notification_logs} | grep \"Monasca notification starting\""
restarts=`${monasca_notification_logs} 2> /dev/null | grep "Monasca notification starting" | wc -l`
echo "${restarts} monasca notification restarts were found"
if [ "${restarts}" -gt ${monasca_notification_restart_limit} ]; then
	errors=("${errors[@]}" "Monasca notification container has restarted ${restarts} times. For details run '${monasca_notification_logs}' on ${server}.\n")
fi

echo
echo "----- monasca-api message size too large"
echo "${monasca_api_logs} | grep MessageSizeTooLargeError"
message_too_large=`${monasca_api_logs} 2> /dev/null | grep MessageSizeTooLargeError | wc -l`
echo "${message_too_large} message too large errors were found in the monasca api logs"
if [ ${message_too_large} -gt 0 ]; then
	errors=("${errors[@]}" "Monasca api logs indicate ${message_too_large} message too large errrors.  For details run '${monasca_api_logs}' on ${server}.\n")
fi

error_str=" error "
error_limit=${seastream_error_limit}
echo
echo "----- seastream '${error_str}'"
search_seastream_logs "${error_str}"
echo "$? seastream '${error_str}' errors were found"
if [ $? -gt ${error_limit} ]; then
	errors=("${errors[@]}" "Seastream logs indicate $? '${error_str}' errors. For details check '${seastream_logs}' on ${server}.\n")
fi

error_str="ZERO TIMESTAMP received"
error_limit=${seastream_zero_timestamp_limit}
echo
echo "----- seastream '${error_str}'"
search_seastream_logs "${error_str}"
echo "$? seastream '${error_str}' metrics were found"
if [ $? -gt ${error_limit} ]; then
	errors=("${errors[@]}" "Seastream logs indicate $? '${error_str}' metrics. For details check '${seastream_logs}' on ${server}.\n")
fi

error_str=" unpack_from "
error_limit=${seastream_unpack_error_limit}
echo
echo "----- seastream '${error_str}'"
search_seastream_logs "${error_str}"
echo "$? seastream '${error_str}' exceptions were found"
if [ $? -gt ${error_limit} ]; then
	errors=("${errors[@]}" "Seastream logs indicate $? '${error_str}' exceptions. For details check '${seastream_logs}' on ${server}.\n")
fi

error_str="Not able to find metadata for id"
error_limit=${seastream_metadata_error_limit}
echo
echo "----- seastream '${error_str}'"
search_seastream_logs "${error_str}"
echo "$? seastream '${error_str}' errors were found"
if [ $? -gt ${error_limit} ]; then
	errors=("${errors[@]}" "Seastream logs indicate $? '${error_str}' errors. For details check '${seastream_logs}' on ${server}.\n")
fi

echo
echo "----- numof streaming processes"
num_streaming_processes=( $(ps -ef | grep "python /usr/lib/python2.7/site-packages/monasca_seastream/streaming.py" | grep -v grep | wc -l) )
echo "${num_streaming_processes} SMA streaming processes were found"
if [ $(( ${num_streaming_processes} % 2)) -ne 0 ]; then 
	errors=("${errors[@]}" "Not all expected SMA streaming processes are running. For details run 'ps -ef | grep streaming.py' on ${server}.\n")
fi

if [ $(( ${num_streaming_processes} )) -eq 0 ]; then 
	errors=("${errors[@]}" "No SMA streaming processes are running on ${server}.\n")
fi

export PYTHONIOENCODING=utf8
jvm_heap_used=( $(docker exec -t sma_grafana_1 curl -s -S 'elasticsearch:9200/_cluster/stats' | \
    python -c "import sys, json; print json.load(sys.stdin)['nodes']['jvm']['mem']['heap_used_in_bytes']") )
jvm_heap_max=( $(docker exec -t sma_grafana_1 curl -s -S 'elasticsearch:9200/_cluster/stats' | \
    python -c "import sys, json; print json.load(sys.stdin)['nodes']['jvm']['mem']['heap_max_in_bytes']") )

jvm_used_percent=`expr $jvm_heap_used \* 100`
jvm_usage_percent=`expr $jvm_used_percent / $jvm_heap_max`

echo
echo "----- elasticsearch state"
echo "${tag} JVM HEAP usage= ${jvm_usage_percent}%"
echo "JVM heap used= ${jvm_heap_used} max= ${jvm_heap_max}"
if [ "${jvm_usage_percent}" -gt "${jvm_heap_space}" ]; then
	docker exec sma_grafana_1 curl -s -S -XGET 'elasticsearch:9200/_cluster/stats?human&pretty&pretty'
	errors=("${errors[@]}" "Elasticsearch JVM heap space used on server has reached ${jvm_usage_percent}%.\n")
fi

echo
echo "----- security key configuration for job event daemons"
num_consumers=0
image_id=$(docker images --format="{{.ID}}" cray_sma/utility)
consumers=$(docker run --rm --network sma_default --entrypoint /bin/sma-kafka-cli $image_id consumer list)
for consumer in ${consumers}
do
	num_consumers=$((num_consumers+1))
	consumer=$(echo ${consumer}|tr -d '\r')
	key=$(docker run --rm --network sma_default --entrypoint /bin/sma-kafka-cli $image_id secret list ${consumer})
	rc=$?
	key=$(echo $key|tr -d '\r')
	echo "${consumer} - secret key is '${key}'"
	if [ ${rc} -ne 0 ]; then
		errors=("${errors[@]}" "No secret is configured for a consumer. For details run '/root/sma-install/sma-kafka-cli secret list ${consumer}' on ${server}.\n")
	fi
done

if [ ${num_consumers} -eq 0 ]; then
	errors=("${errors[@]}" "No consumers are configured for job event daemons. For details run '/root/sma-install/sma-kafka-cli consumer list' on ${server}.\n")
fi

echo
echo "----- critical alarms"
alarms_container=$(docker images --format="{{.ID}}" cray_sma/alarms)
if [ -n "${alarms_container}" ]; then

	monasca_critical="$(docker run -i --name=check_alarms --network=sma_default -v /etc/sma-data:/etc/sma-data --rm $alarms_container monasca -j alarm-list --severity CRITICAL --state ALARM)"
	num_critical_alarms="$(echo ${monasca_critical} | sed -e 's/ \[ /\n\[ /g' | grep -E "${critical_alarms}" | wc -l)"

	monasca_undetermined="$(docker run -i --name=check_alarms --network=sma_default -v /etc/sma-data:/etc/sma-data --rm $alarms_container monasca -j alarm-list --severity CRITICAL --state UNDETERMINED)"
	num_undetermined_critical_alarms="$(echo ${monasca_undetermined} | sed -e 's/ \[ /\n\[ /g' | grep -E "${critical_alarms}" | wc -l)"

	num_critical_alarms=$((num_critical_alarms+num_undetermined_critical_alarms))

	echo "${tag} CRITICAL alarms= ${num_critical_alarms}"
	echo ${monasca_critical} | sed -e 's/ \[ /\n\[ /g' | grep -E "${critical_alarms}"
	echo ${monasca_undetermined} | sed -e 's/ \[ /\n\[ /g' | grep -E "${critical_alarms}"
	if [ ${num_critical_alarms} -gt 0 ]; then
		errors=("${errors[@]}" "Found ${num_critical_alarms} critical alarms. Check View's alarm page on ${server} for details.\n")
	fi
else
	echo "${tag} SMA alarms container not loaded"
fi

echo
echo "----- gui instrumentation"
ls -l /etc/sma-data/sma-webgui/instrumentation/*
num_logs=$(ls -l /etc/sma-data/sma-webgui/instrumentation/* | wc -l)
echo "${tag} GUI instrumentation logs: ${num_logs}"

echo "done in $(($(date +'%s') - $start_time)) seconds"

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
  		echo -e ${message} | mail -s "VIEW for ClusterStor on ${server} is reporting errors" ${email}
	fi
	if [ "$ssa" = false ] ; then
		exit 1
	else
		# For ssa always return 0 so the collection passes
		exit 0
	fi
fi
echo
echo "${tag} Health check passed"
if [ -n "${email}" ]; then
	echo "Sending mail to ${email}"
 	echo "Health check passed" | mail -s "VIEW for ClusterStor on ${server} is healthy" ${email}
fi
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
