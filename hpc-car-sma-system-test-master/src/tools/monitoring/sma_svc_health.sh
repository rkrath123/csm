#!/bin/bash
# set -x

# https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

count=3

function ping_service() {
	local svc=$1
	local pod=$2
	local namespace=$3

	local errs=0
	kubectl -n ${namespace} exec -t ${pod} -- ping -c ${count} ${svc} >/dev/null 2>&1
	if [ "$?" -ne 0 ]; then
		echoerr "${svc} is not ok in ${pod}"
		errs=$((errs+1))
	fi
	return $errs
}

function list_all_services() {
	echo
	kubectl -n services get svc -owide | grep "grafana\|kibana\|sma-telemetry-api"
	echo
	kubectl -n sma get svc -owide

#	IFS=$'\n' 
#	echo
#	for line in `kubectl -n sma get svc --no-headers`
#	do
#		name=$(echo $line | awk '{print $1}')
#		kubectl -n sma describe svc ${name}
#		echo
#	done
}

show_shasta_config
echo

kubectl -n sma get pods -owide
echo
kubectl -n services get pods -owide | grep "grafana\|kibana\|sma-telemetry-api"
echo
list_all_services
echo

errs=0
IFS=$'\n' 

ping -c ${count} ${SMA_API_GATEWAY} >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
	echoerr "${SMA_API_GATEWAY} service is not healthy"
	errs=$((errs+1))
fi

pods=("cluster-kafka-0" "cluster-kafka-1" "cluster-kafka-2")
for pod in "${pods[@]}"; do
	ping_service "cluster-zookeeper-client" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi

	ping_service "cluster-kafka-brokers" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done
pods=()

pods=("cluster-zookeeper-0" "cluster-zookeeper-1" "cluster-zookeeper-2")
for pod in "${pods[@]}"; do
	ping_service "cluster-zookeeper-nodes" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done
pods=()

for pod in $(kubectl -n sma get pods | grep postgres-persister | grep -v postgres-persister-init |  awk '{ print $1 }'); do
	ping_service "cluster-kafka-bootstrap" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
	ping_service "craysma-postgres-cluster" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done

for pod in $(kubectl -n sma get pods | grep sma-ldms-aggr |  awk '{ print $1 }'); do
	ping_service "cluster-kafka-bootstrap.sma.svc.cluster.local" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done

for pod in $(kubectl -n sma get pods | grep rsyslog-aggregator |  awk '{ print $1 }'); do
	ping_service "cluster-kafka-bootstrap.sma.svc.cluster.local" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done

for pod in $(kubectl -n services get pods | grep kibana |  awk '{ print $1 }'); do
	ping_service "elasticsearch.sma.svc.cluster.local" $pod "services"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done

pods=("craysma-postgres-cluster-0" "craysma-postgres-cluster-1")
for pod in "${pods[@]}"; do
	ping_service "craysma-postgres-cluster" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi

	ping_service "craysma-postgres-cluster-repl" $pod "sma"
	if [ "$?" -ne 0 ]; then
		errs=$((errs+1))
	fi
done

# crayctl/files/group_vars/all/networks.yaml
all_ncn_nodes=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
svc="rsyslog-agg-service-nmn.local"
for node in ${all_ncn_nodes}; do
	ssh -o "StrictHostKeyChecking=no" ${node} "ping -c ${count} ${svc} >/dev/null 2>&1"
	if [ "$?" -ne 0 ]; then
		echoerr "${svc} is not ok on ${node}"
		errs=$((errs+1))
	fi
done

# for pod in $(kubectl -n services get pods | grep grafana | grep -v grafana-init | awk '{ print $1 }'); do
# 	ping_service "mysql.sma.services.cluster.local" $pod "services"
# 	if [ "$?" -ne 0 ]; then
# 		errs=$((errs+1))
# 	fi
# done

echo
if [ "$errs" -eq 0 ]; then
	echo "Services are healthy"
else
	echoerr "Services are not healthy"
fi

exit $errs

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
