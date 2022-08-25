#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "unable to talk to kubectl"
	exit 3
fi

show_shasta_config
echo
kubectl get pods -A -owide | grep grafana
kubectl get pods -A -owide | grep kibana

errs=0

echo
grafana_health=$(curl -s -S -XGET "${SMA_API_GATEWAY}/sma-grafana/api/health?pretty=true")
if [ $? -ne 0 ]; then
	echoerr "Grafana is not healthy - failed to access"
	errs=$((errs+1))
else
	echo ${grafana_health}
	database=$(echo ${grafana_health} | jq '.database' 2>/dev/null)
	echo ${database} | grep ok >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "Grafana looks healthy"
	else
		echoerr "Grafana is not healthy - database is not ok"
		errs=$((errs+1))
	fi
fi

echo
pod=$(kubectl -n services get pods | grep grafana |  grep -v init | awk '{ print $1 }')
echo "Grafana RES Mem"
kubectl -n services exec ${pod} -c sma-grafana -- sh -c 'COLUMNS=1000 top -o RES -U grafana -c -n 1 -b | grep -v top'
if [ $? -eq 0 ]; then
	err=$((err+1))
fi

echo
kibana_health=$(curl -s -S -XGET "${SMA_API_GATEWAY}/sma-kibana/api/status?pretty=true")
if [ $? -ne 0 ]; then
	echoerr "Kibana is not healthy - failed to access"
	errs=$((errs+1))
else
	echo ${kibana_health} | jq .
	state=$(echo ${kibana_health} | jq .status.overall.state)
	echo ${state} | grep green >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "Kibana looks healthy"
	else
		echoerr "Kibana is not healthy - status is not green"
		errs=$((errs+1))
	fi
fi

echo
pod=$(kubectl -n services get pods | grep kibana | awk '{ print $1 }')
echo "Kibana RES Mem"
kubectl -n services exec ${pod} -c sma-kibana -- sh -c 'COLUMNS=1000 top -o RES -U kibana -c -n 1 -b | grep -v top'

echo
if [ "$errs" -eq 0 ]; then
	echo "UI looks healthy"
else
	echoerr "UI is not healthy"
fi

exit ${errs}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
