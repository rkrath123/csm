#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for rsyslog in Cray's Shasta System Monitoring Application"
    echo "tests the ability to send compute log messages to kafka/elasticsearch."
    echo "$0 > sma_component_rsyslog-compute_log-\`date +%Y%m%d.%H%M\`"
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

#########################
#Test Case: Rsyslog Collects Compute Logs
time=$(date +%s)
compute=$(cray hsm inventory redfishEndpoints list --format json | jq | grep FQDN | head -1 | cut -d '"' -f 4)
ssh -o "StrictHostKeyChecking no" $compute logger "computetest_$time"
search=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -X GET "elasticsearch:9200/_search?q=computetest_${time}" | jq | grep computetest | grep -v "q=" | cut -d '"' -f 4 | xargs)
if [[ " $search " =~ "computetest_" ]]; then
  echo "Log collected from compute node";
else
  echo "Log collection from compute node failed"
  errs=$((errs+1))
  failures+=("Rsyslog Collects Compute Logs - Log collection from compute failed")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Rsyslog is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Rsyslog recently collected compute logs"

exit 0