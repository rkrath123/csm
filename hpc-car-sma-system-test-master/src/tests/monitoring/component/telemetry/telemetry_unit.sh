#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level unit test for the Telemetry API in Cray's Shasta System Monitoring Application."
    echo "The test focuses on the ability to fetch data using the API."
    echo "$0 > sma_component_telemetry_unit-\`date +%Y%m%d.%H%M\`"
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

###################
telempod=$(kubectl -n services get pods | grep telemetry | grep -v test | head -n 1 | cut -d ' ' -f 1);

###################
#Test Case: Telemetry Unit Test
#   The telemetry pod has unit tests included that test the api output
unitout=$(kubectl -n services exec -it ${telempod} -- python /test/unit_test_jenkins.py | grep OK)
if [[ "$unitout" =~ "OK" ]]; then
  echo "Telemetry Unit Tests Pass";
else
  echo "Telemetry Unit Test Failure"
  errs=$((errs+1))
  failures+=("Telemetry Unit Tests - Unit Test Failure")
fi

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Telemetry API is not healthy"
        echo $errs "error(s) found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Telemetry unit test passes"

exit 0