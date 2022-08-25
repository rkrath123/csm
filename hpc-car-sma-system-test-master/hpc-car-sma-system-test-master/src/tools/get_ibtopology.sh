#!/bin/bash
# set -x 

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

# show_version

# Set field separator to new-line.
IFS=$'\n'

ibstatus
for LINE in `ibstatus | grep Infiniband`
do
	CA=`echo $LINE | sed s/\'//g | awk '{ print $3 }'`
 	PORT=`echo $LINE | sed s/\'//g | awk '{ print $5 }'`
	ibnetdiscover -C $CA -P $PORT
done

num_recv_bytes=$(influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_recv_bytes_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_xmit_bytes=$(influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_xmit_bytes_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_recv_pkts=$(influx --database 'mon'  --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_recv_pkts_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)
num_xmit_pkts=$(influx --database 'mon'  --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_xmit_pkts_sec/ WHERE time > now() - 5m group by guid, port limit 1" | grep "tags:" | wc -l)

echo
echo "Num of endpoints= ${num_recv_bytes} ( ${num_xmit_bytes}, ${num_recv_pkts}, ${num_xmit_pkts} )"
# influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.port_recv_bytes_sec/ WHERE time > now() - 5m group by type, node, lid, guid, port limit 1" | grep "tags:" | sed 's/tags: //g'
# influx --database 'mon' --host 'localhost' --precision 'rfc3339' --execute "select value FROM /cray_ib.topology/ WHERE time > now() - 2h"
