#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test verifies that Elasticsearch self-reports a healthy state."
    echo "$0 > sma_component_elasticsearch_health-\`date +%Y%m%d.%H%M\`"
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
# Test Case: Elasticsearch Health

#       Confirm that Elasticsearch self-reports a healthy state.
health=$(kubectl -n sma exec -t elasticsearch-master-0 -- bash -c "curl -sS -XGET "elasticsearch:9200/_cat/health?format=yaml"| grep status" | cut -d "\"" -f 2)
result=1
for i in $health; do if [ $i != "green" ]; then result=0
    echo "Elasticsearch self-reports $i health state"
    failures+=("Elasticsearch Health - $health health state")
  fi
done
if [ $result == 1 ]; then echo "Elasticsearch self-reports a healthy state"; else
    errs=$((errs+1))
fi

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch looks healthy"

exit 0