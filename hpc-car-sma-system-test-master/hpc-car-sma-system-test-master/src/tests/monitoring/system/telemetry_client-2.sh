#!/bin/bash
set -x
 
# Use telemetry API endpoint script to test multiple clients

test=client2
server="10.2.100.52"
port=8080
pid=$$
kafka_topics=( "cray-node" )
if [[ $# -eq 0 ]] ; then
	num_clients=$(( ( RANDOM % 30 )  + 5 ))
	count=$(( ( RANDOM % 20 )  + 5 ))
	batchsize=$(( ( RANDOM % 1000 )  + 200 ))
else
	num_clients=$1
	count=$2
	batchsize=$3
fi

uid=$(kubectl -n sma get pods | grep kafka | awk '{print $1}')

for topic in "${kafka_topics[@]}"
do

#   kubectl -n sma exec $uid -t -- /kafka/bin/kafka-console-consumer.sh --zookeeper zoo1:2181 --topic $topic --max-messages 1 --timeout-ms 30000 | grep -n ConsumerTimeoutException
#   if [ $? -ne 0 ]; then
#       echo "no producer on $topic"
#       exit 1
#   fi

	echo "starting topic= $topic clients= $num_clients count= $count batchsize= $batchsize"

	for i in $(seq 1 $num_clients)
	do
		outfile="/tmp/telemetry_client_${topic}_${test}-$i.out"
		errfile="/tmp/telemetry_client_${topic}_${test}-$i.err"
		stream=${topic}_${pid}-$i
#		stream=$(LC_ALL=C; cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
		echo $stream
 		cmd="/tests/monitoring/utils/telemetry_client.py -b $batchsize -c $count -p $port -i $stream -s $server -t $topic > $outfile 2> $errfile &"
 		echo $cmd
 		eval $cmd
		echo $stream
	done
done

echo "starting at `date`"
wait
if [ $? -ne 0 ]; then
	echo "command failed"
	exit 1
fi
echo "done `date`"

for topic in "${kafka_topics[@]}"
do
	for i in $(seq 1 $num_clients)
	do
		outfile="/tmp/telemetry_client_${topic}_${test}-$i.out"
		errfile="/tmp/telemetry_client_${topic}_${test}-$i.err"
		echo "checking $outfile"
		grep "telemetry_client_result" $outfile
		failed=$(grep -c "test failed" $outfile)
		if [ $failed -ne 0 ]; then
			echo "$outfile failed"
			exit 1
		fi

		if [ -s "$errfile" ]
		then
			echo "$errfile exists and is not empty"
			cat $errfile
			exit 1
		fi

#		rm -f $outfile
#		rm -f $errfile
	done
done

exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
