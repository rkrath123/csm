#!/bin/bash
# set -x

BINPATH=`dirname "$0"`

nid_count="${1:-1}"
secs="${2:-5}"
copies="${3:-1}"

files="$BINPATH/../utils/tcpflood $BINPATH/../utils/tcpflood_generator.sh $BINPATH/../utils/tcpflood_message.txt"

# copy test files to computes
for (( n=1; n<=$nid_count; n++ ))
do
	node="nid00000$n-nmn"
	echo "copy files to $node"
	scp $files $node:/root/
	if [ $? -ne 0 ]; then
		echo "copy failed"
		exit 1
	fi
done

# run tcpflood on computes
# wait for tests to finish
SECONDS=0
output="tcpflood_${node}_${i}-`date +%Y%m%d.%H%M`.out"
while (( SECONDS < secs )); do
	for (( n=1; n<=$nid_count; n++ ))
	do
		node="nid00000$n-nmn"
		echo "running tcpflood on $node"
		for (( i=1; i<=$copies; i++ ))
		do
			echo "starting tcpflood_generator $output"
			ssh $node 'date; /root/tcpflood_generator.sh -i 0 -S 10 10000 100' >> $output &
		done
	done
	wait
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
