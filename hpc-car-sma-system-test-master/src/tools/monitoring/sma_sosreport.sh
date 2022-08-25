#!/bin/bash
set -o nounset
set -o pipefail
# set -o xtrace
# set -o errexit

BINPATH=`dirname "$0"`
. ${BINPATH}/sma_tools

# default report name and directory path
report_name="sma-SOSreport-`date +%Y%m%d.%H%M`"
report="/tmp/${report_name}"

function usage()
{
	echo "usage: $0"
	echo
	echo "sma_sosreport.sh command is a tool that collects SMF configuration details, system information, SMA docker"
	echo "logs and diagnostics information from the SMS node and stores this output in a compress tar file."
	echo
	echo "$0 [-d /path/to/a/directory]"
	echo
	echo "-d full path to report directory, default is /tmp"
	echo
	exit 1
}

while getopts hd: option
do
	case "${option}"
	in
		d) report="${OPTARG}/${report_name}";;
		h) usage;;
	esac
done
shift $((OPTIND-1))

if [ $# -gt 0 ]; then
	usage
fi

report_dir=`dirname ${report}`
if [ ! -d ${report_dir} ]; then
	echo "Directory ${report_dir} does not exist"
	exit 1
fi

timeout_opts="-k 15 1m"
numof_lines=100

kafka_topics=("cray-lustre" "cray-job" "cray-node" "cray-logs-containers" "cray-logs-syslog" "cray-logs-clusterstor")

# find a healthy kafka instance in the cluster
kafka_pod=$(get_kafka_pod)

container_logs=${report}_container_logs.gz
previous_container_logs=${report}_previous_container_logs.gz
describe_pods=${report}_describe_pods.txt
describe_jobs=${report}_describe_jobs.txt
log_health=${report}_log_health.txt

tar_files=`basename ${report}`
cleanup_files=${report}

server=`hostname`
all_ncn_nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
ncn_node=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | head -n 1)

