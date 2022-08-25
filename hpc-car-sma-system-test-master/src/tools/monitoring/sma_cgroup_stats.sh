#!/bin/bash
# set -x

BINPATH=`dirname "$0"`
. $BINPATH/sma_tools

function usage()
{
    echo "usage: $0"
    echo
	cat <<EOF
* Cgroup memory stats

memory.limit_in_bytes: sets the maximum amount of user memory (including file cache).
memory.max_usage_in_bytes: the maximum memory used by processes in the cgroup (in bytes).
memory.usage_in_bytes: the total current memory usage by processes in the cgroup (in bytes)
	 
memory.failcnt: the number of times that the memory limit has reached the value set in memory.limit_in_bytes.
Reports the number of times that the memory limit has reached the value set in
memory.limit_in_bytes. When a memory cgroup hits a limit, failcnt increases and
memory under it will be reclaimed.
You can reset failcnt by writing 0 to failcnt file.
echo 0 > .../memory.failcnt

Each cgroup maintains a per cgroup LRU which has the same structure as
global VM. When a cgroup goes over its limit, we first try
to reclaim memory from the cgroup so as to make space for the new
pages that the cgroup has touched. If the reclaim is unsuccessful,
an OOM routine is invoked to select and kill the bulkiest task in the
cgroup. (See 10. OOM Control below.)
https://android.googlesource.com/kernel/msm/+/android-msm-flo-3.4-kitkat-mr1/Documentation/cgroups/memory.txt

memory.stat.cache: page cache memory, including tmpfs (shmem), in bytes
memory.stat.rss: anonymous and swap cache, not including tmpfs (shmem), in bytes
memory.stat.mapped_file: # of bytes of mapped file (includes tmpfs/shmem)

All mapped anon pages (RSS) and cache pages (Page Cache) are accounted.

RSS is the Resident Set Size and is used to show how much memory is allocated to that process and is in RAM. 
It does not include memory that is swapped out. It does include memory from shared libraries as long as the 
pages from those libraries are actually in memory. It does include all stack and heap memory.

The Page Cache accelerates many accesses to files on non volatile storage. This happens because, when it 
first reads from or writes to data media like hard drives, Linux also stores data in unused areas of memory, 
which acts as a cache. If this data is read again later, it can be quickly read from this cache in memory.

Only anonymous and swap cache memory is listed as part of ‘rss’ stat. This should not be confused with the true 
‘resident set size’ or the amount of physical memory used by the cgroup.
‘rss + mapped_file” will give you resident set size of cgroup.

memory.under_oom: 0 or 1 (if 1, the memory cgroup is under OOM, tasks may be stopped.)

memory.use_hierarchy: contains a flag (0 or 1) that specifies whether memory usage should be 
accounted for throughout a hierarchy of cgroups. If enabled (1), the memory subsystem reclaims 
memory from the children of and process that exceeds its memory limit. By default (0), the subsystem 
does not reclaim memory from a task's children.

References:

https://docs.fedoraproject.org/en-US/Fedora/16/html/Resource_Management_Guide/sec-memory.html
https://fabiokung.com/2014/03/13/memory-inside-linux-containers/
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/resource_management_guide/sec-memory
https://www.linuxatemyram.com/
https://www.thomas-krenn.com/en/wiki/Linux_Page_Cache_Basics
https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/memory.html

* Cgroup cpu stats

If your container is using multiple CPU cores and you want a convenient total usage number, you can run:
$ cat /sys/fs/cgroup/cpuacct/docker/$CONTAINER_ID/cpuacct.usage
> 45094018900 # total nanoseconds CPUs have been in use (45.09s)

setting cpu limits engages a different system through setting cpu.cfs_period_us and cpu.cfs_quota_us
$ cat /sys/fs/cgroup/cpu/docker/$CONTAINER_ID/cpu.stat
> nr_periods 565 # Number of enforcement intervals that have elapsed
> nr_throttled 559 # Number of times the group has been throttled
> throttled_time 12119585961 # Total time that members of the group were throttled, in nanoseconds (12.12 seconds)
average throttled time = throttled_time/nr_throttled

References:

https://medium.com/@betz.mark/understanding-resource-limits-in-kubernetes-cpu-time-9eff74d3161b
https://www.datadoghq.com/blog/how-to-collect-docker-metrics/
https://unix.stackexchange.com/questions/450748/calculating-cpu-usage-of-a-cgroup-over-a-period-of-time


See also:
systemd-cgtop
systemd-cgls
EOF
    exit 1
}

