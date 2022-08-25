#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

verbose=false

while getopts s:t:vh option
do
        case "${option}"
        in
                v) verbose=true;;
                h) show_help;exit 0;;
        esac
done

# show_version

echo DEBUG: influx ready
cmd="curl -L -I localhost:8086/ping?wait_for_leader=30s"
runit $cmd

cmd="docker exec -i $SMA_INFLUX_CONTAINER ls -l /etc/influxdb/influxdb.conf"
runit $cmd

cmd="docker exec -i $SMA_INFLUX_CONTAINER cat /etc/influxdb/influxdb.conf"
runit $cmd

cmd="docker exec -i $SMA_INFLUX_CONTAINER influxd config"
runit $cmd

echo
echo DEBUG: inspect influxdb container
cmd="docker inspect $SMA_INFLUX_CONTAINER"
runit $cmd

echo
echo DEBUG: influx retention policy
cmd="docker exec -i $SMA_INFLUX_CONTAINER influx --database 'mon' --host 'localhost' -port '8086' --execute \"SHOW RETENTION POLICIES ON mon\""
runit $cmd

echo
echo DEBUG: influxd memory usage VIRT, RES
cmd="top -b -n 1 -p `pgrep influxd`"
runit $cmd

echo
echo DEBUG: space usage
cmd="du -sh /etc/sma-data/*"
runit $cmd

echo
echo "DEBUG: system memory"
runit free -h -lm
runit vmstat -s -SM
runit docker info

echo
echo "DEBUG: docker stats"
CMD="docker stats --no-stream --format \"table {{.Name}}\t{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\""
runit $CMD

echo
echo DEBUG: mean memory, num series for mon and _internal databases
CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(Sys) from /runtime/ where time >= now() - 1h\";"
runit $CMD

CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(Sys) from /runtime/ where time >= now() - 1d\";"
runit $CMD

CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(Sys) from /runtime/ where time >= now() - 3d\";"
runit $CMD

CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(numSeries) from /database/ where time >= now() - 1h\";"
runit $CMD

CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(numSeries) from /database/ where time >= now() - 1d\";"
runit $CMD

CMD="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"select mean(numSeries) from /database/ where time >= now() - 3d\";"
runit $CMD

echo
echo DEBUG: diagnostics
echo "database=mon numSeries"
cmd="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"show diagnostics\""
runit $cmd

echo DEBUG: stats
echo "seriesCreate"
cmd="influx --database '_internal' --host 'localhost' --precision 'rfc3339' --execute \"show stats\""
runit $cmd

echo
echo DEBUG: all MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | wc -l"
runit $cmd

echo DEBUG: cray_storage MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_storage | wc -l"
runit $cmd

echo DEBUG: cray_job MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_job | wc -l"
runit $cmd

echo DEBUG: cray_ib MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_ib | wc -l"
runit $cmd

echo DEBUG: cray_iostat MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_iostat | wc -l"
runit $cmd

echo DEBUG: cray_vmstat MEASUREMENTS
cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_vmstat | wc -l"
runit $cmd

# echo DEBUG: cray_dvsstats MEASUREMENTS
# cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show MEASUREMENTS\" | grep cray_dvsstats | wc -l"
# runit $cmd

if [ "$verbose" == true ]; then
	echo
	echo DEBUG: all SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES\" | wc -l"
	runit $cmd

	echo DEBUG: cray_storage SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_storage.*/\" | grep cray_storage | wc -l"
	runit $cmd

	echo DEBUG: cray_job SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_job.*/\" | grep cray_job | wc -l"
	runit $cmd

	echo DEBUG: cray_ib SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_ib.*/\" | grep cray_ib | wc -l"
	runit $cmd

	echo DEBUG: cray_iostat SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_iostat.*/\" | grep cray_iostat | wc -l"
	runit $cmd

	echo DEBUG: cray_vmstat SERIES
	cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_vmstat.*/\" | grep cray_vmstat | wc -l"
	runit $cmd

	#echo DEBUG: cray_dvsstats SERIES
	#cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"show SERIES FROM /cray_dvsstats.*/\" | grep cray_dvsstats | wc -l"
	#runit $cmd
fi

echo
echo DEBUG: influx space usage
cmd="du -sh /etc/sma-data/influxdb/*"
runit $cmd

echo
echo DEBUG: mysql config
cmd="docker exec -i $SMA_MYSQL_CONTAINER ls -l /etc/mysql/my.cnf"
runit $cmd

cmd="docker exec -i $SMA_MYSQL_CONTAINER cat /etc/mysql/my.cnf"
runit $cmd

echo
echo DEBUG: jobevent_tbl row count
cmd="echo select count\(*\) from jobevent_tbl | mysql -t jobevents -u jobevent"
echo $cmd
echo $cmd | docker exec -i $SMA_MYSQL_CONTAINER /bin/bash -

echo
echo DEBUG: jobevent_tbl status
cmd="echo show table status | mysql -t jobevents -u jobevent"
echo $cmd
echo $cmd | docker exec -i $SMA_MYSQL_CONTAINER /bin/bash -

echo
echo DEBUG: mysql space usage
cmd="du -sh /etc/sma-data/mysql/*"
runit $cmd
