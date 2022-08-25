#! /bin/bash
# set -x

nodes=${1:-"sms0[1-4]-nmn"}
top_sort_field=${2:-"RES"}
delay=10

output="NODE_STATS-`date +%Y%m%d.%H%M`.out"
pdsh -w $nodes "date; echo; ps ax" | dshbak > $output
while :
do
	pdsh -w $nodes "date; echo; free -gh; echo; vmstat -t; echo; top -o $top_sort_field -c -b -n1 | head -20; sleep $delay" | dshbak
done |& tee -a ${output}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