raw=false
while getopts hr option
do
    case "${option}"
    in
        h) usage;;
        r) raw=true;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

kubectl version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echoerr "unable to talk to kubectl"
	exit 3
fi

date=$(date '+%b %d %T')
errs=0
if [ "$raw" = false ] ; then

	if [[ $# -eq 0 ]] ; then
		echo "missing container"
		exit 1
	fi


	if [[ $# -eq 1 ]] ; then
		node=$(kubectl -n sma get pods -o wide | grep ${1} | awk '{ print $7 }')
		echo "cgroup memory/cpu resources used by ${1} on ${node}"
		echo ${date}

		# memory stats
		memory_limit_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
		use_hierarchical=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.use_hierarchy)
		oom_control=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.oom_control)

		usage_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes)
		tasks=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/pids/pids.current)

		max_usage_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes)
		failcnt=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.failcnt)
		under_oom=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.oom_control | grep under_oom | awk '{ print $2 }')
		last_modified_under_oom=$(kubectl -n sma exec $1 -t -- ls -l /sys/fs/cgroup/memory/memory.oom_control | awk '{ print $6 " " $7 " " $8}')

		cache_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep cache | head -n 1 | awk '{ print $2 }')
		rss_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep rss | head -n 1 | awk '{ print $2 }')
		mapped_bytes=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep mapped_file | head -n 1 | awk '{ print $2 }')

		# cpu stats
		start_time=$(kubectl -n sma exec $1 -t -- date +%s%N)
		start_usage=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/cpu/cpuacct.usage)
		sleep 1
		stop_time=$(kubectl -n sma exec $1 -t -- date +%s%N)
		stop_usage=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/cpu/cpuacct.usage)

		throttled_time=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/cpu/cpu.stat | grep throttled_time | awk '{ print $2 }')
		nr_throttled_time=$(kubectl -n sma exec $1 -t -- cat /sys/fs/cgroup/cpu/cpu.stat | grep nr_throttled | awk '{ print $2 }')

	else
		node=$(kubectl -n sma get pods -o wide | grep ${1} | awk '{ print $7 }')
		echo "cgroup memory/cpu resources used by ${1}/${2} on ${node}"
		echo ${date}

		# memory stats
		memory_limit_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
		use_hierarchical=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.use_hierarchy)
		oom_control=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.oom_control)

		usage_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes)
		tasks=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/pids/pids.current)

		max_usage_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes)
		failcnt=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.failcnt)
		under_oom=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.oom_control | grep under_oom | awk '{ print $2 }')
		last_modified_under_oom=$(kubectl -n sma exec $1 -c $2 -t -- ls -l /sys/fs/cgroup/memory/memory.oom_control | awk '{ print $6 " " $7 " " $8}')

		cache_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep cache | head -n 1 | awk '{ print $2 }')
		rss_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep rss | head -n 1 | awk '{ print $2 }')
		mapped_bytes=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/memory/memory.stat | grep mapped_file | head -n 1 | awk '{ print $2 }')

		# cpu stats
		start_time=$(kubectl -n sma exec $1 -c $2 -t -- date +%s%N)
		start_usage=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpuacct.usage)
		sleep 1
		stop_time=$(kubectl -n sma exec $1 -c $2 -t -- date +%s%N)
		stop_usage=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpuacct.usage)

		throttled_time=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpu.stat | grep throttled_time | awk '{ print $2 }')
		nr_throttled_time=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpu.stat | grep nr_throttled | awk '{ print $2 }')

#		cpu_user=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpuacct.stat | grep user | awk '{ print $2 }')
#		cpu_system=$(kubectl -n sma exec $1 -c $2 -t -- cat /sys/fs/cgroup/cpu/cpuacct.stat | grep system | awk '{ print $2 }')
	fi

