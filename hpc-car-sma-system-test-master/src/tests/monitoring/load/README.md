
# SMA load testing

## Load testing SMF log aggregation with tcpflood

tcpflood is a testing tool of the rsyslog testbench which 
is able to send a lot of messages via tcp.
The tool has many command line options.  For load testing a 
proper set of options must be selected.  The option set is kept 
inside script files for easier test 
reproduction at later times.


### In scope

```
Sharp increase of log message rates from one or multiple nodes over longer periods of time.
Rate per second of logs being delivered to SMF infrastructure.
SMS node resources used; memory and cpu.
Elasticsearch disk usage.
Automated load testing of log aggregation in SMF nightly CICT.
```


### Out of scope

```
Test hardware is limited to venom, four compute and four SMS nodes but test cases should scale to larger configurations.
Load testing should create artificial usage that mimics real usage.  There is no data available on expected log message rates.
Load testing should generate a steady of log messages for much longer periods (days).
Rate and resource statistics for reading log messages from Elasticsearch storage.
```


## Running the tests


### Collect resource statistics from SMS nodes


The node_stats script captures memory stats (free, top -o RES and vmstat) from the SMS nodes.
Start collecting memory stats before running the test.  Output is sent
to stdout and a dated output file (node_stats-`date +%Y%m%d.%H%M`.out).  Use cntl-C to stop the 
collection or kill the script process if started with nohup.
The downside of this script is the more to monitor, the longer the resulting output and sifting through all of that JSON, 
it can be difficult to identify problematic nodes and spot troubling trends.
It would be better if we collected these statistics from LDMS samplers running
on the SMS nodes (SMA-4398) and view the statistics in grafana.


```
$ . /root/sma-sos/sma_tools
$ nohup node_stats.sh
$ nohup elasticsearch_stats.sh
```


By default, node_stats will collect from four (sms0[1-4]-nmn) SMS nodes.

The elasticsearch_stats script uses the Elasticsearch cluster stats API to add together all
the stats from each node in the cluster.  The output provides basic statistics
about the nodes in the Elasticsearch cluster (memory usage, file system info).


### Test cases


The tcpflood option set is kept inside script files for easier test
reproduction at later times.


### tcpflood_1node_burst.sh

```
The tested volume is a burst of 1 million messages on 1 compute node.
```

### tcpflood_2nodes_burst.sh

```
The tested volume is a burst of 1 million messages on 2 compute nodes.
```

### tcpflood_4nodes_burst.sh

```
The tested volume is a burst of 1 million messages on 4 compute nodes.
```

### tcpflood_1node_24hrun.sh

```
The tested volume is a steady rate of messages from 1 compute node for 24 hours.
```

### tcpflood_2nodes_24hrun.sh

```
The tested volume is a steady rate of messages from 2 compute nodes for 24 hours.
```

### tcpflood_4nodes_24hrun.sh

```
The tested volume is a steady rate of messages from 4 compute nodes for 24 hours.
```
