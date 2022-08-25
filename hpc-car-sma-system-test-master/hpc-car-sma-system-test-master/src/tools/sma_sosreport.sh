#!/bin/bash
set -o nounset
set -o pipefail
# set -o xtrace
# set -o errexit

BINPATH=`dirname "$0"`
. ${BINPATH}/sma_tools

REPORT=${1:-/tmp/sma-SOSREPORT-`uname -n`-`date +%Y%m%d.%H%M`}
REPORT_DIR=`dirname ${REPORT}`
NUMOF_LINES=${2:-100}

KAFKA_METRICS_TOPIC=${REPORT}_kafka_metrics_topic.txt
KAFKA_JOBEVENTS_TOPIC=${REPORT}_kafka_jobevents_topic.txt
SERVER_DISK_METRICS=${REPORT}_server_disk_metrics.txt
CRAY_STORAGE_METRICS=${REPORT}_cray_storage_metrics.txt
CRAY_JOB_METRICS=${REPORT}_cray_job_metrics.txt
CRAY_IB_METRICS=${REPORT}_cray_ib_metrics.txt
CRAY_JOBEVENTS=${REPORT}_cray_jobevents.txt
MYSQL_JOBEVENTS=${REPORT}_mysql_jobevents.txt
IBTOPOLOGY_DUMP=${REPORT}_ibtopology.txt
CONTAINER_INSPECT=${REPORT}_container_inspect.txt
MONASCA_ALARMS=${REPORT}_monasca_alarms.txt
SMA_DATADIR=${REPORT}_sma_data.txt
SERVICE_STARTS=${REPORT}_sma_service_starts.txt

HTTPD_CONFIG=${REPORT}_httpd_config.tgz
OPENSTACK_CONFIG=${REPORT}_openstack_config.tgz
GRAFANA_DASHBOARDS=${REPORT}_grafana_dashboards.tgz
SMA_CONFIG=${REPORT}_sma_config.tgz

SEASTREAM_LOGS=${REPORT}_seastream_logs.tgz
WEBGUI_LOGS=${REPORT}_webgui_logs.tgz
WEBGUI_INSTRUMENTATION=${REPORT}_webgui_instrumentation.tgz
CONTAINER_LOGS=${REPORT}_container_logs.gz
DATABASE_STATS=${REPORT}_database_stats.gz
JOURNAL_OUTPUT=${REPORT}_systemd_journal.gz

TAR_FILES=`basename ${REPORT}`
CLEANUP_FILES=${REPORT}

SERVER=`hostname -f`

verbose() {
	echo $*
}

run_cmd() {
	eval $* >> ${REPORT} 2>&1
	echo "" >> ${REPORT} 2>&1
}

cat_file() {
	for file in $*
	do
		if [ -f $file ]; then
			echo "----- $file" |& tee -a ${REPORT}
			run_cmd ls -al $file
			run_cmd cat $file
			echo "" >> ${REPORT} 2>&1
		fi
	done
}

tail_file() {
	for file in $*
	do
		if [ -f $file ]; then
			echo "----- $file" |& tee -a ${REPORT}
			run_cmd ls -l $file
			run_cmd tail -f ${NUMOF_LINES} $file
			echo "" >> ${REPORT} 2>&1
		fi
	done
}

add_tarball() {
	echo "adding file `basename $*`" >> ${REPORT} 2>&1
	TAR_FILES="$TAR_FILES `basename $*`"
	CLEANUP_FILES="$CLEANUP_FILES $*"
	chmod 444 $*
	echo "" >>${REPORT} 2>&1
}

add_text() {
 	echo "adding file `basename $*`" >> ${REPORT} 2>&1
	head -n 20 $* >> ${REPORT} 2>&1
	TAR_FILES="$TAR_FILES `basename $*`"
	CLEANUP_FILES="$CLEANUP_FILES $*"
	chmod 444 $*
	echo "" >>${REPORT} 2>&1
}

rm -f ${REPORT}
start_time=$(date +'%s')
echo `date` >${REPORT}

echo "----- uname" |& tee -a ${REPORT}
run_cmd uname -a

echo "----- os-release" |& tee -a ${REPORT}
run_cmd cat /etc/os-release

echo "----- motd" |& tee -a ${REPORT}
run_cmd cat /etc/motd

