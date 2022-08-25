#!/bin/bash
# set -x

# Use standard Logger command to generate entries in the system log
# for forwarding to the SMF log aggregator

count="${1:-10000}"
pid=$$
tag=sma-test
message="syslog_generator-$pid"

i=0
while [ ${i} -lt ${count} ]; do
	let i=i+1
	logger -t $tag $message count=$i of $count
done

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
