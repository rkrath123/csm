#!/bin/bash
# set -x

# Examples
# sma_jobs.sh 24h
# sma_jobs.sh -s snx11253 24h
# sma_jobs.sh -s snx11117 24h
# sma_jobs.sh 24h 3d

# SMW - select parition's log
# cd /var/opt/cray/log/p6-current
# grep 'aprun.*Starting,' messages-20171220 | head -5
# grep 'aprun.*Starting,' messages-20171220 | wc -l

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

DATE=`date +'%Y%m%d.%H%M'`
OUTPUT=sma_JOBS_${DATE}.out

opt_all=true
system=
smw_host=

show_help () {
        echo "[-s SYSTEM_NAME] TIME(s)"
}


while getopts s:h option
do
	case "${option}"
	in
		s) system=${OPTARG};opt_all=false;;
		H) smw_host=${OPTARG};opt_all=false;;
		h) show_help;exit 0;;
	esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo "----- sma version" |& tee -a $OUTPUT
sma_version > $OUTPUT 2>&1

for time in "$@"
do
	echo "----- open ($time)" |& tee -a $OUTPUT
	if $opt_all ; then
		# This counts ALL jobs on all file systems.
		cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"select value FROM /cray_job.d_open/ WHERE time > now() - $time group by system_name, job_id limit 1\" | grep \"tags:\" | wc -l;"
	else
		cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"select value FROM /cray_job.d_open/ WHERE system_name = '$system' AND time > now() - $time group by system_name, job_id limit 1\" | grep \"tags:\" | wc -l;"
	fi
	runit $cmd >> $OUTPUT 2>&1

	echo "----- getattr ($time)" |& tee -a $OUTPUT
	if $opt_all ; then
		cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"select value FROM /cray_job.d_getattr/ WHERE time > now() - $time group by system_name, job_id limit 1\" | grep \"tags:\" | wc -l;"
	else
		cmd="influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute \"select value FROM /cray_job.d_getattr/ WHERE system_name = '$system' AND time > now() - $time group by system_name, job_id limit 1\" | grep \"tags:\" | wc -l;"
	fi
	runit $cmd >> $OUTPUT 2>&1

done

if $opt_all ; then
	cmd="echo select count\(apid\) from jobevent_tbl | mysql -t jobevents -u jobevent"
else
	cmd="echo select count\(apid\) from jobevent_tbl where hostname=\'$smw_host\' | mysql -t jobevents -u jobevent"
fi
echo "----- mysql row count(apid) " |& tee -a $OUTPUT
echo $cmd | docker exec -i $SMA_MYSQL_CONTAINER /bin/bash - >> $OUTPUT 2>&1

echo "DONE: $OUTPUT"