echo "----- cpu" |& tee -a ${REPORT}
run_cmd lscpu

echo "----- memory" |& tee -a ${REPORT}
run_cmd free -h -lm
run_cmd vmstat -s -SM

echo "----- uptime" |& tee -a ${REPORT}
run_cmd uptime

echo "----- ps -eaF" |& tee -a ${REPORT}
run_cmd ps -aeF

echo "----- top sort res" |& tee -a ${REPORT}
run_cmd COLUMNS=1000 top -o RES -c -n 1 -b

# Check where sma-data is mounted
echo "----- mount" |& tee -a ${REPORT}
run_cmd ls -l /etc | grep sma-data
run_cmd readlink /etc/sma-data
run_cmd mount

echo "----- disk space" |& tee -a ${REPORT}
run_cmd df -h $(readlink /etc/sma-data)
run_cmd df -h /

# In lsblk, the ROTA column you should get 1 for hard disks and 0 for an SSD.
echo "----- disk" |& tee -a ${REPORT}
run_cmd lsblk -t
run_cmd lsscsi

echo "----- sysctl values" |& tee -a ${REPORT}
run_cmd sysctl net.ipv4.tcp_keepalive_time
run_cmd sysctl vm.max_map_count
# FIXME-command hung on one View server so removed it
# run_cmd sysctl -a

echo "----- sma service status" |& tee -a ${REPORT}
run_cmd systemctl status sma

echo "----- firewalld service" |& tee -a ${REPORT}
run_cmd systemctl status firewalld

echo "----- iptables" |& tee -a ${REPORT}
run_cmd iptables -L INPUT -v -n
run_cmd iptables -L -n -v

echo "----- sma-release" |& tee -a ${REPORT}
run_cmd cat /etc/opt/cray/release/sma-release

echo "----- docker version" |& tee -a ${REPORT}
run_cmd docker version
run_cmd docker-compose -v

echo "----- docker info" |& tee -a ${REPORT}
run_cmd docker info

echo "----- docker status" |& tee -a ${REPORT}
run_cmd systemctl docker status

echo "----- docker stats" |& tee -a ${REPORT}
run_cmd "docker stats --no-stream --format \"table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\""

echo "----- docker images" |& tee -a ${REPORT}
run_cmd docker images

echo "----- docker network" |& tee -a ${REPORT}
run_cmd docker network ls

echo "----- docker socket" |& tee -a ${REPORT}
run_cmd ls -l /var/run/docker.sock

echo "----- docker system df" |& tee -a ${REPORT}
run_cmd docker system df
run_cmd docker system df -v

echo "----- docker container logfile sizes" |& tee -a ${REPORT}
run_cmd du -sh /var/lib/docker/containers
run_cmd "docker ps -qa | xargs docker inspect --format='{{println .Name}}{{println .Created}}{{println .Id}}'"
run_cmd "docker ps -qa | xargs docker inspect --format='{{.LogPath}}' | xargs ls -hl"
run_cmd du -hs /var/log/sma/*

echo "----- sma status/env" |& tee -a ${REPORT}
run_cmd sma_ps
run_cmd ${BINPATH}/sma_status.sh
run_cmd sma_env

echo "----- sma install logs" |& tee -a ${REPORT}
pushd /root/sma-install > /dev/null
if [ $? -eq 0 ]; then
	cat_file *.log
	popd > /dev/null
	pwd >> ${REPORT}
fi

echo "----- sma core" |& tee -a ${REPORT}
run_cmd ls -la /etc/sma-data/core

echo "----- sma service starts" |& tee -a ${REPORT}
curl -s -XGET 'http://elasticsearch:9200/view-*/_search?pretty=true&size=1000' -d' { "_source": { "includes": [ "@timestamp", "message" ] }, "query": { "match": { "message": "start" } }, "sort": [ { "@timestamp": { "order": "asc" } } ] }' | grep message >> ${REPORT} 2>&1

rm -f ${SERVICE_STARTS}
curl -s -XGET 'http://elasticsearch:9200/view-*/_search?pretty=true&size=1000' -d' { "query": { "match": { "message": "start" } }, "sort": [ { "@timestamp": { "order": "asc" } } ] }' >${SERVICE_STARTS} 2>&1
add_text ${SERVICE_STARTS}

