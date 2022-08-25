#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for rsyslog in Cray's Shasta System Monitoring Application"
    echo "verifies the ability to send ncn log messages to kafka/elasticsearch."
    echo "$0 > sma_component_rsyslog_ncn_log-\`date +%Y%m%d.%H%M\`"
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
#Test Case: Rsyslog Collects NCN Logs
time=$(date +%s)
ssh ncn-w002 logger "ncntest_$time"
search=$(kubectl -n sma exec -it cluster-kafka-0 -c kafka -- curl -X GET "elasticsearch:9200/_search?q=ncntest_${time}" | jq | grep ncntest | grep -v "q=" | cut -d '"' -f 4 | xargs)
if [[ " $search " =~ "ncntest_" ]]; then
  echo "Log collected from ncn";
else
  echo "Log collection from ncn failed"
  errs=$((errs+1))
  failures+=("Rsyslog Collects NCN Logs - Log collection from ncn failed")
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
echo "Rsyslog recently collected ncn logs"

exit 0