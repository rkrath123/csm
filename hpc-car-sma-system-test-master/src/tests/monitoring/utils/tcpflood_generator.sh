#!/bin/bash
# set -x

BINPATH=`dirname "$0"`

# Use tcpflood to send a lot of json formatted log messages to SMF aggregator.
# Defaults is 1000000 messages (100000 messages for 10 runs) per iteration (default=1).

iters=1
sleeptime=30

ipaddr="10.2.100.51"
port="514"

while getopts i:t:S: option
do
	case "${option}"
	in
		i) iters=${OPTARG};;        # number of iterations to run test, zero(0) is forever
		t) ipaddr=${OPTARG};;
		S) sleeptime=${OPTARG};;    # number of seconds to sleep between different runs
	esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

num_msgs_to_send="${1:-100000}"
num_runs="${2:-10}"

tcpflood_bin="$BINPATH/tcpflood"
pid=$$
msgfile="tcpflood_message_$pid"
host=$(hostname)
uuid=$(cat /proc/sys/kernel/random/uuid)

echo "log messages to send: $num_msgs_to_send"
echo "runs: $num_runs"
echo "sleep between runs: $sleeptime"
echo "iterations: $iters"
echo "uuid: $uuid"
echo "start time: `date`"
echo

# timestamp=$(date --rfc-3339=ns | sed 's/ /T/; s/\(\....\).*-/\1-/g')
# timestamp=$(date --rfc-3339=ns)

# Create RFC 5424 log messages.
# https://tools.ietf.org/html/rfc5424
create_message () {

	if [ -f "$msgfile" ]; then
		rm $msgfile
	fi
	cp $BINPATH/tcpflood_message.txt $msgfile
	if [ $? -ne 0 ]; then
		echo "copy failed"
		exit 1
	fi

#	timereported=$(date -u +%Y-%m-%dT%T.000000-05:00)  # UTC
#   FIXME - should be UTC (ISO 8601)?
#   timereported=$(data -u -Iseconds | sed 's/UTC//')

	timereported=$(date -Iseconds | sed 's/-[[:digit:]]\+$/Z/')  # ISO 8601
	logdate=$(date)
	sed -i "s/TIME_REPORTED/${timereported}/" $msgfile
	sed -i "s/HOST_NAME/${host}/" $msgfile
	sed -i "s/LOG_MESSAGE/$logdate $uuid tcpflood generator: $1 numof messages= $num_msgs_to_send runs= $num_runs/" $msgfile

	cat $msgfile
}

if [ $iters -eq 0 ]; then
	i=1
	while true
	do
		create_message $i
		$tcpflood_bin -v -X -T "tcp" -t $ipaddr -p $port -m $num_msgs_to_send -R $num_runs -S $sleeptime -M "$(< ./$msgfile)"; sleep $sleeptime
		i=$((i+1))
	done
else
	for (( i=1; i<=$iters; i++ ))
	do
		create_message $i
		$tcpflood_bin -v -X -T "tcp" -t $ipaddr -p $port -m $num_msgs_to_send -R $num_runs -S $sleeptime -M "$(< ./$msgfile)"; sleep $sleeptime
	done
fi
rm $msgfile
echo
echo "end time: `date`"

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