echo "----- database stats" |& tee -a ${REPORT}
rm -f ${REPORT}_database_stats.out
${BINPATH}/sma_database_stats.sh > ${REPORT}_database_stats.out 2>&1
gzip -c ${REPORT}_database_stats.out > ${DATABASE_STATS}
add_tarball ${DATABASE_STATS}
rm -f ${REPORT}_database_stats.out

echo "----- container top" |& tee -a ${REPORT}
run_cmd ${BINPATH}/sma_container_top.sh

echo "----- container logs" |& tee -a ${REPORT}
rm -f ${REPORT}_container_logs.out
${BINPATH}/sma_container_logs.sh ${REPORT}_container_logs.out
gzip -c ${REPORT}_container_logs.out > ${CONTAINER_LOGS}
add_tarball ${CONTAINER_LOGS}
rm -f ${REPORT}_container_logs.out

echo "----- container inspect" |& tee -a ${REPORT}
rm -f ${CONTAINER_INSPECT}
${BINPATH}/sma_container_inspect.sh > ${CONTAINER_INSPECT}
add_text ${CONTAINER_INSPECT}

# echo "----- sma config" |& tee -a ${REPORT}
run_cmd ls -la /etc/sma-data/etc
cat_file /etc/sma-data/etc/site_config.yaml
cat_file /etc/sma-data/etc/streaming.cfg

# echo "----- grafana dashboards" |& tee -a ${REPORT}
# run_cmd ls -la /etc/cray_seastream
# tar cvzf ${GRAFANA_DASHBOARDS}/etc/cray_seastream >> ${REPORT} 2>&1
# add_tarball ${GRAFANA_DASHBOARDS}

echo "----- influx retention policy" |& tee -a ${REPORT}
run_cmd "influx --database 'mon' --host 'localhost' -port '8086' --execute \"show retention policies on mon;\""

echo "----- elasticsearch health" |& tee -a ${REPORT}
curl -s -S -XGET 'elasticsearch:9200/?pretty=true' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/_cat/health?v' >> ${REPORT} 2>&1

echo "----- elasticsearch indices" |& tee -a ${REPORT}
curl -s -S -XGET 'elasticsearch:9200/_cat/indices' >> ${REPORT} 2>&1

echo "----- elasticsearch entries" |& tee -a ${REPORT}
curl -s -S -XGET 'elasticsearch:9200/snx-logs*/_search?size=1&sort=@timestamp:desc\&pretty' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/event-h*/_search?size=1&sort=@timestamp:desc\&pretty' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/event-ib*/_search?size=1&sort=@timestamp:desc\&pretty' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/views-*/_search?size=1&sort=@timestamp:desc\&pretty' >> ${REPORT} 2>&1

echo "----- elasticsearch stats" |& tee -a ${REPORT}
curl -s -S -XGET 'elasticsearch:9200/_cluster/stats?human&pretty&pretty' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/_nodes/stats?human&pretty&pretty' >> ${REPORT} 2>&1
curl -s -S -XGET 'elasticsearch:9200/_nodes?filter_path=**.mlockall&pretty' >> ${REPORT} 2>&1

echo "----- elasticsearch bootstrap checks" |& tee -a ${REPORT}
docker logs --tail all ${SMA_ELASTICSEARCH_CONTAINER} | grep BootstrapChecks >> ${REPORT} 2>&1

echo "----- kiban indexes" |& tee -a ${REPORT}
run_cmd curl -s -XGET 'elasticsearch:9200/.kibana/config/5.6.4'
run_cmd curl -s -XGET 'elasticsearch:9200/.kibana/index-pattern/snx-logs_*'
run_cmd curl -s -XGET 'elasticsearch:9200/.kibana/index-pattern/event-h*'
run_cmd curl -s -XGET 'elasticsearch:9200/.kibana/index-pattern/event-ib*'
run_cmd curl -s -XGET 'elasticsearch:9200/.kibana/index-pattern/view-*'

# FIXME grafana datasources
# run_cmd curl -k -XGET 'https://admin:admin@grafana:3000/api/datasources'

