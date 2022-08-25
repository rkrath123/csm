#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that Elasticsearch nodes exist and contain localhost"
    echo "$0 > sma_component_elasticsearch_nodes-\`date +%Y%m%d.%H%M\`"
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

################################
# Test Case: Expected Elasticsearch Nodes Exist
#   Confirm that Elasticsearch nodes contain localhost.
declare -a nodes

for i in $(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/nodes?h=name"");
    do nodes+=($i);
done


if [[ " ${nodes[@]} " =~ "elasticsearch-master-0" ]]; then
    echo "Node elasticsearch-master-0 is a member of the cluster"
else
    echo "Node elasticsearch-master-0 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-0 not in cluster")
fi

if [[ " ${nodes[@]} " =~ "elasticsearch-master-1" ]]; then
    echo "Node elasticsearch-master-1 is a member of the cluster"
else
    echo "Node elasticsearch-master-1 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-1 not in cluster")
fi

if [[ " ${nodes[@]} " =~ "elasticsearch-master-2" ]]; then
    echo "Node elasticsearch-master-2 is a member of the cluster"
else
    echo "Node elasticsearch-master-2 is not a member of the cluster"
    errs=$((errs+1))
    failures+=("Elasticsearch Node - elasticsearch-master-2 not in cluster")
fi

unset nodes

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch nodes look good"

exit 0