#!/bin/bash
# set -o xtrace
# set -o errexit
set -o nounset
set -o pipefail

BINPATH=`dirname "$0"`
. ${BINPATH}/sma_tools

quick=false
while getopts q option
do
    case "${option}"
    in
        q) quick=true;;
    esac
done

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "unable to talk to kubectl"
  exit 3
fi

errs=0
restarts=0

function contains_element() {
	local match="$1"
	shift
	local arr=("$@")
	for e in "${arr[@]}"; do
		if echo "$match" | grep ${e} > /dev/null; then
			return 1
		fi
	done
	return 0
}

sma_pods=()

# Get pods of interest from the sma namespace
get_pods=$(kubectl -n ${SMA_NAMESPACE} get pods --output=jsonpath={.items..metadata.name})
if [ -z "$get_pods" ]; then
	echo "no pods in sma namespace found"
	exit 1
fi
for pod in $get_pods
do
	contains_element $pod "${SMA_SKIP_PODS[@]}"
	if [ "$?" -eq 0 ]; then
		sma_pods+=( $pod )
	fi
done

# Get pods of interest from the services namespace
get_pods=$(kubectl -n services get pods --output=jsonpath={.items..metadata.name})
if [ -z "$get_pods" ]; then
	echo "no pods in services namespace found"
	exit 1
fi
for pod in $get_pods
do
  	contains_element $pod "${SMA_SERVICES_PODS[@]}"
	if [ "$?" -eq 1 ]; then
		sma_pods+=( $pod )
	fi
done

# Pod status
#
# Pending	The Pod has been accepted by the Kubernetes system, but one or more of the Container images has not been created.
# This includes time before being scheduled as well as time spent downloading images over the network, which could take a while.
#
# Running	The Pod has been bound to a node, and all of the Containers have been created. At least one Container is still 
# running, or is in the process of starting or restarting.
#
# Succeeded	All Containers in the Pod have terminated in success, and will not be restarted.
#
# Failed	All Containers in the Pod have terminated, and at least one Container has terminated in failure. 
# That is, the Container either exited with non-zero status or was terminated by the system.
#
# Unknown	For some reason the state of the Pod could not be obtained, typically due to an error in communicating 
# with the host of the Pod.

for pod in "${sma_pods[@]}"
do

	namespace="sma"
  	contains_element $pod "${SMA_SERVICES_PODS[@]}"
	if [ "$?" -eq 1 ]; then
		namespace="services"
	fi

	# check pod status
	phase=$(kubectl -n ${namespace} get pod ${pod} --output=jsonpath={.status.phase})
	restart_count=0

	# special case init pods
	for init in "${SMA_INIT_PODS[@]}"; do
		if echo "$pod" | grep ${init} > /dev/null; then
			expected_phase="Succeeded"
			if [ "$phase" == "$expected_phase" ]; then
				echo "$pod..ok"
			else
				echo "$pod...$phase (should be $expected_phase)"
				errs=$((errs+1)) 
			fi
			continue 2
		fi
	done

	expected_phase="Running"
	if [ "$phase" == "$expected_phase" ]; then

		# pod is running, check status of containers in the pod
		status=$(kubectl -n ${namespace} get pod ${pod} --no-headers | awk '{ print $3 }')

		if [ "$status" != "Running" ]; then
			name=$(kubectl -n ${namespace} get pod ${pod} --output=jsonpath={.status.containerStatuses[*].name})
			ready=$(kubectl -n ${namespace} get pod ${pod} --no-headers | awk '{ print $2 }')
			echo "$pod...not ok ($ready container(s) are ready)"
			errs=$((errs+1)) 
		else
			restart_count=$(kubectl -n ${namespace} get pod ${pod} --no-headers | awk '{ print $4 }')
			if [ "$restart_count" -gt 0 ]; then
				echo "$pod..ok (restarts=$restart_count)"
			else
				echo "$pod..ok"
			fi
		fi
	else
		echo "$pod...$phase (should be $expected_phase)"
		errs=$((errs+1)) 
	fi

	# accumulate restart counts
	restarts=$((restarts+restart_count)) 

done

if [ "$quick" = false ] ; then
	echo
	for cmd in "${SMA_HEALTH_CHECKS[@]}"
	do
		${cmd} >/dev/null 2>&1
		health_check=$(basename ${cmd} .sh)
		if [ "$?" -ne 0 ]; then
			echo "$health_check..not ok"
			errs=$((errs+1)) 
		else
			echo "$health_check..ok"
		fi
	done
fi

echo
if [ "$errs" -gt 0 ] || [ "$restarts" -gt 0 ]; then
	echo "SMA status...failed (errs=$errs restarts=$restarts)"
	if [ "$errs" -gt 0 ]; then
		exit 1
	else
		exit 0
	fi
fi
echo "SMA status...ok"
exit 0

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