echo "----- /etc/sma-data" |& tee -a ${REPORT}
rm -f ${SMA_DATADIR}
ls -lRh /etc/sma-data/ > ${SMA_DATADIR}
add_text ${SMA_DATADIR}
pushd /etc/sma-data > /dev/null
if [ $? -eq 0 ]; then
	tar cvzf ${SMA_CONFIG} etc >> ${REPORT} 2>&1
	add_tarball ${SMA_CONFIG}
	popd > /dev/null
fi

# Taking too long.  Container log dump will get tail of the seastream logs.
# echo "----- seastream logs" |& tee -a ${REPORT}
# pushd /etc/sma-data/seastream > /dev/null
# if [ $? -eq 0 ]; then
# 	tar cvzf ${SEASTREAM_LOGS} *.log >> ${REPORT} 2>&1
# 	add_tarball ${SEASTREAM_LOGS}
# 	popd > /dev/null
# fi

echo "----- webgui logs" |& tee -a ${REPORT}
pushd /etc/sma-data/sma-webgui/logs > /dev/null
tar cvzf ${WEBGUI_LOGS} *.log >> ${REPORT} 2>&1
add_tarball ${WEBGUI_LOGS}
popd > /dev/null

echo "----- webgui instrumentation" |& tee -a ${REPORT}
pushd /etc/sma-data/sma-webgui/instrumentation > /dev/null
tar cvzf ${WEBGUI_INSTRUMENTATION} *.log >> ${REPORT} 2>&1
add_tarball ${WEBGUI_INSTRUMENTATION}
popd > /dev/null

echo "----- monasca alarms" |& tee -a ${REPORT}
rm -f ${MONASCA_ALARMS}
${BINPATH}/sma_alarms.sh ${MONASCA_ALARMS}
add_text ${MONASCA_ALARMS}

echo "----- alps config example" |& tee -a ${REPORT}
echo "cat /var/opt/cray/alps/log/apsys" >> ${REPORT}
echo "cat /ufs/alps_shared/proglog.sh" >> ${REPORT}
echo "cat /ufs/alps_shared/epilog.sh" >> ${REPORT}
echo >> ${REPORT}

echo "----- systemd journal" |& tee -a ${REPORT}
rm -f ${REPORT}_journal.out
journalctl -l > ${REPORT}_journal.out
gzip -c ${REPORT}_journal.out > ${JOURNAL_OUTPUT}
add_tarball ${JOURNAL_OUTPUT}
rm -f ${REPORT}_journal.out

echo "----- tenant id" |& tee -a ${REPORT}
run_cmd docker exec -i sma_keystone_1 /get_tenantID.py
run_cmd curl -k https://${SERVER}/run_config/

# echo "----- check telemetry service" |& tee -a ${REPORT}
# run_cmd curl -k -i https://${SERVER}/telemetry-api/v1/ping

echo "----- jobevent security key configuration" |& tee -a ${REPORT}
image_id=$(docker images --format="{{.ID}}" cray_sma/utility)
consumers=$(docker run --rm --network sma_default --entrypoint /bin/sma-kafka-cli $image_id consumer list)
echo ${consumers} >> ${REPORT}
echo >> ${REPORT}
for consumer in ${consumers}
do
    consumer=$(echo ${consumer}|tr -d '\r')
    key=$(docker run --rm --network sma_default --entrypoint /bin/sma-kafka-cli $image_id secret list ${consumer})
    key=$(echo $key|tr -d '\r')
    echo "${consumer} - secret key is '${key}'" >> ${REPORT}
done

echo "----- kafka topics" |& tee -a ${REPORT}
run_cmd docker exec -i sma_kafka_1 ./kafka/bin/kafka-topics.sh --list --zookeeper zoo1:2181

echo "----- kafka metrics topic" |& tee -a ${REPORT}
rm -f $KAFKA_METRICS_TOPIC
timeout -k 15 1m docker exec -i sma_kafka_1 ./kafka/bin/kafka-console-consumer.sh --zookeeper zoo1:2181 --topic metrics --max-messages 20 > $KAFKA_METRICS_TOPIC 2>&1
add_text $KAFKA_METRICS_TOPIC