compute_nodes=("nid000001-nmn" "nid000002-nmn" "nid000003-nmn" "nid000004-nmn")
num_computes=$(curl -s http://api-gw-service-nmn.local/apis/bss/boot/v1/dumpstate | jq '.Components[].Role' | grep Compute | wc -l)

ldms_aggr_compute_uid=$(kubectl -n sma get pods | grep sma-ldms-aggr-compute | awk '{ print $1 }')
ldms_aggr_sms_uid=$(kubectl -n sma get pods | grep sma-ldms-aggr-sms | awk '{ print $1 }')
ldms_aggr_pods=( ${ldms_aggr_compute_uid} ${ldms_aggr_sms_uid} )

rsyslog_collector_uid=$(kubectl -n sma get pods | grep rsyslog-collector | awk '{ print $1 }')
rsyslog_aggregator_uid=$(kubectl -n sma get pods | grep rsyslog-aggregator | awk '{ print $1 }')
rsyslog_pods=( ${rsyslog_collector_uid} ${rsyslog_aggregator_uid} )

elasticsearch_url="$(kubectl -n sma get services | grep elasticsearch | grep -v elasticsearch-curator | awk '{ print $3 }'):9200"

function verbose() {
	echo $*
}

function run_cmd() {
	eval $* >> ${report} 2>&1
	echo "" >> ${report} 2>&1
}

function run_ncn_nodes() {
	for node in ${all_ncn_nodes}; do
#		pdsh -w ${node} "eval $*" | dshbak >> ${report} 2>&1
 		ssh -o "StrictHostKeyChecking=no" ${node} "eval $*" >> ${report} 2>&1
	done
	echo "" >> ${report} 2>&1
}

function run_compute_nodes() {
	for node in "${compute_nodes[@]}"; do
#		pdsh -w ${node} "eval $*" 2> /dev/null | dshbak >> ${report} 2>&1
 		ssh -o "StrictHostKeyChecking=no" ${node} "eval $*" >> ${report} 2>&1
	done
	echo "" >> ${report} 2>&1
}

function cat_file() {
	for file in $*
	do
		if [ -f $file ]; then
			echo "----- $file" |& tee -a ${report}
			run_cmd ls -al $file
			run_cmd cat $file
			echo "" >> ${report} 2>&1
		fi
	done
}

function tail_file() {
	for file in $*
	do
		if [ -f $file ]; then
			echo "----- $file" |& tee -a ${report}
			run_cmd ls -l $file
			run_cmd tail -f ${numof_lines} $file
			echo "" >> ${report} 2>&1
		fi
	done
}

function add_tarball() {
	echo "adding file `basename $*`" >> ${report} 2>&1
	tar_files="$tar_files `basename $*`"
	cleanup_files="$cleanup_files $*"
	chmod 444 $*
	echo "" >>${report} 2>&1
}

function add_text() {
 	echo "adding file `basename $*`" >> ${report} 2>&1
	head -n 20 $* >> ${report} 2>&1
	tar_files="$tar_files `basename $*`"
	cleanup_files="$cleanup_files $*"
	chmod 444 $*
	echo "" >>${report} 2>&1
}

function get_pod_uid {
	uid=$(kubectl -n sma get pods | grep $1 |  awk '{ print $1 }')
	if [ $? -ne 0 ] ; then
		unset uid
	fi
	echo $uid
}

rm -f ${report}
start_time=$(date +'%s')
echo `date` >${report}
echo "sma tools version is ${SMA_TOOLS_VERSION}" >> ${report}

echo "----- motd" |& tee -a ${report}
run_cmd cat /etc/motd

echo "----- cpu" |& tee -a ${report}
run_cmd lscpu

echo "----- block devices" |& tee -a ${report}
run_cmd lsblk

echo "----- memory" |& tee -a ${report}
run_ncn_nodes free -h -lm
run_ncn_nodes vmstat -s -SM

echo "----- uptime" |& tee -a ${report}
run_ncn_nodes uptime

echo "----- ps -eaF" |& tee -a ${report}
run_ncn_nodes ps -aeF

echo "----- top sort res" |& tee -a ${report}
run_ncn_nodes COLUMNS=1000 top -o RES -c -n 1 -b

# Check where sma-data is mounted
echo "----- mount" |& tee -a ${report}
run_ncn_nodes mount

echo "----- disk space" |& tee -a ${report}
run_ncn_nodes df -h /

echo "----- sysctl values" |& tee -a ${report}
run_ncn_nodes sysctl net.ipv4.tcp_keepalive_time
run_ncn_nodes sysctl vm.max_map_count
# FIXME-command hung on one View server so removed it
# run_cmd sysctl -a

echo "----- shasta release" |& tee -a ${report}
run_cmd cat /etc/cray-release

echo "----- shasta config" |& tee -a ${report}
echo "shasta master, worker, storage nodes= ${all_ncn_nodes}" >> ${report}
echo "shasta compute count= ${num_computes}" >> ${report}

echo "----- kubernetes version" |& tee -a ${report}
run_cmd kubectl version --short

echo "----- docker version" |& tee -a ${report}
run_cmd docker version
run_cmd docker-compose -v

echo "----- docker images" |& tee -a ${report}
run_cmd docker images

echo "----- docker system df" |& tee -a ${report}
run_cmd docker system df
run_cmd docker system df -v

# echo "----- docker memory usage" |& tee -a ${report}
# run_cmd docker stats --no-stream --format "table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | sort -k 1

echo "----- docker container logfile sizes" |& tee -a ${report}
run_cmd du -sh /var/lib/docker/containers
run_cmd "docker ps -qa | xargs docker inspect --format='{{println .Name}}{{println .Created}}{{println .Id}}'"
run_cmd "docker ps -qa | xargs docker inspect --format='{{.LogPath}}' | xargs ls -hl"

echo "----- cluster nodes" |& tee -a ${report}
run_cmd kubectl get nodes -o wide
JSONPATH='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}' \
&& kubectl get nodes -o jsonpath="$JSONPATH" >> ${report}
kubectl get nodes -o json >> ${report}
kubectl get nodes --show-labels >> ${report}
kubectl get nodes -o json | jq .items[].spec.taints >> ${report}

echo "----- node resources" |& tee -a ${report}
for node in ${all_ncn_nodes}
do
	run_cmd kubectl -n sma describe node ${node}
done

echo "----- namespace resource limits" |& tee -a ${report}
run_cmd kubectl describe limitrange -n sma
run_cmd kubectl describe limitrange -n services

echo "----- services" |& tee -a ${report}
run_cmd kubectl -n sma get services -owide

echo "----- all pods" |& tee -a ${report}
kubectl get pods --all-namespaces -o wide >> ${report}

echo "----- ceph health" |& tee -a ${report}
run_cmd ceph status
run_cmd ceph osd stat
run_cmd ceph mon stat

echo "----- sma images" |& tee -a ${report}
kubectl -n sma get pods -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{end}{end}' >> ${report}
kubectl -n services get pods -o=jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\t"}{range .spec.containers[*]}{.image}{end}{end}' | egrep -i 'kibana|grafana|sma-telemetry-api' >> ${report}

echo "----- sma pods" |& tee -a ${report}
run_cmd kubectl -n sma get pods -o wide --sort-by=.metadata.name
kubectl -n sma describe pods > ${describe_pods}
add_text ${describe_pods}

echo "----- sma pod restarts" |& tee -a ${report}
run_cmd kubectl -n sma get pods --sort-by='.status.containerStatuses[*].restartCount'

echo "----- sma jobs" |& tee -a ${report}
run_cmd kubectl -n sma get jobs -o wide --sort-by=.metadata.name
kubectl -n sma describe jobs > ${describe_jobs}
add_text ${describe_jobs}

echo "----- sma cron jobs" |& tee -a ${report}
kubectl -n sma get cronjobs >> ${report} 2>&1

echo "----- sma services" |& tee -a ${report}
run_cmd ${BINPATH}/sma_svc_health.sh >> ${report} 2>&1

echo "----- sma postgres" |& tee -a ${report}
run_cmd ${BINPATH}/sma_postgres_health.sh >> ${report} 2>&1

echo "----- sma storage" |& tee -a ${report}
run_cmd ${BINPATH}/sma_pvc_health.sh >> ${report} 2>&1

echo "----- sma secrets" |& tee -a ${report}
kubectl -n sma get secrets >> ${report} 2>&1
kubectl -n sma describe secrets >> ${report} 2>&1
kubectl -n sma get secret cstream-config -o yaml  >> ${report} 2>&1

echo "----- services secrets" |& tee -a ${report}
kubectl -n services get secrets >> ${report} 2>&1
kubectl -n services describe secrets >> ${report} 2>&1
kubectl -n services get secret mariadb-config -o yaml  >> ${report} 2>&1

echo "----- container logs" |& tee -a ${report}
${BINPATH}/sma_gather_logs.sh ${report}_container_logs.out
gzip -c ${report}_container_logs.out > ${container_logs}
add_tarball ${container_logs}
rm -f ${report}_container_logs.out

echo "----- previous container logs" |& tee -a ${report}
${BINPATH}/sma_gather_logs.sh -p ${report}_container_logs.out
gzip -c ${report}_container_logs.out > ${previous_container_logs}
add_tarball ${previous_container_logs}
rm -f ${report}_container_logs.out

echo "----- ldms compute config" |& tee -a ${report}
run_compute_nodes systemctl status ldmsd-bootstrap
run_compute_nodes ldms_ls -p 60000 -a /etc/sysconfig/ldms.d/ClusterSecrets/compute.ldmsauth.conf -l
run_compute_nodes ls -laR /etc/sysconfig/ldms.d
run_compute_nodes md5sum /etc/sysconfig/ldms.d/ClusterSecrets/compute.ldmsauth.conf
run_compute_nodes cat /etc/cray/nid
run_compute_nodes cat /etc/cray/xname
run_compute_nodes cat /proc/cmdline

for pod in "${ldms_aggr_pods[@]}"
do
	echo "----- ldms aggr config ${pod}" |& tee -a ${report}
	kubectl -n sma exec ${pod} -t -- ls -lR /etc/sysconfig/ldms.d >> ${report} 2>&1
	kubectl -n sma exec ${pod} -t -- /ldmsd-bootstrap container_check >> ${report} 2>&1
    kubectl -n sma exec ${pod} -t -- md5sum /etc/sysconfig/ldms.d/ClusterSecrets/compute.ldmsauth.conf >> ${report} 2>&1
done

for pod in "${rsyslog_pods[@]}"
do
	echo "----- rsyslog config ${pod}" |& tee -a ${report}
	kubectl -n sma exec ${pod} -t -- ps -aef >> ${report} 2>&1
	kubectl -n sma exec ${pod} -t -- cat /etc/rsyslog-aggregator.conf >> ${report} 2>&1
done

echo "----- cstream config" |& tee -a ${report}
run_cmd kubectl -n sma get configmap cstream-config
run_cmd kubectl -n sma describe configmap cstream-config
run_cmd ls -la /var/sma/data
cat_file /var/sma/data/cstream/site_config.yaml
cat_file /var/sma/data/cstream/streaming.cfg

echo "----- postgres cluster health" |& tee -a ${report}
kubectl -n sma get pod -l application=spilo -L spilo-role -o wide >> ${report} 2>&1

echo "----- log aggregation health" |& tee -a ${report}
${BINPATH}/sma_log_health.sh > ${log_health}
add_text ${log_health}

echo "----- elasticsearch health" |& tee -a ${report}
curl -s -S -XGET "${elasticsearch_url}/?pretty=true" >> ${report} 2>&1
curl -s -S -XGET "${elasticsearch_url}/_cat/health?v" >> ${report} 2>&1

echo "----- elasticsearch indices" |& tee -a ${report}
curl -s -S -XGET "${elasticsearch_url}/_cat/indices" >> ${report} 2>&1

echo "----- elasticsearch entries" |& tee -a ${report}
curl -s -S -XGET "${elasticsearch_url}/shasta-logs*/_search?size=1&sort=@timestamp:desc\&pretty" >> ${report} 2>&1
curl -s -S -XGET "${elasticsearch_url}/clusterstor-logs*/_search?size=1&sort=@timestamp:desc\&pretty" >> ${report} 2>&1

echo "----- elasticsearch stats" |& tee -a ${report}
curl -s -S -XGET "${elasticsearch_url}/_cluster/stats?human&pretty&pretty" >> ${report} 2>&1
curl -s -S -XGET "${elasticsearch_url}/_nodes/stats?human&pretty&pretty" >> ${report} 2>&1
curl -s -S -XGET "${elasticsearch_url}/_nodes?filter_path=**.mlockall&pretty" >> ${report} 2>&1

echo "----- elasticsearch nodes" |& tee -a ${report}
curl -s -S -XGET "${elasticsearch_url}/_nodes" | jq '.' >> ${report} 2>&1
curl -s -S -XGET "${elasticsearch_url}/_nodes?filter_path=**.mlockall&pretty" >> ${report} 2>&1

echo "----- elasticsearch curator" |& tee -a ${report}
kubectl -n sma get cronjob elasticsearch-curator >> ${report} 2>&1
kubectl -n sma describe cronjob elasticsearch-curator >> ${report} 2>&1

echo "----- kibana indexes" |& tee -a ${report}
curl -s -XGET "${elasticsearch_url}/.kibana/config/5.6.4" | jq '.' >> ${report} 2>&1
curl -s -XGET "${elasticsearch_url}/.kibana/index-pattern/shasta-logs*" | jq '.' >> ${report} 2>&1
curl -s -XGET "${elasticsearch_url}/.kibana/index-pattern/clusterstor-logs*" | jq '.' >> ${report} 2>&1

echo "----- kafka version" |& tee -a ${report}
kubectl -n sma exec ${kafka_pod} -c kafka -t -- find /opt/kafka/libs/ -name \*kafka_\* | head -1 | grep -o '\kafka[^\n]*' >> ${report} 2>&1

echo "----- kafka brokers" |& tee -a ${report}
run_cmd kubectl -n sma exec ${kafka_pod} -c kafka -t -- /opt/kafka/bin/kafka-broker-api-versions.sh  --bootstrap-server localhost:9092

echo "----- kafka topics" |& tee -a ${report}
run_cmd kubectl -n sma get kafkatopic
run_cmd kubectl -n sma exec ${kafka_pod} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --list --zookeeper localhost:2181

for topic in "${kafka_topics[@]}"; do
	echo "----- $topic kafka topic" |& tee -a ${report}
	kubectl -n sma exec ${kafka_pod} -c kafka -t -- /opt/kafka/bin/kafka-topics.sh --describe --zookeeper localhost:2181 --topic $topic >> ${report} 2>&1
	kubectl -n sma exec ${kafka_pod} -c kafka -t -- /bin/sh -c "ls -lh /var/lib/kafka/data/kafka-log*/$topic*" >> ${report} 2>&1
done

echo "----- telemetry api" |& tee -a ${report}
cluster_ip=$(kubectl -n sma get services | grep telemetry | grep Load | awk '{print $3}')
run_cmd curl -k -s -XGET 'https://${cluster_ip}:8080/v1/ping'
run_cmd curl -k -s -XGET 'https://${cluster_ip}:8080/v1'
run_cmd curl -k -s -XGET 'https://${cluster_ip}:8080/v1/stream' | jq '.' >> ${report}

for topic in "${kafka_topics[@]}"; do
	echo "----- $topic kafka dump" |& tee -a ${report}
	dump_topic=${report}_kafka_${topic}_topic.txt
	rm -f $dump_topic
	timeout ${timeout_opts} kubectl -n sma exec ${kafka_pod} -c kafka -c kafka -t -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $topic --max-messages 20 > $dump_topic 2>&1
	add_text $dump_topic
	run_cmd wc -l $dump_topic
done

# FIXME dump database metrics vmstat, clusterstor, job

cd ${report_dir}
tar czf ${report}.tgz $tar_files
chmod 555 ${report}.tgz
echo `date` >>${report}
echo "done in $(($(date +'%s') - $start_time)) seconds"

echo "SMA report saved at ${report}.tgz"
tar tvf ${report}.tgz

# Clean up
for file in $cleanup_files
do
	rm -f $file
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
