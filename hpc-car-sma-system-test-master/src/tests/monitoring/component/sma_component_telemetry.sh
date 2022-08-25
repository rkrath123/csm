#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This is the component-level test for the Telemetry API in Cray's Shasta System Monitoring Application."
    echo "The test focuses on verification of a valid initial state, and of the ability to fetch data using the API."
    echo "$0 > sma_component_telemetry-\`date +%Y%m%d.%H%M\`"
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
#Test Case: Telemetry Pod Exists in SMA Namespace
declare -a pods
declare -A podstatus
declare -A podnode

# get pod name, status, and the node on which each resides
for i in $(kubectl -n services get pods | grep telemetry | awk '{print $1}');
    do pods+=($i);
    status=$(kubectl -n services --no-headers=true get pod $i | awk '{print $3}');
    podstatus[$i]=$status;
    node=$(kubectl -n services --no-headers=true get pod $i -o wide| awk '{print $7}');
    podnode[$i]=$node;
done

if [[ " ${pods[@]} " =~ "sma-telemetry-" ]]; then
  for i in $(seq 1 ${#pods[@]});
    do if [[ " ${pods[$i]} " =~ "sma-telemetry-" ]]; then
      if [[ " ${podstatus[${pods[$i]}]} " =~ "Running" ]]; then
        echo "${pods[$i]} is Running";
      else
        echo "${pods[$i]} is ${podstatus[${pods[$i]}]}"
        errs=$((errs+1))
        failures+=("Telemetry Pods - ${pods[$i]} is ${podstatus[${pods[$i]}]}")
      fi
    fi
  done
else
  echo "telemetry pods are missing"
  errs=$((errs+1))
  failures+=("Telemetry Pods - sma-telemetry pods are missing")
fi

unset pods
unset podstatus
unset podnode

###################
#Test Case: Telemetry is Running as a K8S Service
service=$(kubectl -n services get svc | grep telemetry | awk '{print $1}')
if [[ "$service" =~ "sma-telemetry" ]]; then
  echo "$service is available";
else
  echo "sma-telemetry service is missing"
  errs=$((errs+1))
  failures+=("Telemetry Service - sma-telemetry service is missing")
fi

###################
#Test Case: Gateway DNS is resolvable
ping=$(kubectl -n services exec -it ${telempod} -- ping -c 1 api-gw-service-nmn.local|grep "packet loss" | cut -d "," -f 3 | xargs);
if [[ "$ping" =~ "0% packet loss" ]]; then
  echo "Gateway DNS is resolvable";
else
  echo "Gateway DNS is unresolvable"
  errs=$((errs+1))
  failures+=("Telemetry Gateway - Gateway DNS is resolvable")
fi

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
echo "Telemetry API looks healthy"

exit 0