echo "----- kafka job_events topic" |& tee -a ${REPORT}
rm -f $KAFKA_JOBEVENTS_TOPIC
timeout -k 15 1m docker exec -i sma_kafka_1 ./kafka/bin/kafka-console-consumer.sh --zookeeper zoo1:2181 --topic job_events --max-messages 5 > $KAFKA_JOBEVENTS_TOPIC 2>&1
add_text $KAFKA_JOBEVENTS_TOPIC

echo "----- mysql jobevent table" |& tee -a ${REPORT}
echo "SHOW tables;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "SHOW CREATE TABLE jobevent_tbl;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "SELECT * from mysql_init_schema.schema_version;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "DESCRIBE jobevent_tbl;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "SELECT * from retention_policy;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1 
echo "SELECT * from active_partitions WHERE tablename = 'jobevent_tbl' ORDER BY pdatetime;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "SELECT PARTITION_NAME,PARTITION_DESCRIPTION,TABLE_ROWS,AVG_ROW_LENGTH,DATA_LENGTH,CREATE_TIME,CHECK_TIME FROM information_schema.partitions WHERE table_name = 'jobevent_tbl'" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1
echo "SELECT COUNT(*),MIN(start_app),MAX(start_app) FROM jobevent_tbl;" | mysql -t jobevents -u jobevent >> ${REPORT} 2>&1

echo "----- disk metrics" |& tee -a ${REPORT}
rm -f $SERVER_DISK_METRICS
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select * from /disk.*/ where time > now() - 5m" > $SERVER_DISK_METRICS 2>&1
add_text $SERVER_DISK_METRICS

echo "----- cray_storage metrics" |& tee -a ${REPORT}
rm -f $CRAY_STORAGE_METRICS
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select * from /cray_storage.*/ where time > now() - 5m" > $CRAY_STORAGE_METRICS 2>&1
add_text $CRAY_STORAGE_METRICS

echo "----- job metrics" |& tee -a ${REPORT}
rm -f $CRAY_JOB_METRICS
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select * from /cray_job.*/ where time > now() - 5m" > $CRAY_JOB_METRICS 2>&1
add_text $CRAY_JOB_METRICS

echo "----- job open (24h)" |& tee -a ${REPORT}
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select job_id from /cray_job.d_open/ WHERE time > now() - 24h" | sed -e 's/  */ /g' | cut -d" " -f 2 | sort | uniq -c | wc -l >> ${REPORT} 2>&1

echo "----- job count (24h)" |& tee -a ${REPORT}
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select mean(value) from /cray_job.job_cnt/ WHERE time > now() - 24h" >> ${REPORT} 2>&1

echo "----- ib metrics" |& tee -a ${REPORT}
rm -f $CRAY_IB_METRICS
influx --database 'mon' --host 'localhost' -port '8086' --precision 'rfc3339' --execute "select * from /cray_ib.*/ where time > now() - 5m" > $CRAY_IB_METRICS
add_text $CRAY_IB_METRICS

echo "----- job hostname(s)" |& tee -a ${REPORT}
influx -database 'mon' -precision rfc3339 -execute "select last(value) FROM /cray_job.status/ where time > now() - 1h and value=92 group by hostname" >> ${REPORT} 2>&1

echo "----- mysql jobevents" |& tee -a ${REPORT}
rm -f $MYSQL_JOBEVENTS
echo "select apid,apname,jobid,hostname,userid,start_app,stop_app from jobevent_tbl limit 100;" | mysql -t jobevents -u jobevent  > $MYSQL_JOBEVENTS 2>&1
add_text $MYSQL_JOBEVENTS

echo "----- ib config" |& tee -a ${REPORT}
run_cmd lsmod | grep ib_umad
run_cmd lspci -v | grep Mellanox

echo "----- ib topology" |& tee -a ${REPORT}
rm -f $IBTOPOLOGY_DUMP
get_ibtopology.sh > $IBTOPOLOGY_DUMP 2>&1
add_text $IBTOPOLOGY_DUMP

cd ${REPORT_DIR}
tar czf ${REPORT}.tgz $TAR_FILES
chmod 555 ${REPORT}.tgz
echo `date` >>${REPORT}
echo "done in $(($(date +'%s') - $start_time)) seconds"

echo "SMA report saved at ${REPORT}.tgz"
tar tvf ${REPORT}.tgz

# Clean up
for file in $CLEANUP_FILES
do
	rm -f $file
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
