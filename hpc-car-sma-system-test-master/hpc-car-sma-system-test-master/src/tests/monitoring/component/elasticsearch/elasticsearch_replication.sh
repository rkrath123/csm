#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that a randomly selected shard is replicated."
    echo "$0 > sma_component_elasticsearch_replication-\`date +%Y%m%d.%H%M\`"
    echo
    exit 1
}

while getopts h option
do
    case "${option}"
    in
        h) usage;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

declare -a failures
errs=0

###############################
# Test Case: Elasticsearch Replication
#   Verify that primary ES shards are being replicated
for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET 'elasticsearch:9200/_cat/shards/'| cat | cut -d  ' ' -f 1 | sort | uniq");
    do primary=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET 'elasticsearch:9200/_cat/shards/'| cat | grep $i | grep p");
    if [ $? == 0 ]; then
       echo "$i has primary";
    else
       echo "No primary shard found for $i"
       errs=$((errs+1))
       failures+=("Elasticsearch Replication - Missing primary for $i")
    fi
    primary='';
    replica=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET 'elasticsearch:9200/_cat/shards/'| cat | grep $i | grep r");
    if [ $? == 0 ]; then
       echo "$i is replicated";
    else
       echo "Insufficient replicas found for $i"
       errs=$((errs+1))
       failures+=("Elasticsearch Replication - Missing replica(s) for $i")
    fi
    replica='';
done

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch shards are replicated correctly"

exit 0