#!/bin/bash
# Copyright 2021 Hewlett Packard Enterprise Development LP
# set -x

function usage()
{
    echo "usage: $0"
    echo
    echo "This test for Cray's System Monitoring Application "
    echo "checks the pod memory, %cpu, processes, and storage usage."
    echo "$0 > sma_component_monasca_resources-\`date +%Y%m%d.%H%M\`"
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

monascapod=$(kubectl -n sma get pods | grep monasca-agent | head -n 1 | cut -d " " -f 1)

###################
#
echo "------ mpstat"
# The mpstat command writes to standard output activities for each available processor
# -u reports CPU utilization, displaying the following:
# CPU: Processor number. The keyword all indicates that statistics are calculated as averages among all processors.
# %usr: the percentage of CPU utilization that occurred while executing at the user level (application).
# %nice: the percentage of CPU utilization that occurred while executing at the user level with nice priority.
# %sys: the percentage of CPU utilization that occurred while executing at the system level (kernel). Note that this does not include time spent servicing hardware and software interrupts.
# %iowait: the percentage of time that the CPU or CPUs were idle during which the system had an outstanding disk I/O request.
# %irq: the percentage of time spent by the CPU or CPUs to service hardware interrupts.
# %soft: the percentage of time spent by the CPU or CPUs to service software interrupts.
# %steal: the percentage of time spent in involuntary wait by the virtual CPU or CPUs while the hypervisor was servicing another virtual processor.
# %guest: the percentage of time spent by the CPU or CPUs to run a virtual processor.
# %idle: the percentage of time that the CPU or CPUs were idle and the system did not have an outstanding disk I/O request.
mpstatusr=$(mpstat -u | grep -v CPU | awk {'print $4'} | cut -d "." -f 1);
  if [[ $mpstatusr -lt 70 ]]; then
    echo "mpstat reports total user level CPU utilization is $mpstatusr%";
  else
    errs=$((errs+1))
    failures+=("Warning: mpstat reports total user level CPU utilization is $mpstatusr%")
  fi
echo

echo "------ pidstat"
#The pidstat command is used for monitoring individual tasks currently being managed by the Linux kernel.
# -u reports CPU utilization by process. -C limits the command names displayed.
# -l, not used here, will provide command names and all arguments should that be needed for troubleshooting.
pidstat -u -C "python|influx|java|docker|mysql"
echo

echo "------ elasticsearch-curator mpstat"
# The mpstat command writes to standard output activities for each available processor
# -u reports CPU utilization
# The pods supporting the command are checked with it below.
escurator=$(kubectl -n sma get pods|awk {'print $1'}|grep elasticsearch-curator)
usr=0; usr=$(kubectl -n sma exec -it $escurator -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$escurator application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $escurator application level CPU utilization is $usr%")
fi
echo

echo "------ elastalert mpstat"
elastalert=$(kubectl -n sma get pods|awk {'print $1'}|grep elastalert)
usr=0; usr=$(kubectl -n sma exec -it $elastalert -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$elastalert application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $elastalert application level CPU utilization is $usr%")
fi
echo

echo "------ monasca-agents mpstat"
for monagent in $(kubectl -n sma get pods|awk {'print $1'}|grep monasca-agent);
  do usr=0;
  usr=$(kubectl -n sma exec -it $monagent -c forwarder -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
    if [[ $usr -lt 70 ]]; then
      echo "$monagent forwarder application level CPU utilization is $usr%";
    else
      errs=$((errs+1))
      failures+=("Warning: $monagent forwarder application level CPU utilization is $usr%")
    fi
    echo
    usr=0; usr=$(kubectl -n sma exec -it $monagent -c collector -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
    if [[ $usr -lt 70 ]]; then
      echo "$monagent collector application level CPU utilization is $usr%";
    else
      errs=$((errs+1))
      failures+=("Warning: $monagent collector application level CPU utilization is $usr%")
    fi
    echo;
  done

echo "------ monasca-api api mpstat"
monapi=$(kubectl -n sma get pods|awk {'print $1'}|grep monasca-api)
usr=0; usr=$(kubectl -n sma exec -it $monapi -c api -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$monapi api application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $monapi api application level CPU utilization is $usr%")
fi
echo

echo "------ monasca-api sidecar mpstat"
monapi=$(kubectl -n sma get pods|awk {'print $1'}|grep monasca-api)
usr=0; usr=$(kubectl -n sma exec -it $monapi -c sidecar -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$monapi sidecar application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $monapi sidecar application level CPU utilization is $usr%")
fi
echo

echo "------ monasca-memcached mpstat"
memcached=$(kubectl -n sma get pods|awk {'print $1'}|grep monasca-memcached)
usr=0; usr=$(kubectl -n sma exec -it $memcached -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$memcached application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $memcached application level CPU utilization is $usr%")
fi
echo

echo "------ monasca-thresh-node mpstat"
threshnode=$(kubectl -n sma get pods|awk {'print $1'}|grep thresh-node)
usr=0; usr=$(kubectl -n sma exec -it $threshnode -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$threshnode application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $threshnode application level CPU utilization is $usr%")
fi
echo

echo "------ monasca-thresh-metrics mpstat"
threshmetric=$(kubectl -n sma get pods|awk {'print $1'}|grep thresh-metrics)
usr=0; usr=$(kubectl -n sma exec -it $threshmetric -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$threshmetric application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $threshmetric application level CPU utilization is $usr%")
fi
echo

echo "------ pgdb-prune mpstat"
pgdbprune=$(kubectl -n sma get pods|awk {'print $1'}|grep pgdb-prune)
usr=0; usr=$(kubectl -n sma exec -it $pgdbprune -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "$pgdbprune application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: $pgdbprune application level CPU utilization is $usr%")
fi
echo

echo "------ postgres pods mpstat"
usr=0; usr=$(kubectl -n sma exec -it sma-postgres-cluster-0 -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "sma-postgres-cluster-0 application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: sma-postgres-cluster-0 application level CPU utilization is $usr%")
fi
echo
usr=0; usr=$(kubectl -n sma exec -it sma-postgres-cluster-1 -- mpstat -u |grep all |awk {'print $4'} | cut -d "." -f 1)
if [[ $usr -lt 70 ]]; then
  echo "sma-postgres-cluster-1 application level CPU utilization is $usr%";
else
  errs=$((errs+1))
  failures+=("Warning: sma-postgres-cluster-1 application level CPU utilization is $usr%")
fi
echo

######################################
# Test results
if [ "$errs" -gt 0 ]; then
        echo
        echo  "Resource use is outside expected range"
        echo $errs "High utilization found."
        printf '%s\n' "${failures[@]}"

        exit 1
fi

echo
echo "Resources usage is within expected range"

exit 0