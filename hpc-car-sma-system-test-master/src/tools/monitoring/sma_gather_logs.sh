#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

DATE=`date +'%Y%m%d.%H%M'`

kube_opts="--timestamps --all-containers"

while getopts p option
do
	case "${option}"
	in
		p) kube_opts+="--previous";;
	esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "$1" ]; then
	output=sma-CONTAINER_LOGS-${DATE}.out
else
	output=$1
fi

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

date > $output
show_build >> $output
echo >> $output

sma_pods=()

# get sma pods
get_pods=$(kubectl -n ${SMA_NAMESPACE} get pods --output=jsonpath={.items..metadata.name})
if [ -z "$get_pods" ]; then
	echo "no pods in sma namespace found"
else
	for pod in $get_pods
	do
		contains_element $pod "${SMA_SKIP_PODS[@]}"
		if [ "$?" -eq 0 ]; then
			sma_pods+=( $pod )
		fi
	done
fi

# Get pods of interest from the services namespace
get_pods=$(kubectl -n services get pods --output=jsonpath={.items..metadata.name})
if [ -z "$get_pods" ]; then
	echo "no pods in services namespace found"
fi
for pod in $get_pods
do
	contains_element $pod "${SMA_SERVICES_PODS[@]}"
	if [ "$?" -eq 1 ]; then
		sma_pods+=( $pod )
	fi
done

for pod in "${sma_pods[@]}"
do
	namespace="sma"
	contains_element $pod "${SMA_SERVICES_PODS[@]}"
	if [ "$?" -eq 1 ]; then
		namespace="services"
    fi

	phase=$(kubectl -n ${namespace} get pod ${pod} --output=jsonpath={.status.phase})
	echo >> $output
	echo "----- ${pod}" |& tee -a $output
	if [ "$phase" != "Succeeded" ]; then
		echo "kubectl -n ${namespace} logs $kube_opts $pod" >> $output
		kubectl -n ${namespace} logs $kube_opts $pod >> $output 2>&1
	fi
done

if [ -z "$1" ]; then
	echo "DONE: $output"
fi

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
