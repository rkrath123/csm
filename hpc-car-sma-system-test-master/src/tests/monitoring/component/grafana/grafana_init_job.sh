#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
#set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This component-level test for the Grafana visualization tool in Cray's Shasta System Monitoring Application"
    echo "tests that the init job completed."
    echo "$0 > sma_component_grafana_init_job-\`date +%Y%m%d.%H%M\`"
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
# Test case: Grafana-init Job Completed
initjob=$(kubectl -n services get jobs | grep sma-svc-init | awk '{print $1}');
jobstatus=$(kubectl -n services get jobs | grep sma-svc-init | awk '{print $2}');

if [[ "$initjob" =~ "sma-svc-init" ]]; then
  if [[ "$jobstatus" =~ "1/1" ]]; then
    echo "$initjob Completed";
  else
    echo "$initjob is $jobstatus"
    errs=$((errs+1))
    failures+=("Grafana pod - $initjob is $jobstatus")
  fi
else
  echo "sma-init-job is missing"
  errs=$((errs+1))
  failures+=("Grafana Init Job - sma-svc-init is missing")
fi


######################################
# Test results
if [ "$errs" -gt 0 ]; then
	echo
	echo "Grafana is not healthy"
	echo $errs "error(s) found."
	printf '%s\n' "${failures[@]}"
	exit 1
fi

echo
echo "Grafana init job completed successfully"

exit 0