else
	if [[ $# -eq 0 ]] ; then
		echo "missing pid"
		exit 1
	fi
	cgroup=$(cat /proc/$1/cgroup | grep memory | awk 'BEGIN { FS = ":" } ; { print $3 }')
	container=$(nsenter -t ${1} -u hostname)
	node=$(hostname)

	echo "cgroup memory resources used by ${node}/${container}"
	echo ${cgroup}
	echo ${date}
	memory_limit_bytes=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.limit_in_bytes)
	use_hierarchical=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.use_hierarchy)
	oom_control=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.oom_control)

	usage_bytes=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.usage_in_bytes)
	tasks=$(cat /sys/fs/cgroup/pids/${cgroup}/pids.current)

	max_usage_bytes=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.max_usage_in_bytes)
	failcnt=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.failcnt)
	under_oom=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.oom_control | grep under_oom | awk '{ print $2 }')
	last_modified_under_oom=$(ls -l /sys/fs/cgroup/memory/memory.oom_control | awk '{ print $6 " " $7 " " $8}')

	cache_bytes=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.stat | grep cache | head -n 1 | awk '{ print $2 }')
	rss_bytes=$(cat /sys/fs/cgroup/memory/${cgroup}/memory.stat | grep rss | head -n 1 | awk '{ print $2 }')
fi

if [[ ${use_hierarchial} -ne 0 ]] ; then
	errs=$((errs+1))
	printf "use_hierarchical: %'d\n" ${use_hierarchial}
	echo "Unexpected cgroup memory setting.  memory.use_hierarchy is enabled."
fi

if [[ ${oom_controll} -ne 0 ]] ; then
	errs=$((errs+1))
	printf "oom_control: %'d\n" ${oom_control}
	echo "Unexpected cgroup memory setting.  memory.oom_control is disabled."
fi

# bc is not installed on all systems?
# bash only does integer division
command -v bc >/dev/null 2>&1
if [ $? -eq 0 ]; then
	limit=$(bc -l <<< "($memory_limit_bytes) / 1000000000")
	usage=$(bc -l <<< "($usage_bytes) / 1000000000")
	cache=$(bc -l <<< "($cache_bytes) / 1000000000")
    rss=$(bc -l <<< "($rss_bytes) / 1000000000")
    mapped=$(bc -l <<< "($mapped_bytes) / 1000000000")
	max_usage=$(bc -l <<< "($max_usage_bytes) / 1000000000")

	printf "limit: %'.2f %s\n" ${limit} "Gi"
	printf "usage: %'.2f %s\n" ${usage} "Gi"
	printf "rss: %'.2f %s\n" ${rss} "Gi"
	printf "cache: %'.2f %s\n" ${cache} "Gi"
	printf "mapped_file: %'.2f %s\n" ${mapped} "Gi"
	printf "tasks: %'d\n" ${tasks}
	printf "max_usage: %'.2f %s\n" ${max_usage} "Gi"
	printf "failcnt: %'d\n" ${failcnt}
	printf "under_oom: %'d last modified= %'s\n" "${under_oom}" "${last_modified_under_oom}"

	cpu_usage=$(bc -l <<< "($stop_usage - $start_usage) / ($stop_time - $start_time) * 100")
	avg_throttled_time=0
	if [ "$nr_throttled_time" -gt 0 ]; then
		avg_throttled_time=$(((throttled_time / nr_throttled_time) / 1000000000))
	fi
	throttled_time_secs=$((throttled_time / 1000000000))

	printf "cpu usage: %'.2f%s\n" ${cpu_usage} "%"
	printf "throttled time: %'.2f %s\n" ${throttled_time_secs} "secs"
	printf "numof throttled: %'d\n" ${nr_throttled_time}
	printf "avg throttled time: %'.2f %s\n" ${avg_throttled_time} "secs"
else
	printf "limit: %'d %s\n" ${memory_limit_bytes} "bytes"
	printf "usage: %'d %s\n" ${usage_bytes} "bytes"
	printf "rss: %'d %s\n" ${rss_bytes} "bytes"
	printf "cache: %'.d %s\n" ${cache_bytes} "bytes"
	printf "mapped_file: %'.d %s\n" ${mapped_bytes} "bytes"
	printf "tasks: %'d\n" ${tasks}
	printf "max_usage: %'.d %s\n" ${max_usage_bytes} "bytes"
	printf "failcnt: %'d\n" ${failcnt}
	printf "under_oom: %'d last modified= %'s\n" "${under_oom}" "${last_modified_under_oom}"

	throttled_time_secs=$((throttled_time / 1000000000))
 
 	printf "throttled time: %'d %s\n" ${throttled_time_secs} "secs"
	printf "numof throttled: %'d\n" ${nr_throttled_time}
fi

if [ "$errs" -gt 0 ]; then
	echo
	echo "Unexpected cgroup memory settings"
fi
exit ${errs}

# vim:shiftwidth=4:softtabstop=4:tabstop=4:
