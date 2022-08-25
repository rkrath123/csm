#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This script checks the Elasticsearch data persistence service in HPE Cray's"
    echo "Shasta System Monitoring Application. This test checks for current elasticsearch data."
    echo "$0 > sma_component_elasticsearch_logs-\`date +%Y%m%d.%H%M\`"
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
#Test Case: Elasticsearch current logs
#The following checks for current elasticsearch data. It should report green status and non-zero log count:

when=$(date +%Y.%m.%d)
(IFS='
';
for i in `kubectl -n sma exec -it elasticsearch-master-0 -- curl -X GET "elasticsearch:9200/_cat/indices?v"|grep $when`;
   do status=$(echo $i | awk '{print $1}');
      count=$(echo $i | awk '{print $7}');
      logname=$(echo $i | awk '{print $3}');
      if [ $status == "green" ]; then
        echo "Current index shasta-logs-$when is green";
      else echo "Current index shasta-logs-$when is $status"
        errs=$((errs+1))
        failures+=("Elasticsearch Activity - Current index shasta-logs-$when is $status")
      fi

      if [ $count -gt 0 ]; then
        echo "Current index $logname is populated with $count logs";
      else echo "Current index $logname is unpopulated"
        errs=$((errs+1))
        failures+=("Elasticsearch Activity - Current index $logname is unpopulated")
      fi
done)

#############################
if [ "$errs" -gt 0 ]; then
	echo
	echo "Elasticsearch is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Elasticsearch logs are current and status is green"

exit 0