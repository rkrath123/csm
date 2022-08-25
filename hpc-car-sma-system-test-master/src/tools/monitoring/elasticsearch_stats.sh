#! /bin/bash
# set -x

delay=120

cluster_host="venom-sms.us.cray.com"
output="ELASTICSEARCH_STATS-`date +%Y%m%d.%H%M`.out"
kubectl -n sma get pods -o wide > $output

while :
do
	date; echo; curl -s -XGET "http://${cluster_host}:30200/_cluster/stats?pretty=true"; echo; curl -s -XGET "http://${cluster_host}:30200/_cat/indices?v"; sleep $delay
done |& tee -a ${output}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
